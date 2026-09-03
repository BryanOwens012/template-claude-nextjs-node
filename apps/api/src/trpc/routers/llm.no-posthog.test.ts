import assert from 'node:assert/strict';
import http from 'node:http';
import { after, before, describe, it } from 'node:test';
import type { createContext } from '@/trpc/init.js';

// Its own file because the env singleton is read once per process: this process has an
// OpenRouter key and NO PostHog key, the degraded configuration the docs promise still works.
const emptyContext = { req: {}, res: {} } as unknown as ReturnType<typeof createContext>;

const paths: string[] = [];
const server = http.createServer((req, res) => {
  req.on('data', () => {});
  req.on('end', () => {
    paths.push(req.url ?? '');
    const data = JSON.stringify({
      id: 'gen-fake',
      object: 'chat.completion',
      model: 'anthropic/claude-haiku-4.5',
      choices: [
        { index: 0, message: { role: 'assistant', content: 'unwrapped' }, finish_reason: 'stop' },
      ],
      usage: { prompt_tokens: 10, completion_tokens: 2, total_tokens: 12 },
    });
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data),
    });
    res.end(data);
  });
});

let callTraceExample: (input: { prompt?: string; sessionId?: string }) => Promise<{
  text: string;
  posthogTraced: boolean;
}>;

before(async () => {
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  assert.ok(address && typeof address === 'object');
  process.env.SUPABASE_URL = 'https://placeholder.supabase.co';
  process.env.SUPABASE_SECRET_KEY = 'sb_secret_placeholder';
  process.env.OPENROUTER_API_KEY = 'sk-or-v1-test-key';
  process.env.OPENROUTER_BASE_URL = `http://127.0.0.1:${address.port}/api/v1`;
  delete process.env.POSTHOG_API_KEY;

  const { createCallerFactory } = await import('@/trpc/init.js');
  const { initPostHog } = await import('@/services/posthog.js');
  initPostHog(); // no key: logs a warning and leaves the client null
  const { llmRouter } = await import('./llm.js');
  const caller = createCallerFactory(llmRouter)(emptyContext);
  callTraceExample = (input) => caller.traceExample(input);
});

after(() => {
  server.close();
});

describe('llm.traceExample without a PostHog key', () => {
  it('runs the model unwrapped, reports posthogTraced: false, and sends nothing but the completion request', async () => {
    const result = await callTraceExample({ prompt: 'hello', sessionId: 'no-posthog' });

    assert.equal(result.text, 'unwrapped');
    assert.equal(result.posthogTraced, false);
    assert.deepEqual(paths, ['/api/v1/chat/completions']);
  });
});
