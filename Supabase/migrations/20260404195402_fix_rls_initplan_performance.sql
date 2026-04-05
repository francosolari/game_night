-- ============================================================
-- Fix: auth_rls_initplan performance + missing WITH CHECK
-- ============================================================
-- Wraps all auth.uid() calls in (SELECT auth.uid()) so Postgres
-- evaluates the JWT claim once per query, not once per row.
-- Also adds missing WITH CHECK to all UPDATE policies.
-- Also enables RLS on bgg_backfill_jobs.
-- ============================================================

-- ── activity_feed ─────────────────────────────────────────────
DROP POLICY IF EXISTS "activity_feed_delete" ON activity_feed;
CREATE POLICY "activity_feed_delete" ON activity_feed FOR DELETE USING (
  (SELECT auth.uid()) = user_id
  OR EXISTS (
    SELECT 1 FROM events
    WHERE events.id = activity_feed.event_id AND events.host_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS "activity_feed_insert" ON activity_feed;
CREATE POLICY "activity_feed_insert" ON activity_feed FOR INSERT WITH CHECK (
  (SELECT auth.uid()) = user_id
  AND (
    EXISTS (
      SELECT 1 FROM invites
      WHERE invites.event_id = activity_feed.event_id
        AND invites.user_id = (SELECT auth.uid())
        AND invites.status = ANY (ARRAY['accepted'::text, 'maybe'::text])
    )
    OR EXISTS (
      SELECT 1 FROM events
      WHERE events.id = activity_feed.event_id AND events.host_id = (SELECT auth.uid())
    )
  )
);

DROP POLICY IF EXISTS "activity_feed_insert_host_rsvp" ON activity_feed;
CREATE POLICY "activity_feed_insert_host_rsvp" ON activity_feed FOR INSERT WITH CHECK (
  type = 'rsvp_update'
  AND EXISTS (
    SELECT 1 FROM events
    WHERE events.id = activity_feed.event_id AND events.host_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS "activity_feed_select" ON activity_feed;
CREATE POLICY "activity_feed_select" ON activity_feed FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM invites
    WHERE invites.event_id = activity_feed.event_id
      AND invites.user_id = (SELECT auth.uid())
      AND invites.status = ANY (ARRAY['accepted'::text, 'maybe'::text])
  )
  OR EXISTS (
    SELECT 1 FROM events
    WHERE events.id = activity_feed.event_id AND events.host_id = (SELECT auth.uid())
  )
);

-- FIX: added WITH CHECK (was missing)
DROP POLICY IF EXISTS "activity_feed_update" ON activity_feed;
CREATE POLICY "activity_feed_update" ON activity_feed FOR UPDATE
  USING (
    (SELECT auth.uid()) = user_id
    OR EXISTS (
      SELECT 1 FROM events
      WHERE events.id = activity_feed.event_id AND events.host_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    OR EXISTS (
      SELECT 1 FROM events
      WHERE events.id = activity_feed.event_id AND events.host_id = (SELECT auth.uid())
    )
  );

-- ── bgg_sync_state ────────────────────────────────────────────
DROP POLICY IF EXISTS "bgg_sync_state_delete" ON bgg_sync_state;
CREATE POLICY "bgg_sync_state_delete" ON bgg_sync_state FOR DELETE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "bgg_sync_state_insert" ON bgg_sync_state;
CREATE POLICY "bgg_sync_state_insert" ON bgg_sync_state FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "bgg_sync_state_select" ON bgg_sync_state;
CREATE POLICY "bgg_sync_state_select" ON bgg_sync_state FOR SELECT USING ((SELECT auth.uid()) = user_id);

-- FIX: added WITH CHECK (was missing)
DROP POLICY IF EXISTS "bgg_sync_state_update" ON bgg_sync_state;
CREATE POLICY "bgg_sync_state_update" ON bgg_sync_state FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- ── blocked_users ─────────────────────────────────────────────
DROP POLICY IF EXISTS "blocked_users_own" ON blocked_users;
CREATE POLICY "blocked_users_own" ON blocked_users FOR ALL USING ((SELECT auth.uid()) = blocker_id);

-- ── consent_log ───────────────────────────────────────────────
DROP POLICY IF EXISTS "consent_log_own" ON consent_log;
CREATE POLICY "consent_log_own" ON consent_log FOR ALL USING ((SELECT auth.uid()) = user_id);

-- ── conversation_participants ─────────────────────────────────
DROP POLICY IF EXISTS "conv_participants_update" ON conversation_participants;
CREATE POLICY "conv_participants_update" ON conversation_participants FOR UPDATE
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- ── direct_messages ───────────────────────────────────────────
DROP POLICY IF EXISTS "dm_insert" ON direct_messages;
CREATE POLICY "dm_insert" ON direct_messages FOR INSERT WITH CHECK (
  sender_id = (SELECT auth.uid()) AND is_conversation_member(conversation_id)
);

-- ── event_games ───────────────────────────────────────────────
DROP POLICY IF EXISTS "event_games_manage" ON event_games;
CREATE POLICY "event_games_manage" ON event_games FOR ALL USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = event_games.event_id AND events.host_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS "event_games_select" ON event_games;
CREATE POLICY "event_games_select" ON event_games FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = event_games.event_id
      AND events.deleted_at IS NULL
      AND events.host_id = (SELECT auth.uid())
  )
  OR EXISTS (
    SELECT 1
    FROM event_participants
    JOIN events ON events.id = event_participants.event_id
    WHERE event_participants.event_id = event_games.event_id
      AND event_participants.user_id = (SELECT auth.uid())
      AND events.deleted_at IS NULL
  )
);

-- ── event_participants ────────────────────────────────────────
DROP POLICY IF EXISTS "event_participants_host_manage" ON event_participants;
CREATE POLICY "event_participants_host_manage" ON event_participants FOR ALL
  USING (host_user_id = (SELECT auth.uid()))
  WITH CHECK (host_user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "event_participants_self_insert" ON event_participants;
CREATE POLICY "event_participants_self_insert" ON event_participants FOR INSERT WITH CHECK (
  user_id = (SELECT auth.uid())
  AND role = 'guest'
  AND source_invite_id IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM invites
    WHERE invites.id = event_participants.source_invite_id
      AND invites.event_id = event_participants.event_id
      AND invites.user_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS "event_participants_self_select" ON event_participants;
CREATE POLICY "event_participants_self_select" ON event_participants FOR SELECT
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "event_participants_self_update" ON event_participants;
CREATE POLICY "event_participants_self_update" ON event_participants FOR UPDATE
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND role = 'guest'
    AND source_invite_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM invites
      WHERE invites.id = event_participants.source_invite_id
        AND invites.event_id = event_participants.event_id
        AND invites.user_id = (SELECT auth.uid())
    )
  );

-- ── events ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "events_insert" ON events;
CREATE POLICY "events_insert" ON events FOR INSERT WITH CHECK ((SELECT auth.uid()) = host_id);

DROP POLICY IF EXISTS "events_select" ON events;
CREATE POLICY "events_select" ON events FOR SELECT USING (
  (SELECT auth.uid()) = host_id
  OR (
    deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM event_participants
      WHERE event_participants.event_id = events.id
        AND event_participants.user_id = (SELECT auth.uid())
    )
  )
);

