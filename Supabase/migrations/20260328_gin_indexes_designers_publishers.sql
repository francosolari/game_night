-- GIN indexes for array containment queries on games table.
-- These make fetchGamesByDesigner and fetchGamesByPublisher fast
-- by avoiding full table scans on @> array operators.
CREATE INDEX IF NOT EXISTS idx_games_designers_gin
    ON games USING GIN (designers);

CREATE INDEX IF NOT EXISTS idx_games_publishers_gin
    ON games USING GIN (publishers);

-- Same pattern used for mechanics/categories filters.
CREATE INDEX IF NOT EXISTS idx_games_mechanics_gin
    ON games USING GIN (mechanics);

CREATE INDEX IF NOT EXISTS idx_games_categories_gin
    ON games USING GIN (categories);
