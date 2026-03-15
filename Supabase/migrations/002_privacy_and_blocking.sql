-- Migration 002: Privacy settings and blocking system
-- Implements Partiful-level privacy guarantees

-- ============================================================
-- Add privacy columns to users
-- ============================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_visible BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS discoverable_by_phone BOOLEAN DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS marketing_opt_in BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS contacts_synced BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS privacy_accepted_at TIMESTAMPTZ;

-- IMPORTANT: phone_visible defaults to FALSE
-- Users must explicitly opt in to show their phone number.
-- By default, other users see display names only.

-- ============================================================
-- BLOCKED USERS
-- ============================================================
CREATE TABLE IF NOT EXISTS blocked_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID REFERENCES users(id) ON DELETE CASCADE,
    blocked_phone TEXT,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- Prevent duplicate blocks
    UNIQUE(blocker_id, blocked_id),
    -- At least one of blocked_id or blocked_phone must be set
    CONSTRAINT block_target CHECK (blocked_id IS NOT NULL OR blocked_phone IS NOT NULL)
);

CREATE INDEX idx_blocked_blocker ON blocked_users(blocker_id);
CREATE INDEX idx_blocked_blocked ON blocked_users(blocked_id);
CREATE INDEX idx_blocked_phone ON blocked_users(blocked_phone);

ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

-- Users can only manage their own blocks
CREATE POLICY blocked_users_own ON blocked_users FOR ALL
    USING (auth.uid() = blocker_id);

-- ============================================================
-- CONSENT LOG (audit trail for privacy compliance)
-- ============================================================
CREATE TABLE IF NOT EXISTS consent_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    consent_type TEXT NOT NULL
        CHECK (consent_type IN ('privacy_policy', 'terms_of_service', 'marketing', 'contacts_access', 'sms_notifications')),
    granted BOOLEAN NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_consent_user ON consent_log(user_id);

ALTER TABLE consent_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY consent_log_own ON consent_log FOR ALL
    USING (auth.uid() = user_id);

-- ============================================================
-- Update user select policy to respect privacy
-- Users with phone_visible=false should not expose their phone
-- to other users (only to themselves)
-- ============================================================

-- Drop old permissive policy
DROP POLICY IF EXISTS users_select ON users;

-- New policy: see all users but phone is filtered in application layer.
-- For extra safety, create a view that masks phone numbers:
CREATE OR REPLACE VIEW users_public AS
SELECT
    id,
    display_name,
    avatar_url,
    bio,
    bgg_username,
    CASE WHEN phone_visible THEN phone_number ELSE NULL END AS phone_number,
    created_at
FROM users;

-- Re-create select policy (full access for own record, limited for others)
CREATE POLICY users_select_own ON users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY users_select_others ON users FOR SELECT
    USING (
        auth.uid() != id
        -- Cannot see users who blocked you
        AND NOT EXISTS (
            SELECT 1 FROM blocked_users
            WHERE blocked_users.blocker_id = users.id
            AND (blocked_users.blocked_id = auth.uid())
        )
    );

-- ============================================================
-- Update invites to respect blocking
-- Blocked users cannot receive invites from the blocker
-- ============================================================

-- Add a check: when inserting invites, skip blocked users
CREATE OR REPLACE FUNCTION check_invite_blocked()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the invitee has blocked the host
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_invite_blocked
    BEFORE INSERT ON invites
    FOR EACH ROW EXECUTE FUNCTION check_invite_blocked();

-- ============================================================
-- Update handle_new_user to set privacy defaults
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO users (
        id, phone_number, display_name,
        phone_visible, discoverable_by_phone,
        marketing_opt_in, contacts_synced
    )
    VALUES (
        NEW.id,
        NEW.phone,
        COALESCE(NEW.raw_user_meta_data->>'display_name', 'Player'),
        FALSE,   -- phone hidden by default
        TRUE,    -- discoverable by phone (so friends can find you)
        FALSE,   -- no marketing by default
        FALSE    -- contacts not synced
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- DATA DELETION support
-- When a user deletes their account, cascade everything
-- ============================================================
-- Already handled by ON DELETE CASCADE on all FKs
-- But add a function for soft-delete / anonymization option:

CREATE OR REPLACE FUNCTION anonymize_user(target_user_id UUID)
RETURNS VOID AS $$
BEGIN
    -- Anonymize user data instead of hard delete
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

    -- Remove from all groups
    DELETE FROM group_members WHERE user_id = target_user_id;

    -- Anonymize invite display names
    UPDATE invites SET display_name = 'Deleted User'
    WHERE user_id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
