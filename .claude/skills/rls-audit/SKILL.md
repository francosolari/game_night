     ---
name: rls-audit
description: Game Night–specific RLS audit. Checks recursion, unsafe policies, missing WITH CHECK, cross-table chains, and SECURITY DEFINER correctness across all app tables.
---

# Game Night — RLS Policy Audit

This skill audits the full RLS policy set for the Game Night Supabase backend. It is tuned to the
exact schema and failure patterns that have caused production incidents in this project.

## When to Run This Skill

- Before merging any migration that touches a table's RLS policies
- After adding a new table (verify policies exist + are correct)
- After adding a trigger function that writes to another table
- After any permission error reported from the iOS app or Supabase logs
- When a query returns 0 rows unexpectedly (silent RLS block)

---

## Step 0 — Get All Current Policies in One Shot

Run this first. Every check below builds on this output.

```sql
-- All RLS policies across app tables
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd;
```

Also run:

```sql
-- Confirm RLS is enabled on every table
SELECT
    relname AS table,
    relrowsecurity AS rls_enabled,
    relforcerowsecurity AS rls_forced
FROM pg_class
WHERE relnamespace = 'public'::regnamespace
  AND relkind = 'r'
ORDER BY relname;
```

---

## Step 1 — Check for Recursive Policy Patterns

This is the #1 cause of production incidents in this project. PostgreSQL will throw `ERROR 42P17`
or return a 502 from PostgREST when a policy on table A subqueries table B whose policy subqueries
table A.

### Known Recursion-Prone Chains in This Schema

| At-Risk Table | Policy Queries | Which Queries Back | Past Incident? |
|---|---|---|---|
| `conversation_participants` | `conversation_participants` (self) | — | ✅ Fixed via `is_conversation_member()` |
| `conversations` | `conversation_participants` | `conversation_participants` policy also queries `conversations` | ✅ Fixed |
| `direct_messages` | `conversation_participants` | same | ✅ Fixed |
| `group_members` | `groups` | `groups` policy could query `group_members` if carelessly written | Watch |
| `events` | `invites` | `invites` policy queries `events` | Watch |
| `invites` | `events` | `events` policy queries `invites` | Watch |
| `notifications` | `users` / `events` | those tables may query back | Watch |

### Recursion Detection Query

```sql
-- Find policies whose USING/WITH CHECK expression references their own table
SELECT
    p.tablename,
    p.policyname,
    p.cmd,
    p.qual,
    p.with_check
FROM pg_policies p
WHERE p.schemaname = 'public'
  AND (
      p.qual ILIKE '%' || p.tablename || '%'
      OR p.with_check ILIKE '%' || p.tablename || '%'
  );
```

### events ↔ invites Cross-Reference Test

Both tables reference each other. Verify the chain is unidirectional at the policy layer:

```sql
-- events SELECT policy should NOT also query invites in a way that triggers invites RLS
-- invites host policy queries events — events must NOT query invites in a subquery used by invites
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename IN ('events', 'invites') AND schemaname = 'public'
ORDER BY tablename, cmd;
```

**Pass condition:** `events` SELECT policy queries `invites`, but `invites` policies do NOT
subquery `events` in a way that itself triggers the `events` RLS check from `invites` context.
If `invites_host` queries `events.host_id = auth.uid()`, that single-row lookup is fine.

### group_members ↔ groups Cross-Reference Test

```sql
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename IN ('groups', 'group_members') AND schemaname = 'public'
ORDER BY tablename;
```

**Pass condition:** `group_members` policy uses `EXISTS (SELECT 1 FROM groups WHERE ...)`, which
is fine. Fails if `groups` policy also uses `EXISTS (SELECT 1 FROM group_members WHERE ...)` — that
creates mutual recursion.

---

## Step 2 — Check for Overly Permissive Policies

### USING (true) or WITH CHECK (true) on Sensitive Tables

```sql
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND (qual = 'true' OR with_check = 'true');
```

**Expected results** (these are intentional and acceptable):
- `games` SELECT: `USING (true)` — games are public read ✅
- `users` SELECT: `USING (true)` — public profiles ✅ (review if bio/phone should be masked)

**Fail conditions** (any row here is a P0):
- `notifications` with `USING (true)`
- `invites` with `USING (true)` or `WITH CHECK (true)`
- `events` with `USING (true)` on INSERT or UPDATE
- `direct_messages`, `conversations`, `conversation_participants` with `USING (true)`
- `plays`, `play_participants` with `USING (true)` on INSERT

