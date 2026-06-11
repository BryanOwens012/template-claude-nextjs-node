import Langfuse from 'langfuse';
import { getEnvironment } from '@/config/environment.js';

// Langfuse is used for tracing and sessions only. LLM prompts live in the codebase
// (src/prompts/) as the single source of truth — never in Langfuse prompt management.

let langfuseClient: Langfuse | null = null;
let langfuseAvailable = false;

export const initLangfuse = async () => {
  try {
    const env = getEnvironment();

    if (!env.LANGFUSE_PUBLIC_KEY || !env.LANGFUSE_SECRET_KEY) {
      console.warn('⚠️  Langfuse keys not set — tracing disabled');
      return;
    }

    langfuseClient = new Langfuse({
      publicKey: env.LANGFUSE_PUBLIC_KEY,
      secretKey: env.LANGFUSE_SECRET_KEY,
      baseUrl: env.LANGFUSE_BASE_URL ?? 'https://cloud.langfuse.com',
    });

    console.log('✅ Langfuse connected');
    langfuseAvailable = true;
  } catch (error) {
    console.warn(
      `⚠️  Langfuse initialization failed: ${error instanceof Error ? error.message : String(error)}`,
    );
    langfuseAvailable = false;
  }
};

export const getLangfuse = (): Langfuse | null => langfuseClient;
export const isLangfuseAvailable = () => langfuseAvailable;

// Graceful shutdown
export const closeLangfuse = async () => {
  if (!langfuseClient) {
    return;
  }

  try {
    await Promise.race([
      langfuseClient.shutdownAsync(),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Langfuse shutdown timeout')), 5000),
      ),
    ]);
  } catch (error) {
    console.warn(
      `[langfuse] Shutdown error: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
};