DROP POLICY IF EXISTS "events_update" ON events;
CREATE POLICY "events_update" ON events FOR UPDATE
  USING ((SELECT auth.uid()) = host_id)
  WITH CHECK ((SELECT auth.uid()) = host_id);

-- ── game_categories ───────────────────────────────────────────
DROP POLICY IF EXISTS "categories_all" ON game_categories;
CREATE POLICY "categories_all" ON game_categories FOR ALL USING ((SELECT auth.uid()) = user_id);

-- ── game_library ──────────────────────────────────────────────
DROP POLICY IF EXISTS "library_all" ON game_library;
CREATE POLICY "library_all" ON game_library FOR ALL USING ((SELECT auth.uid()) = user_id);

-- ── game_votes ────────────────────────────────────────────────
DROP POLICY IF EXISTS "game_votes_delete" ON game_votes;
CREATE POLICY "game_votes_delete" ON game_votes FOR DELETE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "game_votes_insert" ON game_votes;
CREATE POLICY "game_votes_insert" ON game_votes FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "game_votes_select" ON game_votes;
CREATE POLICY "game_votes_select" ON game_votes FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = game_votes.event_id AND events.host_id = (SELECT auth.uid())
  )
  OR EXISTS (
    SELECT 1 FROM invites
    WHERE invites.event_id = game_votes.event_id AND invites.user_id = (SELECT auth.uid())
  )
);

