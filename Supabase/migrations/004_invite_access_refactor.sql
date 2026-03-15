-- Migration 004: split invite delivery from authenticated event access

-- ============================================================
-- HELPERS
-- ============================================================

create or replace function normalize_phone(input text)
returns text
language sql
immutable
as $$
    select regexp_replace(coalesce(input, ''), '\D', '', 'g')
$$;

create or replace function invite_status_to_participant_rsvp(invite_status text)
returns text
language sql
immutable
as $$
    select case invite_status
        when 'accepted' then 'accepted'
        when 'declined' then 'declined'
        when 'maybe' then 'maybe'
        else 'pending'
    end
$$;

-- ============================================================
-- INVITES: add direct host ownership to avoid policy recursion
-- ============================================================

alter table invites
    add column if not exists host_user_id uuid references users(id) on delete cascade;

update invites
set host_user_id = events.host_id
from events
where events.id = invites.event_id
  and invites.host_user_id is null;

alter table invites
    alter column host_user_id set not null;

create index if not exists idx_invites_host_user on invites(host_user_id);

create or replace function sync_invite_host_user_id()
returns trigger
language plpgsql
as $$
begin
    select host_id
    into new.host_user_id
    from events
    where id = new.event_id;

    if new.host_user_id is null then
        raise exception 'Event % not found for invite host sync', new.event_id;
    end if;

    return new;
end;
$$;

drop trigger if exists trg_sync_invite_host_user_id on invites;
create trigger trg_sync_invite_host_user_id
    before insert or update of event_id
    on invites
    for each row
    execute function sync_invite_host_user_id();

-- ============================================================
-- EVENT PARTICIPANTS: authenticated event access + RSVP state
-- ============================================================

create table if not exists event_participants (
    id uuid primary key default uuid_generate_v4(),
    event_id uuid not null references events(id) on delete cascade,
    user_id uuid not null references users(id) on delete cascade,
    host_user_id uuid not null references users(id) on delete cascade,
    source_invite_id uuid references invites(id) on delete set null,
    role text not null default 'guest'
        check (role in ('host', 'guest')),
    rsvp_status text not null default 'pending'
        check (rsvp_status in ('pending', 'accepted', 'declined', 'maybe')),
    responded_at timestamptz,
    phone_number_snapshot text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (event_id, user_id)
);

create index if not exists idx_event_participants_event on event_participants(event_id);
create index if not exists idx_event_participants_user on event_participants(user_id);
create index if not exists idx_event_participants_host on event_participants(host_user_id);
create index if not exists idx_event_participants_source_invite on event_participants(source_invite_id);

alter table event_participants enable row level security;

create or replace function sync_event_participant_host_user_id()
returns trigger
language plpgsql
as $$
begin
    select host_id
    into new.host_user_id
    from events
    where id = new.event_id;

    if new.host_user_id is null then
        raise exception 'Event % not found for participant host sync', new.event_id;
    end if;

    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists trg_sync_event_participant_host_user_id on event_participants;
create trigger trg_sync_event_participant_host_user_id
    before insert or update of event_id
    on event_participants
    for each row
    execute function sync_event_participant_host_user_id();

create or replace function ensure_event_host_participant()
returns trigger
language plpgsql
as $$
begin
    insert into event_participants (
        event_id,
        user_id,
        host_user_id,
        role,
        rsvp_status,
        responded_at,
        phone_number_snapshot
    )
    select
        new.id,
        new.host_id,
        new.host_id,
        'host',
        'accepted',
        now(),
        users.phone_number
    from users
    where users.id = new.host_id
    on conflict (event_id, user_id) do update
    set host_user_id = excluded.host_user_id,
        role = excluded.role,
        rsvp_status = excluded.rsvp_status,
        responded_at = excluded.responded_at,
        phone_number_snapshot = excluded.phone_number_snapshot,
        updated_at = now();

    return new;
end;
$$;

drop trigger if exists trg_ensure_event_host_participant on events;
create trigger trg_ensure_event_host_participant
    after insert
    on events
    for each row
    execute function ensure_event_host_participant();

