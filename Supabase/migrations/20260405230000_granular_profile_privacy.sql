-- Add granular privacy columns to users table
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS wishlist_public boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS plays_public boolean NOT NULL DEFAULT true;

-- RPC: fetch public plays for a user profile (respects plays_public setting)
CREATE OR REPLACE FUNCTION get_user_public_plays(p_user_id uuid)
RETURNS SETOF json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plays_public boolean;
BEGIN
  SELECT plays_public INTO v_plays_public FROM users WHERE id = p_user_id;
  IF NOT FOUND OR NOT v_plays_public THEN
    RETURN;
  END IF;

  RETURN QUERY
    SELECT row_to_json(play_row)
    FROM (
      SELECT
        pl.id,
        pl.event_id,
        pl.group_id,
        pl.game_id,
        pl.logged_by,
        pl.played_at,
        pl.duration_minutes,
        pl.notes,
        pl.is_cooperative,
        pl.cooperative_result,
        pl.bgg_play_id,
        pl.quantity,
        pl.location,
        pl.incomplete,
        pl.created_at,
        pl.updated_at,
        row_to_json(g.*) AS game,
        COALESCE(
          (SELECT json_agg(row_to_json(pp))
           FROM play_participants pp WHERE pp.play_id = pl.id),
          '[]'::json
        ) AS play_participants,
        NULL::json AS logged_by_user
      FROM plays pl
      LEFT JOIN games g ON g.id = pl.game_id
      WHERE pl.logged_by = p_user_id
        OR EXISTS (
          SELECT 1 FROM play_participants pp2
          WHERE pp2.play_id = pl.id AND pp2.user_id = p_user_id
        )
      ORDER BY pl.played_at DESC
      LIMIT 20
    ) play_row;
END;
$$;

REVOKE ALL ON FUNCTION get_user_public_plays(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_user_public_plays(uuid) TO authenticated, service_role;
