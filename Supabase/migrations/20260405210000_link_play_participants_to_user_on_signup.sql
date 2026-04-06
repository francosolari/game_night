-- Link play_participants rows (logged by phone) to users when they sign up.
-- Mirrors the group_members auto-link pattern from 20260322_auto_link_group_members_by_phone.sql

-- ============================================================
-- 1. INDEX: fast lookup of unlinked play_participants by phone
-- ============================================================

create index if not exists idx_play_participants_phone_unassigned
    on play_participants (normalize_phone(phone_number))
    where user_id is null;

-- ============================================================
-- 2. BEFORE INSERT: auto-resolve user_id from phone on insert
--    If the person already has an account, link immediately.
-- ============================================================

create or replace function assign_play_participant_user_id_from_phone()
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

drop trigger if exists trg_assign_play_participant_user_id_from_phone on play_participants;
create trigger trg_assign_play_participant_user_id_from_phone
    before insert or update of phone_number, user_id
    on play_participants
    for each row
    execute function assign_play_participant_user_id_from_phone();

-- ============================================================
-- 3. ON USER SIGNUP: backfill user_id on matching play_participants
-- ============================================================

create or replace function link_open_play_participants_to_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if coalesce(new.phone_number, '') = '' then
        return new;
    end if;

    -- Backfill user_id on all unlinked play_participants matching this phone
    update play_participants
    set user_id = new.id
    where user_id is null
      and normalize_phone(play_participants.phone_number) = normalize_phone(new.phone_number);

    return new;
end;
$$;

drop trigger if exists trg_link_open_play_participants_to_user on users;
create trigger trg_link_open_play_participants_to_user
    after insert or update of phone_number
    on users
    for each row
    execute function link_open_play_participants_to_user();

revoke execute on function assign_play_participant_user_id_from_phone() from public, anon, authenticated;
revoke execute on function link_open_play_participants_to_user() from public, anon, authenticated;

-- ============================================================
-- 4. BACKFILL: resolve any existing unlinked play_participants
-- ============================================================

with resolved_users as (
    select distinct on (normalize_phone(users.phone_number))
        normalize_phone(users.phone_number) as phone_key,
        users.id
    from users
    where coalesce(users.phone_number, '') <> ''
    order by normalize_phone(users.phone_number), users.created_at asc, users.id asc
)
update play_participants
set user_id = resolved_users.id
from resolved_users
where play_participants.user_id is null
  and normalize_phone(play_participants.phone_number) = resolved_users.phone_key;