create or replace function sync_invite_participant_access()
returns trigger
language plpgsql
as $$
begin
    if new.user_id is null then
        return new;
    end if;

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
        new.event_id,
        new.user_id,
        new.host_user_id,
        new.id,
        'guest',
        invite_status_to_participant_rsvp(new.status),
        new.responded_at,
        new.phone_number
    )
    on conflict (event_id, user_id) do update
    set source_invite_id = excluded.source_invite_id,
        phone_number_snapshot = excluded.phone_number_snapshot,
        updated_at = now();

    return new;
end;
$$;

drop trigger if exists trg_sync_invite_participant_access on invites;
create trigger trg_sync_invite_participant_access
    after insert or update of user_id, event_id, phone_number, status, responded_at, host_user_id
    on invites
    for each row
    execute function sync_invite_participant_access();

insert into event_participants (
    event_id,
    user_id,
    host_user_id,
    role,
    rsvp_status,
    responded_at,
    phone_number_snapshot
)
select
    events.id,
    events.host_id,
    events.host_id,
    'host',
    'accepted',
    events.updated_at,
    users.phone_number
from events
join users on users.id = events.host_id
on conflict (event_id, user_id) do nothing;

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
select
    invites.event_id,
    invites.user_id,
    invites.host_user_id,
    invites.id,
    'guest',
    invite_status_to_participant_rsvp(invites.status),
    invites.responded_at,
    invites.phone_number
from invites
where invites.user_id is not null
on conflict (event_id, user_id) do update
set source_invite_id = excluded.source_invite_id,
    phone_number_snapshot = excluded.phone_number_snapshot,
    updated_at = now();

-- ============================================================
-- TIME OPTION VOTES: attach to authenticated participants
-- ============================================================

alter table time_option_votes
    add column if not exists event_participant_id uuid references event_participants(id) on delete cascade;

update time_option_votes
set event_participant_id = event_participants.id
from invites
join event_participants
    on event_participants.event_id = invites.event_id
   and event_participants.user_id = invites.user_id
where invites.id = time_option_votes.invite_id
  and time_option_votes.event_participant_id is null
  and invites.user_id is not null;

create unique index if not exists idx_time_option_votes_participant_unique
    on time_option_votes(time_option_id, event_participant_id)
    where event_participant_id is not null;