-- FIX: added WITH CHECK (was missing)
DROP POLICY IF EXISTS "game_votes_update" ON game_votes;
CREATE POLICY "game_votes_update" ON game_votes FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- ── game_wishlist ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can remove from own wishlist" ON game_wishlist;
CREATE POLICY "Users can remove from own wishlist" ON game_wishlist FOR DELETE
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can add to own wishlist" ON game_wishlist;
CREATE POLICY "Users can add to own wishlist" ON game_wishlist FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can view own wishlist" ON game_wishlist;
CREATE POLICY "Users can view own wishlist" ON game_wishlist FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

-- ── games ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "games_insert" ON games;
CREATE POLICY "games_insert" ON games FOR INSERT WITH CHECK (
  owner_id IS NULL OR owner_id = (SELECT auth.uid())
);

DROP POLICY IF EXISTS "games_select" ON games;
CREATE POLICY "games_select" ON games FOR SELECT USING (
  owner_id IS NULL
  OR owner_id = (SELECT auth.uid())
  OR EXISTS (
    SELECT 1
    FROM event_games
    JOIN events ON events.id = event_games.event_id
    WHERE event_games.game_id = games.id
      AND (
        events.host_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1 FROM invites
          WHERE invites.event_id = events.id AND invites.user_id = (SELECT auth.uid())
        )
      )
  )
);

DROP POLICY IF EXISTS "games_update" ON games;
CREATE POLICY "games_update" ON games FOR UPDATE
  USING (owner_id IS NULL OR owner_id = (SELECT auth.uid()))
  WITH CHECK (owner_id IS NULL OR owner_id = (SELECT auth.uid()));

-- ── group_members ─────────────────────────────────────────────
DROP POLICY IF EXISTS "group_members_all" ON group_members;
CREATE POLICY "group_members_all" ON group_members FOR ALL USING (
  EXISTS (
    SELECT 1 FROM groups
    WHERE groups.id = group_members.group_id AND groups.owner_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS "group_members_select_self" ON group_members;
CREATE POLICY "group_members_select_self" ON group_members FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "group_members_select_via_membership" ON group_members;
CREATE POLICY "group_members_select_via_membership" ON group_members FOR SELECT USING (
  group_id IN (
    SELECT group_membership_lookup.group_id
    FROM group_membership_lookup
    WHERE group_membership_lookup.user_id = (SELECT auth.uid())
      AND group_membership_lookup.status = ANY (ARRAY['accepted'::text, 'pending'::text])
  )
);

DROP POLICY IF EXISTS "group_members_update_own_status" ON group_members;
CREATE POLICY "group_members_update_own_status" ON group_members FOR UPDATE
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- ── group_messages ────────────────────────────────────────────
DROP POLICY IF EXISTS "group_messages_delete" ON group_messages;
CREATE POLICY "group_messages_delete" ON group_messages FOR DELETE USING (
  (SELECT auth.uid()) = user_id
  OR EXISTS (
    SELECT 1 FROM groups
    WHERE groups.id = group_messages.group_id AND groups.owner_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS "group_messages_insert" ON group_messages;
CREATE POLICY "group_messages_insert" ON group_messages FOR INSERT WITH CHECK (
  (SELECT auth.uid()) = user_id
  AND EXISTS (
    SELECT 1 FROM groups
    WHERE groups.id = group_messages.group_id
      AND (
        groups.owner_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1 FROM group_members
          WHERE group_members.group_id = group_messages.group_id
            AND group_members.user_id = (SELECT auth.uid())
        )
      )
  )
);

DROP POLICY IF EXISTS "group_messages_select" ON group_messages;
CREATE POLICY "group_messages_select" ON group_messages FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM groups
    WHERE groups.id = group_messages.group_id
      AND (
        groups.owner_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1 FROM group_members
          WHERE group_members.group_id = group_messages.group_id
            AND group_members.user_id = (SELECT auth.uid())
        )
      )
  )
);

