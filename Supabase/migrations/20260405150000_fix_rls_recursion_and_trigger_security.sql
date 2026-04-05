-- ============================================================
-- Fix: RLS infinite recursion (42P17) and related trigger security
--
-- Bug 1 (P0): sync_event_participant_host_user_id is NOT SECURITY DEFINER.
--   As a BEFORE trigger on event_participants INSERT, it runs SELECT FROM events.
--   events_select has EXISTS (SELECT 1 FROM event_participants ...).
--   PostgreSQL detects the re-entrant event_participants context → 42P17.
--   Same chain prevents ensure_event_host_participant and sync_invite_participant_access
--   from populating event_participants at all.
--
-- Bug 2 (P0): event_participants_self_insert/self_update WITH CHECK
--   queries invites → invites_guest_select queries events → events_select
--   queries event_participants → 42P17 while inside event_participants INSERT.
--
-- Bug 3 (P0): group_members_select_via_membership reads group_membership_lookup
--   (a view) which reads group_members with user RLS applied → the same policy
--   fires again → 42P17. Breaks groups SELECT for non-owners and plays_select
--   for group-linked plays.
--
-- Fixes:
--   1. Make sync_event_participant_host_user_id SECURITY DEFINER.
--   2. Make ensure_event_host_participant SECURITY DEFINER.
--   3. Make sync_invite_participant_access SECURITY DEFINER.
--   4. Make sync_invite_host_user_id SECURITY DEFINER.
--   5. Create has_valid_invite() SECURITY DEFINER helper (breaks self_insert chain).
--   6. Rewrite event_participants_self_insert / self_update to use it.
--   7. Create is_group_member() SECURITY DEFINER helper (mirrors is_conversation_member).
--   8. Rewrite groups_select and group_members_select_via_membership to use it.
--   9. Backfill event_participants from existing invites (pre-existing invites have no rows).
--  10. Fix missing search_path on remaining functions flagged by advisors.
--  11. REVOKE execute on trigger-only functions from anon/authenticated.
--  12. Add deny-all policy on bgg_backfill_jobs (RLS enabled, no policies).
-- ============================================================


-- ============================================================
-- 1. SECURITY DEFINER on sync_event_participant_host_user_id
--    (BEFORE trigger on event_participants INSERT/UPDATE)
--    Queries events — must bypass RLS to avoid 42P17.
-- ============================================================
CREATE OR REPLACE FUNCTION public.sync_event_participant_host_user_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SELECT host_id
    INTO new.host_user_id
    FROM events
    WHERE id = new.event_id;

    IF new.host_user_id IS NULL THEN
        RAISE EXCEPTION 'Event % not found for participant host sync', new.event_id;
    END IF;

    new.updated_at = now();
    RETURN new;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_event_participant_host_user_id() FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 2. SECURITY DEFINER on ensure_event_host_participant
--    (AFTER INSERT trigger on events)
--    Inserts into event_participants — must bypass RLS so the
--    nested BEFORE trigger (now also SECURITY DEFINER) runs cleanly.
-- ============================================================
CREATE OR REPLACE FUNCTION public.ensure_event_host_participant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO event_participants (
        event_id,
        user_id,
        host_user_id,
        role,
        rsvp_status,
        responded_at,
        phone_number_snapshot
    )
    SELECT
        new.id,
        new.host_id,
        new.host_id,
        'host',
        'accepted',
        now(),
        users.phone_number
    FROM users
    WHERE users.id = new.host_id
    ON CONFLICT (event_id, user_id) DO UPDATE
        SET host_user_id          = excluded.host_user_id,
            role                  = excluded.role,
            rsvp_status           = excluded.rsvp_status,
            responded_at          = excluded.responded_at,
            phone_number_snapshot = excluded.phone_number_snapshot,
            updated_at            = now();

    RETURN new;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.ensure_event_host_participant() FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 3. SECURITY DEFINER on sync_invite_participant_access
--    (AFTER INSERT/UPDATE trigger on invites)
--    Inserts into event_participants on behalf of the invited user.
--    Must bypass RLS: the invited user has no event_participants row
--    yet, so user-level RLS would block this insert.
-- ============================================================
CREATE OR REPLACE FUNCTION public.sync_invite_participant_access()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF new.user_id IS NULL THEN
        RETURN new;
    END IF;

    INSERT INTO event_participants (
        event_id,
        user_id,
        host_user_id,
        source_invite_id,
        role,
        rsvp_status,
        responded_at,
        phone_number_snapshot
    )
    VALUES (
        new.event_id,
        new.user_id,
        new.host_user_id,
        new.id,
        'guest',
        invite_status_to_participant_rsvp(new.status),
        new.responded_at,
        new.phone_number
    )
    ON CONFLICT (event_id, user_id) DO UPDATE
        SET source_invite_id      = excluded.source_invite_id,
            rsvp_status           = excluded.rsvp_status,
            responded_at          = excluded.responded_at,
            phone_number_snapshot = excluded.phone_number_snapshot,
            updated_at            = now();

    RETURN new;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_invite_participant_access() FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 4. SECURITY DEFINER on sync_invite_host_user_id