### Missing WITH CHECK on INSERT/UPDATE Policies

```sql
-- Policies for INSERT or UPDATE that lack WITH CHECK
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND cmd IN ('INSERT', 'UPDATE', 'ALL')
  AND (with_check IS NULL OR with_check = '');
```

For `ALL` policies (like `library_all`), `qual` doubles as both USING and WITH CHECK, which is
correct. Flag any INSERT-only or UPDATE-only policy missing `with_check`.

---

## Step 3 — Verify Cross-Table Access Chains Work Correctly

The app's most complex RLS patterns are chains: a user can see `event_games` only if they can see
the parent `event`. Test each chain with actual SQL.

### event_games & time_options Must Follow events

```sql
-- Simulate: does an invited user see event_games for their event?
-- Replace [invited_user_id] and [event_id] with real values from invites table
SELECT eg.*
FROM event_games eg
WHERE eg.event_id = '[event_id]'::uuid;
-- Must return rows when run as the invited user, nothing when run as unrelated user
```

### invites: invited user can see but NOT modify other fields

```sql
-- invites_respond allows UPDATE but only own invite
-- Verify WITH CHECK exists and matches USING
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'invites' AND schemaname = 'public' AND cmd IN ('UPDATE', 'ALL');
```

**Pass condition:** UPDATE policy has both `USING (auth.uid() = user_id)` AND `WITH CHECK (auth.uid() = user_id)`.

### plays & play_participants Visibility

```sql
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename IN ('plays', 'play_participants') AND schemaname = 'public';
```

**Check:** Can a group member see plays logged for their group? Can they see plays for events
they were invited to? Confirm policies cover both `group_id` and `event_id` access paths.

### groups SELECT Must Include Members, Not Just Owner

```sql
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'groups' AND schemaname = 'public' AND cmd IN ('SELECT', 'ALL');
```

**Known risk:** Original `groups_select` policy only allowed `owner_id = auth.uid()`. Members added
to a group via `group_members` could not see the group. Confirm this has been expanded to:
```sql
USING (
    auth.uid() = owner_id
    OR EXISTS (SELECT 1 FROM group_members WHERE group_id = groups.id AND user_id = auth.uid())
)
```

If the `group_members` subquery is in `groups` AND `groups` subquery is in `group_members` →
**immediate recursion risk**. Use a `SECURITY DEFINER` helper function instead (same pattern as
`is_conversation_member`).

---

## Step 4 — Verify SECURITY DEFINER Functions Are Safe

SECURITY DEFINER bypasses RLS. Every such function must be audited for:
1. Auth check at the top (`auth.uid() IS NOT NULL` or parameter validation)
2. `SET search_path = public` to prevent search_path injection
3. No unvalidated user input used in dynamic SQL
4. REVOKE execute from `public`, `anon` where client callers should not directly invoke

```sql
-- List all SECURITY DEFINER functions in public schema
SELECT
    p.proname AS function_name,
    pg_get_function_arguments(p.oid) AS args,
    p.prosecdef AS security_definer,
    p.proconfig AS config  -- should contain search_path=public
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef = true
ORDER BY p.proname;
```

### Verify Trigger Functions Are REVOKED from Direct Call

```sql
-- Check execute privileges on SECURITY DEFINER functions
SELECT
    r.routine_name,
    grantee,
    privilege_type
FROM information_schema.routine_privileges r
WHERE r.routine_schema = 'public'
  AND grantee IN ('public', 'anon', 'authenticated')
ORDER BY r.routine_name, grantee;
```

**Functions that should NOT be callable by `anon` or `public`** (trigger-only):
- `notify_invite_received`
- `notify_rsvp_update`
- `notify_bench_promoted`
- `notify_dm_received`
- `notify_group_member_added`
- `update_conversation_last_message`
- `create_invite_dm`
- `process_pending_invite_dms`
- `handle_new_user`
- `update_vote_count`

**Functions that SHOULD be callable by `authenticated`** (RPC functions):
- `is_conversation_member` — authenticated only
- `get_or_create_dm` — authenticated only
- `search_games_fuzzy` — check it doesn't leak games without auth

---

## Step 5 — Test Silent Blocking (Common App Bugs)

These are the queries that have returned empty results in the iOS app due to RLS silently blocking.

### Event Feed Is Empty for Invited User

