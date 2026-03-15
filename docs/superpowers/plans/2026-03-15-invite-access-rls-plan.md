# Invite Access RLS Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the `events`/`invites` policy recursion by splitting authenticated access and RSVP state out of `invites`, while preserving public invite-token event viewing.

**Architecture:** Add an `event_participants` table as the authenticated access and RSVP boundary, denormalize `host_user_id` onto `invites`, migrate vote ownership away from `invite_id`, move public invite reads into an Edge Function, and move authenticated RSVP writes into a transactional RPC. Policies must form a one-way graph and never require `events` and `invites` to read each other.

**Tech Stack:** Supabase Postgres migrations, Row Level Security, Supabase Edge Functions (TypeScript), Swift client, static invite web page.

---

## Current Status

- Completed remotely:
  - applied Supabase migration `invite_access_refactor` (`20260315200721`)
  - deployed `get-public-invite`, `send-sms`, `send-invite`, `process-tiered-invites`, `r2-upload-url`, and `r2-delete`
  - resolved the `404` Edge Function failure by deploying the missing functions to the linked Supabase project
  - redeployed `send-invite` and `process-tiered-invites` as version `2` with internal host authorization and `verify_jwt: false`
  - redeployed `send-invite` as version `3` after removing the unnecessary `event_id` request validation that was producing `400`
- Completed locally:
  - added `Supabase/tests/invite_access_rls.sql`
  - added `Supabase/migrations/004_invite_access_refactor.sql`
  - updated the iOS app to call `respond_to_invite(...)`
  - updated the invite web page to use `get-public-invite`
  - updated protected iOS Edge Function invocations to send the current bearer token explicitly after diagnosing `401` responses from `send-invite`
  - refactored Edge Functions to share Twilio delivery code and removed nested `send-invite -> send-sms` and `process-tiered-invites -> send-invite/send-sms` dependencies
  - normalized manual and persisted invite phone numbers before SMS delivery
  - made invite delivery best-effort from the iOS create flow so a `502` from the SMS provider does not fail event creation after the rows are already inserted
  - `xcodebuild` succeeded
- Still pending:
  - run the pgTAP regression locally end-to-end
  - verify the public invite page end-to-end against the deployed `get-public-invite` function
  - verify from the running app that `send-invite` and the other protected Edge Functions now return `2xx`
  - commit the changes
  - run any remaining remote SQL spot-checks that were skipped after the Supabase MCP `execute_sql` call stalled

## Chunk 1: Schema and Policy Foundation

### Task 1: Add a migration-level regression harness

**Files:**
- Create: `Supabase/tests/invite_access_rls.sql`
- Modify: `Supabase/config.toml`

- [x] **Step 1: Write the failing regression script**

Create a SQL script that:
- seeds one host, one invited user, one event, one invite
- executes representative queries as host and guest
- documents the currently failing recursive path

- [ ] **Step 2: Run it to verify the current schema fails or is blocked by the old policy graph**

Run: `supabase db reset`
Expected: migration stack succeeds, but the regression script demonstrates that the old graph cannot support the desired access model without recursion-safe restructuring.

- [x] **Step 3: Wire the script into the local verification workflow**

Document the command used to execute the script after `db reset`.

- [ ] **Step 4: Re-run the script and capture the failing baseline**

Run: `supabase db reset && supabase db query < Supabase/tests/invite_access_rls.sql`
Expected: failure or missing-behavior output on the old schema.

### Task 2: Add the modular access schema

**Files:**
- Create: `Supabase/migrations/004_invite_access_refactor.sql`
- Test: `Supabase/tests/invite_access_rls.sql`

- [x] **Step 1: Extend the failing script for the new expected data model**

Add assertions for:
- events readable by host before invites exist
- invited authenticated users readable through `event_participants`
- invite host management without `events` recursion
- participant-owned time-option votes

- [ ] **Step 2: Run the script to confirm it still fails before implementation**

Run: `supabase db reset && supabase db query < Supabase/tests/invite_access_rls.sql`
Expected: fail because the new table/policies do not exist yet.

- [x] **Step 3: Write the additive migration**

Implement:
- `invites.host_user_id`
- `event_participants`
- `time_option_votes.event_participant_id`
- backfills
- indexes
- updated triggers where needed

- [x] **Step 4: Replace the recursive policies with one-way policies**

