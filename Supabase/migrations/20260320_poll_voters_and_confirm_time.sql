-- Poll voter details + host confirm time option
-- Phase 1a: fetch_time_poll_voters — returns flat voter rows for time options
create or replace function fetch_time_poll_voters(p_event_id uuid)
returns table (
    time_option_id uuid,
    vote_type text,
    user_id uuid,
    display_name text,
    avatar_url text
)
language sql
stable
set search_path = public
as $$
    select
        tov.time_option_id,
        tov.vote_type,
        u.id as user_id,
        u.display_name,
        u.avatar_url
    from time_option_votes tov
    join event_participants ep on ep.id = tov.event_participant_id
    join users u on u.id = ep.user_id
    join time_options to2 on to2.id = tov.time_option_id
    where to2.event_id = p_event_id;
$$;

grant execute on function fetch_time_poll_voters(uuid) to authenticated;

-- Phase 1b: fetch_game_poll_voters — returns flat voter rows for game votes
create or replace function fetch_game_poll_voters(p_event_id uuid)
returns table (
    game_id uuid,
    vote_type text,
    user_id uuid,
    display_name text,
    avatar_url text
)
language sql
stable
set search_path = public
as $$
    select
        gv.game_id,
        gv.vote_type,
        u.id as user_id,
        u.display_name,
        u.avatar_url
    from game_votes gv
    join users u on u.id = gv.user_id
    where gv.event_id = p_event_id;
$$;

grant execute on function fetch_game_poll_voters(uuid) to authenticated;

-- Phase 1c: confirm_time_option — host picks a time, auto-updates RSVPs
create or replace function confirm_time_option(
    p_event_id uuid,
    p_time_option_id uuid
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
    v_event events%rowtype;
    v_affected_invite_ids uuid[];
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

    -- Set confirmed time option and end the poll (switch to fixed mode)
    update events
    set confirmed_time_option_id = p_time_option_id,
        schedule_mode = 'fixed',
        updated_at = now()
    where id = p_event_id;

    -- Remove non-confirmed time options (poll is over)
    delete from time_options
    where event_id = p_event_id
      and id <> p_time_option_id;

    -- Auto-update invites: yes voters -> accepted, maybe voters -> maybe
    -- First: yes voters
    update invites
    set status = 'accepted',
        responded_at = coalesce(responded_at, now())
    where event_id = p_event_id
      and id in (
          select tov.invite_id
          from time_option_votes tov
          where tov.time_option_id = p_time_option_id
            and tov.vote_type = 'yes'
      )
      and status in ('pending', 'maybe');

    -- Maybe voters
    update invites
    set status = 'maybe',
        responded_at = coalesce(responded_at, now())
    where event_id = p_event_id
      and id in (
          select tov.invite_id
          from time_option_votes tov
          where tov.time_option_id = p_time_option_id
            and tov.vote_type = 'maybe'
      )
      and status = 'pending';

    -- Sync event_participants rsvp_status
    update event_participants ep
    set rsvp_status = i.status,
        updated_at = now()
    from invites i
    where i.event_id = p_event_id
      and ep.source_invite_id = i.id
      and ep.rsvp_status <> i.status;

    -- Collect affected invite IDs for notification
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
