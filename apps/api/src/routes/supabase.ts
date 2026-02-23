import { Router } from "express";
import { getSupabaseClient, isSupabaseAvailable } from "@/services/supabase.js";
import { getEnvironment } from "@/config/environment.js";

const router = Router();

router.get("/test", (_req, res) => {
  const supabase = getSupabaseClient();
  if (!supabase || !isSupabaseAvailable()) {
    res.json({ supabaseAvailable: false, message: "Supabase client not initialized" });
    return;
  }
  const env = getEnvironment();
  res.json({
    supabaseAvailable: true,
    message: "Supabase client initialized successfully",
    url: env.SUPABASE_URL,
  });
});

export default router;
