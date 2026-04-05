# Supabase unhealthy investigation (iOS) - 2026-04-04

## Scope
- User reports backend unhealthy/crashing behavior from iOS clients.
- Prior hypothesis: JWT issues for new user.
- Current goal: systematically eliminate causes and identify root issue from logs and schema.

## What I did
1. Pulled fresh Supabase logs for `api`, `auth`, `postgres`, and `edge-function`.
2. Correlated iOS request failures (user-agent `CWM/...`) with DB timestamps.
3. Mapped failing endpoints to concrete iOS query paths in `SupabaseService.swift`.

## Evidence
- API logs show iOS `500` responses on:
  - `/rest/v1/events`
  - `/rest/v1/invites`
  - `/rest/v1/plays`
  - `/rest/v1/game_wishlist`
- Postgres logs at same window show repeated:
  - `ERROR: canceling statement due to statement timeout`
- Auth logs show malformed JWT events mostly from `referer: http://localhost:3000` (web/admin traffic), not a clean match to iOS-only failures.
- Edge logs:
  - `beta-ensure-user` mostly `200` with some expected `401` when auth/secret invalid.
  - `send-invite` has intermittent `502` (separate path).

## Hypotheses and status
- H1: JWT for new beta user is primary root cause.
  - Status: **deprioritized**.
  - Reason: existing users reproduce unhealthy behavior; iOS failures are endpoint `500` with concurrent Postgres statement timeouts.
- H2: Edge function auth failure is primary root cause.
  - Status: **deprioritized**.
  - Reason: failing endpoints are PostgREST table reads (`events/invites/plays/game_wishlist`) not edge-only.
- H3: DB query performance / RLS path causes statement timeouts leading to 500.
  - Status: **active lead**.
  - Reason: strongest log correlation so far.

## Next eliminations in progress
1. Verify whether required indexes exist for RLS-heavy joins used by:
   - `events_select`, `invites_*`, `time_options_select`, `event_games_select`, `plays` access
2. Inspect current policies for repeated nested `exists` scans.
3. Run targeted SQL plan checks and identify worst offenders.
4. Apply minimal migration(s) for missing indexes / policy-safe optimization.
5. Re-check logs after change.

## Notes
- Tracking this file as live issue log; will append findings and decisions as investigation continues.

## Additional elimination findings
- Table cardinality for affected tables is low (`events=50`, `invites=79`, `plays=12`, `game_wishlist=3`), so deterministic full-table slowness is unlikely as primary cause.
- Direct `EXPLAIN (ANALYZE)` checks (with authenticated JWT claims applied) show the failing query shapes complete quickly when isolated (milliseconds), which supports contention/spike behavior rather than a single always-slow query.
- `pg_stat_statements` shows substantial unrelated heavy workload in this DB (e.g. `backfill_publisher_creators`, `bgg_backfill_step`, and very high-volume `realtime.list_changes`), which can coincide with statement-timeout windows.

## Fixes applied this pass
1. iOS pressure reduction
   - Removed duplicate housekeeping RPC trigger in Home view model (`complete_past_events`) because AppState preload already runs it.
   - Removed duplicate `expire_stale_group_invites` call from Home refresh path; Home refresh now only reads pending group invites.
2. DB hot-path index hardening
   - Added and applied migration: `20260404214500_reduce_rls_hotpath_contention_indexes.sql`
   - Created indexes:
     - `idx_invites_event_user` on `invites(event_id, user_id)`
     - `idx_group_members_group_user_active` on `group_members(group_id, user_id)` with status/user partial filter

## Current conclusion
- Root issue is not "bad JWT for one new user".
- Primary pattern is transient DB pressure/timeout windows that surface as iOS `500` on nested PostgREST reads.
- JWT malformed events observed in auth logs are mostly web/admin-origin traffic and are not the main driver of these iOS failures.

## Stress script run (2026-04-04 23:00 UTC)
- Script: `socs/issues/stress_supabase_ios.sh`
- Mode: `mixed`
- Rounds: `20`
- Parallel: `6`
- Result log: `socs/issues/results/stress-20260404-190050.log`
- Outcome: all endpoint calls returned `401`.
- Interpretation: supplied bearer value was not a valid user access JWT for PostgREST RLS requests.

## Simulator forensics (iPhone 17 Pro signed-in)
- Located app container for `com.cardboardwithme.app`.
- Verified active signed-in user ID from cached auth payloads: `87257b34-56c6-4722-b160-6bd79ff31e22`.
- Extracted cached `/auth/v1/token` responses from simulator `Cache.db`:
  - includes historical `access_token` + `refresh_token`.
  - cached refresh token was already rotated (`Invalid Refresh Token: Already Used`) so cannot mint a fresh token from cache snapshot alone.
- Confirmed this means keychain/session token in active runtime is newer than cached auth payload.

## New API-log correlation (existing user repro)
- Existing user `1652326c-1d56-4d1e-8453-354e55262c5f` showed clustered `500`s across:
  - `events`, `invites`, `plays`, `complete_past_events`, `confirm_time_option`.
