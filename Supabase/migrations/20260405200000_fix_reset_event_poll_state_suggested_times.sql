-- Re-fix reset_event_poll_state: 20260403_add_voted_invite_status.sql re-created the function
-- after the earlier fix, re-introducing "suggested_times = null" on a column that does not exist.

CREATE OR REPLACE FUNCTION reset_event_poll_state(
    p_event_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_event events%rowtype;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT *
    INTO v_event
    FROM events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event not found';
    END IF;

    IF v_event.host_id <> v_user_id THEN
        RAISE EXCEPTION 'Only the host can reset poll state';
    END IF;

    UPDATE events
    SET confirmed_time_option_id = null,
        schedule_mode = 'poll',
        updated_at = now()
    WHERE id = p_event_id;

    DELETE FROM time_option_votes tov
    USING time_options to2
    WHERE to2.id = tov.time_option_id
      AND to2.event_id = p_event_id;

    -- Reset non-declined responses; leave declined unchanged.
    -- Note: suggested_times is not a column on invites; suggested times live in time_options.
    UPDATE invites
    SET status = 'pending',
        responded_at = null,
        selected_time_option_ids = '{}'::uuid[]
    WHERE event_id = p_event_id
      AND status IN ('accepted', 'maybe', 'voted');

    UPDATE event_participants
    SET rsvp_status = 'pending',
        responded_at = null,
        updated_at = now()
    WHERE event_id = p_event_id
      AND role = 'guest'
      AND rsvp_status NOT IN ('declined');

    RETURN jsonb_build_object(
        'event_id', p_event_id,
        'status', 'ok'
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION reset_event_poll_state(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION reset_event_poll_state(uuid) TO authenticated;
