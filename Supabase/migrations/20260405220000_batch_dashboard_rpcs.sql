-- Batch dashboard RPCs: fetch events + plays for multiple groups in a single query.
-- Replaces N individual get_group_events / get_group_plays calls with 2 total,
-- reducing server round trips from 2N → 2 for the groups tab dashboard.

-- ============================================================
-- get_dashboard_events(p_group_ids uuid[])
-- Returns events for all supplied groups the caller is a member/owner of.
-- Same shape as get_group_events per-event row.
-- ============================================================
CREATE OR REPLACE FUNCTION get_dashboard_events(p_group_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET jit = off
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_result  jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(event_row ORDER BY (sub.event_row->>'created_at')::timestamptz DESC NULLS LAST), '[]'::jsonb)
  INTO v_result
  FROM events e
  -- Only groups the caller may access
  JOIN groups g ON g.id = e.group_id
    AND g.id = ANY(p_group_ids)
    AND (
      g.owner_id = v_uid
      OR EXISTS (
        SELECT 1 FROM group_members gm
        WHERE gm.group_id = g.id
          AND gm.user_id  = v_uid
          AND gm.status   IN ('accepted', 'pending')
      )
    )
  CROSS JOIN LATERAL (
    SELECT to_jsonb(e) || jsonb_build_object(
      'host', (SELECT to_jsonb(u) FROM users u WHERE u.id = e.host_id),
      'games', coalesce(
        (SELECT jsonb_agg(
          to_jsonb(eg) || jsonb_build_object(
            'game', (SELECT to_jsonb(gm) FROM games gm WHERE gm.id = eg.game_id)
          )
        ) FROM event_games eg WHERE eg.event_id = e.id),
        '[]'::jsonb
      ),
      'time_options', coalesce(
        (SELECT jsonb_agg(to_jsonb(t)) FROM time_options t WHERE t.event_id = e.id),
        '[]'::jsonb
      ),
      'groups', jsonb_build_object('id', g.id, 'name', g.name, 'emoji', g.emoji)
    ) AS event_row
  ) sub
  WHERE e.deleted_at IS NULL;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_dashboard_events(uuid[]) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION get_dashboard_events(uuid[]) TO authenticated, service_role;

-- ============================================================
-- get_dashboard_plays(p_group_ids uuid[])
-- Returns plays for all supplied groups the caller is a member/owner of.
-- Same shape as get_group_plays per-play row.
-- ============================================================
CREATE OR REPLACE FUNCTION get_dashboard_plays(p_group_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET jit = off
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_result jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(play_row ORDER BY (sub.play_row->>'played_at')::timestamptz DESC NULLS LAST), '[]'::jsonb)
  INTO v_result
  FROM plays p
  -- Only groups the caller may access
  JOIN groups g ON g.id = p.group_id
    AND g.id = ANY(p_group_ids)
    AND (
      g.owner_id = v_uid
      OR EXISTS (
        SELECT 1 FROM group_members gm
        WHERE gm.group_id = g.id
          AND gm.user_id  = v_uid
          AND gm.status   IN ('accepted', 'pending')
      )
    )
  CROSS JOIN LATERAL (
    SELECT to_jsonb(p) || jsonb_build_object(
      'game', (SELECT to_jsonb(gm) FROM games gm WHERE gm.id = p.game_id),
      'play_participants', coalesce(
        (SELECT jsonb_agg(to_jsonb(pp)) FROM play_participants pp WHERE pp.play_id = p.id),
        '[]'::jsonb
      ),
      'logged_by_user', (SELECT to_jsonb(u) FROM users u WHERE u.id = p.logged_by)
    ) AS play_row
  ) sub;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_dashboard_plays(uuid[]) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION get_dashboard_plays(uuid[]) TO authenticated, service_role;
