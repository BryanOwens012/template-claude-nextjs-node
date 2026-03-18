// Regenerate with:
//   npx supabase gen types typescript --project-id YOUR_PROJECT_ID > apps/shared/supabase/types.ts
// Or with local Supabase:
//   npx supabase gen types typescript --local > apps/shared/supabase/types.ts
//
// After regenerating, apply manual overrides for pgvector fields:
//   Insert/Update embedding fields: number[] | null

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
