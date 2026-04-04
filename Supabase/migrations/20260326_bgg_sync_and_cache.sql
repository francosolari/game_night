-- BGG API Integration: server-side caching, sync tracking, and BGG-compatible fields
-- Enables moving all BGG API calls to edge functions with local DB caching

-- A. Cache freshness tracking on games
ALTER TABLE games ADD COLUMN IF NOT EXISTS bgg_last_synced TIMESTAMPTZ;

-- B. BGG-compatible fields on plays (for import/export parity)
ALTER TABLE plays
  ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS incomplete BOOLEAN DEFAULT FALSE;

-- C. BGG-compatible fields on play_participants
ALTER TABLE play_participants
  ADD COLUMN IF NOT EXISTS start_position TEXT,
  ADD COLUMN IF NOT EXISTS color TEXT,
  ADD COLUMN IF NOT EXISTS new_to_game BOOLEAN,
  ADD COLUMN IF NOT EXISTS bgg_rating DOUBLE PRECISION;

-- D. Per-user BGG sync state tracking
CREATE TABLE IF NOT EXISTS bgg_sync_state (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sync_type TEXT NOT NULL CHECK (sync_type IN ('collection', 'plays')),
  last_synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_bgg_username TEXT,
  metadata JSONB DEFAULT '{}',
  UNIQUE(user_id, sync_type)
);

ALTER TABLE bgg_sync_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY bgg_sync_state_select ON bgg_sync_state
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY bgg_sync_state_insert ON bgg_sync_state
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY bgg_sync_state_update ON bgg_sync_state
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY bgg_sync_state_delete ON bgg_sync_state
  FOR DELETE USING (auth.uid() = user_id);

-- E. Hot games cache (server-managed, public read)
CREATE TABLE IF NOT EXISTS bgg_hot_games_cache (
  id SERIAL PRIMARY KEY,
  bgg_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  year_published INTEGER,
  thumbnail_url TEXT,
  rank INTEGER,
  cached_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE bgg_hot_games_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY bgg_hot_games_cache_select ON bgg_hot_games_cache
  FOR SELECT USING (true);

-- F. Trigram index on games.name for fast local-first search
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_games_name_trgm ON games USING gin (name gin_trgm_ops);
