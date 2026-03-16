-- Activity Feed & Game Voting: comments, threads, RSVP updates, game polls

-- 1. Events table: add game voting toggle and confirmed game
ALTER TABLE events ADD COLUMN IF NOT EXISTS allow_game_voting BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE events ADD COLUMN IF NOT EXISTS confirmed_game_id UUID REFERENCES games(id);

-- 2. Event games: denormalized vote counts (trigger-maintained)
ALTER TABLE event_games ADD COLUMN IF NOT EXISTS yes_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE event_games ADD COLUMN IF NOT EXISTS maybe_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE event_games ADD COLUMN IF NOT EXISTS no_count INTEGER NOT NULL DEFAULT 0;

-- 3. Activity feed table (comments, announcements, RSVP updates)
CREATE TABLE activity_feed (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('comment', 'rsvp_update', 'announcement')),
    content TEXT,
    parent_id UUID REFERENCES activity_feed(id) ON DELETE CASCADE,
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_activity_feed_event ON activity_feed(event_id);
CREATE INDEX idx_activity_feed_parent ON activity_feed(parent_id);

-- updated_at trigger for activity_feed
CREATE TRIGGER trg_activity_feed_updated_at
    BEFORE UPDATE ON activity_feed
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 4. Game votes table (tri-state, mirrors time_option_votes pattern)
CREATE TABLE game_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vote_type TEXT NOT NULL CHECK (vote_type IN ('yes', 'maybe', 'no')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(event_id, game_id, user_id)
);

CREATE INDEX idx_game_votes_event ON game_votes(event_id);
CREATE INDEX idx_game_votes_event_game ON game_votes(event_id, game_id);

-- 5. Trigger to maintain game vote counts on event_games (mirrors update_vote_count)
CREATE OR REPLACE FUNCTION update_game_vote_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.vote_type = 'yes' THEN
            UPDATE event_games SET yes_count = yes_count + 1
            WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        ELSIF NEW.vote_type = 'maybe' THEN
            UPDATE event_games SET maybe_count = maybe_count + 1
            WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        ELSIF NEW.vote_type = 'no' THEN
            UPDATE event_games SET no_count = no_count + 1
            WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.vote_type = 'yes' THEN
            UPDATE event_games SET yes_count = yes_count - 1
            WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        ELSIF OLD.vote_type = 'maybe' THEN
            UPDATE event_games SET maybe_count = maybe_count - 1
            WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        ELSIF OLD.vote_type = 'no' THEN
            UPDATE event_games SET no_count = no_count - 1
            WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Decrement old
        IF OLD.vote_type = 'yes' THEN
            UPDATE event_games SET yes_count = yes_count - 1
            WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        ELSIF OLD.vote_type = 'maybe' THEN
            UPDATE event_games SET maybe_count = maybe_count - 1
            WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        ELSIF OLD.vote_type = 'no' THEN
            UPDATE event_games SET no_count = no_count - 1
            WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        END IF;
        -- Increment new
        IF NEW.vote_type = 'yes' THEN
            UPDATE event_games SET yes_count = yes_count + 1
            WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        ELSIF NEW.vote_type = 'maybe' THEN
            UPDATE event_games SET maybe_count = maybe_count + 1
            WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        ELSIF NEW.vote_type = 'no' THEN
            UPDATE event_games SET no_count = no_count + 1
            WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_game_vote_count
    AFTER INSERT OR UPDATE OR DELETE ON game_votes
    FOR EACH ROW EXECUTE FUNCTION update_game_vote_count();

-- 6. Auto-post RSVP updates to activity feed
CREATE OR REPLACE FUNCTION auto_post_rsvp_update()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status IN ('accepted', 'maybe', 'declined')
       AND NEW.user_id IS NOT NULL THEN
        INSERT INTO activity_feed (event_id, user_id, type, content)
        VALUES (NEW.event_id, NEW.user_id, 'rsvp_update', NEW.status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_rsvp_update
    AFTER UPDATE ON invites
    FOR EACH ROW EXECUTE FUNCTION auto_post_rsvp_update();

-- 7. RLS Policies

ALTER TABLE activity_feed ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_votes ENABLE ROW LEVEL SECURITY;

-- activity_feed: participants who RSVP'd (accepted/maybe) or host can read
CREATE POLICY activity_feed_select ON activity_feed FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM invites
        WHERE invites.event_id = activity_feed.event_id
          AND invites.user_id = auth.uid()
          AND invites.status IN ('accepted', 'maybe')
    )
    OR EXISTS (
        SELECT 1 FROM events
        WHERE events.id = activity_feed.event_id
          AND events.host_id = auth.uid()
    )
);

-- activity_feed: participants can insert their own items
CREATE POLICY activity_feed_insert ON activity_feed FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND (
        EXISTS (
            SELECT 1 FROM invites
            WHERE invites.event_id = activity_feed.event_id
              AND invites.user_id = auth.uid()
              AND invites.status IN ('accepted', 'maybe')
        )
        OR EXISTS (
            SELECT 1 FROM events
            WHERE events.id = activity_feed.event_id
              AND events.host_id = auth.uid()
        )
    )
);

-- activity_feed: own items or host can update (for pinning)
CREATE POLICY activity_feed_update ON activity_feed FOR UPDATE USING (
    auth.uid() = user_id
    OR EXISTS (
        SELECT 1 FROM events
        WHERE events.id = activity_feed.event_id
          AND events.host_id = auth.uid()
    )
);

-- activity_feed: own items or host can delete
CREATE POLICY activity_feed_delete ON activity_feed FOR DELETE USING (
    auth.uid() = user_id
    OR EXISTS (
        SELECT 1 FROM events
        WHERE events.id = activity_feed.event_id
          AND events.host_id = auth.uid()
    )
);

-- game_votes: event participants can read
CREATE POLICY game_votes_select ON game_votes FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM events
        WHERE events.id = game_votes.event_id
          AND events.host_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM invites
        WHERE invites.event_id = game_votes.event_id
          AND invites.user_id = auth.uid()
    )
);

-- game_votes: own votes only
CREATE POLICY game_votes_insert ON game_votes FOR INSERT WITH CHECK (
    auth.uid() = user_id
);

CREATE POLICY game_votes_update ON game_votes FOR UPDATE USING (
    auth.uid() = user_id
);

CREATE POLICY game_votes_delete ON game_votes FOR DELETE USING (
    auth.uid() = user_id
);
