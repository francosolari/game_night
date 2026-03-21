-- Add share_token to events table for generic (non-invite-specific) sharing
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS share_token TEXT UNIQUE
    DEFAULT encode(gen_random_bytes(8), 'hex');

-- Backfill existing rows
UPDATE events
  SET share_token = encode(gen_random_bytes(8), 'hex')
  WHERE share_token IS NULL;

-- Not-null constraint after backfill
ALTER TABLE events
  ALTER COLUMN share_token SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_events_share_token ON events(share_token);
