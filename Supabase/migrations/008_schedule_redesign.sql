-- Schedule Redesign: fixed/poll modes, tri-state votes, maybe counts

-- 1. Schedule mode on events (fixed = set date, poll = vote on options)
ALTER TABLE events ADD COLUMN IF NOT EXISTS schedule_mode text NOT NULL DEFAULT 'fixed'
    CHECK (schedule_mode IN ('fixed', 'poll'));

-- 2. Tri-state votes (yes/maybe/no instead of binary presence)
ALTER TABLE time_option_votes ADD COLUMN IF NOT EXISTS vote_type text NOT NULL DEFAULT 'yes'
    CHECK (vote_type IN ('yes', 'maybe', 'no'));

-- 3. Maybe count for display alongside vote_count
ALTER TABLE time_options ADD COLUMN IF NOT EXISTS maybe_count integer NOT NULL DEFAULT 0;

-- 4. Update vote_count trigger to handle tri-state votes + UPDATE operations
CREATE OR REPLACE FUNCTION update_vote_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.vote_type = 'yes' THEN
            UPDATE time_options SET vote_count = vote_count + 1 WHERE id = NEW.time_option_id;
        ELSIF NEW.vote_type = 'maybe' THEN
            UPDATE time_options SET maybe_count = maybe_count + 1 WHERE id = NEW.time_option_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.vote_type = 'yes' THEN
            UPDATE time_options SET vote_count = vote_count - 1 WHERE id = OLD.time_option_id;
        ELSIF OLD.vote_type = 'maybe' THEN
            UPDATE time_options SET maybe_count = maybe_count - 1 WHERE id = OLD.time_option_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Decrement old counts
        IF OLD.vote_type = 'yes' THEN
            UPDATE time_options SET vote_count = vote_count - 1 WHERE id = OLD.time_option_id;
        ELSIF OLD.vote_type = 'maybe' THEN
            UPDATE time_options SET maybe_count = maybe_count - 1 WHERE id = OLD.time_option_id;
        END IF;
        -- Increment new counts
        IF NEW.vote_type = 'yes' THEN
            UPDATE time_options SET vote_count = vote_count + 1 WHERE id = NEW.time_option_id;
        ELSIF NEW.vote_type = 'maybe' THEN
            UPDATE time_options SET maybe_count = maybe_count + 1 WHERE id = NEW.time_option_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 5. Drop + recreate trigger to fire on INSERT OR UPDATE OR DELETE
DROP TRIGGER IF EXISTS trg_vote_count ON time_option_votes;
CREATE TRIGGER trg_vote_count
    AFTER INSERT OR UPDATE OR DELETE ON time_option_votes
    FOR EACH ROW EXECUTE FUNCTION update_vote_count();
