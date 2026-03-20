-- Activity feed: poll confirmation announcements + RLS fix for host-triggered rsvp_update inserts

-- 1. Expand type CHECK constraint to include date_confirmed and game_confirmed
ALTER TABLE activity_feed DROP CONSTRAINT IF EXISTS activity_feed_type_check;
ALTER TABLE activity_feed ADD CONSTRAINT activity_feed_type_check
    CHECK (type IN ('comment', 'rsvp_update', 'announcement', 'date_confirmed', 'game_confirmed'));

-- 2. RLS fix: allow host to insert rsvp_update entries on behalf of their event invitees
--    (needed because confirm_time_option updates invites, which triggers auto_post_rsvp_update
--    as the host's auth context but inserts rows with user_id = the invitee)
CREATE POLICY activity_feed_insert_host_rsvp ON activity_feed FOR INSERT WITH CHECK (
    type = 'rsvp_update'
    AND EXISTS (
        SELECT 1 FROM events
        WHERE events.id = activity_feed.event_id
          AND events.host_id = auth.uid()
    )
);

-- 3. Update confirm_time_option to post a date_confirmed entry to activity_feed
CREATE OR REPLACE FUNCTION confirm_time_option(
    p_event_id uuid,
    p_time_option_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_event events%rowtype;
    v_affected_invite_ids uuid[];
    v_start_time text;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT * INTO v_event
    FROM events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event not found';
    END IF;

    IF v_event.host_id <> v_user_id THEN
        RAISE EXCEPTION 'Only the host can confirm a time option';
    END IF;

    -- Capture the confirmed start_time as ISO 8601 UTC for the announcement
    SELECT to_char(start_time AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    INTO v_start_time
    FROM time_options
    WHERE id = p_time_option_id;

    -- Set confirmed time option and end the poll (switch to fixed mode)
    UPDATE events
    SET confirmed_time_option_id = p_time_option_id,
        schedule_mode = 'fixed',
        updated_at = now()
    WHERE id = p_event_id;

    -- Remove non-confirmed time options (poll is over)
    DELETE FROM time_options
    WHERE event_id = p_event_id
      AND id <> p_time_option_id;

    -- Auto-update invites: yes voters -> accepted, maybe voters -> maybe
    UPDATE invites
    SET status = 'accepted',
        responded_at = coalesce(responded_at, now())
    WHERE event_id = p_event_id
      AND id IN (
          SELECT tov.invite_id
          FROM time_option_votes tov
          WHERE tov.time_option_id = p_time_option_id
            AND tov.vote_type = 'yes'
      )
      AND status IN ('pending', 'maybe');

    UPDATE invites
    SET status = 'maybe',
        responded_at = coalesce(responded_at, now())
    WHERE event_id = p_event_id
      AND id IN (
          SELECT tov.invite_id
          FROM time_option_votes tov
          WHERE tov.time_option_id = p_time_option_id
            AND tov.vote_type = 'maybe'
      )
      AND status = 'pending';

    -- Sync event_participants rsvp_status
    UPDATE event_participants ep
    SET rsvp_status = i.status,
        updated_at = now()
    FROM invites i
    WHERE i.event_id = p_event_id
      AND ep.source_invite_id = i.id
      AND ep.rsvp_status <> i.status;

    -- Post date_confirmed announcement to activity feed
    INSERT INTO activity_feed (event_id, user_id, type, content)
    VALUES (p_event_id, v_user_id, 'date_confirmed', v_start_time);

    -- Collect affected invite IDs for notification
    SELECT array_agg(i.id)
    INTO v_affected_invite_ids
    FROM invites i
    WHERE i.event_id = p_event_id
      AND i.status IN ('accepted', 'maybe');

    RETURN jsonb_build_object(
        'event_id', p_event_id,
        'confirmed_time_option_id', p_time_option_id,
        'affected_invite_ids', to_jsonb(coalesce(v_affected_invite_ids, '{}'::uuid[]))
    );
END;
$$;

GRANT EXECUTE ON FUNCTION confirm_time_option(uuid, uuid) TO authenticated;
