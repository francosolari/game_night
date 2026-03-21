-- Fix infinite recursion in conversation-related RLS policies.
--
-- Problem: conv_participants_select subqueries conversation_participants
-- within its own USING clause, causing PostgreSQL error 42P17.
-- The conversations_select, dm_select, and dm_insert policies also
-- subquery conversation_participants, hitting the same recursive policy.
--
-- Fix: A minimal SECURITY DEFINER helper function that checks membership
-- without triggering RLS, then replace all 4 policies to use it.

-- ============================================================
-- 1. MEMBERSHIP CHECK FUNCTION (SECURITY DEFINER)
-- ============================================================

create or replace function is_conversation_member(p_conversation_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
    select exists(
        select 1
        from conversation_participants
        where conversation_id = p_conversation_id
          and user_id = auth.uid()
    );
$$;

-- Only authenticated users should call this (via RLS policy evaluation)
revoke execute on function is_conversation_member(uuid) from public, anon;
grant execute on function is_conversation_member(uuid) to authenticated;

-- ============================================================
-- 2. REPLACE RECURSIVE POLICIES
-- ============================================================

-- conversation_participants: was self-referential → now uses helper
drop policy if exists conv_participants_select on conversation_participants;
create policy conv_participants_select on conversation_participants for select
    using (is_conversation_member(conversation_id));

-- conversations: subqueried conversation_participants → now uses helper
drop policy if exists conversations_select on conversations;
create policy conversations_select on conversations for select
    using (is_conversation_member(id));

-- direct_messages SELECT: subqueried conversation_participants → now uses helper
drop policy if exists dm_select on direct_messages;
create policy dm_select on direct_messages for select
    using (is_conversation_member(conversation_id));

-- direct_messages INSERT: subqueried conversation_participants → now uses helper
drop policy if exists dm_insert on direct_messages;
create policy dm_insert on direct_messages for insert
    with check (
        sender_id = auth.uid()
        and is_conversation_member(conversation_id)
    );

-- ============================================================
-- 3. MAKE get_or_create_dm SECURITY DEFINER
--    It INSERTs into conversations and conversation_participants which have
--    no client INSERT policies (correctly). It already validates auth.uid().
-- ============================================================

create or replace function get_or_create_dm(p_other_user_id uuid)
returns uuid
language plpgsql
security definer
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
