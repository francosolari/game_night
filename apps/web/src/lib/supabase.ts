import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = "https://irhidoryicawwlwrilbb.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_CmwWqE82EARyPuLf0VwE2Q_Qm8kcnOz";

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: localStorage,
    persistSession: true,
    autoRefreshToken: true,
  },
});
