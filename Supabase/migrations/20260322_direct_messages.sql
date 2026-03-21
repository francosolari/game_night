-- Direct messaging: conversations, participants, and messages

-- ============================================================
-- CONVERSATIONS
-- ============================================================

create table conversations (
    id uuid primary key default gen_random_uuid(),
    last_message_at timestamptz,
    created_at timestamptz not null default now()
);

create table conversation_participants (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid not null references conversations(id) on delete cascade,
    user_id uuid not null references users(id) on delete cascade,
    joined_at timestamptz not null default now(),
    unique(conversation_id, user_id)
);

create index idx_conv_participants_user on conversation_participants(user_id);
create index idx_conv_participants_conv on conversation_participants(conversation_id);

create table direct_messages (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid not null references conversations(id) on delete cascade,
    sender_id uuid not null references users(id) on delete cascade,
    content text,
    message_type text not null default 'text' check (message_type in ('text', 'invite', 'system')),
    metadata jsonb default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index idx_dm_conversation on direct_messages(conversation_id, created_at desc);
create index idx_dm_sender on direct_messages(sender_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table conversations enable row level security;

create policy conversations_select on conversations for select
    using (
        id in (
            select conversation_id
            from conversation_participants
            where user_id = auth.uid()
        )
    );

-- Trigger functions are SECURITY DEFINER (see rls_security_hardening migration)
-- so they bypass RLS when creating conversations. No client INSERT policy needed.

alter table conversation_participants enable row level security;

create policy conv_participants_select on conversation_participants for select
    using (
        conversation_id in (
            select conversation_id
            from conversation_participants cp
            where cp.user_id = auth.uid()
        )
    );

-- Trigger functions are SECURITY DEFINER (see rls_security_hardening migration)
-- so they bypass RLS when adding participants. No client INSERT policy needed.

alter table direct_messages enable row level security;

create policy dm_select on direct_messages for select
    using (
        conversation_id in (
            select conversation_id
            from conversation_participants
            where user_id = auth.uid()
        )
    );

create policy dm_insert on direct_messages for insert
    with check (
        sender_id = auth.uid()
        and conversation_id in (
            select conversation_id
            from conversation_participants
            where user_id = auth.uid()
        )
    );

-- Trigger functions are SECURITY DEFINER (see rls_security_hardening migration)
-- so they bypass RLS for system/invite messages. No permissive INSERT override needed.

-- ============================================================
-- UPDATE CONVERSATIONS.LAST_MESSAGE_AT ON MESSAGE INSERT
-- ============================================================

create or replace function update_conversation_last_message()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    update conversations
    set last_message_at = new.created_at
    where id = new.conversation_id;
    return new;
end;
$$;

create trigger trg_update_conversation_last_message
    after insert on direct_messages
    for each row
    execute function update_conversation_last_message();

-- ============================================================
-- RPC: GET OR CREATE 1:1 DM CONVERSATION
-- ============================================================

create or replace function get_or_create_dm(p_other_user_id uuid)
returns uuid
language plpgsql
set search_path = public
as $$
declare
    v_conversation_id uuid;
    v_caller_id uuid := auth.uid();
begin
    if v_caller_id is null then
        raise exception 'Authentication required';
    end if;

    if v_caller_id = p_other_user_id then
        raise exception 'Cannot create conversation with yourself';
    end if;

    -- Find existing 1:1 conversation between these two users
    select cp1.conversation_id into v_conversation_id
    from conversation_participants cp1
    join conversation_participants cp2
        on cp1.conversation_id = cp2.conversation_id
    where cp1.user_id = v_caller_id
      and cp2.user_id = p_other_user_id
      and (
          select count(*)
          from conversation_participants
          where conversation_id = cp1.conversation_id
      ) = 2
    limit 1;

    if v_conversation_id is not null then
        return v_conversation_id;
    end if;

    -- Create new conversation
    insert into conversations default values
    returning id into v_conversation_id;

    insert into conversation_participants (conversation_id, user_id) values
        (v_conversation_id, v_caller_id),
        (v_conversation_id, p_other_user_id);

    return v_conversation_id;
end;
$$;

grant execute on function get_or_create_dm(uuid) to authenticated;

-- ============================================================
-- RPC: FETCH CONVERSATIONS FOR USER
-- ============================================================

create or replace function fetch_conversations_for_user()
returns table (
    conversation_id uuid,
    last_message_at timestamptz,
    other_user_id uuid,
    other_display_name text,
    other_avatar_url text,
    last_message_content text,
    last_message_type text,
    last_message_sender_id uuid,
    last_message_created_at timestamptz,
    unread_count bigint
)
language sql
stable
set search_path = public
as $$
    select
        c.id as conversation_id,
        c.last_message_at,
        other_cp.user_id as other_user_id,
        other_u.display_name as other_display_name,
        other_u.avatar_url as other_avatar_url,
        last_msg.content as last_message_content,
        last_msg.message_type as last_message_type,
        last_msg.sender_id as last_message_sender_id,
        last_msg.created_at as last_message_created_at,
        coalesce(unread.cnt, 0) as unread_count
    from conversations c
    join conversation_participants my_cp
        on my_cp.conversation_id = c.id
        and my_cp.user_id = auth.uid()
    join conversation_participants other_cp
        on other_cp.conversation_id = c.id
        and other_cp.user_id != auth.uid()
    join users other_u
        on other_u.id = other_cp.user_id
    left join lateral (
        select dm.content, dm.message_type, dm.sender_id, dm.created_at
        from direct_messages dm
        where dm.conversation_id = c.id
        order by dm.created_at desc
        limit 1
    ) last_msg on true
    left join lateral (
        select count(*) as cnt
        from direct_messages dm
        where dm.conversation_id = c.id
          and dm.sender_id != auth.uid()
          and dm.created_at > coalesce(my_cp.joined_at, '1970-01-01'::timestamptz)
          -- We track "read" by comparing against a read_cursor; for MVP we use joined_at
    ) unread on true
    where c.last_message_at is not null
    order by c.last_message_at desc nulls last;
$$;

grant execute on function fetch_conversations_for_user() to authenticated;

-- Add conversation_id FK on notifications now that conversations table exists
alter table notifications
    add constraint fk_notifications_conversation
    foreign key (conversation_id) references conversations(id) on delete set null;
