-- Auto-link group_members to users by phone, mirroring the invite auto-link flow.
-- Ensures non-users who later sign up get their group invites resolved, triggering
-- notifications and appearing in "Awaiting Response" on the homepage.

-- ============================================================
-- 1. INDEX: fast lookup of unlinked group_members by phone
-- ============================================================

create index if not exists idx_group_members_phone_normalized_unassigned
    on group_members (normalize_phone(phone_number))
    where user_id is null;

-- ============================================================
-- 2. BEFORE INSERT: auto-resolve user_id from phone on insert
-- ============================================================

create or replace function assign_group_member_user_id_from_phone()
returns trigger
language plpgsql
set search_path = public
as $$
declare
    v_user_id uuid;
begin
    if new.user_id is null and coalesce(new.phone_number, '') <> '' then
        select find_user_id_by_phone(new.phone_number) into v_user_id;
        if v_user_id is not null then
            new.user_id = v_user_id;
        end if;
    end if;

    return new;
end;
$$;

drop trigger if exists trg_assign_group_member_user_id_from_phone on group_members;
create trigger trg_assign_group_member_user_id_from_phone
    before insert or update of phone_number, user_id
    on group_members
    for each row
    execute function assign_group_member_user_id_from_phone();

-- ============================================================
-- 3. ON USER SIGNUP: backfill user_id on matching group_members
--    Also fires notification for newly-linked group invites.
-- ============================================================

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

    -- Backfill user_id on all unlinked group_members matching this phone
    for v_member in
        update group_members
        set user_id = new.id
        where user_id is null
          and normalize_phone(group_members.phone_number) = normalize_phone(new.phone_number)
        returning *
    loop
        -- Fire a notification for each newly-linked pending group invite
        if v_member.status = 'pending' then
            insert into notifications (user_id, type, title, body, group_id, metadata)
            select
                new.id,
                'group_invite',
                'You were added to ' || g.name,
                'By ' || coalesce(owner.display_name, 'someone'),
                v_member.group_id,
                jsonb_build_object(
                    'group_name', g.name,
                    'group_emoji', coalesce(g.emoji, ''),
                    'owner_name', coalesce(owner.display_name, '')
                )
            from groups g
            left join users owner on owner.id = g.owner_id
            where g.id = v_member.group_id
              and g.owner_id != new.id;
        end if;
    end loop;

    return new;
end;
$$;

drop trigger if exists trg_link_open_group_members_to_user on users;
create trigger trg_link_open_group_members_to_user
    after insert or update of phone_number
    on users
    for each row
    execute function link_open_group_members_to_user();

revoke execute on function assign_group_member_user_id_from_phone() from public, anon, authenticated;
revoke execute on function link_open_group_members_to_user() from public, anon, authenticated;

-- ============================================================
-- 4. BACKFILL: resolve any existing unlinked group_members
-- ============================================================

with resolved_users as (
    select distinct on (normalize_phone(users.phone_number))
        normalize_phone(users.phone_number) as phone_key,
        users.id
    from users
    where coalesce(users.phone_number, '') <> ''
    order by normalize_phone(users.phone_number), users.created_at asc, users.id asc
)
update group_members
set user_id = resolved_users.id
from resolved_users
where group_members.user_id is null
  and normalize_phone(group_members.phone_number) = resolved_users.phone_key;
