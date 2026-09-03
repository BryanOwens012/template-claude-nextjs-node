import assert from 'node:assert/strict';
import { before, describe, it } from 'node:test';
import type { createContext } from '@/trpc/init.js';

// Its own file because the env singleton is read once per process: this process has no
// OpenRouter key, so the scaffold must refuse before it builds a model or touches the network.
const emptyContext = { req: {}, res: {} } as unknown as ReturnType<typeof createContext>;

let callTraceExample: (input: { prompt?: string }) => Promise<unknown>;
let callGetPrompt: (input: { name: string; variables?: Record<string, string> }) => Promise<{
  source: string;
  prompt: string;
}>;

before(async () => {
  process.env.SUPABASE_URL = 'https://placeholder.supabase.co';
  process.env.SUPABASE_SECRET_KEY = 'sb_secret_placeholder';
  delete process.env.OPENROUTER_API_KEY;
  delete process.env.POSTHOG_API_KEY;

  const { createCallerFactory } = await import('@/trpc/init.js');
  const { llmRouter } = await import('./llm.js');
  const caller = createCallerFactory(llmRouter)(emptyContext);
  callTraceExample = (input) => caller.traceExample(input);
  callGetPrompt = (input) => caller.getPrompt(input);
});

describe('llm router without an OpenRouter key', () => {
  it('traceExample fails closed with PRECONDITION_FAILED naming the missing variable', async () => {
    await assert.rejects(callTraceExample({ prompt: 'hello' }), (error: unknown) => {
      const err = error as { code?: string; message?: string };
      assert.equal(err.code, 'PRECONDITION_FAILED');
      assert.match(err.message ?? '', /OPENROUTER_API_KEY/);
      return true;
    });
  });

  it('getPrompt still works: prompts come from the codebase, not from any configured service', async () => {
    const result = await callGetPrompt({ name: 'example', variables: {} });
    assert.equal(result.source, 'codebase');
    assert.ok(result.prompt.length > 0);
  });

  it('getPrompt fails closed on an unknown prompt name', async () => {
    await assert.rejects(callGetPrompt({ name: 'does-not-exist' }), (error: unknown) => {
      assert.equal((error as { code?: string }).code, 'NOT_FOUND');
      return true;
    });
  });
});
