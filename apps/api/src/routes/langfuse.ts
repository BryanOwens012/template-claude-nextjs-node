import { createAnthropic } from '@ai-sdk/anthropic';
import { propagateAttributes, startActiveObservation } from '@langfuse/tracing';
import { generateText, stepCountIs, tool } from 'ai';
import { Router } from 'express';
import createError from 'http-errors';
import { z } from 'zod';
import { getEnvironment } from '@/config/environment.js';
import { getLangfuse, getPrompt, isLangfuseAvailable } from '@/services/langfuse.js';

const router = Router();

router.get('/test', (_req, res) => {
  const langfuse = getLangfuse();
  if (!langfuse || !isLangfuseAvailable()) {
    res.json({ langfuseAvailable: false, message: 'Langfuse client not initialized' });
    return;
  }
  const env = getEnvironment();
  res.json({
    langfuseAvailable: true,
    message: 'Langfuse client initialized successfully',
    baseUrl: env.LANGFUSE_BASE_URL ?? 'https://cloud.langfuse.com',
  });
});

router.get('/prompts/:name', async (req, res, next) => {
  if (!isLangfuseAvailable()) {
    res.json({
      langfuseAvailable: false,
      message: 'Langfuse not available',
      promptName: req.params.name,
    });
    return;
  }

  try {
    const { name } = req.params;
    const variables: Record<string, string> = {};

    // Parse query string for variable substitution: ?context=X&query=Y
    for (const [key, value] of Object.entries(req.query)) {
      if (typeof value === 'string') {
        variables[key] = value;
      }
    }

    const { text, promptObj } = await getPrompt(name, variables);

    res.json({
      langfuseAvailable: true,
      promptName: name,
      prompt: text,
      variables,
      promptObj: promptObj ? { name: promptObj.name, version: promptObj.version } : null,
    });
  } catch (error) {
    next(error);
  }
});

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

// POST /langfuse/trace-example
// Demonstrates: Vercel AI SDK + Claude Haiku + tool call + Langfuse tracing + session association.
// Body: { prompt?: string, sessionId?: string }
router.post('/trace-example', async (req, res, next) => {
  const env = getEnvironment();

  if (!env.ANTHROPIC_API_KEY) {
    return next(createError(503, 'ANTHROPIC_API_KEY is not configured'));
  }

  const { prompt = "What's the weather like in San Francisco?", sessionId } = req.body as {
    prompt?: string;
    sessionId?: string;
  };

  const anthropic = createAnthropic({ apiKey: env.ANTHROPIC_API_KEY });
  const traceAttrs = sessionId ? { sessionId: String(sessionId) } : {};

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
          // stopWhen allows multi-step: model calls tool → receives result → generates final text
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

    res.json({
      success: true,
      prompt,
      text: generatedText,
      usage: usageInfo,
      toolCalls: toolCallsMade,
      sessionId: sessionId ?? null,
      langfuseTraced: isLangfuseAvailable(),
      model: 'claude-haiku-4-5',
    });
  } catch (error) {
    next(
      createError(500, `AI call failed: ${error instanceof Error ? error.message : String(error)}`),
    );
  }
});

export default router;
