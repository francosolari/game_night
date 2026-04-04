-- Make time-confirmed notifications include the selected time in the body text.

create or replace function confirm_time_option(
    p_event_id uuid,
    p_time_option_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
    v_event events%rowtype;
    v_affected_invite_ids uuid[];
    v_start_time text;
    v_notification_time_text text;
    v_time_label text;
begin
    if v_user_id is null then
        raise exception 'Authentication required';
    end if;

    select * into v_event
    from events
    where id = p_event_id;

    if not found then
        raise exception 'Event not found';
    end if;

    if v_event.host_id <> v_user_id then
        raise exception 'Only the host can confirm a time option';
    end if;

    if not exists (
        select 1
        from time_options
        where id = p_time_option_id
          and event_id = p_event_id
    ) then
        raise exception 'Time option does not belong to this event';
    end if;

    select
        to_char(start_time at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        to_char(start_time, 'Dy, Mon FMDD at FMHH12:MI AM TZ'),
        nullif(btrim(label), '')
    into v_start_time, v_notification_time_text, v_time_label
    from time_options
    where id = p_time_option_id;

    update events
    set confirmed_time_option_id = p_time_option_id,
        schedule_mode = 'fixed',
        updated_at = now()
    where id = p_event_id;

    delete from time_options
    where event_id = p_event_id
      and id <> p_time_option_id;

    -- Reconcile from votes deterministically for this decision:
    -- start clean, then promote by vote_type precedence.
    update invites
    set status = 'pending',
        responded_at = null,
        selected_time_option_ids = '{}'::uuid[]
    where event_id = p_event_id
      and status in ('accepted', 'maybe', 'declined', 'pending');

    update invites
    set status = 'accepted',
        responded_at = coalesce(responded_at, now()),
        selected_time_option_ids = array[p_time_option_id]
    where event_id = p_event_id
      and id in (
          select tov.invite_id
          from time_option_votes tov
          where tov.time_option_id = p_time_option_id
            and tov.vote_type = 'yes'
      );

    update invites
    set status = 'maybe',
        responded_at = coalesce(responded_at, now()),
        selected_time_option_ids = '{}'::uuid[]
    where event_id = p_event_id
      and id in (
          select tov.invite_id
          from time_option_votes tov
          where tov.time_option_id = p_time_option_id
            and tov.vote_type = 'maybe'
      )
      and status = 'pending';

    update invites
    set status = 'declined',
        responded_at = coalesce(responded_at, now()),
        selected_time_option_ids = '{}'::uuid[]
    where event_id = p_event_id
      and id in (
          select tov.invite_id
          from time_option_votes tov
          where tov.time_option_id = p_time_option_id
            and tov.vote_type = 'no'
      )
      and status = 'pending';

    update event_participants ep
    set rsvp_status = i.status,
        responded_at = i.responded_at,
        updated_at = now()
    from invites i
    where i.event_id = p_event_id
      and ep.source_invite_id = i.id
      and (ep.rsvp_status <> i.status or ep.responded_at is distinct from i.responded_at);

    insert into activity_feed (event_id, user_id, type, content)
    values (p_event_id, v_user_id, 'date_confirmed', v_start_time);

    -- In-app/push notifications (no SMS blast):
    insert into notifications (user_id, type, title, body, event_id, invite_id, metadata)
    select
        i.user_id,
        'time_confirmed',
        'Date Confirmed',
        coalesce(v_event.title, 'Game Night') || ' is locked in for ' || coalesce(v_time_label, v_notification_time_text, v_start_time) || '.',
        p_event_id,
        i.id,
        jsonb_build_object(
            'time_option_id', p_time_option_id,
            'start_time_utc', v_start_time,
            'time_display', coalesce(v_time_label, v_notification_time_text, v_start_time)
        )
    from invites i
    where i.event_id = p_event_id
      and i.user_id is not null
      and i.user_id <> v_user_id
      and i.status <> 'declined';

    select array_agg(i.id)
    into v_affected_invite_ids
    from invites i
    where i.event_id = p_event_id
      and i.status in ('accepted', 'maybe');

    return jsonb_build_object(
        'event_id', p_event_id,
        'confirmed_time_option_id', p_time_option_id,
        'affected_invite_ids', to_jsonb(coalesce(v_affected_invite_ids, '{}'::uuid[]))
    );
end;
$$;

grant execute on function confirm_time_option(uuid, uuid) to authenticated;