--    (BEFORE INSERT/UPDATE trigger on invites)
--    Queries events — safe even from nested trigger contexts.
-- ============================================================
CREATE OR REPLACE FUNCTION public.sync_invite_host_user_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SELECT host_id
    INTO new.host_user_id
    FROM events
    WHERE id = new.event_id;

    IF new.host_user_id IS NULL THEN
        RAISE EXCEPTION 'Event % not found for invite host sync', new.event_id;
    END IF;

    RETURN new;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_invite_host_user_id() FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 5. has_valid_invite() — SECURITY DEFINER helper
--    Checks that the calling user has a matching invite row.
--    Used by event_participants_self_insert / self_update WITH CHECK
--    to break the chain: invites → events → event_participants → 42P17.
-- ============================================================
CREATE OR REPLACE FUNCTION public.has_valid_invite(p_event_id uuid, p_invite_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM invites
        WHERE id       = p_invite_id
          AND event_id = p_event_id
          AND user_id  = auth.uid()
    );
$$;

REVOKE EXECUTE ON FUNCTION public.has_valid_invite(uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.has_valid_invite(uuid, uuid) TO authenticated;


-- ============================================================
-- 6. Fix event_participants_self_insert WITH CHECK
--    Replace EXISTS (invites...) with has_valid_invite() to stop
--    the recursive chain through invites_guest_select → events_select.
-- ============================================================
DROP POLICY IF EXISTS "event_participants_self_insert" ON event_participants;
CREATE POLICY "event_participants_self_insert" ON event_participants
    FOR INSERT
    WITH CHECK (
        user_id         = (SELECT auth.uid())
        AND role        = 'guest'
        AND source_invite_id IS NOT NULL
        AND has_valid_invite(event_id, source_invite_id)
    );


-- ============================================================
-- 7. Fix event_participants_self_update WITH CHECK (same chain)
-- ============================================================
DROP POLICY IF EXISTS "event_participants_self_update" ON event_participants;
CREATE POLICY "event_participants_self_update" ON event_participants
    FOR UPDATE
    USING  (user_id = (SELECT auth.uid()))
    WITH CHECK (
        user_id         = (SELECT auth.uid())
        AND role        = 'guest'
        AND source_invite_id IS NOT NULL
        AND has_valid_invite(event_id, source_invite_id)
    );


-- ============================================================
-- 8. is_group_member() — SECURITY DEFINER helper
--    Mirrors is_conversation_member. Reads group_members without
--    RLS to break the recursive chain:
--    group_members_select_via_membership → group_membership_lookup
--    → group_members (RLS) → same policy again → 42P17.
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM group_members
        WHERE group_id = p_group_id
          AND user_id  = auth.uid()
          AND status   IN ('accepted', 'pending')
    );
$$;

REVOKE EXECUTE ON FUNCTION public.is_group_member(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.is_group_member(uuid) TO authenticated;


-- ============================================================
-- 9. Rewrite groups_select to use is_group_member()
--    Removes group_membership_lookup from the policy hot-path,
--    eliminating the view → group_members → view recursion.
-- ============================================================
DROP POLICY IF EXISTS "groups_select" ON groups;
CREATE POLICY "groups_select" ON groups
    FOR SELECT
    USING (
        owner_id = (SELECT auth.uid())
        OR is_group_member(id)
    );


-- ============================================================
-- 10. Rewrite group_members_select_via_membership to use is_group_member()
-- ============================================================
DROP POLICY IF EXISTS "group_members_select_via_membership" ON group_members;
CREATE POLICY "group_members_select_via_membership" ON group_members
    FOR SELECT
    USING (is_group_member(group_id));


-- ============================================================
-- 11. Backfill event_participants from existing invites
--     Pre-existing invites (before the event_participants table
--     existed) have no corresponding rows. Without them,
--     events_select blocks invited users.
-- ============================================================
INSERT INTO event_participants (
    event_id,
    user_id,
    host_user_id,
    source_invite_id,
    role,
    rsvp_status,
    responded_at,
    phone_number_snapshot
)
SELECT
    i.event_id,
    i.user_id,
    i.host_user_id,
    i.id,
    'guest',
    CASE i.status
        WHEN 'accepted' THEN 'accepted'
        WHEN 'declined' THEN 'declined'
        WHEN 'maybe'    THEN 'maybe'
        ELSE 'pending'
    END,
    i.responded_at,
    i.phone_number
FROM invites i
WHERE i.user_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM event_participants ep
      WHERE ep.event_id = i.event_id
        AND ep.user_id  = i.user_id
  )
