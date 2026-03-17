-- Add missing UPDATE and DELETE RLS policies for time_options
-- The table only had SELECT and INSERT policies, causing failures on:
--   - upsertTimeOptions (needs UPDATE)
--   - deleteTimeOptions (needs DELETE)
--   - update_vote_count trigger (does UPDATE on time_options)

-- UPDATE policy: host can update any time option for their event
drop policy if exists time_options_update on time_options;
create policy time_options_update on time_options for update
    using (
        exists (
            select 1
            from events
            where events.id = time_options.event_id
              and events.deleted_at is null
              and events.host_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1
            from events
            where events.id = time_options.event_id
              and events.deleted_at is null
              and events.host_id = auth.uid()
        )
    );

-- DELETE policy: host can delete time options for their event
drop policy if exists time_options_delete on time_options;
create policy time_options_delete on time_options for delete
    using (
        exists (
            select 1
            from events
            where events.id = time_options.event_id
              and events.deleted_at is null
              and events.host_id = auth.uid()
        )
    );
