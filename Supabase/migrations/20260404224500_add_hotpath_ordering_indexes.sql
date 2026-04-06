-- Reduce sort/scan pressure for high-frequency mobile reads under concurrency.
-- These match current PostgREST access patterns in iOS and stress harness.

create index if not exists idx_events_group_deleted_created_desc
  on public.events (group_id, deleted_at, created_at desc);

create index if not exists idx_plays_group_played_desc
  on public.plays (group_id, played_at desc);

create index if not exists idx_game_wishlist_user_added_desc
  on public.game_wishlist (user_id, added_at desc);
