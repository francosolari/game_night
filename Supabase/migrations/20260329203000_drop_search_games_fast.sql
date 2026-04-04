-- Cleanup: remove deprecated wrapper RPC.
-- App now calls public.search_games_fuzzy directly.

DROP FUNCTION IF EXISTS public.search_games_fast(text, int);
