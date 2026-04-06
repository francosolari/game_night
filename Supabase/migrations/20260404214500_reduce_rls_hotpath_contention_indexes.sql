-- Reduce RLS hot-path lookup cost under concurrent load.
-- These indexes speed EXISTS checks used by plays/invites visibility policies.

CREATE INDEX IF NOT EXISTS idx_invites_event_user
    ON public.invites (event_id, user_id);

CREATE INDEX IF NOT EXISTS idx_group_members_group_user_active
    ON public.group_members (group_id, user_id)
    WHERE status IN ('accepted', 'pending') AND user_id IS NOT NULL;
