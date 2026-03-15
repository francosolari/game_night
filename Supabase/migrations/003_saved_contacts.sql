-- ============================================================
-- SAVED CONTACTS (user's personal contact book within the app)
-- ============================================================
CREATE TABLE saved_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    avatar_url TEXT,
    is_app_user BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, phone_number)
);

CREATE INDEX idx_saved_contacts_user ON saved_contacts(user_id);

-- RLS
ALTER TABLE saved_contacts ENABLE ROW LEVEL SECURITY;
CREATE POLICY saved_contacts_all ON saved_contacts FOR ALL USING (auth.uid() = user_id);
