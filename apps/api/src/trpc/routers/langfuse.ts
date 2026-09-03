import { propagateAttributes, startActiveObservation } from '@langfuse/tracing';
import { createOpenRouter } from '@openrouter/ai-sdk-provider';
import { TRPCError } from '@trpc/server';
import { generateText, stepCountIs, tool } from 'ai';
import { z } from 'zod';
import { getEnvironment } from '@/config/environment.js';
import { getPrompt } from '@/prompts/index.js';
import { getLangfuse, isLangfuseAvailable } from '@/services/langfuse.js';
import { createRouter, publicProcedure } from '@/trpc/init.js';
import { PromptInputSchema, PromptResponseSchema, TraceExampleInputSchema } from '@/types/index.js';

// Every LLM call goes through OpenRouter (see CLAUDE.md -> "Routing"), so a model is an
// OpenRouter catalog id, pinned per call site. Swapping vendors is a string change here.
const TRACE_EXAMPLE_MODEL = 'anthropic/claude-haiku-4.5';

// Mock tool — returns hardcoded data so the scaffold runs without external APIs.
// Replace the execute function with a real API call in your project.
const getCurrentWeather = tool({
  description: 'Get the current weather for a city.',
  inputSchema: z.object({
    city: z.string().describe('The city to get weather for'),
  }),
  execute: async ({ city }) => ({
    city,
    temperature: 68,
    unit: '°F',
    condition: 'Partly cloudy',
    humidity: '62%',
  }),
});

export const langfuseRouter = createRouter({
  test: publicProcedure.query(() => {
    const langfuse = getLangfuse();
    if (!langfuse || !isLangfuseAvailable()) {
      return { langfuseAvailable: false, message: 'Langfuse client not initialized' };
    }
    const env = getEnvironment();
    return {
      langfuseAvailable: true,
      message: 'Langfuse client initialized successfully',
      baseUrl: env.LANGFUSE_BASE_URL ?? 'https://cloud.langfuse.com',
    };
  }),

  // Prompts are stored in the codebase (src/prompts/), not in Langfuse — so this
  // works regardless of whether Langfuse is configured. Unknown names fail closed.
  getPrompt: publicProcedure
    .input(PromptInputSchema)
    .output(PromptResponseSchema)
    .query(({ input }) => {
      const { text, name, wasFound } = getPrompt(input.name, input.variables);

      if (!wasFound) {
        throw new TRPCError({
          code: 'NOT_FOUND',
          message: `Prompt '${input.name}' is not in the registry (src/prompts/)`,
        });
      }

      return {
        source: 'codebase' as const,
        promptName: name,
        prompt: text,
        variables: input.variables,
      };
    }),

  traceExample: publicProcedure.input(TraceExampleInputSchema).mutation(async ({ input }) => {
    const env = getEnvironment();

    if (!env.OPENROUTER_API_KEY) {
      throw new TRPCError({
        code: 'PRECONDITION_FAILED',
        message: 'OPENROUTER_API_KEY is not configured',
      });
    }

    const { prompt, sessionId } = input;
    // All LLM calls are grouped into a Langfuse session (see CLAUDE.md). When the
    // client omits sessionId (or sends ''), generate one so no call is session-less.
    const effectiveSessionId = sessionId || `anon-${crypto.randomUUID()}`;
    const traceAttrs = { sessionId: effectiveSessionId };

    const openrouter = createOpenRouter({
      apiKey: env.OPENROUTER_API_KEY,
      ...(env.OPENROUTER_BASE_URL ? { baseURL: env.OPENROUTER_BASE_URL } : {}),
    });
    const model = openrouter(TRACE_EXAMPLE_MODEL, {
      // Real token counts and cost come back on providerMetadata.openrouter.usage;
      // OpenRouter has no count_tokens endpoint, so this is the measurement.
      usage: { include: true },
      // The same session id pins OpenRouter's sticky routing, so every turn of a
      // conversation lands on the upstream that holds its prompt cache. Without it the
      // key is derived from a message hash and lapses after 10 minutes of inactivity.
      extraBody: { session_id: effectiveSessionId },
    });

    try {
      let generatedText = '';
      let usageInfo: Record<string, unknown> = {};
      let toolCallsMade: Array<{ tool: string; input: unknown; output: unknown }> = [];

      await startActiveObservation('trace-example', async (span) => {
        span.update({ input: { prompt } });

        await propagateAttributes(traceAttrs, async () => {
          const result = await generateText({
            model,
            prompt,
            tools: { getCurrentWeather },
            // stopWhen allows multi-step: model calls tool -> receives result -> generates final text
            stopWhen: stepCountIs(3),
            // Prompt caching through OpenRouter: a request-level cacheControl becomes the
            // top-level `cache_control`, and OpenRouter places the breakpoint on the last
            // cacheable block and advances it as the conversation grows. It only engages once
            // the prefix exceeds the model's minimum cacheable size (~4096 tokens on Haiku
            // 4.5); kept in the scaffold as the pattern to copy for real prompts. Cached
            // tokens report as usage.cachedInputTokens, never Anthropic's field names.
            providerOptions: { openrouter: { cacheControl: { type: 'ephemeral' } } },
            experimental_telemetry: {
              isEnabled: true,
              functionId: 'trace-example-generateText',
              metadata: { route: '/langfuse/trace-example' },
            },
          });

          generatedText = result.text;
          usageInfo = {
            inputTokens: result.usage.inputTokens,
            outputTokens: result.usage.outputTokens,
            totalTokens: result.usage.totalTokens,
            cachedInputTokens: result.usage.cachedInputTokens,
            openrouter: result.providerMetadata?.openrouter?.usage,
          };

          // Collect tool calls made across all steps
          toolCallsMade = result.steps.flatMap((step) =>
            step.toolResults.map((tr) => ({
              tool: tr.toolName,
              input: tr.input,
              output: tr.output,
            })),
          );
        });

        span.update({ output: { text: generatedText } });
      });

      return {
        success: true,
        prompt,
        text: generatedText,
        usage: usageInfo,
        toolCalls: toolCallsMade,
        sessionId: effectiveSessionId,
        langfuseTraced: isLangfuseAvailable(),
        model: TRACE_EXAMPLE_MODEL,
      };
    } catch (error) {
      if (error instanceof TRPCError) {
        throw error;
      }
      throw new TRPCError({
        code: 'INTERNAL_SERVER_ERROR',
        message: `AI call failed: ${error instanceof Error ? error.message : String(error)}`,
      });
    }
  }),
});
