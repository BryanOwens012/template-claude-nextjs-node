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

const FALLBACK_PROMPT_NAME: PromptName = 'example';

// Object.hasOwn (not `in`) so prototype members like 'toString' don't match
export const isPromptName = (name: string): name is PromptName =>
  Object.hasOwn(promptRegistry, name);

// Substitute {{variable}} placeholders with provided values. The function form of
// the replacement keeps values literal — a string replacement would interpret `$`
// patterns ($&, $$, $') and corrupt values containing dollar signs.
export const compilePrompt = (text: string, variables: Record<string, string> = {}): string =>
  Object.entries(variables).reduce(
    (t, [key, value]) => t.replaceAll(`{{${key}}}`, () => value),
    text,
  );

// Total function (never throws): unknown names compile the fallback prompt with
// wasFound: false, so callers decide whether to use it or fail closed.
export const getPrompt = (
  name: string,
  variables: Record<string, string> = {},
): { text: string; name: PromptName; wasFound: boolean } => {
  if (isPromptName(name)) {
    return { text: compilePrompt(promptRegistry[name], variables), name, wasFound: true };
  }

  console.warn(
    `[prompts] Prompt '${name}' not found in registry, using '${FALLBACK_PROMPT_NAME}' fallback`,
  );
  return {
    text: compilePrompt(promptRegistry[FALLBACK_PROMPT_NAME], variables),
    name: FALLBACK_PROMPT_NAME,
    wasFound: false,
  };
};
