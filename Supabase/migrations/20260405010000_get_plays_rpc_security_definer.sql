-- SECURITY DEFINER RPCs for plays hot paths.
-- Rationale: plays_select and play_participants_select RLS have deeply nested
-- EXISTS checks that compound under concurrency, exceeding the 8s statement_timeout.
-- These RPCs validate membership once and bypass per-row RLS evaluation.

-- ============================================================
-- get_group_plays: returns plays for a group with game, participants, logger
-- ============================================================
CREATE OR REPLACE FUNCTION get_group_plays(p_group_id uuid)
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

  -- Build plays array with embedded game, participants, logger
  SELECT coalesce(jsonb_agg(play_row ORDER BY (sub.play_row->>'played_at')::timestamptz DESC NULLS LAST), '[]'::jsonb)
  INTO v_result
  FROM plays p
  CROSS JOIN LATERAL (
    SELECT to_jsonb(p) || jsonb_build_object(
      'game', (SELECT to_jsonb(g) FROM games g WHERE g.id = p.game_id),
      'play_participants', coalesce(
        (SELECT jsonb_agg(to_jsonb(pp)) FROM play_participants pp WHERE pp.play_id = p.id),
        '[]'::jsonb
      ),
      'logged_by_user', (SELECT to_jsonb(u) FROM users u WHERE u.id = p.logged_by)
    ) AS play_row
  ) sub
  WHERE p.group_id = p_group_id;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_group_plays(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_group_plays(uuid) TO authenticated, service_role;

-- ============================================================
-- get_event_plays: returns plays for an event with game, participants, logger
-- ============================================================
CREATE OR REPLACE FUNCTION get_event_plays(p_event_id uuid)
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
  -- Membership gate: event host OR invited user
  IF NOT EXISTS (
    SELECT 1 FROM events WHERE id = p_event_id AND host_id = v_uid
  ) AND NOT EXISTS (
    SELECT 1 FROM invites
    WHERE event_id = p_event_id AND user_id = v_uid
  ) THEN
    RAISE EXCEPTION 'Not authorized to view this event';
  END IF;

  -- Build plays array with embedded game, participants, logger
  SELECT coalesce(jsonb_agg(play_row ORDER BY (sub.play_row->>'played_at')::timestamptz DESC NULLS LAST), '[]'::jsonb)
  INTO v_result
  FROM plays p
  CROSS JOIN LATERAL (
    SELECT to_jsonb(p) || jsonb_build_object(
      'game', (SELECT to_jsonb(g) FROM games g WHERE g.id = p.game_id),
      'play_participants', coalesce(
        (SELECT jsonb_agg(to_jsonb(pp)) FROM play_participants pp WHERE pp.play_id = p.id),
        '[]'::jsonb
      ),
      'logged_by_user', (SELECT to_jsonb(u) FROM users u WHERE u.id = p.logged_by)
    ) AS play_row
  ) sub
  WHERE p.event_id = p_event_id;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_event_plays(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_event_plays(uuid) TO authenticated, service_role;

-- ============================================================
-- Simplify play_participants_select RLS for remaining direct-query paths.
-- Delegates visibility to plays_select instead of duplicating nested EXISTS.
-- ============================================================
DROP POLICY IF EXISTS "play_participants_select" ON play_participants;
CREATE POLICY "play_participants_select" ON play_participants FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM plays
    WHERE plays.id = play_participants.play_id
  )
);
