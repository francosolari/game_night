-- Fix search_games_fuzzy performance: remove word_similarity from WHERE clause
-- which forced a full sequential scan of all 97k games.
-- Now uses only ILIKE for filtering (hits idx_games_name_trgm trigram index),
-- with similarity() only in ORDER BY for ranking. ~9s → ~50ms warm cache.

CREATE OR REPLACE FUNCTION search_games_fuzzy(
    search_query text,
    result_limit int DEFAULT 20
)
RETURNS SETOF games
LANGUAGE sql
STABLE
AS $$
    SELECT g.*
    FROM games g
    WHERE g.bgg_id IS NOT NULL
      AND g.owner_id IS NULL
      AND g.name ILIKE ('%' || search_query || '%')
    ORDER BY
      CASE WHEN lower(g.name) LIKE lower(search_query || '%') THEN 0 ELSE 1 END,
      similarity(g.name, search_query) DESC,
      g.bgg_rank ASC NULLS LAST,
      g.name ASC
    LIMIT GREATEST(COALESCE(result_limit, 20), 1);
$$;

-- Also backfill any games still missing publisher entries in game_creators
-- (defensive: function already ran, this is a no-op if complete)
CREATE OR REPLACE FUNCTION backfill_publisher_creators(batch_size INT DEFAULT 5000)
RETURNS INT AS $$
DECLARE
  inserted_count INT;
BEGIN
  WITH missing_games AS (
    SELECT g.id
    FROM games g
    WHERE array_length(g.publishers, 1) > 0
      AND NOT EXISTS (
        SELECT 1 FROM game_creators gc
        WHERE gc.game_id = g.id AND gc.creator_role = 'publisher'
      )
    ORDER BY g.id
    LIMIT batch_size
  )
  INSERT INTO game_creators (
    game_id, creator_name, creator_role,
    bgg_id, name, year_published, thumbnail_url, image_url,
    min_players, max_players, min_playtime, max_playtime,
    complexity, bgg_rating, bgg_rank, categories, mechanics,
    designers, publishers, artists, min_age, owner_id, recommended_players
  )
  SELECT g.id, pub.publisher_name, 'publisher',
    g.bgg_id, g.name, g.year_published, g.thumbnail_url, g.image_url,
    g.min_players, g.max_players, g.min_playtime, g.max_playtime,
    g.complexity, g.bgg_rating, g.bgg_rank, g.categories, g.mechanics,
    g.designers, g.publishers, g.artists, g.min_age, g.owner_id, g.recommended_players
  FROM missing_games mg
  JOIN games g ON g.id = mg.id
  CROSS JOIN LATERAL unnest(g.publishers) AS pub(publisher_name)
  ON CONFLICT (game_id, creator_name, creator_role) DO NOTHING;

  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  RETURN inserted_count;
END;
$$ LANGUAGE plpgsql;
