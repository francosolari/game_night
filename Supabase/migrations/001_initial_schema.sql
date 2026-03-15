-- Game Night App - Initial Schema
-- Supabase (PostgreSQL)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    bgg_username TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create user row on auth signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO users (id, phone_number, display_name)
    VALUES (
        NEW.id,
        NEW.phone,
        COALESCE(NEW.raw_user_meta_data->>'display_name', 'Player')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- GAMES (from BGG or manual)
-- ============================================================
CREATE TABLE games (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bgg_id INTEGER UNIQUE,
    name TEXT NOT NULL,
    year_published INTEGER,
    thumbnail_url TEXT,
    image_url TEXT,
    min_players INTEGER NOT NULL DEFAULT 1,
    max_players INTEGER NOT NULL DEFAULT 4,
    recommended_players INTEGER[],
    min_playtime INTEGER NOT NULL DEFAULT 30,
    max_playtime INTEGER NOT NULL DEFAULT 60,
    complexity DOUBLE PRECISION NOT NULL DEFAULT 2.5,
    bgg_rating DOUBLE PRECISION,
    description TEXT,
    categories TEXT[] DEFAULT '{}',
    mechanics TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_games_bgg_id ON games(bgg_id);
CREATE INDEX idx_games_name ON games(name);

-- ============================================================
-- GAME CATEGORIES (user-defined)
-- ============================================================
CREATE TABLE game_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT,
    sort_order INTEGER DEFAULT 0,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_game_categories_user ON game_categories(user_id);

-- ============================================================
-- GAME LIBRARY (user's collection)
-- ============================================================
CREATE TABLE game_library (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    category_id UUID REFERENCES game_categories(id) ON DELETE SET NULL,
    notes TEXT,
    rating INTEGER CHECK (rating BETWEEN 1 AND 10),
    play_count INTEGER DEFAULT 0,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, game_id)
);

CREATE INDEX idx_game_library_user ON game_library(user_id);

-- ============================================================
-- GROUPS
-- ============================================================
CREATE TABLE groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    emoji TEXT,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_groups_owner ON groups(owner_id);

-- ============================================================
-- GROUP MEMBERS
-- ============================================================
CREATE TABLE group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    phone_number TEXT NOT NULL,
    display_name TEXT,
    tier INTEGER DEFAULT 1 CHECK (tier BETWEEN 1 AND 5),
    sort_order INTEGER DEFAULT 0,
    added_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_group_members_group ON group_members(group_id);

-- ============================================================
-- EVENTS
-- ============================================================
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    host_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    location TEXT,
    location_address TEXT,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'published', 'confirmed', 'in_progress', 'completed', 'cancelled')),
    allow_time_suggestions BOOLEAN DEFAULT TRUE,
    invite_strategy JSONB NOT NULL DEFAULT '{"type": "all_at_once", "auto_promote": true}',
    min_players INTEGER NOT NULL DEFAULT 2,
    max_players INTEGER,
    cover_image_url TEXT,
    confirmed_time_option_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_events_host ON events(host_id);
CREATE INDEX idx_events_status ON events(status);

-- ============================================================
-- EVENT GAMES (games attached to an event)
-- ============================================================
CREATE TABLE event_games (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    is_primary BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0
);

CREATE INDEX idx_event_games_event ON event_games(event_id);

-- ============================================================
-- TIME OPTIONS
-- ============================================================
CREATE TABLE time_options (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    label TEXT,
    is_suggested BOOLEAN DEFAULT FALSE,
    suggested_by UUID REFERENCES users(id),
    vote_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_time_options_event ON time_options(event_id);

-- Add FK for confirmed time option
ALTER TABLE events
    ADD CONSTRAINT fk_confirmed_time
    FOREIGN KEY (confirmed_time_option_id)
    REFERENCES time_options(id);

-- ============================================================
-- INVITES
-- ============================================================
CREATE TABLE invites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    phone_number TEXT NOT NULL,
    display_name TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'declined', 'maybe', 'expired', 'waitlisted')),
    tier INTEGER DEFAULT 1 CHECK (tier BETWEEN 1 AND 5),
    tier_position INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    responded_at TIMESTAMPTZ,
    selected_time_option_ids UUID[] DEFAULT '{}',
    sent_via TEXT DEFAULT 'both'
        CHECK (sent_via IN ('push', 'sms', 'both')),
    sms_delivery_status TEXT
        CHECK (sms_delivery_status IS NULL OR sms_delivery_status IN ('queued', 'sent', 'delivered', 'failed', 'undelivered')),
    invite_token TEXT UNIQUE DEFAULT encode(gen_random_bytes(16), 'hex'),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_invites_event ON invites(event_id);
