// LLM prompts live here, in the codebase, as the single source of truth — not in
// Langfuse (see CLAUDE.md: "Langfuse (Tracing Yes, Prompts No)"). This keeps prompts
// version-controlled alongside the code that uses them and lets terminal agents like
// Claude Code read them as context. Add new prompts to the registry below.

export const examplePrompt = `You are a helpful assistant.

Context: {{context}}
User Query: {{query}}

Please provide a thoughtful response.`;

const promptRegistry = {
  example: examplePrompt,
} as const;

export type PromptName = keyof typeof promptRegistry;

export const isPromptName = (name: string): name is PromptName => name in promptRegistry;

// Substitute {{variable}} placeholders with provided values
export const compilePrompt = (text: string, variables: Record<string, string> = {}): string =>
  Object.entries(variables).reduce((t, [key, value]) => t.replaceAll(`{{${key}}}`, value), text);

export const getPrompt = (
  name: string,
  variables: Record<string, string> = {},
): { text: string; name: PromptName; found: boolean } => {
  if (isPromptName(name)) {
    return { text: compilePrompt(promptRegistry[name], variables), name, found: true };
  }

  console.warn(`[prompts] Prompt '${name}' not found in registry, using 'example' fallback`);
  return { text: compilePrompt(promptRegistry.example, variables), name: 'example', found: false };
};
