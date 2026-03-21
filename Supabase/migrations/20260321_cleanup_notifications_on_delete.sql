-- Clean up notifications when events are soft-deleted or invites are rescinded

-- ============================================================
-- 1. CASCADE DELETE notifications when an invite is hard-deleted
--    (host rescinding an invite)
-- ============================================================

-- Swap the invite_id FK from SET NULL → CASCADE DELETE
ALTER TABLE notifications
    DROP CONSTRAINT IF EXISTS notifications_invite_id_fkey;

ALTER TABLE notifications
    ADD CONSTRAINT notifications_invite_id_fkey
    FOREIGN KEY (invite_id) REFERENCES invites(id) ON DELETE CASCADE;

-- ============================================================
-- 2. DELETE notifications when an event is soft-deleted
--    (deleted_at flips from NULL → non-NULL)
-- ============================================================

CREATE OR REPLACE FUNCTION cleanup_notifications_on_event_soft_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
        DELETE FROM notifications WHERE event_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

-- Trigger functions that write across user boundaries must not be callable directly
REVOKE EXECUTE ON FUNCTION cleanup_notifications_on_event_soft_delete() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS trg_cleanup_notifications_on_event_soft_delete ON events;
CREATE TRIGGER trg_cleanup_notifications_on_event_soft_delete
    AFTER UPDATE OF deleted_at ON events
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_notifications_on_event_soft_delete();
