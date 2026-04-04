-- Suppress duplicate push notification for auto-created invite DMs.
-- When an invite is sent to a registered user, two APNs were firing:
--   1. invite_received (from trg_notify_invite_received on invites INSERT)
--   2. dm_received (from trg_notify_dm_received on the auto-created DM)
-- Fix: skip dm_received notifications when message_type = 'invite'.
--
-- RLS audit:
--   - SECURITY DEFINER preserved (writes to other users' notifications rows)
--   - SET search_path = public maintained
--   - REVOKE re-applied (trigger-only function, not client-callable)
--   - No new table access; no recursion risk (notifications doesn't query direct_messages)

create or replace function notify_dm_received()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Skip notification for auto-created invite cards. The invite flow already fires
    -- trg_notify_invite_received which sends an invite_received push. A second
    -- dm_received push for the same action would double-notify the invitee.
    if new.message_type = 'invite' then
        return new;
    end if;

    insert into notifications (user_id, type, title, body, conversation_id, metadata)
    select
        cp.user_id,
        'dm_received',
        coalesce(sender.display_name, 'Someone') || ' sent you a message',
        left(coalesce(new.content, ''), 100),
        new.conversation_id,
        jsonb_build_object(
            'sender_name', coalesce(sender.display_name, ''),
            'sender_id', new.sender_id,
            'message_type', new.message_type
        )
    from conversation_participants cp
    join users sender on sender.id = new.sender_id
    where cp.conversation_id = new.conversation_id
      and cp.user_id != new.sender_id;

    return new;
end;
$$;

-- Maintain: trigger-only function, must not be directly callable
revoke execute on function notify_dm_received() from public, anon, authenticated;
