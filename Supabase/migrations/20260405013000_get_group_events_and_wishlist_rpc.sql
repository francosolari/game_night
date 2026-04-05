-- SECURITY DEFINER RPCs for events and wishlist hot paths.
-- Same rationale as get_group_plays: nested RLS policies compound under
-- concurrency and exceed the 8s statement_timeout.

-- ============================================================
-- get_group_events: returns events for a group with host, games, time_options, group
-- ============================================================
CREATE OR REPLACE FUNCTION get_group_events(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET jit = off
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_result jsonb;
BEGIN
  -- Membership gate: owner OR accepted/pending member
  IF NOT EXISTS (
    SELECT 1 FROM groups WHERE id = p_group_id AND owner_id = v_uid
  ) AND NOT EXISTS (
    SELECT 1 FROM group_members
    WHERE group_id = p_group_id AND user_id = v_uid
      AND status IN ('accepted', 'pending')
  ) THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  SELECT coalesce(jsonb_agg(event_row ORDER BY (sub.event_row->>'created_at')::timestamptz DESC NULLS LAST), '[]'::jsonb)
  INTO v_result
  FROM events e
  CROSS JOIN LATERAL (
    SELECT to_jsonb(e) || jsonb_build_object(
      'host', (SELECT to_jsonb(u) FROM users u WHERE u.id = e.host_id),
      'games', coalesce(
        (SELECT jsonb_agg(
          to_jsonb(eg) || jsonb_build_object(
            'game', (SELECT to_jsonb(g) FROM games g WHERE g.id = eg.game_id)
          )
        ) FROM event_games eg WHERE eg.event_id = e.id),
        '[]'::jsonb
      ),
      'time_options', coalesce(
        (SELECT jsonb_agg(to_jsonb(t)) FROM time_options t WHERE t.event_id = e.id),
        '[]'::jsonb
      ),
      'groups', (
        SELECT jsonb_build_object('id', gr.id, 'name', gr.name, 'emoji', gr.emoji)
        FROM groups gr WHERE gr.id = e.group_id
      )
    ) AS event_row
  ) sub
  WHERE e.group_id = p_group_id
    AND e.deleted_at IS NULL;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_group_events(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_group_events(uuid) TO authenticated, service_role;

-- ============================================================
-- get_user_wishlist: returns wishlist entries for the calling user with game
-- ============================================================
CREATE OR REPLACE FUNCTION get_user_wishlist()
RETURNS jsonb
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET jit = off
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_result jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(entry_row ORDER BY (sub.entry_row->>'added_at')::timestamptz DESC NULLS LAST), '[]'::jsonb)
  INTO v_result
  FROM game_wishlist w
  CROSS JOIN LATERAL (
    SELECT to_jsonb(w) || jsonb_build_object(
      'game', (SELECT to_jsonb(g) FROM games g WHERE g.id = w.game_id)
    ) AS entry_row
  ) sub
  WHERE w.user_id = v_uid;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_user_wishlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_user_wishlist() TO authenticated, service_role;
