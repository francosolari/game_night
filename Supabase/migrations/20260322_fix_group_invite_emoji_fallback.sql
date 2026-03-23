-- Fix: use '🎲' instead of '' as fallback for group_emoji in metadata JSON.
-- An empty string renders as a question-mark box on iOS.

-- 1. notify_group_member_added (insert-time trigger)
create or replace function notify_group_member_added()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.user_id is not null and new.status = 'pending' then
        insert into notifications (user_id, type, title, body, group_id, metadata)
        select
            new.user_id,
            'group_invite',
            coalesce(g.emoji, '🎲') || ' ' || g.name,
            coalesce(inviter.display_name, 'Someone') || ' invited you to join their group',
            new.group_id,
            jsonb_build_object(
                'group_name', g.name,
                'group_emoji', coalesce(g.emoji, '🎲'),
                'owner_name', coalesce(owner.display_name, ''),
                'inviter_name', coalesce(inviter.display_name, ''),
                'member_id', new.id
            )
        from groups g
        left join users owner on owner.id = g.owner_id
        left join users inviter on inviter.id = new.invited_by
        where g.id = new.group_id
          and g.owner_id != new.user_id;
    end if;

    return new;
end;
$$;

revoke execute on function notify_group_member_added() from public, anon, authenticated;

-- 2. link_open_group_members_to_user (signup-time trigger)
create or replace function link_open_group_members_to_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_member record;
begin
    if coalesce(new.phone_number, '') = '' then
        return new;
    end if;

    for v_member in
        update group_members
        set user_id = new.id
        where user_id is null
          and normalize_phone(group_members.phone_number) = normalize_phone(new.phone_number)
        returning *
    loop
        if v_member.status = 'pending' then
            insert into notifications (user_id, type, title, body, group_id, metadata)
            select
                new.id,
                'group_invite',
                coalesce(g.emoji, '🎲') || ' ' || g.name,
                coalesce(inviter.display_name, 'Someone') || ' invited you to join their group',
                v_member.group_id,
                jsonb_build_object(
                    'group_name', g.name,
                    'group_emoji', coalesce(g.emoji, '🎲'),
                    'owner_name', coalesce(owner.display_name, ''),
                    'inviter_name', coalesce(inviter.display_name, ''),
                    'member_id', v_member.id
                )
            from groups g
            left join users owner on owner.id = g.owner_id
            left join users inviter on inviter.id = v_member.invited_by
            where g.id = v_member.group_id
              and g.owner_id != new.id;
        end if;
    end loop;

    return new;
end;
$$;

revoke execute on function link_open_group_members_to_user() from public, anon, authenticated;

-- 3. create_group_invite_dm (DM trigger) — metadata already used '🎲' for title
--    but the metadata JSON field used ''. Fix that too.
create or replace function create_group_invite_dm()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_conversation_id uuid;
    v_group_name text;
    v_group_emoji text;
    v_inviter_name text;
begin
    if new.status != 'pending' or new.invited_by is null then
        return new;
    end if;

    select g.name, coalesce(g.emoji, '🎲')
    into v_group_name, v_group_emoji
    from groups g
    where g.id = new.group_id;

    select coalesce(u.display_name, 'Someone')
    into v_inviter_name
    from users u
    where u.id = new.invited_by;

    if new.user_id is not null then
        select cp1.conversation_id into v_conversation_id
        from conversation_participants cp1
        join conversation_participants cp2
            on cp1.conversation_id = cp2.conversation_id
        where cp1.user_id = new.invited_by
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
                (v_conversation_id, new.invited_by),
                (v_conversation_id, new.user_id);
        end if;

        insert into direct_messages (conversation_id, sender_id, content, message_type, metadata)
        values (
            v_conversation_id,
            new.invited_by,
            v_group_emoji || ' Join ' || v_group_name || '! You''ve been invited to the group.',
            'group_invite',
            jsonb_build_object(
                'group_id', new.group_id,
                'group_name', v_group_name,
                'group_emoji', v_group_emoji,
                'member_id', new.id
            )
        );
    end if;

    return new;
end;
$$;

revoke execute on function create_group_invite_dm() from public, anon, authenticated;

-- 4. Fix existing empty-string emoji values in notification metadata
update notifications
set metadata = jsonb_set(metadata, '{group_emoji}', '"🎲"')
where type = 'group_invite'
  and metadata->>'group_emoji' = '';

-- 5. Fix existing empty-string emoji values in DM metadata
update direct_messages
set metadata = jsonb_set(metadata, '{group_emoji}', '"🎲"')
where message_type = 'group_invite'
  and metadata->>'group_emoji' = '';
