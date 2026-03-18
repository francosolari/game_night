-- Game detail data model expansion
-- Adds BGG-parity metadata to games and normalized relationship tables for
-- expansions and families.

-- 1. Extend games with additional BGG fields
ALTER TABLE games
    ADD COLUMN IF NOT EXISTS designers text[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS publishers text[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS artists text[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS min_age int,
    ADD COLUMN IF NOT EXISTS bgg_rank int;

-- 2. Backfill existing rows so old records decode safely
UPDATE games
SET designers = '{}'
WHERE designers IS NULL;

UPDATE games
SET publishers = '{}'
WHERE publishers IS NULL;

UPDATE games
SET artists = '{}'
WHERE artists IS NULL;

-- 3. Expansion relationships between games
CREATE TABLE IF NOT EXISTS game_expansions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    base_game_id uuid NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    expansion_game_id uuid NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT game_expansions_no_self CHECK (base_game_id <> expansion_game_id),
    CONSTRAINT game_expansions_unique UNIQUE (base_game_id, expansion_game_id)
);

CREATE INDEX IF NOT EXISTS idx_game_expansions_base ON game_expansions(base_game_id);
CREATE INDEX IF NOT EXISTS idx_game_expansions_expansion ON game_expansions(expansion_game_id);

-- 4. BGG families / series metadata
CREATE TABLE IF NOT EXISTS game_families (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bgg_family_id int NOT NULL UNIQUE,
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- 5. Junction table between games and families
CREATE TABLE IF NOT EXISTS game_family_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id uuid NOT NULL REFERENCES game_families(id) ON DELETE CASCADE,
    game_id uuid NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT game_family_members_unique UNIQUE (family_id, game_id)
);

CREATE INDEX IF NOT EXISTS idx_game_family_members_family ON game_family_members(family_id);
CREATE INDEX IF NOT EXISTS idx_game_family_members_game ON game_family_members(game_id);

-- 6. Row Level Security
ALTER TABLE game_expansions ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_families ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_family_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS game_expansions_select_authenticated ON game_expansions;
DROP POLICY IF EXISTS game_expansions_insert_authenticated ON game_expansions;
DROP POLICY IF EXISTS game_expansions_update_authenticated ON game_expansions;
DROP POLICY IF EXISTS game_expansions_delete_authenticated ON game_expansions;

CREATE POLICY game_expansions_select_authenticated
    ON game_expansions
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY game_expansions_insert_authenticated
    ON game_expansions
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY game_expansions_update_authenticated
    ON game_expansions
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY game_expansions_delete_authenticated
    ON game_expansions
    FOR DELETE
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS game_families_select_authenticated ON game_families;
DROP POLICY IF EXISTS game_families_insert_authenticated ON game_families;
DROP POLICY IF EXISTS game_families_update_authenticated ON game_families;
DROP POLICY IF EXISTS game_families_delete_authenticated ON game_families;

CREATE POLICY game_families_select_authenticated
    ON game_families
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY game_families_insert_authenticated
    ON game_families
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY game_families_update_authenticated
    ON game_families
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY game_families_delete_authenticated
    ON game_families
    FOR DELETE
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS game_family_members_select_authenticated ON game_family_members;
DROP POLICY IF EXISTS game_family_members_insert_authenticated ON game_family_members;
DROP POLICY IF EXISTS game_family_members_update_authenticated ON game_family_members;
DROP POLICY IF EXISTS game_family_members_delete_authenticated ON game_family_members;

CREATE POLICY game_family_members_select_authenticated
    ON game_family_members
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY game_family_members_insert_authenticated
    ON game_family_members
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY game_family_members_update_authenticated
    ON game_family_members
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY game_family_members_delete_authenticated
    ON game_family_members
    FOR DELETE
    TO authenticated
    USING (true);
