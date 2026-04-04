-- Production hardening for Games tab search.
-- 1) Add a partial prefix index for 3-char queries (common high-fanout case).
-- 2) Replace search_games_fuzzy with a branch optimized for short vs longer queries.

CREATE INDEX IF NOT EXISTS idx_games_name_prefix_bgg
ON public.games (lower(name) text_pattern_ops)
WHERE bgg_id IS NOT NULL AND owner_id IS NULL;

CREATE OR REPLACE FUNCTION public.search_games_fuzzy(
    search_query text,
    result_limit int DEFAULT 20
)
RETURNS SETOF public.games
LANGUAGE sql
STABLE
SET search_path TO public
AS $$
    WITH normalized AS (
        SELECT
            trim(coalesce(search_query, '')) AS raw_query,
            lower(trim(coalesce(search_query, ''))) AS normalized_query,
            length(trim(coalesce(search_query, ''))) AS query_len,
            GREATEST(COALESCE(result_limit, 20), 1) AS lim
    )
    SELECT g.*
    FROM public.games g
    CROSS JOIN normalized q
    WHERE g.bgg_id IS NOT NULL
      AND g.owner_id IS NULL
      AND q.query_len >= 3
      AND (
        (q.query_len = 3 AND lower(g.name) LIKE (q.normalized_query || '%'))
        OR
        (q.query_len >= 4 AND g.name ILIKE ('%' || q.raw_query || '%'))
      )
    ORDER BY
      CASE
          WHEN lower(g.name) LIKE (q.normalized_query || '%') THEN 0
          WHEN lower(g.name) LIKE ('% ' || q.normalized_query || '%') THEN 1
          ELSE 2
      END,
      CASE WHEN q.query_len >= 4 THEN similarity(g.name, q.raw_query) ELSE 0 END DESC,
      g.bgg_rank ASC NULLS LAST,
      g.name ASC
    LIMIT (SELECT lim FROM normalized);
$$;

GRANT EXECUTE ON FUNCTION public.search_games_fuzzy(text, int) TO authenticated;