-- FIX: added WITH CHECK (was missing)
DROP POLICY IF EXISTS "group_messages_update" ON group_messages;
CREATE POLICY "group_messages_update" ON group_messages FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- ── groups ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "groups_delete" ON groups;
CREATE POLICY "groups_delete" ON groups FOR DELETE USING ((SELECT auth.uid()) = owner_id);

DROP POLICY IF EXISTS "groups_insert" ON groups;
CREATE POLICY "groups_insert" ON groups FOR INSERT WITH CHECK ((SELECT auth.uid()) = owner_id);

DROP POLICY IF EXISTS "groups_select" ON groups;
CREATE POLICY "groups_select" ON groups FOR SELECT USING (
  owner_id = (SELECT auth.uid())
  OR id IN (
    SELECT group_membership_lookup.group_id
    FROM group_membership_lookup
    WHERE group_membership_lookup.user_id = (SELECT auth.uid())
      AND group_membership_lookup.status = ANY (ARRAY['accepted'::text, 'pending'::text])
  )
);

-- FIX: added WITH CHECK (was missing)
DROP POLICY IF EXISTS "groups_update" ON groups;
CREATE POLICY "groups_update" ON groups FOR UPDATE
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

-- ── invites ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "invites_host_delete" ON invites;
CREATE POLICY "invites_host_delete" ON invites FOR DELETE
  USING (host_user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "invites_guest_insert" ON invites;
CREATE POLICY "invites_guest_insert" ON invites FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM event_participants
    WHERE event_participants.event_id = invites.event_id
      AND event_participants.user_id = (SELECT auth.uid())
      AND event_participants.role = 'guest'
  )
  AND EXISTS (
    SELECT 1 FROM events
    WHERE events.id = invites.event_id AND events.allow_guest_invites = true
  )
  AND host_user_id = (SELECT events.host_id FROM events WHERE events.id = invites.event_id)
);

DROP POLICY IF EXISTS "invites_host_insert" ON invites;
CREATE POLICY "invites_host_insert" ON invites FOR INSERT
  WITH CHECK (host_user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "invites_host_select" ON invites;
CREATE POLICY "invites_host_select" ON invites FOR SELECT USING (
  host_user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM events WHERE events.id = invites.event_id AND events.deleted_at IS NULL
  )
);

DROP POLICY IF EXISTS "invites_guest_select" ON invites;
CREATE POLICY "invites_guest_select" ON invites FOR SELECT USING (
  EXISTS (SELECT 1 FROM events WHERE events.id = invites.event_id AND events.deleted_at IS NULL)
  AND (
    (SELECT auth.uid()) = user_id
    OR (
      user_id IS NULL
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = (SELECT auth.uid())
          AND normalize_phone(users.phone_number) = normalize_phone(invites.phone_number)
      )
    )
  )
);

DROP POLICY IF EXISTS "invites_guest_update" ON invites;
CREATE POLICY "invites_guest_update" ON invites FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM events WHERE events.id = invites.event_id AND events.deleted_at IS NULL)
    AND (
      (SELECT auth.uid()) = user_id
      OR (
        user_id IS NULL
        AND EXISTS (
          SELECT 1 FROM users
          WHERE users.id = (SELECT auth.uid())
            AND normalize_phone(users.phone_number) = normalize_phone(invites.phone_number)
        )
      )
    )
  )
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND EXISTS (
      SELECT 1 FROM users
      WHERE users.id = (SELECT auth.uid())
        AND normalize_phone(users.phone_number) = normalize_phone(invites.phone_number)
    )
    AND EXISTS (SELECT 1 FROM events WHERE events.id = invites.event_id AND events.deleted_at IS NULL)
  );

DROP POLICY IF EXISTS "invites_host_update" ON invites;
CREATE POLICY "invites_host_update" ON invites FOR UPDATE
  USING (host_user_id = (SELECT auth.uid()))
  WITH CHECK (host_user_id = (SELECT auth.uid()));