- Immediately before this burst, same endpoints were returning `200`.
- Nearby auth refresh calls for the app succeed (`POST /auth/v1/token?grant_type=refresh_token -> 200`), so this repro is not an auth-refresh failure.
- This strongly supports transient backend contention/unavailability windows over per-user JWT corruption.

## Query plan elimination for existing-user failing routes
- Replayed representative failing queries under authenticated RLS context (`set local role authenticated`, `request.jwt.claim.sub=1652326c...`).
- Representative execution times remained low (roughly 1-9ms), including:
  - drafts/hosted events query
  - invites by user query
  - plays by group query
- Conclusion: issue is not a single deterministic always-slow SELECT plan; more likely burst/concurrency contention windows.

## Additional fixes applied this pass (iOS)
1. Reduced Home startup query fan-out:
   - `HomeDataLoader.load` switched from parallel `async let` to bounded sequential fetch for `upcomingEvents`, `invites`, `drafts`.
2. Added resilient retry/backoff for transient failures in `HomeDataLoader`:
   - retries now include transient 5xx/timeout-style failures, not just `URLError`.
3. Reduced event-query fan-out:
   - `SupabaseService.fetchUpcomingEvents()` now fetches public and hosted streams sequentially (instead of parallel) to lower request burst pressure.

## Migration drift status
- Remote migration history includes:
  - `20260404195402_fix_rls_initplan_performance`
  - `20260404213602_reduce_rls_hotpath_contention_indexes`
- Local repository had semantically equivalent migrations but mismatched versioned filenames.
- Added exact-version local files to align timeline:
  - `Supabase/migrations/20260404195402_fix_rls_initplan_performance.sql`
  - `Supabase/migrations/20260404213602_reduce_rls_hotpath_contention_indexes.sql`

## Controlled authenticated stress run (automation)
- Date/time: 2026-04-05 around `00:03` to `00:06` UTC.
- Goal: remove "bad JWT" as confounder and force reproducible load with a known-valid token.
- Steps executed:
  1. Created a dedicated auth test user via Supabase admin API.
  2. Signed in that user via `/auth/v1/token?grant_type=password` to mint a fresh access token.
  3. Added test user as accepted member in active group `A6C84503-F496-464A-BC00-206E7D3691AE`.
  4. Ran `socs/issues/stress_supabase_ios.sh -m mixed -n 60 -p 12`.
  5. Hardened stress harness so curl transport failures are recorded as `code=000` and do not abort the run.
- Artifacts:
  - Stress log: `socs/issues/results/stress-20260404-200329.log`
  - Script update: `socs/issues/stress_supabase_ios.sh` (`curl_code` now returns `000` on non-HTTP transport failure)
- Observed from stress log (partial run; aborted early due cascading timeouts):
  - `events:200` = 22
  - `events:000` = 2
  - `invites:500` = 7
  - `invites:000` = 17
  - `plays:500` = 8
  - `plays:000` = 16
  - `wishlist:000` = 12
- Interpretation:
  - `000` indicates client-side timeout/network failure after 30s max-time.
  - `500` responses clustered on `invites` and `plays` while `events` intermittently stayed `200`.
  - This happened with a freshly minted valid JWT, so failures are not caused by malformed or expired JWT.

## Fresh backend correlation during stress run
- API logs for `User-Agent: CWM-Stress/1.0` show:
  - repeated `500` on `/rest/v1/invites` and `/rest/v1/plays`
  - concurrent `200` on `/rest/v1/events`
- Postgres logs in same window show dense bursts of:
  - `ERROR: canceling statement due to statement timeout`
- Conclusion reinforced:
  - primary fault domain is backend query/connection contention under concurrency, not per-user JWT integrity.
  - JWT/session failures exist as a separate issue (stale refresh token reuse) but are not the root cause of unhealthy 500 bursts.

## Open considerations
- Check whether nested `invites -> event -> host/games/time_options/groups` shape should be split into staged fetches server-side (materialized view or lighter select profile) for high-concurrency paths.
- Add DB-side guardrails for hot windows:
  - tighten/selective indexes for nested joins still timing out under concurrent scans
  - evaluate statement timeout policy per role/query class vs global setting
  - inspect concurrent heavy jobs (realtime/backfills) during mobile peak paths
- Keep iOS startup/query pressure reduced (sequential + retry/backoff) while DB-side fixes are rolled out.

## 2026-04-05 follow-up: production hardening pass

### iOS-side changes applied
1. Reduced invite startup load in app path:
   - `SupabaseService.fetchMyInvites()` now uses `select(*)` only (no nested event graph).
2. Preserved image preloading behavior without invite-embedded events:
   - `AppState.preloadImages` now uses `awaitingResponseEvents` + upcoming + drafts URLs.

### DB migration applied
- Added and applied: `20260404224500_add_hotpath_ordering_indexes.sql`
  - `idx_events_group_deleted_created_desc` on `events(group_id, deleted_at, created_at desc)`
  - `idx_plays_group_played_desc` on `plays(group_id, played_at desc)`
  - `idx_game_wishlist_user_added_desc` on `game_wishlist(user_id, added_at desc)`

