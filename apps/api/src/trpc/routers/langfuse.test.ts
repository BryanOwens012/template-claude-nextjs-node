import assert from 'node:assert/strict';
import http from 'node:http';
import { after, before, describe, it } from 'node:test';
import type { createContext } from '@/trpc/init.js';

// The procedures under test never read the Express request or response.
const emptyContext = { req: {}, res: {} } as unknown as ReturnType<typeof createContext>;

// A stand-in for OpenRouter's chat-completions endpoint on an ephemeral port. It records
// every request so the tests can assert the exact wire shape the scaffold sends (the part
// no typecheck can see), and answers with canned completions whose usage carries
// OpenRouter's cached-token and cost fields, so the mapping back into the AI SDK result
// is checked too. Nothing here reaches the network.
type RecordedRequest = { headers: http.IncomingHttpHeaders; body: Record<string, unknown> };

const requests: RecordedRequest[] = [];
let replies: Array<Record<string, unknown>> = [];

const textReply = (text: string) => ({
  id: 'gen-fake',
  object: 'chat.completion',
  model: 'anthropic/claude-haiku-4.5',
  choices: [{ index: 0, message: { role: 'assistant', content: text }, finish_reason: 'stop' }],
  usage: {
    prompt_tokens: 1500,
    completion_tokens: 12,
    total_tokens: 1512,
    prompt_tokens_details: { cached_tokens: 1024 },
    cost: 0.000123,
  },
});

const toolCallReply = (city: string) => ({
  id: 'gen-fake-tool',
  object: 'chat.completion',
  model: 'anthropic/claude-haiku-4.5',
  choices: [
    {
      index: 0,
      message: {
        role: 'assistant',
        content: null,
        tool_calls: [
          {
            id: 'call_1',
            type: 'function',
            function: { name: 'getCurrentWeather', arguments: JSON.stringify({ city }) },
          },
        ],
      },
      finish_reason: 'tool_calls',
    },
  ],
  usage: { prompt_tokens: 100, completion_tokens: 20, total_tokens: 120 },
});

const server = http.createServer((req, res) => {
  const chunks: Buffer[] = [];
  req.on('data', (c: Buffer) => chunks.push(c));
  req.on('end', () => {
    requests.push({ headers: req.headers, body: JSON.parse(Buffer.concat(chunks).toString()) });
    const reply = replies.shift() ?? textReply('fallback');
    const data = JSON.stringify(reply);
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data),
    });
    res.end(data);
  });
});

// The env singleton is read on the first procedure call, so everything it needs is set
// before the router is imported (dynamically, below) and never changed afterwards.
let callTraceExample: (input: { prompt?: string; sessionId?: string }) => Promise<{
  text: string;
  usage: Record<string, unknown>;
  toolCalls: Array<{ tool: string; input: unknown; output: unknown }>;
  sessionId: string;
  model: string;
}>;

before(async () => {
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  assert.ok(address && typeof address === 'object');
  process.env.SUPABASE_URL = 'https://placeholder.supabase.co';
  process.env.SUPABASE_SECRET_KEY = 'sb_secret_placeholder';
  process.env.OPENROUTER_API_KEY = 'sk-or-v1-test-key';
  process.env.OPENROUTER_BASE_URL = `http://127.0.0.1:${address.port}/api/v1`;

  const { createCallerFactory } = await import('@/trpc/init.js');
  const { langfuseRouter } = await import('./langfuse.js');
  const caller = createCallerFactory(langfuseRouter)(emptyContext);
  callTraceExample = (input) => caller.traceExample(input);
});

after(() => {
  server.close();
});

const lastRequest = () => {
  const r = requests.at(-1);
  assert.ok(r, 'the stand-in received no request');
  return r;
};

describe('langfuse.traceExample through OpenRouter', () => {
  it('sends the OpenRouter wire shape: model id, top-level cache_control, session_id, usage accounting, tools, bearer key', async () => {
    replies = [textReply('It is 68°F in Paris.')];
    const result = await callTraceExample({
      prompt: 'Weather in Paris?',
      sessionId: 'session-abc',
    });

    const { headers, body } = lastRequest();
    assert.equal(headers.authorization, 'Bearer sk-or-v1-test-key');
    assert.equal(body.model, 'anthropic/claude-haiku-4.5');
    assert.deepEqual(body.cache_control, { type: 'ephemeral' });
    assert.equal(body.session_id, 'session-abc');
    assert.deepEqual(body.usage, { include: true });
    const tools = body.tools as Array<{ function: { name: string } }>;
    assert.equal(tools.length, 1);
    assert.equal(tools[0]?.function.name, 'getCurrentWeather');
    assert.equal(result.model, 'anthropic/claude-haiku-4.5');
    assert.equal(result.sessionId, 'session-abc');
    assert.equal(result.text, 'It is 68°F in Paris.');
  });

  it('maps OpenRouter cached tokens and cost back onto the result', async () => {
    replies = [textReply('cached answer')];
    const result = await callTraceExample({ prompt: 'again', sessionId: 'session-abc' });

    assert.equal(result.usage.inputTokens, 1500);
    assert.equal(result.usage.outputTokens, 12);
    assert.equal(result.usage.cachedInputTokens, 1024);
    const openrouter = result.usage.openrouter as { cost?: number; totalTokens?: number };
    assert.equal(openrouter.cost, 0.000123);
    assert.equal(openrouter.totalTokens, 1512);
  });

  it('generates a session id when the client sends none, and uses it for OpenRouter too', async () => {
    replies = [textReply('ok')];
    const result = await callTraceExample({ prompt: 'no session' });

    assert.match(result.sessionId, /^anon-[0-9a-f-]{36}$/);
    assert.equal(lastRequest().body.session_id, result.sessionId);
  });

  it('treats an empty session id the same as a missing one', async () => {
    replies = [textReply('ok')];
    const result = await callTraceExample({ prompt: 'empty session', sessionId: '' });

    assert.match(result.sessionId, /^anon-/);
  });

  it('runs the tool round trip: tool call, local execution, final answer, with the call reported', async () => {
    replies = [toolCallReply('Paris'), textReply('It is 68°F and partly cloudy in Paris.')];
    const seenSoFar = requests.length;
    const result = await callTraceExample({ prompt: 'Weather in Paris?', sessionId: 'tools' });

    assert.equal(
      requests.length - seenSoFar,
      2,
      'one request for the tool call, one for the answer',
    );
    assert.equal(result.text, 'It is 68°F and partly cloudy in Paris.');
    assert.equal(result.toolCalls.length, 1);
    assert.equal(result.toolCalls[0]?.tool, 'getCurrentWeather');
    assert.deepEqual(result.toolCalls[0]?.input, { city: 'Paris' });
    assert.deepEqual(result.toolCalls[0]?.output, {
      city: 'Paris',
      temperature: 68,
      unit: '°F',
      condition: 'Partly cloudy',
      humidity: '62%',
    });
    // The second request carries the tool result back to the model.
    const secondBody = lastRequest().body as { messages: Array<{ role: string }> };
    assert.ok(secondBody.messages.some((m) => m.role === 'tool'));
  });
});