Implement new policies for:
- `events`
- `invites`
- `event_participants`
- `event_games`
- `time_options`
- `time_option_votes`

- [ ] **Step 5: Run the regression script**

Run: `supabase db reset && supabase db query < Supabase/tests/invite_access_rls.sql`
Expected: pass without recursion errors.

## Chunk 2: Edge Functions and Public Invite Flow

### Task 3: Move public invite reads behind an Edge Function

**Files:**
- Create: `Supabase/functions/get-public-invite/index.ts`
- Modify: `InviteWeb/public/index.html`

- [ ] **Step 1: Write the failing public-flow verification**

Document a request that should return:
- invite metadata
- event details
- time options
- no unauthorized RSVP write path

- [x] **Step 2: Verify the existing page still depends on direct PostgREST joins**

Inspect the current fetch path in `InviteWeb/public/index.html`.
Expected: direct query against `invites` with nested event joins.

- [x] **Step 3: Implement the public read function**

Return only the fields the page needs.

- [x] **Step 4: Update the invite page to call the function**

Replace the direct REST select with the Edge Function response.

- [ ] **Step 5: Verify the public page can still load invite details**

Run the local function workflow and confirm the page receives the expected payload.

### Task 4: Move RSVP writes into a dedicated workflow

**Files:**
- Modify: `Supabase/migrations/004_invite_access_refactor.sql`
- Modify: `Supabase/functions/process-tiered-invites/index.ts`
- Modify: `GameNight/GameNight/Services/SupabaseService.swift`

- [ ] **Step 1: Write the failing RSVP-path verification**

Assert that responding:
- links the authenticated user to the invite when phones match
- upserts `event_participants`
- writes votes through `event_participant_id`
- mirrors legacy invite fields during transition

- [ ] **Step 2: Run the verification and confirm the current code does not satisfy it**

Expected: current path updates only `invites`.

- [x] **Step 3: Implement `respond_to_invite(...)`**

Use a single transactional database workflow where possible.

- [x] **Step 4: Update app and function call sites**

Change the Swift client to invoke the workflow instead of writing directly to `invites`.

- [ ] **Step 5: Verify decline still triggers tier promotion**

Confirm `process-tiered-invites` reads the transitioned data correctly.

## Chunk 3: Client Reads and Compatibility

### Task 5: Update authenticated reads to the new access model

**Files:**
- Modify: `GameNight/GameNight/Services/SupabaseService.swift`
- Modify: `GameNight/GameNight/ViewModels/EventViewModel.swift`
- Modify: `GameNight/GameNight/Models/Invite.swift`

- [ ] **Step 1: Write the failing read-path verification**

Assert that:
- hosts can load events they created before inviting anyone
- invited users can load event details via participant access
- invite lists still render correctly for hosts

- [x] **Step 2: Confirm current reads are still nested under `invites`**

Expected: `fetchMyInvites()` uses `invites` plus nested `events`.

- [x] **Step 3: Implement minimal client read changes**

Read event access from the new participant boundary while preserving host invite management views.

- [x] **Step 4: Verify the client-side data contracts still decode**

Run project-appropriate build or focused tests.

## Chunk 4: Cleanup and Verification

### Task 6: Verify end-to-end behavior and document follow-up cleanup

**Files:**
- Modify: `docs/superpowers/specs/2026-03-15-invite-access-rls-design.md`

- [ ] **Step 1: Run full migration verification**

Run: `supabase db reset`
Expected: success on a clean local stack.

- [ ] **Step 2: Run the regression script**

Run: `supabase db query < Supabase/tests/invite_access_rls.sql`
Expected: pass.

- [x] **Step 3: Run focused app verification**

Run the smallest build or test command that exercises the modified Swift code.

- [x] **Step 4: Record any deferred cleanup**

Document whether legacy invite RSVP columns remain for a later migration.

- [ ] **Step 5: Commit**

```bash
git add Supabase/migrations/004_invite_access_refactor.sql Supabase/functions/get-public-invite/index.ts Supabase/tests/invite_access_rls.sql InviteWeb/public/index.html GameNight/GameNight/Services/SupabaseService.swift GameNight/GameNight/ViewModels/EventViewModel.swift GameNight/GameNight/Models/Invite.swift docs/superpowers/specs/2026-03-15-invite-access-rls-design.md docs/superpowers/plans/2026-03-15-invite-access-rls-plan.md
git commit -m "feat: split invite delivery from event access"
```
