-- Manual games stay private
-- Adds an owner_id marker and reworks the games policies so only the owner (or an event participant) can read/edit manual rows.

ALTER TABLE games
    ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES users(id);

CREATE INDEX IF NOT EXISTS idx_games_owner_id ON games(owner_id);

DROP POLICY IF EXISTS games_select ON games;
DROP POLICY IF EXISTS games_insert ON games;
DROP POLICY IF EXISTS games_update ON games;

CREATE POLICY games_select ON games
    FOR SELECT
    USING (
        owner_id IS NULL
        OR owner_id = auth.uid()
        OR EXISTS (
            SELECT 1
            FROM event_games
            JOIN events ON events.id = event_games.event_id
            WHERE event_games.game_id = games.id
                AND (
                    events.host_id = auth.uid()
                    OR EXISTS (
                        SELECT 1 FROM invites
                        WHERE invites.event_id = events.id
                          AND invites.user_id = auth.uid()
                    )
                )
        )
    );

CREATE POLICY games_insert ON games
    FOR INSERT
    WITH CHECK (
        owner_id IS NULL
        OR owner_id = auth.uid()
    );

CREATE POLICY games_update ON games
    FOR UPDATE
    USING (
        owner_id IS NULL
        OR owner_id = auth.uid()
    )
    WITH CHECK (
        owner_id IS NULL
        OR owner_id = auth.uid()
    );
