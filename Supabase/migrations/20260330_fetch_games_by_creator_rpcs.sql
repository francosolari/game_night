-- RPC functions for fetching games by designer or publisher.
-- Uses @> array containment which hits GIN indexes on games.designers / games.publishers
-- (created in 20260328_gin_indexes_designers_publishers.sql).

CREATE OR REPLACE FUNCTION public.fetch_games_by_designer(designer_name text)
RETURNS SETOF games
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT * FROM games
  WHERE designers @> ARRAY[designer_name]
  ORDER BY bgg_rating DESC NULLS LAST, name ASC;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_games_by_designer(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.fetch_games_by_publisher(publisher_name text)
RETURNS SETOF games
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT * FROM games
  WHERE publishers @> ARRAY[publisher_name]
  ORDER BY bgg_rating DESC NULLS LAST, name ASC;
$$;

GRANT EXECUTE ON FUNCTION public.fetch_games_by_publisher(text) TO authenticated;
