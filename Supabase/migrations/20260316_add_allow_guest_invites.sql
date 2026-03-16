alter table public.events
add column if not exists allow_guest_invites boolean not null default false;
