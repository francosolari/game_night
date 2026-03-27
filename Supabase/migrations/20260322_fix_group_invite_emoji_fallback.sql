-- Fix group invite issues:
-- 1. RLS: allow invited/accepted members to SELECT groups they belong to
-- 2. RLS: allow members to see other members in their groups
-- 3. RPC: group invite preview (members + top 3 games)
-- 4. Fix empty-string emoji fallback in notification/DM metadata

-- ============================================================
-- 1. FIX GROUPS RLS — members (pending or accepted) can read
-- ============================================================

-- Current policy only allows owner to SELECT. Members invited to a group
-- cannot see the group data (name, emoji, etc.), which causes broken UI.
drop policy if exists groups_select on groups;
create policy groups_select on groups for select using (
    auth.uid() = owner_id
    or exists (
        select 1 from group_members
        where group_members.group_id = groups.id
          and group_members.user_id = auth.uid()
    )
);

-- ============================================================
-- 2. FIX GROUP_MEMBERS RLS — members can see co-members
-- ============================================================

-- Current policy only allows owner (via groups join) or self-row.
-- Accepted members should see other accepted members in their groups.
-- Pending members should also see accepted members (for invite preview).
create policy group_members_select_cogroup on group_members for select using (
    exists (
        select 1 from group_members my
        where my.group_id = group_members.group_id
          and my.user_id = auth.uid()
    )
);

-- ============================================================
-- 3. RPC: group invite preview — members + their top 3 games
-- ============================================================

create or replace function get_group_invite_preview(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_result jsonb;
begin
    -- Verify caller is a member (pending or accepted)
    if not exists (
        select 1 from group_members
        where group_id = p_group_id
          and user_id = auth.uid()
    ) then
        raise exception 'Not a member of this group';
    end if;

    select jsonb_build_object(
        'group', jsonb_build_object(
            'id', g.id,
            'name', g.name,
            'emoji', coalesce(g.emoji, '🎲'),
            'description', g.description,
            'owner_id', g.owner_id
        ),
        'owner', (
            select jsonb_build_object(
                'id', u.id,
                'display_name', coalesce(u.display_name, 'Unknown'),
                'avatar_url', u.avatar_url,
                'top_games', coalesce((
                    select jsonb_agg(game_info order by gl.play_count desc)
                    from (
                        select jsonb_build_object(
                            'name', gm.name,
                            'thumbnail_url', gm.thumbnail_url
                        ) as game_info, gl.play_count
                        from game_library gl
                        join games gm on gm.id = gl.game_id
                        where gl.user_id = u.id
                        order by gl.play_count desc
                        limit 3
                    ) sub
                ), '[]'::jsonb)
            )
            from users u
            where u.id = g.owner_id
        ),
        'members', coalesce((
            select jsonb_agg(member_info)
            from (
                select jsonb_build_object(
                    'id', gm_row.id,
                    'user_id', gm_row.user_id,
                    'display_name', coalesce(u.display_name, gm_row.display_name, 'Unknown'),
                    'avatar_url', u.avatar_url,
                    'status', gm_row.status,
                    'top_games', coalesce((
                        select jsonb_agg(game_info order by gl.play_count desc)
                        from (
                            select jsonb_build_object(
                                'name', g2.name,
                                'thumbnail_url', g2.thumbnail_url
                            ) as game_info, gl.play_count
                            from game_library gl
                            join games g2 on g2.id = gl.game_id
                            where gl.user_id = gm_row.user_id
                            order by gl.play_count desc
                            limit 3
                        ) sub
                    ), '[]'::jsonb)
                ) as member_info
                from group_members gm_row
                left join users u on u.id = gm_row.user_id
                where gm_row.group_id = p_group_id
                  and gm_row.status = 'accepted'
                  and gm_row.user_id != g.owner_id
                order by gm_row.sort_order
            ) sub2
        ), '[]'::jsonb)
    )
    into v_result
    from groups g
    where g.id = p_group_id;

    return v_result;
end;
$$;

revoke execute on function get_group_invite_preview(uuid) from public, anon;
grant execute on function get_group_invite_preview(uuid) to authenticated;

-- ============================================================
-- 4. FIX EMOJI FALLBACK in trigger functions
-- ============================================================

-- notify_group_member_added
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

-- link_open_group_members_to_user
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

-- create_group_invite_dm
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

-- ============================================================
-- 5. BACKFILL existing broken metadata
-- ============================================================

update notifications
set metadata = jsonb_set(metadata, '{group_emoji}', '"🎲"')
where type = 'group_invite'
  and metadata->>'group_emoji' = '';

update direct_messages
set metadata = jsonb_set(metadata, '{group_emoji}', '"🎲"')
where message_type = 'group_invite'
  and metadata->>'group_emoji' = '';