-- ── notification_preferences ──────────────────────────────────
DROP POLICY IF EXISTS "notification_preferences_insert" ON notification_preferences;
CREATE POLICY "notification_preferences_insert" ON notification_preferences FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "notification_preferences_select" ON notification_preferences;
CREATE POLICY "notification_preferences_select" ON notification_preferences FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "notification_preferences_update" ON notification_preferences;
CREATE POLICY "notification_preferences_update" ON notification_preferences FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- ── notifications ─────────────────────────────────────────────
DROP POLICY IF EXISTS "notifications_select" ON notifications;
CREATE POLICY "notifications_select" ON notifications FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "notifications_update" ON notifications;
CREATE POLICY "notifications_update" ON notifications FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- ── pending_invite_dms ────────────────────────────────────────
DROP POLICY IF EXISTS "pending_invite_dms_host" ON pending_invite_dms;
CREATE POLICY "pending_invite_dms_host" ON pending_invite_dms FOR SELECT
  USING (host_user_id = (SELECT auth.uid()));

-- ── play_participants ─────────────────────────────────────────
DROP POLICY IF EXISTS "play_participants_delete" ON play_participants;
CREATE POLICY "play_participants_delete" ON play_participants FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM plays
    WHERE plays.id = play_participants.play_id AND plays.logged_by = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS "play_participants_insert" ON play_participants;
CREATE POLICY "play_participants_insert" ON play_participants FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM plays
    WHERE plays.id = play_participants.play_id AND plays.logged_by = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS "play_participants_select" ON play_participants;
CREATE POLICY "play_participants_select" ON play_participants FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM plays
    WHERE plays.id = play_participants.play_id
      AND (
        plays.logged_by = (SELECT auth.uid())
        OR (
          plays.event_id IS NOT NULL
          AND EXISTS (
            SELECT 1 FROM events
            WHERE events.id = plays.event_id
              AND (
                events.host_id = (SELECT auth.uid())
                OR EXISTS (
                  SELECT 1 FROM invites
                  WHERE invites.event_id = plays.event_id
                    AND invites.user_id = (SELECT auth.uid())
                )
              )
          )
        )
        OR (
          plays.group_id IS NOT NULL
          AND EXISTS (
            SELECT 1 FROM groups
            WHERE groups.id = plays.group_id
              AND (
                groups.owner_id = (SELECT auth.uid())
                OR EXISTS (
                  SELECT 1 FROM group_members
                  WHERE group_members.group_id = plays.group_id
                    AND group_members.user_id = (SELECT auth.uid())
                )
              )
          )
        )
      )
  )
);

-- FIX: added WITH CHECK (was missing)
DROP POLICY IF EXISTS "play_participants_update" ON play_participants;
CREATE POLICY "play_participants_update" ON play_participants FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM plays
      WHERE plays.id = play_participants.play_id AND plays.logged_by = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM plays
      WHERE plays.id = play_participants.play_id AND plays.logged_by = (SELECT auth.uid())
    )
  );

-- ── plays ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "plays_delete" ON plays;
CREATE POLICY "plays_delete" ON plays FOR DELETE USING ((SELECT auth.uid()) = logged_by);

DROP POLICY IF EXISTS "plays_insert" ON plays;
CREATE POLICY "plays_insert" ON plays FOR INSERT WITH CHECK ((SELECT auth.uid()) = logged_by);

DROP POLICY IF EXISTS "plays_select" ON plays;
CREATE POLICY "plays_select" ON plays FOR SELECT USING (
  (SELECT auth.uid()) = logged_by
  OR (
    event_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM events
      WHERE events.id = plays.event_id
        AND (
          events.host_id = (SELECT auth.uid())
          OR EXISTS (
            SELECT 1 FROM invites
            WHERE invites.event_id = plays.event_id AND invites.user_id = (SELECT auth.uid())
          )
        )
    )
  )
  OR (
    group_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM groups
      WHERE groups.id = plays.group_id
        AND (
          groups.owner_id = (SELECT auth.uid())
          OR EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = plays.group_id
              AND group_members.user_id = (SELECT auth.uid())
          )
        )
    )
  )
);

-- FIX: added WITH CHECK (was missing)
DROP POLICY IF EXISTS "plays_update" ON plays;
CREATE POLICY "plays_update" ON plays FOR UPDATE
  USING ((SELECT auth.uid()) = logged_by)
  WITH CHECK ((SELECT auth.uid()) = logged_by);