```sql
-- Run as authenticated invited user
SELECT e.* FROM events e
WHERE e.id IN (SELECT event_id FROM invites WHERE user_id = auth.uid());
-- Must return events. If empty: events SELECT policy is blocking invited user.
```

### Notifications Inbox Missing Items

```sql
-- Run as authenticated user
SELECT * FROM notifications WHERE user_id = auth.uid() ORDER BY created_at DESC LIMIT 10;
-- Must return rows if any exist. If empty with rows in DB: RLS or index issue.
```

### Group Members Missing for Non-Owner

```sql
-- If a user is a member of a group but not the owner, can they see the group?
SELECT g.* FROM groups g
WHERE EXISTS (
    SELECT 1 FROM group_members gm WHERE gm.group_id = g.id AND gm.user_id = auth.uid()
);
-- Must return groups where the user is a member.
```

### DM Conversation Invisible After Invite

```sql
-- After being invited, user should see the DM conversation
SELECT c.* FROM conversations c WHERE is_conversation_member(c.id) = true;
-- Must return conversations. If empty: check conversation_participants INSERT policy.
```

---

## Step 6 — Check for Missing Table Coverage

Every table must have RLS enabled and at least one SELECT policy.

```sql
-- Tables with RLS enabled but ZERO policies
SELECT c.relname AS table
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_policies p ON p.tablename = c.relname AND p.schemaname = n.nspname
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relrowsecurity = true
  AND p.policyname IS NULL;
```

```sql
-- Tables with RLS DISABLED (should be empty for app tables)
SELECT relname
FROM pg_class
WHERE relnamespace = 'public'::regnamespace
  AND relkind = 'r'
  AND relrowsecurity = false;
```

**Expected tables without RLS** (system or controlled via service role only): none for this app.
All public schema tables must have RLS enabled.

---

## Step 7 — Validate New Migration Before Applying

Before applying any migration that modifies RLS policies, answer these questions:

1. **Does this policy query another table?**
   - If yes: does that table's policy query back? Draw the dependency graph.
   - If mutual: extract the lookup into a `SECURITY DEFINER` helper function (like `is_conversation_member`).

2. **Is this a trigger function inserting into another user's rows?**
   - Must be `SECURITY DEFINER` + `SET search_path = public`
   - Must have `REVOKE execute ... FROM public, anon`
   - Must validate `auth.uid()` or a parameter before touching data

3. **Does this policy allow INSERT/UPDATE without `WITH CHECK`?**
   - Any INSERT or UPDATE policy without `WITH CHECK` matching USING is a bug.

4. **Does this disable an existing INSERT policy in favor of SECURITY DEFINER triggers?**
   - Confirm the trigger actually fires and covers all code paths (direct API calls + edge functions).

5. **Will this policy block the iOS app from reading data it previously could read?**
   - Check what the app queries in `SupabaseService.swift` for the affected table before deploying.

---

## Severity Reference

| Severity | Condition |
|---|---|
| P0 — Deploy blocker | RLS disabled on any table; `USING (true)` on `invites`, `notifications`, `direct_messages` |
| P0 — Deploy blocker | Recursive policy (will 502 in production) |
| P1 — Fix before next release | INSERT/UPDATE policy missing `WITH CHECK` |
| P1 — Fix before next release | Trigger function not SECURITY DEFINER inserting for other users |
| P1 — Fix before next release | SECURITY DEFINER function missing `SET search_path` |
| P2 — Address in sprint | Missing operation coverage (e.g., SELECT policy but no INSERT for user-owned table) |
| P2 — Address in sprint | Group members can't see their own group (owner-only SELECT policy) |
| P3 — Track | Overly broad `auth.uid() IS NOT NULL` guards on game data tables |

---

## Quick Checklist (Pre-Merge Gate)

Copy this into a PR comment or run through it manually:

- [ ] `pg_policies` shows at least one policy per affected table
- [ ] No `USING (true)` or `WITH CHECK (true)` on invites / events / notifications / direct_messages
- [ ] No policy on table A that subqueries table B whose policy subqueries back to A
- [ ] All trigger functions writing to other users' rows are `SECURITY DEFINER` + `SET search_path = public`
- [ ] All trigger functions have `REVOKE execute` from `public, anon`
- [ ] All INSERT/UPDATE client-facing policies have `WITH CHECK` matching USING
- [ ] iOS app queries for the affected table still return data after migration (run simulator test)
