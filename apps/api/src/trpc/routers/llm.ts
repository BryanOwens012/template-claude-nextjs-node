import { createOpenRouter } from '@openrouter/ai-sdk-provider';
import { withTracing } from '@posthog/ai/vercel';
import { TRPCError } from '@trpc/server';
import { generateText, stepCountIs, tool } from 'ai';
import { z } from 'zod';
import { getEnvironment } from '@/config/environment.js';
import { getPrompt } from '@/prompts/index.js';
import { getPostHog } from '@/services/posthog.js';
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

export const llmRouter = createRouter({
  // Prompts are stored in the codebase (src/prompts/), never in a hosted prompt registry, so
  // this works with no external service configured. Unknown names fail closed.
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

  // Runnable scaffold for an LLM call: OpenRouter model, a tool, multi-step generation, and
  // PostHog LLM analytics tracing grouped by session. Copy it for real calls.
  traceExample: publicProcedure.input(TraceExampleInputSchema).mutation(async ({ input }) => {
    const env = getEnvironment();

    if (!env.OPENROUTER_API_KEY) {
      throw new TRPCError({
        code: 'PRECONDITION_FAILED',
        message: 'OPENROUTER_API_KEY is not configured',
      });
    }

    const { prompt, sessionId } = input;
    // Every call belongs to a session. When the client omits sessionId (or sends ''), one is
    // generated so no call is session-less. The same id is the PostHog trace id, so a
    // conversation's generations group into one trace, and OpenRouter's session_id, so its
    // sticky routing keeps the conversation on the upstream that holds its prompt cache.
    const effectiveSessionId = sessionId || `anon-${crypto.randomUUID()}`;

    const openrouter = createOpenRouter({
      apiKey: env.OPENROUTER_API_KEY,
      ...(env.OPENROUTER_BASE_URL ? { baseURL: env.OPENROUTER_BASE_URL } : {}),
    });
    const baseModel = openrouter(TRACE_EXAMPLE_MODEL, {
      // Real token counts and cost come back on providerMetadata.openrouter.usage;
      // OpenRouter has no count_tokens endpoint, so this is the measurement.
      usage: { include: true },
      extraBody: { session_id: effectiveSessionId },
    });

    // PostHog LLM analytics: one $ai_generation event per model call (model, tokens, cost,
    // latency, tool calls), grouped by posthogTraceId. Privacy mode is a single project-wide
    // setting (POSTHOG_LLM_PRIVACY_MODE): when on, prompt and completion text are dropped
    // and only the numbers are kept. Without a PostHog key the model runs unwrapped, so the
    // scaffold still works with OpenRouter alone; OpenRouter's activity page then remains
    // the per-request record.
    const posthog = getPostHog();
    const model = posthog
      ? withTracing(baseModel, posthog, {
          posthogDistinctId: effectiveSessionId,
          posthogTraceId: effectiveSessionId,
          posthogPrivacyMode: env.POSTHOG_LLM_PRIVACY_MODE,
          posthogProperties: { route: 'llm.traceExample' },
        })
      : baseModel;

    try {
      const result = await generateText({
        model,
        prompt,
        tools: { getCurrentWeather },
        // stopWhen allows multi-step: model calls tool -> receives result -> generates final text
        stopWhen: stepCountIs(3),
        // Prompt caching through OpenRouter: a request-level cacheControl becomes the top-level
        // `cache_control`, and OpenRouter places the breakpoint on the last cacheable block and
        // advances it as the conversation grows. It only engages once the prefix exceeds the
        // model's minimum cacheable size (~4096 tokens on Haiku 4.5); kept in the scaffold as the
        // pattern to copy for real prompts. Cached tokens report as usage.cachedInputTokens.
        providerOptions: { openrouter: { cacheControl: { type: 'ephemeral' } } },
      });

      return {
        success: true,
        prompt,
        text: result.text,
        usage: {
          inputTokens: result.usage.inputTokens,
          outputTokens: result.usage.outputTokens,
          totalTokens: result.usage.totalTokens,
          cachedInputTokens: result.usage.cachedInputTokens,
          openrouter: result.providerMetadata?.openrouter?.usage,
        },
        // Tool calls made across all steps
        toolCalls: result.steps.flatMap((step) =>
          step.toolResults.map((tr) => ({
            tool: tr.toolName,
            input: tr.input,
            output: tr.output,
          })),
        ),
        sessionId: effectiveSessionId,
        posthogTraced: posthog !== null,
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
