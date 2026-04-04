-- Clean up notifications and DMs when a group invite is accepted or declined.
-- On accept: remove the group_invite notification (no longer actionable)
-- On decline: remove notification AND the group_invite DM

create or replace function cleanup_group_invite_on_response()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Only fire when status changes from pending to accepted/declined
    if old.status = 'pending' and new.status in ('accepted', 'declined') then
        -- Always remove the notification (no longer actionable)
        delete from notifications
        where type = 'group_invite'
          and group_id = new.group_id
          and user_id = new.user_id;

        -- On decline, also remove the DM
        if new.status = 'declined' then
            delete from direct_messages
            where message_type = 'group_invite'
              and (metadata->>'group_id')::text = new.group_id::text
              and (metadata->>'member_id')::text = new.id::text;
        end if;
    end if;

    return new;
end;
$$;

drop trigger if exists trg_cleanup_group_invite_on_response on group_members;
create trigger trg_cleanup_group_invite_on_response
    after update of status on group_members
    for each row
    execute function cleanup_group_invite_on_response();

revoke execute on function cleanup_group_invite_on_response() from public, anon, authenticated;