ON CONFLICT (event_id, user_id) DO NOTHING;


-- ============================================================
-- 12. Fix missing search_path on remaining functions
--     (flagged by security advisor)
-- ============================================================

-- update_updated_at (used by users, groups, events, activity_feed triggers)
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- update_updated_at_column (used by plays, group_messages triggers)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- invite_status_to_participant_rsvp
CREATE OR REPLACE FUNCTION public.invite_status_to_participant_rsvp(invite_status text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
    SELECT CASE invite_status
        WHEN 'accepted' THEN 'accepted'
        WHEN 'declined' THEN 'declined'
        WHEN 'maybe'    THEN 'maybe'
        ELSE 'pending'
    END;
$$;

-- auto_post_rsvp_update (AFTER UPDATE trigger on invites)
CREATE OR REPLACE FUNCTION public.auto_post_rsvp_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status IN ('accepted', 'maybe')
       AND NEW.user_id IS NOT NULL THEN
        INSERT INTO activity_feed (event_id, user_id, type, content)
        VALUES (NEW.event_id, NEW.user_id, 'rsvp_update', NEW.status);
    END IF;
    RETURN NEW;
END;
$$;

-- check_invite_blocked (BEFORE INSERT trigger on invites)
CREATE OR REPLACE FUNCTION public.check_invite_blocked()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM blocked_users b
        JOIN events e ON e.id = NEW.event_id
        WHERE (b.blocker_id = NEW.user_id AND b.blocked_id = e.host_id)
           OR (b.blocked_phone = NEW.phone_number AND b.blocked_id = e.host_id)
    ) THEN
        RAISE EXCEPTION 'Cannot invite a user who has blocked the host';
    END IF;
    RETURN NEW;
END;
$$;

