-- Migration 005: owner edit/delete with backend soft delete

alter table events
    add column if not exists deleted_at timestamptz;

create index if not exists idx_events_deleted_at on events(deleted_at);

drop policy if exists events_select on events;
create policy events_select on events for select
    using (
        deleted_at is null
        and (
            auth.uid() = host_id
            or exists (
                select 1
                from event_participants
                where event_participants.event_id = events.id
                  and event_participants.user_id = auth.uid()
            )
        )
    );

drop policy if exists event_games_select on event_games;
create policy event_games_select on event_games for select
    using (
        exists (
            select 1
            from events
            where events.id = event_games.event_id
              and events.deleted_at is null
              and events.host_id = auth.uid()
        )
        or exists (
            select 1
            from event_participants
            join events on events.id = event_participants.event_id
            where event_participants.event_id = event_games.event_id
              and event_participants.user_id = auth.uid()
              and events.deleted_at is null
        )
    );

drop policy if exists time_options_select on time_options;
create policy time_options_select on time_options for select
    using (
        exists (
            select 1
            from events
            where events.id = time_options.event_id
              and events.deleted_at is null
              and events.host_id = auth.uid()
        )
        or exists (
            select 1
            from event_participants
            join events on events.id = event_participants.event_id
            where event_participants.event_id = time_options.event_id
              and event_participants.user_id = auth.uid()
              and events.deleted_at is null
        )
    );

drop policy if exists time_options_insert on time_options;
create policy time_options_insert on time_options for insert
    with check (
        exists (
            select 1
            from events
            where events.id = time_options.event_id
              and events.deleted_at is null
              and events.host_id = auth.uid()
        )
        or (
            exists (
                select 1
                from event_participants
                join events on events.id = event_participants.event_id
                where event_participants.event_id = time_options.event_id
                  and event_participants.user_id = auth.uid()
                  and events.deleted_at is null
            )
            and exists (
                select 1
                from events
                where events.id = time_options.event_id
                  and events.deleted_at is null
                  and events.allow_time_suggestions = true
            )
        )
    );

drop policy if exists invites_host_select on invites;
create policy invites_host_select on invites for select
    using (
        host_user_id = auth.uid()
        and exists (
            select 1
            from events
            where events.id = invites.event_id
              and events.deleted_at is null
        )
    );

drop policy if exists invites_guest_select on invites;
create policy invites_guest_select on invites for select
    using (
        exists (
            select 1
            from events
            where events.id = invites.event_id
              and events.deleted_at is null
        )
        and (
            auth.uid() = user_id
            or (
                user_id is null
                and exists (
                    select 1
                    from users
                    where users.id = auth.uid()
                      and normalize_phone(users.phone_number) = normalize_phone(invites.phone_number)
                )
            )
        )
    );

drop policy if exists invites_guest_update on invites;
create policy invites_guest_update on invites for update
    using (
        exists (
            select 1
            from events
            where events.id = invites.event_id
              and events.deleted_at is null
        )
        and (
            auth.uid() = user_id
            or (
                user_id is null
                and exists (
                    select 1
                    from users
                    where users.id = auth.uid()
                      and normalize_phone(users.phone_number) = normalize_phone(invites.phone_number)
                )
            )
        )
    )
    with check (
        auth.uid() = user_id
        and exists (
            select 1
            from users
            where users.id = auth.uid()
              and normalize_phone(users.phone_number) = normalize_phone(invites.phone_number)
        )
        and exists (
            select 1
            from events
            where events.id = invites.event_id
              and events.deleted_at is null
        )
    );