CREATE INDEX idx_invites_user ON invites(user_id);
CREATE INDEX idx_invites_phone ON invites(phone_number);
CREATE INDEX idx_invites_token ON invites(invite_token);
CREATE INDEX idx_invites_status ON invites(status);

-- ============================================================
-- TIME OPTION VOTES (track who voted for what)
-- ============================================================
CREATE TABLE time_option_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    time_option_id UUID NOT NULL REFERENCES time_options(id) ON DELETE CASCADE,
    invite_id UUID NOT NULL REFERENCES invites(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(time_option_id, invite_id)
);

-- Trigger to update vote count
CREATE OR REPLACE FUNCTION update_vote_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE time_options SET vote_count = vote_count + 1 WHERE id = NEW.time_option_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE time_options SET vote_count = vote_count - 1 WHERE id = OLD.time_option_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_vote_count
    AFTER INSERT OR DELETE ON time_option_votes
    FOR EACH ROW EXECUTE FUNCTION update_vote_count();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_library ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_option_votes ENABLE ROW LEVEL SECURITY;

-- Users: read any, update own
CREATE POLICY users_select ON users FOR SELECT USING (true);
CREATE POLICY users_update ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY users_insert ON users FOR INSERT WITH CHECK (auth.uid() = id);

-- Games: anyone can read/insert (community data)
CREATE POLICY games_select ON games FOR SELECT USING (true);
CREATE POLICY games_insert ON games FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY games_update ON games FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Game categories: own only
CREATE POLICY categories_all ON game_categories FOR ALL USING (auth.uid() = user_id);

-- Game library: own only
CREATE POLICY library_all ON game_library FOR ALL USING (auth.uid() = user_id);

-- Groups: owner manages
CREATE POLICY groups_select ON groups FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY groups_insert ON groups FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY groups_update ON groups FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY groups_delete ON groups FOR DELETE USING (auth.uid() = owner_id);

-- Group members: group owner manages
CREATE POLICY group_members_all ON group_members FOR ALL
    USING (EXISTS (SELECT 1 FROM groups WHERE groups.id = group_id AND groups.owner_id = auth.uid()));

-- Events: host manages, invitees can view
CREATE POLICY events_select ON events FOR SELECT
    USING (
        auth.uid() = host_id
        OR EXISTS (SELECT 1 FROM invites WHERE invites.event_id = events.id AND invites.user_id = auth.uid())
    );
CREATE POLICY events_insert ON events FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY events_update ON events FOR UPDATE USING (auth.uid() = host_id);

-- Event games: follow event policy
CREATE POLICY event_games_select ON event_games FOR SELECT
    USING (EXISTS (SELECT 1 FROM events WHERE events.id = event_id AND (
        events.host_id = auth.uid()
        OR EXISTS (SELECT 1 FROM invites WHERE invites.event_id = events.id AND invites.user_id = auth.uid())
    )));
CREATE POLICY event_games_manage ON event_games FOR ALL
    USING (EXISTS (SELECT 1 FROM events WHERE events.id = event_id AND events.host_id = auth.uid()));

-- Time options: follow event policy
CREATE POLICY time_options_select ON time_options FOR SELECT
    USING (EXISTS (SELECT 1 FROM events WHERE events.id = event_id AND (
        events.host_id = auth.uid()
        OR EXISTS (SELECT 1 FROM invites WHERE invites.event_id = events.id AND invites.user_id = auth.uid())
    )));
CREATE POLICY time_options_insert ON time_options FOR INSERT
    WITH CHECK (
        EXISTS (SELECT 1 FROM events WHERE events.id = event_id AND events.host_id = auth.uid())
        OR EXISTS (SELECT 1 FROM events WHERE events.id = event_id AND events.allow_time_suggestions = true
            AND EXISTS (SELECT 1 FROM invites WHERE invites.event_id = events.id AND invites.user_id = auth.uid()))
    );

-- Invites: host manages, invitee can view/update own
CREATE POLICY invites_host ON invites FOR ALL
    USING (EXISTS (SELECT 1 FROM events WHERE events.id = event_id AND events.host_id = auth.uid()));
CREATE POLICY invites_own ON invites FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY invites_respond ON invites FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Time option votes
CREATE POLICY votes_all ON time_option_votes FOR ALL
    USING (EXISTS (SELECT 1 FROM invites WHERE invites.id = invite_id AND invites.user_id = auth.uid()));

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_groups_updated_at BEFORE UPDATE ON groups FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_events_updated_at BEFORE UPDATE ON events FOR EACH ROW EXECUTE FUNCTION update_updated_at();
