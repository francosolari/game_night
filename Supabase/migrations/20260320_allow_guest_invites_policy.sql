-- Migration: Add RLS policy to allow guests to invite other guests
-- Allows a guest participant to insert a new invite if the event has allow_guest_invites = true

create policy invites_guest_insert on invites for insert
    with check (
        -- Guest must be a participant in the event
        exists (
            select 1
            from event_participants
            where event_participants.event_id = invites.event_id
              and event_participants.user_id = auth.uid()
              and event_participants.role = 'guest'
        )
        -- Event must allow guest invites
        and exists (
            select 1
            from events
            where events.id = invites.event_id
              and events.allow_guest_invites = true
        )
        -- The new invite must be for the same event
        and invites.host_user_id = (
            select host_id from events where id = invites.event_id
        )
    );
