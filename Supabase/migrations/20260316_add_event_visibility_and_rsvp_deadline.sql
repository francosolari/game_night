alter table if exists public.events
add column if not exists visibility text not null default 'private',
add column if not exists rsvp_deadline timestamptz null;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'events_visibility_check'
    ) then
        alter table public.events
        add constraint events_visibility_check
        check (visibility in ('private', 'public'));
    end if;
end $$;
