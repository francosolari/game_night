-- Fix: PostgreSQL applies SELECT USING to the NEW row during UPDATE.
-- The previous events_select policy had "deleted_at IS NULL" at the top level,
-- which blocked soft-delete (setting deleted_at) because the new row became
-- invisible to the SELECT policy.
--
-- Solution: let the host always see their own events (even soft-deleted).
-- Guests/participants can only see non-deleted events.
-- The app already filters deleted_at=is.NULL in queries, so hosts won't
-- see deleted events in the UI.

DROP POLICY IF EXISTS events_select ON events;
CREATE POLICY events_select ON events FOR SELECT
    USING (
        auth.uid() = host_id
        OR (
            deleted_at IS NULL
            AND EXISTS (
                SELECT 1
                FROM event_participants
                WHERE event_participants.event_id = events.id
                  AND event_participants.user_id = auth.uid()
            )
        )
    );

-- Also add explicit WITH CHECK on update policy for clarity.
DROP POLICY IF EXISTS events_update ON events;
CREATE POLICY events_update ON events FOR UPDATE
    USING (auth.uid() = host_id)
    WITH CHECK (auth.uid() = host_id);