-- Drop game_creators table and associated backfill function.
-- Replaced by fetch_games_by_designer / fetch_games_by_publisher RPCs
-- which query games directly via GIN indexes.
DROP TABLE IF EXISTS public.game_creators CASCADE;
DROP FUNCTION IF EXISTS backfill_publisher_creators(INT);
