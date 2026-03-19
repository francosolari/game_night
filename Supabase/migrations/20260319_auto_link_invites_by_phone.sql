-- Automatically link phone-based invites to real users as accounts are created.
-- This makes invite-first flows reliable (invite now, account claim later).

create index if not exists idx_users_phone_normalized
    on users (normalize_phone(phone_number));

create index if not exists idx_invites_phone_normalized_unassigned
    on invites (normalize_phone(phone_number))
    where user_id is null;

create or replace function find_user_id_by_phone(p_phone text)
returns uuid
language sql
stable
set search_path = public
as $$
    select users.id
    from users
    where normalize_phone(users.phone_number) = normalize_phone(p_phone)
    order by users.created_at asc, users.id asc
    limit 1
$$;

create or replace function assign_invite_user_id_from_phone()
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

drop trigger if exists trg_assign_invite_user_id_from_phone on invites;
create trigger trg_assign_invite_user_id_from_phone
    before insert or update of phone_number, user_id
    on invites
    for each row
    execute function assign_invite_user_id_from_phone();

create or replace function link_open_invites_to_user()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if coalesce(new.phone_number, '') = '' then
        return new;
    end if;

    update invites
    set user_id = new.id
    where user_id is null
      and normalize_phone(invites.phone_number) = normalize_phone(new.phone_number);

    return new;
end;
$$;

drop trigger if exists trg_link_open_invites_to_user on users;
create trigger trg_link_open_invites_to_user
    after insert or update of phone_number
    on users
    for each row
    execute function link_open_invites_to_user();

with resolved_users as (
    select distinct on (normalize_phone(users.phone_number))
        normalize_phone(users.phone_number) as phone_key,
        users.id
    from users
    where coalesce(users.phone_number, '') <> ''
    order by normalize_phone(users.phone_number), users.created_at asc, users.id asc
)
update invites
set user_id = resolved_users.id
from resolved_users
where invites.user_id is null
  and normalize_phone(invites.phone_number) = resolved_users.phone_key;
