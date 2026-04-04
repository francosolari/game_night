-- Allow poll RSVP submissions to persist as pending until host confirms a date.
-- Voting is the RSVP action in poll mode.

create or replace function respond_to_invite(
    p_invite_id uuid,
    p_status text,
    p_selected_time_option_ids uuid[] default '{}'::uuid[],
    p_suggested_times jsonb default '[]'::jsonb,
    p_votes jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
    v_user_phone text;
    v_invite invites%rowtype;
    v_event events%rowtype;
    v_participant_id uuid;
    v_votes_count integer := 0;
    v_selected_count integer := 0;
    v_valid_selected_count integer := 0;
    v_yes_ids uuid[];
begin
    if v_user_id is null then
        raise exception 'Authentication required';
    end if;

    if p_status not in ('pending', 'accepted', 'maybe', 'declined') then
        raise exception 'Invalid RSVP status: %', p_status;
    end if;

    select phone_number
    into v_user_phone
    from users
    where id = v_user_id;

    if v_user_phone is null then
        raise exception 'Authenticated user profile not found';
    end if;

    select *
    into v_invite
    from invites
    where id = p_invite_id;

    if not found then
        raise exception 'Invite not found';
    end if;

    if v_invite.user_id is not null and v_invite.user_id <> v_user_id then
        raise exception 'Invite belongs to a different user';
    end if;

    if normalize_phone(v_invite.phone_number) <> normalize_phone(v_user_phone) then
        raise exception 'Phone number does not match invite recipient';
    end if;

    if p_suggested_times is not null and jsonb_typeof(p_suggested_times) <> 'array' then
        raise exception 'Suggested times payload must be a JSON array';
    end if;

    if p_votes is not null and jsonb_typeof(p_votes) <> 'array' then
        raise exception 'Votes payload must be a JSON array';
    end if;

    -- Determine which vote source to use
    if p_votes is not null and jsonb_array_length(p_votes) > 0 then
        v_votes_count := jsonb_array_length(p_votes);

        -- Extract yes-vote IDs to keep selected_time_option_ids in sync
        select array_agg((v->>'time_option_id')::uuid)
        into v_yes_ids
        from jsonb_array_elements(p_votes) as v
        where v->>'vote_type' = 'yes';

        v_yes_ids := coalesce(v_yes_ids, '{}'::uuid[]);
    else
        -- Backward compat: treat p_selected_time_option_ids as yes votes
        v_selected_count := coalesce(array_length(p_selected_time_option_ids, 1), 0);
        v_yes_ids := coalesce(p_selected_time_option_ids, '{}'::uuid[]);
    end if;

    select *
    into v_event
    from events
    where id = v_invite.event_id;

    if not found then
        raise exception 'Event not found';
    end if;

    if p_status = 'pending' then
        if v_event.schedule_mode <> 'poll' then
            raise exception 'Pending RSVP status is only valid for poll events';
        end if;

        if v_votes_count = 0 and v_selected_count = 0 then
            raise exception 'Poll RSVP requires at least one vote';
        end if;
    end if;

    update invites
    set user_id = v_user_id,
        status = p_status,
        responded_at = now(),
        selected_time_option_ids = v_yes_ids
    where id = p_invite_id;

    insert into event_participants (
        event_id,
        user_id,
        host_user_id,
        source_invite_id,
        role,
        rsvp_status,
        responded_at,
        phone_number_snapshot
    )
    values (
        v_invite.event_id,
        v_user_id,
        v_invite.host_user_id,
        v_invite.id,
        'guest',
        p_status,
        now(),
        v_user_phone
    )
    on conflict (event_id, user_id) do update
    set source_invite_id = excluded.source_invite_id,
        host_user_id = excluded.host_user_id,
        rsvp_status = excluded.rsvp_status,
        responded_at = excluded.responded_at,
        phone_number_snapshot = excluded.phone_number_snapshot,
        updated_at = now()
    returning id into v_participant_id;

    -- Clear existing votes for this participant on this event's time options
    delete from time_option_votes
    where event_participant_id = v_participant_id
      and time_option_id in (
          select id
          from time_options
          where event_id = v_invite.event_id
      );

    -- Insert votes: prefer p_votes (with vote_type) over legacy p_selected_time_option_ids
    if v_votes_count > 0 then
        -- Validate all referenced time options belong to this event
        select count(distinct to2.id)
        into v_valid_selected_count
        from jsonb_array_elements(p_votes) as v
        join time_options to2 on to2.id = (v->>'time_option_id')::uuid
        where to2.event_id = v_invite.event_id;

        if v_valid_selected_count <> v_votes_count then
            raise exception 'All voted time options must belong to the invite event';
        end if;

        insert into time_option_votes (
            time_option_id,
            invite_id,
            event_participant_id,
            vote_type
        )
        select
            (v->>'time_option_id')::uuid,
            v_invite.id,
            v_participant_id,
            coalesce(v->>'vote_type', 'yes')
        from jsonb_array_elements(p_votes) as v;

    elsif v_selected_count > 0 then
        -- Legacy path: p_selected_time_option_ids as yes votes
        select count(distinct id)
        into v_valid_selected_count
        from time_options
        where event_id = v_invite.event_id
          and id = any(p_selected_time_option_ids);

        if v_valid_selected_count <> v_selected_count then
            raise exception 'Selected time options must all belong to the invite event';
        end if;

        insert into time_option_votes (
            time_option_id,
            invite_id,
            event_participant_id,
            vote_type
        )
        select
            selected_time_option_id,
            v_invite.id,
            v_participant_id,
            'yes'
        from unnest(p_selected_time_option_ids) as selected_time_option_id;
    end if;

    if p_suggested_times is not null
       and jsonb_typeof(p_suggested_times) = 'array'
       and jsonb_array_length(p_suggested_times) > 0 then
        if not v_event.allow_time_suggestions then
            raise exception 'This event does not allow suggested times';
        end if;

        insert into time_options (
            event_id,
            date,
            start_time,
            end_time,
            label,
            is_suggested,
            suggested_by
        )
        select
            v_invite.event_id,
            suggested_time.date,
            suggested_time.start_time,
            suggested_time.end_time,
            suggested_time.label,
            true,
            v_user_id
        from jsonb_to_recordset(p_suggested_times) as suggested_time(
            date date,
            start_time timestamptz,
            end_time timestamptz,
            label text
        );
    end if;

    return jsonb_build_object(
        'invite_id', v_invite.id,
        'event_id', v_invite.event_id,
        'participant_id', v_participant_id,
        'status', p_status
    );
end;
$$;

grant execute on function respond_to_invite(uuid, text, uuid[], jsonb, jsonb) to authenticated;
