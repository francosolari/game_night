-- Add draft_invitees column to events table
-- Stores invitee data as JSON when event is in draft status,
-- so invites aren't created until the event is published.
ALTER TABLE events ADD COLUMN IF NOT EXISTS draft_invitees jsonb DEFAULT NULL;
