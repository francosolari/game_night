-- Triggers for automatic notification creation

-- ============================================================
-- NOTIFY ON INVITE RECEIVED (new invite for app user)
-- ============================================================

create or replace function notify_invite_received()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    -- Only notify if invitee is a registered user, invite is active, and status is pending
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

drop trigger if exists trg_notify_invite_received on invites;
create trigger trg_notify_invite_received
    after insert on invites
    for each row
    execute function notify_invite_received();

-- ============================================================
-- NOTIFY HOST ON RSVP UPDATE
-- ============================================================

create or replace function notify_rsvp_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    -- Only fire when status actually changes and is not pending
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
          -- Don't notify host about their own actions
          and e.host_id != coalesce(new.user_id, '00000000-0000-0000-0000-000000000000'::uuid);
    end if;

    return new;
end;
$$;

drop trigger if exists trg_notify_rsvp_update on invites;
create trigger trg_notify_rsvp_update
    after update of status on invites
    for each row
    execute function notify_rsvp_update();

-- ============================================================
-- NOTIFY ON BENCH PROMOTION
-- ============================================================

create or replace function notify_bench_promoted()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    -- Fire when is_active flips from false to true (bench → promoted)
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

        -- Also notify the host
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

drop trigger if exists trg_notify_bench_promoted on invites;
create trigger trg_notify_bench_promoted
    after update of is_active on invites
    for each row
    execute function notify_bench_promoted();

-- ============================================================
-- NOTIFY ON DM RECEIVED
-- ============================================================

create or replace function notify_dm_received()
returns trigger
language plpgsql
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

drop trigger if exists trg_notify_dm_received on direct_messages;
create trigger trg_notify_dm_received
    after insert on direct_messages
    for each row
    execute function notify_dm_received();

-- ============================================================
-- NOTIFY ON GROUP MEMBER ADDED (for the added user)
-- ============================================================

create or replace function notify_group_member_added()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    -- Only notify if the added user is a registered user and not the group owner
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

drop trigger if exists trg_notify_group_member_added on group_members;
create trigger trg_notify_group_member_added
    after insert on group_members
    for each row
    execute function notify_group_member_added();
