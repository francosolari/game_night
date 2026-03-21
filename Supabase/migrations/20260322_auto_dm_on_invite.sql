-- Auto-create DM conversations when invites are sent
-- For app users: immediate DM with invite card
-- For non-users: deferred DM processed on signup

-- ============================================================
-- PENDING INVITE DMs (for non-registered invitees)
-- ============================================================

create table pending_invite_dms (
    id uuid primary key default gen_random_uuid(),
    host_user_id uuid not null references users(id) on delete cascade,
    invite_id uuid not null references invites(id) on delete cascade,
    event_id uuid not null references events(id) on delete cascade,
    invitee_phone text not null,
    message text,
    created_at timestamptz not null default now()
);

create index idx_pending_invite_dms_phone
    on pending_invite_dms(normalize_phone(invitee_phone));

alter table pending_invite_dms enable row level security;

-- Host can see their own pending DMs
create policy pending_invite_dms_host on pending_invite_dms for select
    using (host_user_id = auth.uid());

-- Trigger functions are SECURITY DEFINER (see rls_security_hardening migration)
-- so they bypass RLS for insert/delete. No permissive client policies needed.

-- ============================================================
-- CREATE DM ON INVITE INSERT
-- ============================================================

create or replace function create_invite_dm()
returns trigger
language plpgsql
set search_path = public
as $$
declare
    v_conversation_id uuid;
    v_event_title text;
    v_event_cover text;
    v_host_name text;
    v_time_label text;
begin
    -- Only process active pending invites
    if new.status != 'pending' or new.is_active != true then
        return new;
    end if;

    -- Get event info for the invite card
    select e.title, e.cover_image_url,
           coalesce(h.display_name, ''),
           coalesce(
               to_char(
                   (select start_time from time_options where event_id = e.id order by start_time asc limit 1),
                   'Mon DD "at" HH12:MIam'
               ),
               ''
           )
    into v_event_title, v_event_cover, v_host_name, v_time_label
    from events e
    left join users h on h.id = e.host_id
    where e.id = new.event_id;

    if new.user_id is not null then
        -- Invitee is a registered user: create DM immediately

        -- Find or create conversation between host and invitee
        select cp1.conversation_id into v_conversation_id
        from conversation_participants cp1
        join conversation_participants cp2
            on cp1.conversation_id = cp2.conversation_id
        where cp1.user_id = new.host_user_id
          and cp2.user_id = new.user_id
          and (
              select count(*)
              from conversation_participants
              where conversation_id = cp1.conversation_id
          ) = 2
        limit 1;

        if v_conversation_id is null then
            insert into conversations default values
            returning id into v_conversation_id;

            insert into conversation_participants (conversation_id, user_id) values
                (v_conversation_id, new.host_user_id),
                (v_conversation_id, new.user_id);
        end if;

        -- Send invite card message
        insert into direct_messages (conversation_id, sender_id, content, message_type, metadata)
        values (
            v_conversation_id,
            new.host_user_id,
            'You''re invited to ' || coalesce(v_event_title, 'an event') || '!',
            'invite',
            jsonb_build_object(
                'event_id', new.event_id,
                'invite_id', new.id,
                'event_title', coalesce(v_event_title, ''),
                'cover_image_url', coalesce(v_event_cover, ''),
                'host_name', v_host_name,
                'time_label', coalesce(v_time_label, ''),
                'invite_token', new.invite_token
            )
        );
    else
        -- Invitee is not registered: store a pending DM for later
        insert into pending_invite_dms (host_user_id, invite_id, event_id, invitee_phone, message)
        values (
            new.host_user_id,
            new.id,
            new.event_id,
            new.phone_number,
            'You''re invited to ' || coalesce(v_event_title, 'an event') || '!'
        );
    end if;

    return new;
end;
$$;

drop trigger if exists trg_create_invite_dm on invites;
create trigger trg_create_invite_dm
    after insert on invites
    for each row
    execute function create_invite_dm();

-- ============================================================
-- PROCESS PENDING DMs WHEN USER SIGNS UP
-- ============================================================

create or replace function process_pending_invite_dms()
returns trigger
language plpgsql
set search_path = public
as $$
declare
    v_pending record;
    v_conversation_id uuid;
    v_event_title text;
    v_event_cover text;
    v_host_name text;
    v_time_label text;
