-- P0 follow-up: anonymize_user had no internal auth check.
-- Any authenticated user could call anonymize_user(<any-uuid>) and wipe another user's data.
-- Add self-only guard: caller must be the target, or service_role (auth.uid() IS NULL).

CREATE OR REPLACE FUNCTION anonymize_user(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Only allow self-anonymization from authenticated clients.
    -- Service role (auth.uid() IS NULL) may still call this for admin-initiated deletions.
    IF auth.uid() IS NOT NULL AND auth.uid() <> target_user_id THEN
        RAISE EXCEPTION 'Not authorized to anonymize this user';
    END IF;

    UPDATE users SET
        phone_number = 'deleted_' || target_user_id::text,
        display_name = 'Deleted User',
        avatar_url = NULL,
        bio = NULL,
        bgg_username = NULL,
        phone_visible = FALSE,
        discoverable_by_phone = FALSE,
        marketing_opt_in = FALSE
    WHERE id = target_user_id;

    DELETE FROM group_members WHERE user_id = target_user_id;

    UPDATE invites SET display_name = 'Deleted User'
    WHERE user_id = target_user_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION anonymize_user(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION anonymize_user(uuid) TO authenticated, service_role;
