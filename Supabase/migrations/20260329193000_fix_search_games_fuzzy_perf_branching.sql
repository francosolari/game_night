-- Fix planner regression from CTE/OR branching and harden search latency.
-- Strategy:
-- - 3-4 chars: prefix-only search (fast, predictable, high signal while typing)
-- - 5+ chars: substring search with similarity ranking
-- - Return a lightweight game payload to avoid wide-row/TOAST overhead during search.

DROP FUNCTION IF EXISTS public.search_games_fuzzy(text, int);

CREATE FUNCTION public.search_games_fuzzy(
    search_query text,
    result_limit int DEFAULT 20
)
RETURNS TABLE (
    id uuid,
    owner_id uuid,
    bgg_id integer,
    name text,
    year_published integer,
    thumbnail_url text,
    image_url text,
    min_players integer,
    max_players integer,
    recommended_players integer[],
    min_playtime integer,
    max_playtime integer,
    complexity double precision,
    bgg_rating double precision,
    description text,
    categories text[],
    mechanics text[],
    designers text[],
    publishers text[],
    artists text[],
    min_age integer,
    bgg_rank integer,
    bgg_last_synced timestamptz
)
LANGUAGE plpgsql
STABLE
SET search_path TO public
SET jit TO off
AS $$
DECLARE
    q text := trim(coalesce(search_query, ''));
    q_lower text := lower(trim(coalesce(search_query, '')));
    lim int := GREATEST(COALESCE(result_limit, 20), 1);
BEGIN
    IF length(q) < 3 THEN
        RETURN;
    END IF;

    IF length(q) <= 4 THEN
        RETURN QUERY
        SELECT
            g.id,
            g.owner_id,
            g.bgg_id,
            g.name,
            g.year_published,
            g.thumbnail_url,
            g.image_url,
            g.min_players,
            g.max_players,
            g.recommended_players,
            g.min_playtime,
            g.max_playtime,
            g.complexity,
            g.bgg_rating,
            NULL::text AS description,
            ARRAY[]::text[] AS categories,
            ARRAY[]::text[] AS mechanics,
            ARRAY[]::text[] AS designers,
            ARRAY[]::text[] AS publishers,
            ARRAY[]::text[] AS artists,
            g.min_age,
            g.bgg_rank,
            g.bgg_last_synced
        FROM public.games g
        WHERE g.bgg_id IS NOT NULL
          AND g.owner_id IS NULL
          AND lower(g.name) LIKE (q_lower || '%')
        ORDER BY lower(g.name) ASC
        LIMIT lim;
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        g.id,
        g.owner_id,
        g.bgg_id,
        g.name,
        g.year_published,
        g.thumbnail_url,
        g.image_url,
        g.min_players,
        g.max_players,
        g.recommended_players,
        g.min_playtime,
        g.max_playtime,
        g.complexity,
        g.bgg_rating,
        NULL::text AS description,
        ARRAY[]::text[] AS categories,
        ARRAY[]::text[] AS mechanics,
        ARRAY[]::text[] AS designers,
        ARRAY[]::text[] AS publishers,
        ARRAY[]::text[] AS artists,
        g.min_age,
        g.bgg_rank,
        g.bgg_last_synced
    FROM public.games g
    WHERE g.bgg_id IS NOT NULL
      AND g.owner_id IS NULL
      AND g.name ILIKE ('%' || q || '%')
    ORDER BY
      CASE WHEN lower(g.name) LIKE (q_lower || '%') THEN 0 ELSE 1 END,
      similarity(g.name, q) DESC,
      g.bgg_rank ASC NULLS LAST,
      g.name ASC
    LIMIT lim;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_games_fuzzy(text, int) TO authenticated;
