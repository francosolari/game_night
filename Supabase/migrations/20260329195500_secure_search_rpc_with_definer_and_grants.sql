-- Security + performance hardening for game search RPC.
-- Rationale:
-- 1) search_games_fuzzy/search_games_fast currently run as SECURITY INVOKER and can hit
--    expensive RLS predicates on games_select, causing request timeouts.
-- 2) Before enabling SECURITY DEFINER, tighten execute grants so anon/public cannot call it.
--
-- Guardrails preserved:
-- - search only returns catalog rows (owner_id IS NULL, bgg_id IS NOT NULL)
-- - no dynamic SQL
-- - fixed search_path

ALTER FUNCTION public.search_games_fuzzy(text, int)
  SECURITY DEFINER
  SET search_path = public, pg_temp
  SET jit = off;

ALTER FUNCTION public.search_games_fast(text, int)
  SECURITY DEFINER
  SET search_path = public, pg_temp
  SET jit = off;

REVOKE EXECUTE ON FUNCTION public.search_games_fuzzy(text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.search_games_fast(text, int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.search_games_fuzzy(text, int) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.search_games_fast(text, int) TO authenticated, service_role;
