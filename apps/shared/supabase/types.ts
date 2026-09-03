// Placeholder until the first real generation. Regenerate with the committed wrapper only:
//   bash scripts/gen-supabase-types.sh            (project named by SUPABASE_URL in apps/api/.env)
//   bash scripts/gen-supabase-types.sh --local    (running local Supabase stack)
// Never redirect the generator onto this file: a failed run would truncate it. The wrapper
// generates to a temp file, checks it is a types module, then moves it into place, and this
// whole file is replaced by the generator's own output, biome-exempt so the diff is only schema.
//
// Do not hand-edit this file; the next regeneration discards the edit. Where the generator's
// type is too loose (a pgvector column comes out as string | null; the app wants number[]),
// narrow it in hand-written code that imports from here, not in this file.

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  public: {
    Tables: Record<string, never>;
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