create index if not exists idx_time_option_votes_participant
    on time_option_votes(event_participant_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

drop policy if exists events_select on events;
create policy events_select on events for select
    using (
        auth.uid() = host_id
        or exists (
            select 1
            from event_participants
            where event_participants.event_id = events.id
              and event_participants.user_id = auth.uid()
        )
    );

drop policy if exists event_games_select on event_games;
create policy event_games_select on event_games for select
    using (
        exists (
            select 1
            from events
            where events.id = event_games.event_id
              and events.host_id = auth.uid()
        )
        or exists (
            select 1
            from event_participants
            where event_participants.event_id = event_games.event_id
              and event_participants.user_id = auth.uid()
        )
    );

drop policy if exists time_options_select on time_options;
create policy time_options_select on time_options for select
    using (
        exists (
            select 1
            from events
            where events.id = time_options.event_id
              and events.host_id = auth.uid()
        )
        or exists (
            select 1
            from event_participants
            where event_participants.event_id = time_options.event_id
              and event_participants.user_id = auth.uid()
        )
    );

drop policy if exists time_options_insert on time_options;
create policy time_options_insert on time_options for insert
    with check (
        exists (
            select 1
            from events
            where events.id = time_options.event_id
              and events.host_id = auth.uid()
        )
        or (
            exists (
                select 1
                from event_participants
                where event_participants.event_id = time_options.event_id
                  and event_participants.user_id = auth.uid()
            )
            and exists (
                select 1
                from events
                where events.id = time_options.event_id
                  and events.allow_time_suggestions = true
            )
        )
    );

drop policy if exists invites_host on invites;
drop policy if exists invites_own on invites;
drop policy if exists invites_respond on invites;

create policy invites_host_select on invites for select
    using (host_user_id = auth.uid());

create policy invites_host_insert on invites for insert
    with check (host_user_id = auth.uid());

create policy invites_host_update on invites for update
    using (host_user_id = auth.uid())
    with check (host_user_id = auth.uid());

create policy invites_host_delete on invites for delete
    using (host_user_id = auth.uid());

create policy invites_guest_select on invites for select
    using (
        auth.uid() = user_id
        or (
            user_id is null
            and exists (
                select 1
                from users
                where users.id = auth.uid()
                  and normalize_phone(users.phone_number) = normalize_phone(invites.phone_number)
            )
        )
    );

create policy invites_guest_update on invites for update
    using (
        auth.uid() = user_id
        or (
            user_id is null
            and exists (
                select 1
                from users
                where users.id = auth.uid()
                  and normalize_phone(users.phone_number) = normalize_phone(invites.phone_number)
            )
        )
    )
    with check (
        auth.uid() = user_id
        and exists (
            select 1
            from users
            where users.id = auth.uid()
              and normalize_phone(users.phone_number) = normalize_phone(invites.phone_number)
        )
    );

create policy event_participants_host_manage on event_participants for all
    using (host_user_id = auth.uid())
    with check (host_user_id = auth.uid());

create policy event_participants_self_select on event_participants for select
    using (user_id = auth.uid());

create policy event_participants_self_insert on event_participants for insert
    with check (
        user_id = auth.uid()
        and role = 'guest'
        and source_invite_id is not null
        and exists (
            select 1
            from invites
            where invites.id = event_participants.source_invite_id
              and invites.event_id = event_participants.event_id
              and invites.user_id = auth.uid()
        )
    );

create policy event_participants_self_update on event_participants for update
    using (user_id = auth.uid())
    with check (
        user_id = auth.uid()
        and role = 'guest'
        and source_invite_id is not null
        and exists (
            select 1
            from invites
            where invites.id = event_participants.source_invite_id
              and invites.event_id = event_participants.event_id
              and invites.user_id = auth.uid()
        )
    );

drop policy if exists votes_all on time_option_votes;

create policy votes_host_select on time_option_votes for select
    using (
        exists (
            select 1
            from event_participants
            where event_participants.id = time_option_votes.event_participant_id
              and event_participants.host_user_id = auth.uid()
        )
    );

create policy votes_participant_all on time_option_votes for all
    using (
        exists (
            select 1
            from event_participants
            where event_participants.id = time_option_votes.event_participant_id
              and event_participants.user_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1
            from event_participants
            where event_participants.id = time_option_votes.event_participant_id
              and event_participants.user_id = auth.uid()
        )
    );

-- ============================================================
-- AUTHENTICATED RSVP WORKFLOW
-- ============================================================

create or replace function respond_to_invite(
    p_invite_id uuid,
    p_status text,
    p_selected_time_option_ids uuid[] default '{}'::uuid[],
    p_suggested_times jsonb default '[]'::jsonb
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
    v_selected_count integer := coalesce(array_length(p_selected_time_option_ids, 1), 0);
    v_valid_selected_count integer := 0;
begin
    if v_user_id is null then
        raise exception 'Authentication required';
    end if;

    if p_status not in ('accepted', 'maybe', 'declined') then
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

    update invites
    set user_id = v_user_id,
        status = p_status,
        responded_at = now(),
        selected_time_option_ids = coalesce(p_selected_time_option_ids, '{}'::uuid[])
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

    select *
    into v_event
    from events
    where id = v_invite.event_id;

    if not found then
        raise exception 'Event not found';
    end if;

    if v_selected_count > 0 then
        select count(distinct id)
        into v_valid_selected_count
        from time_options
        where event_id = v_invite.event_id
          and id = any(p_selected_time_option_ids);

        if v_valid_selected_count <> v_selected_count then
            raise exception 'Selected time options must all belong to the invite event';
        end if;
    end if;

    delete from time_option_votes
    where event_participant_id = v_participant_id
      and time_option_id in (
          select id
          from time_options
          where event_id = v_invite.event_id
      );

    if v_selected_count > 0 then
        insert into time_option_votes (
            time_option_id,
            invite_id,
            event_participant_id
        )
        select
            selected_time_option_id,
            v_invite.id,
            v_participant_id
        from unnest(p_selected_time_option_ids) as selected_time_option_id
        on conflict (time_option_id, event_participant_id) do nothing;
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

grant execute on function respond_to_invite(uuid, text, uuid[], jsonb) to authenticated;
