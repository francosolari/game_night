-- RLS Security Hardening
-- Fixes P0 vulnerabilities: removes overly-permissive WITH CHECK (true) and
-- USING (true) policies, replaces them with SECURITY DEFINER trigger functions
-- so triggers can insert across user boundaries without opening tables to
-- direct client abuse.

-- ============================================================
-- 1. DROP OVERLY-PERMISSIVE POLICIES
-- ============================================================

-- notifications: anyone could inject fake notifications for any user
drop policy if exists notifications_insert on notifications;

-- conversations: anyone could create arbitrary conversations
drop policy if exists conversations_insert on conversations;

-- conversation_participants: anyone could add themselves/others to any conversation
drop policy if exists conv_participants_insert on conversation_participants;

-- direct_messages: dm_system_insert bypassed the proper dm_insert checks entirely
drop policy if exists dm_system_insert on direct_messages;

-- pending_invite_dms: anyone could create fake pending DMs or delete any pending DM
drop policy if exists pending_invite_dms_insert on pending_invite_dms;
drop policy if exists pending_invite_dms_delete on pending_invite_dms;

-- ============================================================
-- 2. MAKE TRIGGER FUNCTIONS SECURITY DEFINER
--    (postgres owns the tables + force_rls is off → bypasses RLS)
--    All already have `set search_path = public` for safety.
-- ============================================================

-- --- Notification triggers ---

create or replace function notify_invite_received()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.user_id is not null
       and new.is_active = true
       and new.status = 'pending' then
        insert into notifications (user_id, type, title, body, event_id, invite_id, metadata)
        select
            new.user_id,
            'invite_received',
            'You''re invited to ' || e.title,
            'From ' || coalesce(h.display_name, 'a host'),
            new.event_id,
            new.id,
            jsonb_build_object(
                'host_name', coalesce(h.display_name, ''),
                'host_id', e.host_id,
                'event_title', e.title
            )
        from events e
        left join users h on h.id = e.host_id
        where e.id = new.event_id;
    end if;

    return new;
end;
$$;

create or replace function notify_rsvp_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if old.status is distinct from new.status
       and new.status in ('accepted', 'declined', 'maybe') then
        insert into notifications (user_id, type, title, body, event_id, invite_id, metadata)
        select
            e.host_id,
            'rsvp_update',
            coalesce(new.display_name, 'Someone') || ' is ' ||
                case new.status
                    when 'accepted' then 'going'
                    when 'declined' then 'not going'
                    when 'maybe' then 'maybe'
                end,
            e.title,
            new.event_id,
            new.id,
            jsonb_build_object(
                'new_status', new.status,
                'old_status', old.status,
                'invitee_name', coalesce(new.display_name, ''),
                'invitee_user_id', new.user_id
            )
        from events e
        where e.id = new.event_id
          and e.host_id != coalesce(new.user_id, '00000000-0000-0000-0000-000000000000'::uuid);
    end if;

    return new;
end;
$$;

create or replace function notify_bench_promoted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if old.is_active = false and new.is_active = true and new.user_id is not null then
        insert into notifications (user_id, type, title, body, event_id, invite_id)
        select
            new.user_id,
            'bench_promoted',
            'A spot opened up!',
            'You''ve been moved off the waitlist for ' || e.title,
            new.event_id,
            new.id
        from events e
        where e.id = new.event_id;

        insert into notifications (user_id, type, title, body, event_id, invite_id, metadata)
        select
            e.host_id,
            'bench_promoted',
            coalesce(new.display_name, 'Someone') || ' was promoted from the waitlist',
            e.title,
            new.event_id,
            new.id,
            jsonb_build_object('invitee_name', coalesce(new.display_name, ''))
        from events e
        where e.id = new.event_id;
    end if;

    return new;
end;
$$;

create or replace function notify_dm_received()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into notifications (user_id, type, title, body, conversation_id, metadata)
    select
        cp.user_id,
        'dm_received',
        coalesce(sender.display_name, 'Someone') || ' sent you a message',
        case new.message_type
            when 'invite' then 'You''re invited!'
            else left(coalesce(new.content, ''), 100)
        end,
        new.conversation_id,
        jsonb_build_object(
            'sender_name', coalesce(sender.display_name, ''),
            'sender_id', new.sender_id,
            'message_type', new.message_type
        )
    from conversation_participants cp
    join users sender on sender.id = new.sender_id
    where cp.conversation_id = new.conversation_id
      and cp.user_id != new.sender_id;

    return new;
end;
$$;

create or replace function notify_group_member_added()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.user_id is not null then
        insert into notifications (user_id, type, title, body, group_id, metadata)
        select
            new.user_id,
            'group_invite',
            'You were added to ' || g.name,
            'By ' || coalesce(owner.display_name, 'someone'),
            new.group_id,
            jsonb_build_object(
                'group_name', g.name,
                'group_emoji', coalesce(g.emoji, ''),
                'owner_name', coalesce(owner.display_name, '')
            )
        from groups g
        left join users owner on owner.id = g.owner_id
        where g.id = new.group_id
          and g.owner_id != new.user_id;
    end if;

    return new;
end;
$$;

-- --- DM/Conversation triggers ---

create or replace function update_conversation_last_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    update conversations
    set last_message_at = new.created_at
    where id = new.conversation_id;
    return new;
end;
$$;

create or replace function create_invite_dm()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_conversation_id uuid;
    v_event_title text;
    v_event_cover text;
    v_host_name text;
    v_time_label text;
begin
    if new.status != 'pending' or new.is_active != true then
        return new;
    end if;

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

create or replace function process_pending_invite_dms()
returns trigger
language plpgsql
security definer
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

        delete from pending_invite_dms where id = v_pending.id;
    end loop;

    return new;
end;
$$;

-- ============================================================
-- 3. REVOKE DIRECT EXECUTE ON TRIGGER FUNCTIONS FROM PUBLIC
--    These should only fire via triggers, never called directly.
-- ============================================================

revoke execute on function notify_invite_received() from public, anon, authenticated;
revoke execute on function notify_rsvp_update() from public, anon, authenticated;
revoke execute on function notify_bench_promoted() from public, anon, authenticated;
revoke execute on function notify_dm_received() from public, anon, authenticated;
revoke execute on function notify_group_member_added() from public, anon, authenticated;
revoke execute on function update_conversation_last_message() from public, anon, authenticated;
revoke execute on function create_invite_dm() from public, anon, authenticated;
revoke execute on function process_pending_invite_dms() from public, anon, authenticated;
