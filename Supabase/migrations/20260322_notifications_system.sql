-- Notification system: persistent notifications, preferences, and push tokens

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

create table notifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    type text not null check (type in (
        'invite_received', 'rsvp_update', 'group_invite',
        'time_confirmed', 'bench_promoted', 'dm_received',
        'text_blast', 'game_confirmed', 'event_cancelled'
    )),
    title text not null,
    body text,
    metadata jsonb default '{}'::jsonb,
    event_id uuid references events(id) on delete set null,
    invite_id uuid references invites(id) on delete set null,
    group_id uuid references groups(id) on delete set null,
    conversation_id uuid,  -- FK added after conversations table exists
    read_at timestamptz,
    created_at timestamptz not null default now()
);

create index idx_notifications_user_unread
    on notifications(user_id, created_at desc)
    where read_at is null;

create index idx_notifications_user_created
    on notifications(user_id, created_at desc);

-- ============================================================
-- NOTIFICATION PREFERENCES
-- ============================================================

create table notification_preferences (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references users(id) on delete cascade,
    invites_enabled boolean not null default true,
    text_blasts_enabled boolean not null default true,
    dms_enabled boolean not null default true,
    rsvp_updates_enabled boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- ============================================================
-- PUSH TOKENS
-- ============================================================

create table push_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    device_token text not null,
    platform text not null default 'ios' check (platform in ('ios', 'android')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique(user_id, device_token)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table notifications enable row level security;

create policy notifications_select on notifications for select
    using (auth.uid() = user_id);

create policy notifications_update on notifications for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- Trigger functions are SECURITY DEFINER (see rls_security_hardening migration)
-- so they bypass RLS when inserting notifications for other users.
-- No INSERT policy needed — client-side inserts are intentionally blocked.

alter table notification_preferences enable row level security;

create policy notification_preferences_select on notification_preferences for select
    using (auth.uid() = user_id);

create policy notification_preferences_insert on notification_preferences for insert
    with check (auth.uid() = user_id);

create policy notification_preferences_update on notification_preferences for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

alter table push_tokens enable row level security;

create policy push_tokens_select on push_tokens for select
    using (auth.uid() = user_id);

create policy push_tokens_insert on push_tokens for insert
    with check (auth.uid() = user_id);

create policy push_tokens_update on push_tokens for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy push_tokens_delete on push_tokens for delete
    using (auth.uid() = user_id);
