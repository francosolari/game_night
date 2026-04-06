-- Security hardening: revoke anon access from sensitive functions,
-- fix missing search_path on SECURITY DEFINER functions,
-- and lock down BGG reference table write policies.
--
-- Findings from RLS audit (2026-04-05):
-- P0: anonymize_user callable by anon with no search_path
-- P1: handle_user_updated missing search_path
-- P1: find_user_id_by_phone, bgg_backfill_step, get_frequent_contacts,
--     get_or_create_dm, get_my_profile_summary callable by anon
-- P1: game_expansions/families/family_members INSERT/UPDATE/DELETE
--     had WITH CHECK (true) for all authenticated users

-- ============================================================
-- P0: anonymize_user — add search_path, revoke from anon/public
-- ============================================================
ALTER FUNCTION anonymize_user(uuid)
  SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION anonymize_user(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION anonymize_user(uuid) TO authenticated, service_role;

-- ============================================================
-- P1: handle_user_updated — add search_path (trigger function)
-- ============================================================
ALTER FUNCTION handle_user_updated()
  SET search_path = public, pg_temp;

-- ============================================================
-- P1: Revoke anon access from functions that require authentication
-- ============================================================
REVOKE EXECUTE ON FUNCTION find_user_id_by_phone FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION find_user_id_by_phone TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION bgg_backfill_step() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION bgg_backfill_step() TO service_role;

REVOKE EXECUTE ON FUNCTION get_frequent_contacts FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_frequent_contacts TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION get_or_create_dm(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_or_create_dm(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION get_my_profile_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_my_profile_summary() TO authenticated, service_role;

-- ============================================================
-- P1: game_expansions / game_families / game_family_members
-- Drop write policies — these are BGG reference data, iOS never writes directly.
-- Reads remain open to authenticated users.
-- ============================================================
DROP POLICY IF EXISTS "Authenticated users can insert game_expansions" ON game_expansions;
DROP POLICY IF EXISTS "Authenticated users can update game_expansions" ON game_expansions;
DROP POLICY IF EXISTS "Authenticated users can delete game_expansions" ON game_expansions;

DROP POLICY IF EXISTS "Authenticated users can insert game_families" ON game_families;
DROP POLICY IF EXISTS "Authenticated users can update game_families" ON game_families;
DROP POLICY IF EXISTS "Authenticated users can delete game_families" ON game_families;

DROP POLICY IF EXISTS "Authenticated users can insert game_family_members" ON game_family_members;
DROP POLICY IF EXISTS "Authenticated users can update game_family_members" ON game_family_members;
DROP POLICY IF EXISTS "Authenticated users can delete game_family_members" ON game_family_members;
