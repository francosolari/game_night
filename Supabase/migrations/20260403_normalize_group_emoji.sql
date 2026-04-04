-- Normalize group emoji placeholders and harden group invite preview output.

create or replace function normalize_group_emoji(p_emoji text)
returns text
language sql
immutable
as $$
    select case
        when p_emoji is null then '🎲'
        when btrim(p_emoji) = '' then '🎲'
        when btrim(p_emoji) in ('?', '�') then '🎲'
        else btrim(p_emoji)
    end;
$$;

-- Backfill source-of-truth group emoji values.
update groups
set emoji = normalize_group_emoji(emoji)
where emoji is distinct from normalize_group_emoji(emoji);

-- Backfill notification metadata.
update notifications
set metadata = jsonb_set(
    metadata,
    '{group_emoji}',
    to_jsonb(normalize_group_emoji(metadata->>'group_emoji'))
)
where metadata ? 'group_emoji';

-- Backfill DM metadata.
update direct_messages
set metadata = jsonb_set(
    metadata,
    '{group_emoji}',
    to_jsonb(normalize_group_emoji(metadata->>'group_emoji'))
)
where metadata ? 'group_emoji';

create or replace function get_group_invite_preview(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_result jsonb;
begin
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
            'emoji', normalize_group_emoji(g.emoji),
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
            normalize_group_emoji(g.emoji) || ' ' || g.name,
            coalesce(inviter.display_name, 'Someone') || ' invited you to join their group',
            new.group_id,
            jsonb_build_object(
                'group_name', g.name,
                'group_emoji', normalize_group_emoji(g.emoji),
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