begin
    if coalesce(new.phone_number, '') = '' then
        return new;
    end if;

    for v_pending in
        select p.*
        from pending_invite_dms p
        where normalize_phone(p.invitee_phone) = normalize_phone(new.phone_number)
    loop
        -- Get event info
        select e.title, e.cover_image_url,
               coalesce(h.display_name, ''),
               coalesce(
                   to_char(
                       (select start_time from time_options where event_id = e.id order by start_time asc limit 1),
                       'Mon DD "at" HH12:MIam'
                   ),
                   ''
               )
        into v_event_title, v_event_cover, v_host_name, v_time_label
        from events e
        left join users h on h.id = e.host_id
        where e.id = v_pending.event_id;

        -- Find or create conversation
        select cp1.conversation_id into v_conversation_id
        from conversation_participants cp1
        join conversation_participants cp2
            on cp1.conversation_id = cp2.conversation_id
        where cp1.user_id = v_pending.host_user_id
          and cp2.user_id = new.id
          and (
              select count(*)
              from conversation_participants
              where conversation_id = cp1.conversation_id
          ) = 2
        limit 1;

        if v_conversation_id is null then
            insert into conversations default values
            returning id into v_conversation_id;

            insert into conversation_participants (conversation_id, user_id) values
                (v_conversation_id, v_pending.host_user_id),
                (v_conversation_id, new.id);
        end if;

        -- Send the invite card message
        insert into direct_messages (conversation_id, sender_id, content, message_type, metadata)
        values (
            v_conversation_id,
            v_pending.host_user_id,
            v_pending.message,
            'invite',
            jsonb_build_object(
                'event_id', v_pending.event_id,
                'invite_id', v_pending.invite_id,
                'event_title', coalesce(v_event_title, ''),
                'cover_image_url', coalesce(v_event_cover, ''),
                'host_name', v_host_name,
                'time_label', coalesce(v_time_label, '')
            )
        );

        -- Clean up
        delete from pending_invite_dms where id = v_pending.id;
    end loop;

    return new;
end;
$$;

drop trigger if exists trg_process_pending_invite_dms on users;
create trigger trg_process_pending_invite_dms
    after insert or update of phone_number on users
    for each row
    execute function process_pending_invite_dms();

-- ============================================================
-- ADD READ CURSOR TO CONVERSATION PARTICIPANTS
-- ============================================================

alter table conversation_participants
    add column if not exists last_read_at timestamptz;

-- Update the unread count in fetch_conversations_for_user to use last_read_at
create or replace function fetch_conversations_for_user()
returns table (
    conversation_id uuid,
    last_message_at timestamptz,
    other_user_id uuid,
    other_display_name text,
    other_avatar_url text,
    last_message_content text,
    last_message_type text,
    last_message_sender_id uuid,
    last_message_created_at timestamptz,
    unread_count bigint
)
language sql
stable
set search_path = public
as $$
    select
        c.id as conversation_id,
        c.last_message_at,
        other_cp.user_id as other_user_id,
        other_u.display_name as other_display_name,
        other_u.avatar_url as other_avatar_url,
        last_msg.content as last_message_content,
        last_msg.message_type as last_message_type,
        last_msg.sender_id as last_message_sender_id,
        last_msg.created_at as last_message_created_at,
        coalesce(unread.cnt, 0) as unread_count
    from conversations c
    join conversation_participants my_cp
        on my_cp.conversation_id = c.id
        and my_cp.user_id = auth.uid()
    join conversation_participants other_cp
        on other_cp.conversation_id = c.id
        and other_cp.user_id != auth.uid()
    join users other_u
        on other_u.id = other_cp.user_id
    left join lateral (
        select dm.content, dm.message_type, dm.sender_id, dm.created_at
        from direct_messages dm
        where dm.conversation_id = c.id
        order by dm.created_at desc
        limit 1
    ) last_msg on true
    left join lateral (
        select count(*) as cnt
        from direct_messages dm
        where dm.conversation_id = c.id
          and dm.sender_id != auth.uid()
          and dm.created_at > coalesce(my_cp.last_read_at, my_cp.joined_at)
    ) unread on true
    where c.last_message_at is not null
    order by c.last_message_at desc nulls last;
$$;

-- RPC: Mark conversation as read
create or replace function mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
set search_path = public
as $$
begin
    update conversation_participants
    set last_read_at = now()
    where conversation_id = p_conversation_id
      and user_id = auth.uid();
end;
$$;

grant execute on function mark_conversation_read(uuid) to authenticated;

-- Allow users to update their own conversation_participants (for last_read_at)
create policy conv_participants_update on conversation_participants for update
    using (user_id = auth.uid())
    with check (user_id = auth.uid());