-- normalize_group_emoji
CREATE OR REPLACE FUNCTION public.normalize_group_emoji(p_emoji text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
    SELECT CASE
        WHEN p_emoji IS NULL       THEN '🎲'
        WHEN btrim(p_emoji) = ''   THEN '🎲'
        WHEN btrim(p_emoji) IN ('?', '?') THEN '🎲'
        ELSE btrim(p_emoji)
    END;
$$;

-- update_vote_count (AFTER INSERT/UPDATE/DELETE trigger on time_option_votes)
CREATE OR REPLACE FUNCTION public.update_vote_count()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.vote_type = 'yes' THEN
            UPDATE time_options SET vote_count  = vote_count  + 1 WHERE id = NEW.time_option_id;
        ELSIF NEW.vote_type = 'maybe' THEN
            UPDATE time_options SET maybe_count = maybe_count + 1 WHERE id = NEW.time_option_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.vote_type = 'yes' THEN
            UPDATE time_options SET vote_count  = vote_count  - 1 WHERE id = OLD.time_option_id;
        ELSIF OLD.vote_type = 'maybe' THEN
            UPDATE time_options SET maybe_count = maybe_count - 1 WHERE id = OLD.time_option_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.vote_type = 'yes'   THEN UPDATE time_options SET vote_count  = vote_count  - 1 WHERE id = OLD.time_option_id; END IF;
        IF OLD.vote_type = 'maybe' THEN UPDATE time_options SET maybe_count = maybe_count - 1 WHERE id = OLD.time_option_id; END IF;
        IF NEW.vote_type = 'yes'   THEN UPDATE time_options SET vote_count  = vote_count  + 1 WHERE id = NEW.time_option_id; END IF;
        IF NEW.vote_type = 'maybe' THEN UPDATE time_options SET maybe_count = maybe_count + 1 WHERE id = NEW.time_option_id; END IF;
    END IF;
    RETURN NULL;
END;
$$;

-- update_game_vote_count (AFTER INSERT/UPDATE/DELETE trigger on game_votes)
CREATE OR REPLACE FUNCTION public.update_game_vote_count()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF    NEW.vote_type = 'yes'   THEN UPDATE event_games SET yes_count   = yes_count   + 1 WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        ELSIF NEW.vote_type = 'maybe' THEN UPDATE event_games SET maybe_count = maybe_count + 1 WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        ELSIF NEW.vote_type = 'no'    THEN UPDATE event_games SET no_count    = no_count    + 1 WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF    OLD.vote_type = 'yes'   THEN UPDATE event_games SET yes_count   = yes_count   - 1 WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        ELSIF OLD.vote_type = 'maybe' THEN UPDATE event_games SET maybe_count = maybe_count - 1 WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        ELSIF OLD.vote_type = 'no'    THEN UPDATE event_games SET no_count    = no_count    - 1 WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF    OLD.vote_type = 'yes'   THEN UPDATE event_games SET yes_count   = yes_count   - 1 WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        ELSIF OLD.vote_type = 'maybe' THEN UPDATE event_games SET maybe_count = maybe_count - 1 WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        ELSIF OLD.vote_type = 'no'    THEN UPDATE event_games SET no_count    = no_count    - 1 WHERE event_id = OLD.event_id AND game_id = OLD.game_id;
        END IF;
        IF    NEW.vote_type = 'yes'   THEN UPDATE event_games SET yes_count   = yes_count   + 1 WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        ELSIF NEW.vote_type = 'maybe' THEN UPDATE event_games SET maybe_count = maybe_count + 1 WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        ELSIF NEW.vote_type = 'no'    THEN UPDATE event_games SET no_count    = no_count    + 1 WHERE event_id = NEW.event_id AND game_id = NEW.game_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

-- complete_past_events (scheduled function, no auth context)
CREATE OR REPLACE FUNCTION public.complete_past_events()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    affected integer;
BEGIN
    WITH past_events AS (
        SELECT e.id
        FROM events e
        WHERE e.status IN ('published', 'confirmed')
          AND e.deleted_at IS NULL
          AND EXISTS (SELECT 1 FROM time_options t WHERE t.event_id = e.id)
          AND (
            (e.confirmed_time_option_id IS NOT NULL AND (
                SELECT COALESCE(t.end_time, (t.start_time::date + interval '1 day'))
                FROM time_options t WHERE t.id = e.confirmed_time_option_id
            ) < now())
            OR
            (e.confirmed_time_option_id IS NULL AND (
                SELECT MAX(COALESCE(t.end_time, (t.start_time::date + interval '1 day')))
                FROM time_options t WHERE t.event_id = e.id
            ) < now())
          )
    )
    UPDATE events SET status = 'completed'
    WHERE id IN (SELECT id FROM past_events);

    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;

-- get_frequent_contacts (RPC called by authenticated users)
CREATE OR REPLACE FUNCTION public.get_frequent_contacts(requesting_user_id uuid, max_results integer DEFAULT 20)
RETURNS TABLE (
    contact_phone      text,
    contact_name       text,
    contact_user_id    uuid,
    contact_avatar_url text,
    is_app_user        boolean,
    mutual_event_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        other_inv.phone_number                                                        AS contact_phone,
        COALESCE(other_inv.display_name, u.display_name, other_inv.phone_number)      AS contact_name,
        other_inv.user_id                                                             AS contact_user_id,
        u.avatar_url                                                                  AS contact_avatar_url,
        (other_inv.user_id IS NOT NULL)                                               AS is_app_user,
        COUNT(DISTINCT other_inv.event_id)                                            AS mutual_event_count
    FROM invites my_inv
    JOIN invites other_inv ON my_inv.event_id = other_inv.event_id
    LEFT JOIN users u ON other_inv.user_id = u.id
    WHERE my_inv.user_id = requesting_user_id
      AND other_inv.phone_number != (SELECT phone_number FROM users WHERE id = requesting_user_id)
      AND other_inv.user_id IS DISTINCT FROM requesting_user_id
      AND NOT EXISTS (
          SELECT 1 FROM blocked_users b
          WHERE b.blocker_id = requesting_user_id
            AND (b.blocked_id = other_inv.user_id OR b.blocked_phone = other_inv.phone_number)
      )
    GROUP BY other_inv.phone_number, contact_name, other_inv.user_id, u.avatar_url
    ORDER BY mutual_event_count DESC, contact_name ASC
    LIMIT max_results;
$$;


-- ============================================================
-- 13. REVOKE execute on trigger-only functions from anon/authenticated
--     These are internal trigger functions — clients must not call them.
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.auto_post_rsvp_update()    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.check_invite_blocked()     FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_updated_at()        FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_vote_count()        FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_game_vote_count()   FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.normalize_group_emoji(text) FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 14. bgg_backfill_jobs — add deny-all policy
--     RLS is enabled but there are zero policies, so authenticated
--     users get implicit deny. Make it explicit and safe.
-- ============================================================
DROP POLICY IF EXISTS "bgg_backfill_jobs_no_access" ON bgg_backfill_jobs;
CREATE POLICY "bgg_backfill_jobs_no_access" ON bgg_backfill_jobs
    FOR ALL
    USING (false)
    WITH CHECK (false);
