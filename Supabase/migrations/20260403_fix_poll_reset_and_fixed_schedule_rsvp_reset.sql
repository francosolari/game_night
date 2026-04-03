-- 1) Fix reset_event_poll_state referencing removed invites.suggested_times column.
-- 2) Keep declined RSVPs unchanged when resetting poll/schedule.
-- 3) Add RPC for fixed-date schedule changes that resets non-declined RSVPs to pending.

create or replace function reset_event_poll_state(
    p_event_id uuid
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
    v_event events%rowtype;
begin
    if v_user_id is null then
        raise exception 'Authentication required';
    end if;

    select *
    into v_event
    from events
    where id = p_event_id;

    if not found then
        raise exception 'Event not found';
    end if;

    if v_event.host_id <> v_user_id then
        raise exception 'Only the host can reset poll state';
    end if;

    update events
    set confirmed_time_option_id = null,
        schedule_mode = 'poll',
        updated_at = now()
    where id = p_event_id;

    delete from time_option_votes tov
    using time_options to2
    where to2.id = tov.time_option_id
      and to2.event_id = p_event_id;

    -- Reset only non-declined responses
    update invites
    set status = 'pending',
        responded_at = null,
        selected_time_option_ids = '{}'::uuid[]
    where event_id = p_event_id
      and status <> 'declined';

    update event_participants
    set rsvp_status = 'pending',
        responded_at = null,
        updated_at = now()
    where event_id = p_event_id
      and role = 'guest'
      and rsvp_status <> 'declined';

    return jsonb_build_object(
        'event_id', p_event_id,
        'status', 'ok'
    );
end;
$$;

revoke execute on function reset_event_poll_state(uuid) from public, anon;
grant execute on function reset_event_poll_state(uuid) to authenticated;

create or replace function reset_event_rsvps_for_schedule_change(
    p_event_id uuid
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
    v_event events%rowtype;
begin
    if v_user_id is null then
        raise exception 'Authentication required';
    end if;

    select *
    into v_event
    from events
    where id = p_event_id;

    if not found then
        raise exception 'Event not found';
    end if;

    if v_event.host_id <> v_user_id then
        raise exception 'Only the host can reset RSVPs for schedule changes';
    end if;

    update invites
    set status = 'pending',
        responded_at = null,
        selected_time_option_ids = '{}'::uuid[]
    where event_id = p_event_id
      and status <> 'declined';

    update event_participants
    set rsvp_status = 'pending',
        responded_at = null,
        updated_at = now()
    where event_id = p_event_id
      and role = 'guest'
      and rsvp_status <> 'declined';

    return jsonb_build_object(
        'event_id', p_event_id,
        'status', 'ok'
    );
end;
$$;

revoke execute on function reset_event_rsvps_for_schedule_change(uuid) from public, anon;
grant execute on function reset_event_rsvps_for_schedule_change(uuid) to authenticated;
