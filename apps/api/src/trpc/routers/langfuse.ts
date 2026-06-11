import { createAnthropic } from '@ai-sdk/anthropic';
import { propagateAttributes, startActiveObservation } from '@langfuse/tracing';
import { TRPCError } from '@trpc/server';
import { generateText, stepCountIs, tool } from 'ai';
import { z } from 'zod';
import { getEnvironment } from '@/config/environment.js';
import { getPrompt } from '@/prompts/index.js';
import { getLangfuse, isLangfuseAvailable } from '@/services/langfuse.js';
import { createRouter, publicProcedure } from '@/trpc/init.js';
import { PromptInputSchema, TraceExampleInputSchema } from '@/types/index.js';

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
    unit: '\u00b0F',
    condition: 'Partly cloudy',
    humidity: '62%',
  }),
  // Prompt-caching breakpoint on the LAST tool: tools render first in the prompt,
  // so one breakpoint here covers every preceding tool definition. It only engages
  // once the prefix exceeds the model's minimum cacheable size (~4096 tokens on
  // Haiku 4.5) — kept in this scaffold as the pattern to copy for real prompts.
  // Verify hits via result.providerMetadata?.anthropic (not result.usage).
  providerOptions: { anthropic: { cacheControl: { type: 'ephemeral' } } },
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
  // works regardless of whether Langfuse is configured.
  getPrompt: publicProcedure.input(PromptInputSchema).query(({ input }) => {
    const { text, name, found } = getPrompt(input.name, input.variables);

    return {
      source: 'codebase' as const,
      promptName: name,
      requestedName: input.name,
      found,
      prompt: text,
      variables: input.variables,
    };
  }),

  traceExample: publicProcedure.input(TraceExampleInputSchema).mutation(async ({ input }) => {
    const env = getEnvironment();

    if (!env.ANTHROPIC_API_KEY) {
      throw new TRPCError({
        code: 'PRECONDITION_FAILED',
        message: 'ANTHROPIC_API_KEY is not configured',
      });
    }

    const { prompt, sessionId } = input;
    const anthropic = createAnthropic({ apiKey: env.ANTHROPIC_API_KEY });
    // All LLM calls are grouped into a Langfuse session (see CLAUDE.md). When the
    // client doesn't supply a sessionId, generate one so no call is session-less.
    const effectiveSessionId = sessionId ? String(sessionId) : `anon-${crypto.randomUUID()}`;
    const traceAttrs = { sessionId: effectiveSessionId };

    try {
      let generatedText = '';
      let usageInfo: Record<string, unknown> = {};
      let toolCallsMade: Array<{ tool: string; input: unknown; output: unknown }> = [];

      await startActiveObservation('trace-example', async (span) => {
        span.update({ input: { prompt } });

        await propagateAttributes(traceAttrs, async () => {
          const result = await generateText({
            model: anthropic('claude-haiku-4-5'),
            prompt,
            tools: { getCurrentWeather },
            // stopWhen allows multi-step: model calls tool -> receives result -> generates final text
            stopWhen: stepCountIs(3),
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
        model: 'claude-haiku-4-5',
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
