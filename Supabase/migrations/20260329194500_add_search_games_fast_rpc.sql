-- Add a dedicated RPC name for app search to avoid any stale schema-cache coupling
-- to historical versions of search_games_fuzzy.

CREATE OR REPLACE FUNCTION public.search_games_fast(
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
LANGUAGE sql
STABLE
SET search_path TO public
SET jit TO off
AS $$
    SELECT *
    FROM public.search_games_fuzzy(search_query, result_limit);
$$;

GRANT EXECUTE ON FUNCTION public.search_games_fast(text, int) TO authenticated;
