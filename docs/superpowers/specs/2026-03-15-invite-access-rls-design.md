# Invite Access RLS Redesign

**Implementation Status (2026-03-15)**

- Applied remotely as Supabase migration `invite_access_refactor` (`20260315200721`)
- Deployed Edge Functions: `get-public-invite`, `send-sms`, `send-invite`, `process-tiered-invites`, `r2-upload-url`, `r2-delete`
- Resolved the production `404` on Edge Function calls by deploying the missing functions to the linked project
- Implemented authenticated RSVP via `respond_to_invite(...)` RPC in the database and updated the iOS client to use it
- Identified the later `401` on `send-invite` as a client invocation auth issue and updated the iOS client to send the current bearer token explicitly on protected Edge Function calls
- Redesigned `send-invite` and `process-tiered-invites` to perform host authorization inside the function body and removed their nested function-call dependency on `send-sms`
- Redeployed `send-invite` and `process-tiered-invites` as version `2` with `verify_jwt: false`, while keeping `send-sms` on `verify_jwt: true`
- Removed the unnecessary `event_id` request contract from `send-invite` and redeployed it as version `3` so invite delivery resolves the event exclusively from the invite row
- Normalized invite phone numbers in both the iOS create flow and the Edge Function SMS path, and changed the iOS invite-send step to be best-effort so SMS provider failures do not roll back a successfully created event
- Verified iOS compile path with `xcodebuild`
- Not yet verified with the local pgTAP regression harness end-to-end
- Additional remote SQL spot-checks may still be useful because a later Supabase MCP `execute_sql` call stalled
- Still pending live confirmation from the app that protected Edge Function calls now return `2xx`

**Problem**

The current RLS graph creates a circular dependency:

- `events_select` checks whether the current user has a matching row in `invites`
- `invites_host` checks whether the current user owns the parent `events` row

That makes policy evaluation recurse when Postgres needs to resolve visibility between `events` and `invites`.

**Goal**

Remove the circular dependency without using `SECURITY DEFINER` as the primary fix, and make the data model modular enough that:

- events can exist before any invite exists
- authenticated invitees can immediately read the event and time options
- public invite-token flows can reveal event details without granting RSVP rights
- RSVP state no longer lives on the delivery record

**Architecture**

Split invitation delivery from authenticated event access:

- `invites` remains the delivery artifact
- `event_participants` becomes the authenticated access and RSVP source of truth
- public invite-token reads move behind an Edge Function instead of anonymous PostgREST joins
- authenticated RSVP writes move through a transactional RPC instead of direct table patches

This creates a one-way policy graph:

- `events` depends on `event_participants`
- `event_games` and `time_options` depend on `events` and `event_participants`
- `invites` depends on `host_user_id`, not `events`

**Data Model**

`invites`

- Keep: `id`, `event_id`, `user_id`, `phone_number`, `display_name`, `tier`, `tier_position`, `is_active`, `sent_via`, `sms_delivery_status`, `invite_token`, `created_at`
- Add: `host_user_id`
- Keep `status`, `responded_at`, and `selected_time_option_ids` only as legacy compatibility fields during migration

`event_participants`

- `id UUID PRIMARY KEY`
- `event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE`
- `user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE`
- `source_invite_id UUID REFERENCES invites(id) ON DELETE SET NULL`
- `role TEXT NOT NULL DEFAULT 'guest' CHECK (role IN ('host', 'guest'))`
- `rsvp_status TEXT NOT NULL DEFAULT 'pending' CHECK (rsvp_status IN ('pending', 'accepted', 'declined', 'maybe'))`
- `responded_at TIMESTAMPTZ`
- `phone_number_snapshot TEXT`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
- unique `(event_id, user_id)`

`time_option_votes`

- Replace `invite_id` ownership with `event_participant_id`
- Uniqueness becomes `(time_option_id, event_participant_id)`

**Policy Design**

`events`

- host can always read/manage
- authenticated guest can read when a matching `event_participants` row exists
- no policy on `events` reads `invites`

`invites`

- host manage policy uses `host_user_id = auth.uid()`
- invited authenticated user can read only their own invite by `user_id = auth.uid()`
- no policy on `invites` reads `events`

`event_participants`

- host can create/read/update/delete guest rows for their own events
- guest can read and update only their own row

`event_games`

- readable by host or authenticated participant
- manageable by host only

`time_options`

- readable by host or authenticated participant
- insertable by host
- insertable by participant only if `events.allow_time_suggestions = true`

`time_option_votes`

- readable/writable by the owning participant row

**Public Invite Flow**

The current invite page queried `invites -> events -> time_options` directly through PostgREST with the publishable key. The implementation replaces that with:

- `get-public-invite` Edge Function for token-based read access
- `respond_to_invite(...)` authenticated RPC for phone/auth-backed RSVP workflows

`get-public-invite`

- input: `invite_token`
- validates invite token
- returns minimal event payload for rendering the page
- does not require authentication

`respond_to_invite(...)`

- authenticated RPC
- verifies the caller phone matches the invite phone number
- links `invites.user_id` if not already linked
- upserts `event_participants`
- writes RSVP status and time-option votes
- mirrors legacy invite fields during transition
- leaves tier-promotion triggering as a follow-on workflow after decline

**Migration Strategy**

1. Add `host_user_id` to `invites` and backfill from `events.host_id`
2. Create `event_participants`
3. Backfill participant rows for:
   - all event hosts
   - all authenticated invites (`invites.user_id IS NOT NULL`)
4. Add `event_participant_id` to `time_option_votes` and backfill from invite-linked users
5. Add new RLS policies
6. Update client and Edge Functions to use `event_participants` for authenticated access and RSVP
7. Remove `events -> invites` and other invite-based visibility checks
8. Drop legacy `invite_id` from votes after code has cut over
9. Keep legacy invite RSVP fields only until rollout is stable, then remove them in a later migration

**Rollout Considerations**

- The migration should be additive first, destructive later
- Backfills must run before the old policies are removed
- Host rows in `event_participants` simplify access checks and reporting
- Public invite reads should expose only the fields needed for invite rendering

**Verification**

- apply migrations on a clean local Supabase instance
- verify host can create/read events before invites exist
- verify invited authenticated user can read event, event games, and time options
- verify host can manage invites without recursive policy errors
- verify public token flow can read event data but cannot RSVP without authenticated phone-backed user
- verify RSVP writes update `event_participants` and votes, not just `invites`
