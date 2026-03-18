-- Add cover_variant column for generative cover art style selection
ALTER TABLE events ADD COLUMN IF NOT EXISTS cover_variant integer NOT NULL DEFAULT 0;
