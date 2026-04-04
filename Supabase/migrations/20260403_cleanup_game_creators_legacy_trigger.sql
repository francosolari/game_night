-- Remove stale legacy trigger/function that still references dropped game_creators.
-- This unblocks writes to public.games (e.g. add-to-library upsert path).

drop trigger if exists games_sync_creators_trigger on public.games;
drop function if exists public.sync_game_creators_from_game();
drop function if exists public.backfill_publisher_creators(int);

-- Defensive no-op if already removed.
drop table if exists public.game_creators cascade;