-- ── push_tokens ───────────────────────────────────────────────
DROP POLICY IF EXISTS "push_tokens_delete" ON push_tokens;
CREATE POLICY "push_tokens_delete" ON push_tokens FOR DELETE USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "push_tokens_insert" ON push_tokens;
CREATE POLICY "push_tokens_insert" ON push_tokens FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "push_tokens_select" ON push_tokens;
CREATE POLICY "push_tokens_select" ON push_tokens FOR SELECT USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "push_tokens_update" ON push_tokens;
CREATE POLICY "push_tokens_update" ON push_tokens FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- ── saved_contacts ────────────────────────────────────────────
DROP POLICY IF EXISTS "saved_contacts_all" ON saved_contacts;
CREATE POLICY "saved_contacts_all" ON saved_contacts FOR ALL USING ((SELECT auth.uid()) = user_id);

-- ── time_option_votes ─────────────────────────────────────────
DROP POLICY IF EXISTS "votes_participant_all" ON time_option_votes;
CREATE POLICY "votes_participant_all" ON time_option_votes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM event_participants
      WHERE event_participants.id = time_option_votes.event_participant_id
        AND event_participants.user_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM event_participants
      WHERE event_participants.id = time_option_votes.event_participant_id
        AND event_participants.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS "votes_host_select" ON time_option_votes;
CREATE POLICY "votes_host_select" ON time_option_votes FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM event_participants
    WHERE event_participants.id = time_option_votes.event_participant_id
      AND event_participants.host_user_id = (SELECT auth.uid())
  )
);

-- ── time_options ──────────────────────────────────────────────
DROP POLICY IF EXISTS "time_options_delete" ON time_options;
CREATE POLICY "time_options_delete" ON time_options FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = time_options.event_id
      AND events.deleted_at IS NULL
      AND events.host_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS "time_options_insert" ON time_options;
CREATE POLICY "time_options_insert" ON time_options FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = time_options.event_id
      AND events.deleted_at IS NULL
      AND events.host_id = (SELECT auth.uid())
  )
  OR (
    EXISTS (
      SELECT 1
      FROM event_participants
      JOIN events ON events.id = event_participants.event_id
      WHERE event_participants.event_id = time_options.event_id
        AND event_participants.user_id = (SELECT auth.uid())
        AND events.deleted_at IS NULL
    )
    AND EXISTS (
      SELECT 1 FROM events
      WHERE events.id = time_options.event_id
        AND events.deleted_at IS NULL
        AND events.allow_time_suggestions = true
    )
  )
);

DROP POLICY IF EXISTS "time_options_select" ON time_options;
CREATE POLICY "time_options_select" ON time_options FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = time_options.event_id
      AND events.deleted_at IS NULL
      AND events.host_id = (SELECT auth.uid())
  )
  OR EXISTS (
    SELECT 1
    FROM event_participants
    JOIN events ON events.id = event_participants.event_id
    WHERE event_participants.event_id = time_options.event_id
      AND event_participants.user_id = (SELECT auth.uid())
      AND events.deleted_at IS NULL
  )
);

DROP POLICY IF EXISTS "time_options_update" ON time_options;
CREATE POLICY "time_options_update" ON time_options FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = time_options.event_id
        AND events.deleted_at IS NULL
        AND events.host_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = time_options.event_id
        AND events.deleted_at IS NULL
        AND events.host_id = (SELECT auth.uid())
    )
  );

-- ── users ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "users_insert" ON users;
CREATE POLICY "users_insert" ON users FOR INSERT WITH CHECK ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "users_select_others" ON users;
CREATE POLICY "users_select_others" ON users FOR SELECT USING (
  (SELECT auth.uid()) <> id
  AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocked_users.blocker_id = users.id
      AND blocked_users.blocked_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS "users_select_own" ON users;
CREATE POLICY "users_select_own" ON users FOR SELECT USING ((SELECT auth.uid()) = id);

-- FIX: added WITH CHECK (was missing)
DROP POLICY IF EXISTS "users_update" ON users;
CREATE POLICY "users_update" ON users FOR UPDATE
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- ── bgg_backfill_jobs: enable RLS (service-role access only) ──
ALTER TABLE bgg_backfill_jobs ENABLE ROW LEVEL SECURITY;