### Migration drift status
- Drift is now resolved for the known mismatch set and latest migration chain is aligned.
- Remote migration list now includes latest applied version:
  - `20260405003303 add_hotpath_ordering_indexes`

### Fresh stress results (same user/group, valid JWT)

1. Baseline heavy-query run (`-n 80 -p 12`, legacy heavy invites shape)
   - log: `socs/issues/results/stress-20260404-202412.log`
   - events: `200=40, 500=29, 000=11`
   - invites: `200=19, 500=47, 000=14`
   - plays: `200=4, 500=54, 502=1, 000=21`
   - wishlist: `200=24, 500=38, 000=18`

2. Post-index run (`-n 40 -p 8`, still heavy invites shape)
   - log: `socs/issues/results/stress-20260404-203319.log`
   - events: `200=26, 500=6, 000=8`
   - invites: `200=13, 500=14, 000=13`
   - plays: `200=9, 500=12, 000=19`
   - wishlist: `200=28, 500=5, 000=7`

3. Realistic current iOS path (`-n 30 -p 8`, `STRESS_INVITES_QUERY=light`)
   - log: `socs/issues/results/stress-20260404-204118.log`
   - events: `200=20, 500=10`
   - invites: `200=30` (no invite failures in this run)
   - plays: `200=7, 500=14, 000=9`
  - wishlist: `200=16, 500=11, 000=3`

4. Stress harness improvement:
   - `socs/issues/stress_supabase_ios.sh` now supports `STRESS_INVITES_QUERY=light|heavy` so tests can target either current app behavior (`light`) or legacy worst-case (`heavy`).

### Interpretation update
- JWT integrity is conclusively not the primary root cause for unhealthy behavior.
- iOS invite-path hardening + index changes improved invite reliability significantly on realistic app query shape.
- `plays` remains the dominant unstable endpoint under concurrency and is the current highest-priority hot path.
- Postgres logs during these windows continue to show repeated:
  - `canceling statement due to statement timeout`
  which correlates with API `500` and client `000` timeouts.

### Next target (highest impact) — RESOLVED
- Reduce `plays` query complexity in app and/or move to a constrained server-side RPC path.

## 2026-04-05 fix: SECURITY DEFINER RPCs for plays

### Root cause (confirmed)
- `plays_select` RLS has 3-level nested EXISTS (plays → events → invites, plays → groups → group_members)
- `play_participants_select` RLS **duplicates the entire plays_select chain** inside another EXISTS
- PostgREST evaluates both policies per-row, compounding under concurrency
- `authenticated` role has `statement_timeout=8s` — exceeded under 8-12 parallel requests
- Only 12 rows in plays — pure RLS policy overhead, not data volume

### Fix applied
1. **Migration**: `20260405010000_get_plays_rpc_security_definer.sql`
   - `get_group_plays(p_group_id uuid)` — validates group membership once, returns plays with game/participants/logger as JSONB
   - `get_event_plays(p_event_id uuid)` — validates event host/invite membership once, same structure
   - Both use SECURITY DEFINER with `SET search_path = public, pg_temp`, `SET jit = off`, REVOKE from anon/public
   - Simplified `play_participants_select` RLS to delegate visibility to `plays_select` instead of duplicating nested EXISTS

2. **iOS**: `SupabaseService.swift`
   - `fetchPlaysForGroup` → calls `get_group_plays` RPC
   - `fetchPlaysForEvent` → calls `get_event_plays` RPC

3. **Stress test**: `stress_supabase_ios.sh`
   - Added `STRESS_PLAYS_QUERY=rpc|legacy` (default: rpc)
   - Added `curl_post_code` for RPC POST requests

### Build status
- xcodegen + xcodebuild: **BUILD SUCCEEDED**

## 2026-04-05 verification run after plays RPC rollout

### Stress test executed
- Time window start: `2026-04-05T01:19:47Z`
- Command profile:
  - `STRESS_INVITES_QUERY=light`
  - `STRESS_PLAYS_QUERY=rpc`
  - `mode=mixed`
  - `rounds=40`
  - `parallel=10`
- Artifact:
  - `socs/issues/results/stress-20260404-211947.log`

### Result summary
- invites: `200=40` (0 failures)
- plays (RPC): `200=39`, `500=1`
- wishlist: `200=37`, `500=3`
- events: `200=33`, `500=6`, `000=1`

### Log correlation
- API logs in-window show dominant `200` for:
  - `POST /rest/v1/rpc/get_group_plays`
  - `GET /rest/v1/invites?select=*`
- Residual failures are concentrated in:
  - `GET /rest/v1/events` (`500`, occasional timeout)
  - `GET /rest/v1/game_wishlist` (`500`)
- Postgres logs still show intermittent:
  - `canceling statement due to statement timeout`
  but substantially less blast radius than earlier runs where plays dominated failures.

### Conclusion
- Plays path hardening is effective and materially improves concurrent reliability.
- Remaining instability target is now `events`, then `game_wishlist`.
