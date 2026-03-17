CREATE OR REPLACE FUNCTION public.get_my_profile_summary()
RETURNS TABLE (
    user_id UUID,
    joined_at TIMESTAMPTZ,
    hosted_event_count BIGINT,
    attended_event_count BIGINT,
    group_count BIGINT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        u.id AS user_id,
        u.created_at AS joined_at,
        (
            SELECT COUNT(*)::BIGINT
            FROM events e
            WHERE e.host_id = u.id
              AND e.deleted_at IS NULL
        ) AS hosted_event_count,
        (
            SELECT COUNT(DISTINCT i.event_id)::BIGINT
            FROM invites i
            JOIN events e ON e.id = i.event_id
            WHERE i.user_id = u.id
              AND i.status = 'accepted'
              AND e.deleted_at IS NULL
        ) AS attended_event_count,
        (
            SELECT COUNT(DISTINCT memberships.group_id)::BIGINT
            FROM (
                SELECT g.id AS group_id
                FROM groups g
                WHERE g.owner_id = u.id

                UNION

                SELECT gm.group_id
                FROM group_members gm
                WHERE gm.user_id = u.id
            ) AS memberships
        ) AS group_count
    FROM users u
    WHERE u.id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.get_my_profile_summary() TO authenticated;
