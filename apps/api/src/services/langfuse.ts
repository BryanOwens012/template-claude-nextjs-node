import Langfuse, { type LangfusePromptClient } from "langfuse";
import { getEnvironment } from "@/config/environment.js";

let langfuseClient: Langfuse | null = null;
let langfuseAvailable = false;

// Fallback example prompt with {{variable}} interpolation support
const FALLBACK_EXAMPLE_PROMPT = `You are a helpful assistant.

Context: {{context}}
User Query: {{query}}

Please provide a thoughtful response.`;

export const initLangfuse = async () => {
  try {
    const env = getEnvironment();

    if (!env.LANGFUSE_PUBLIC_KEY || !env.LANGFUSE_SECRET_KEY) {
      console.warn(
        "⚠️  Langfuse keys not set — prompt management and tracing disabled"
      );
      return;
    }

    langfuseClient = new Langfuse({
      publicKey: env.LANGFUSE_PUBLIC_KEY,
      secretKey: env.LANGFUSE_SECRET_KEY,
      baseUrl: env.LANGFUSE_BASE_URL ?? "https://cloud.langfuse.com",
    });

    console.log("✅ Langfuse connected");
    langfuseAvailable = true;
  } catch (error) {
    console.warn(
      `⚠️  Langfuse initialization failed: ${error instanceof Error ? error.message : String(error)}`
    );
    langfuseAvailable = false;
  }
};

export const getLangfuse = (): Langfuse | null => langfuseClient;
export const isLangfuseAvailable = () => langfuseAvailable;

// Utility function for variable substitution in prompts
const applyVariables = (text: string, variables: Record<string, string>): string =>
  Object.entries(variables).reduce(
    (t, [key, value]) => t.replaceAll(`{{${key}}}`, value),
    text
  );

// Fetch prompt from Langfuse or use fallback
export const getPrompt = async (
  promptName: string,
  variables: Record<string, string> = {}
): Promise<{
  text: string;
  promptObj: LangfusePromptClient | null;
}> => {
  if (!langfuseClient) {
    return { text: applyVariables(FALLBACK_EXAMPLE_PROMPT, variables), promptObj: null };
  }

  try {
    const promptObj = await langfuseClient.getPrompt(promptName, undefined, {
      label: "latest",
    });
    const text = promptObj.compile(variables);
    return { text: text as string, promptObj };
  } catch (error) {
    console.warn(
      `[langfuse] Prompt '${promptName}' not found, using fallback: ${error instanceof Error ? error.message : String(error)}`
    );
    return { text: applyVariables(FALLBACK_EXAMPLE_PROMPT, variables), promptObj: null };
  }
};

// Graceful shutdown
export const closeLangfuse = async () => {
  if (!langfuseClient) return;

  try {
    await Promise.race([
      langfuseClient.shutdownAsync(),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error("Langfuse shutdown timeout")), 5000)
      ),
    ]);
  } catch (error) {
    console.warn(
      `[langfuse] Shutdown error: ${error instanceof Error ? error.message : String(error)}`
    );
  }
};
