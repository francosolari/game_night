-- Plays & Group Linking Migration
-- Adds play logging, group chat, and event-group linking

-- ============================================================
-- ADD group_id TO EVENTS
-- ============================================================
ALTER TABLE events ADD COLUMN group_id UUID REFERENCES groups(id) ON DELETE SET NULL;
CREATE INDEX idx_events_group ON events(group_id);

-- ============================================================
-- PLAYS
-- ============================================================
CREATE TABLE plays (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    logged_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    played_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_minutes INTEGER,
    notes TEXT,
    is_cooperative BOOLEAN DEFAULT FALSE,
    cooperative_result TEXT CHECK (cooperative_result IS NULL OR cooperative_result IN ('won', 'lost')),
    bgg_play_id INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_plays_event ON plays(event_id);
CREATE INDEX idx_plays_group ON plays(group_id);
CREATE INDEX idx_plays_game ON plays(game_id);
CREATE INDEX idx_plays_logged_by ON plays(logged_by);

-- ============================================================
-- PLAY PARTICIPANTS
-- ============================================================
CREATE TABLE play_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    play_id UUID NOT NULL REFERENCES plays(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    phone_number TEXT,
    display_name TEXT NOT NULL,
    placement INTEGER,
    is_winner BOOLEAN DEFAULT FALSE,
    score INTEGER,
    team TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_play_participants_play ON play_participants(play_id);
CREATE INDEX idx_play_participants_user ON play_participants(user_id);
CREATE UNIQUE INDEX idx_play_participants_unique_user
    ON play_participants(play_id, user_id) WHERE user_id IS NOT NULL;

-- ============================================================
-- GROUP MESSAGES
-- ============================================================
CREATE TABLE group_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    parent_id UUID REFERENCES group_messages(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_group_messages_group ON group_messages(group_id);
CREATE INDEX idx_group_messages_user ON group_messages(user_id);
CREATE INDEX idx_group_messages_parent ON group_messages(parent_id);

-- ============================================================
-- TRIGGERS: auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER plays_updated_at
    BEFORE UPDATE ON plays
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER group_messages_updated_at
    BEFORE UPDATE ON group_messages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE plays ENABLE ROW LEVEL SECURITY;
ALTER TABLE play_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_messages ENABLE ROW LEVEL SECURITY;

-- PLAYS: SELECT — logger, event participants (host or invited), or group members/owner
CREATE POLICY plays_select ON plays FOR SELECT USING (
    auth.uid() = logged_by
    OR (event_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM events WHERE events.id = event_id AND (
            events.host_id = auth.uid()
            OR EXISTS (SELECT 1 FROM invites WHERE invites.event_id = plays.event_id AND invites.user_id = auth.uid())
        )
    ))
    OR (group_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM groups WHERE groups.id = plays.group_id AND (
            groups.owner_id = auth.uid()
            OR EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = plays.group_id AND group_members.user_id = auth.uid())
        )
    ))
);

-- PLAYS: INSERT — logged_by must be current user
CREATE POLICY plays_insert ON plays FOR INSERT WITH CHECK (auth.uid() = logged_by);

-- PLAYS: UPDATE/DELETE — logger only
CREATE POLICY plays_update ON plays FOR UPDATE USING (auth.uid() = logged_by);
CREATE POLICY plays_delete ON plays FOR DELETE USING (auth.uid() = logged_by);

-- PLAY PARTICIPANTS: SELECT follows play visibility
CREATE POLICY play_participants_select ON play_participants FOR SELECT USING (
    EXISTS (SELECT 1 FROM plays WHERE plays.id = play_id AND (
        plays.logged_by = auth.uid()
        OR (plays.event_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM events WHERE events.id = plays.event_id AND (
                events.host_id = auth.uid()
                OR EXISTS (SELECT 1 FROM invites WHERE invites.event_id = plays.event_id AND invites.user_id = auth.uid())
            )
        ))
        OR (plays.group_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM groups WHERE groups.id = plays.group_id AND (
                groups.owner_id = auth.uid()
                OR EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = plays.group_id AND group_members.user_id = auth.uid())
            )
        ))
    ))
);

-- PLAY PARTICIPANTS: INSERT/UPDATE/DELETE — play logger only
CREATE POLICY play_participants_insert ON play_participants FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM plays WHERE plays.id = play_id AND plays.logged_by = auth.uid())
);
CREATE POLICY play_participants_update ON play_participants FOR UPDATE USING (
    EXISTS (SELECT 1 FROM plays WHERE plays.id = play_id AND plays.logged_by = auth.uid())
);
CREATE POLICY play_participants_delete ON play_participants FOR DELETE USING (
    EXISTS (SELECT 1 FROM plays WHERE plays.id = play_id AND plays.logged_by = auth.uid())
);

-- GROUP MESSAGES: SELECT — group owner or members with user_id
CREATE POLICY group_messages_select ON group_messages FOR SELECT USING (
    EXISTS (SELECT 1 FROM groups WHERE groups.id = group_id AND (
        groups.owner_id = auth.uid()
        OR EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = group_messages.group_id AND group_members.user_id = auth.uid())
    ))
);

-- GROUP MESSAGES: INSERT — group owner or members
CREATE POLICY group_messages_insert ON group_messages FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM groups WHERE groups.id = group_id AND (
        groups.owner_id = auth.uid()
        OR EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = group_messages.group_id AND group_members.user_id = auth.uid())
    ))
);

-- GROUP MESSAGES: DELETE — own messages or group owner
CREATE POLICY group_messages_delete ON group_messages FOR DELETE USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM groups WHERE groups.id = group_id AND groups.owner_id = auth.uid())
);

-- GROUP MESSAGES: UPDATE — own messages only
CREATE POLICY group_messages_update ON group_messages FOR UPDATE USING (auth.uid() = user_id);

-- GROUP MEMBERS: Allow members to see their own membership row (no cross-reference to groups)
CREATE POLICY group_members_select_self ON group_members FOR SELECT
    USING (auth.uid() = user_id);
