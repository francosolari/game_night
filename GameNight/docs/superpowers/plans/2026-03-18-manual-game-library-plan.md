# Manual Game Privacy + Manual Editor Updates Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents are available) or superpowers:executing-plans to follow this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep manual games private to the creator while polishing the manual editor (30-minute playtime ticks and full recommended-player selection) and ensuring guests can still view manual entries through shared events.

**Architecture:** Manual records remain in the `games` table with a new `owner_id`; RLS gates access based on ownership and event membership. The Swift client tracks `ownerId` on `Game`, only enables editing for the owner, and extends the manual editor with chips and time increment logic.

**Tech Stack:** Swift/SwiftUI, Supabase/Postgres (SQL migrations and RLS), Swift concurrency, XCTest (where available).

---

## Chunk 1: Database schema + security

### Task 1: Add owner_id column and tighten games policies

**Files:**
- Create: `Supabase/migrations/20260319_manual_game_owner.sql`

- [ ] **Step 1: Draft SQL to alter `games`** (add nullable `owner_id` referencing `users`, create `idx_games_owner_id`).
- [ ] **Step 2: Replace `games` policies** (`SELECT`, `INSERT`, `UPDATE`) so manual rows only surface to their owner or to users with a relevant invite/host link, while BGG rows stay public.
- [ ] **Step 3: Update the migration list** (if necessary) so Supabase applies this script after the existing schema.
- [ ] **Step 4: Run/validate the SQL locally** (e.g., `supabase db push` or dry-run via `psql --file`) to ensure there are no syntax errors.
- [ ] **Step 5: Commit the migration** with a message like `feat: scope manual games to owner`.


## Chunk 2: Game model and Supabase service

### Task 2: Teach `Game` about ownership and recommended-players display

**Files:**
- Modify: `Models/Game.swift`

- [ ] **Step 1: Add `ownerId: UUID?` plus `isManual`/`isEditable(by:)` helpers, keep defaults so existing initializers stay valid.**
- [ ] **Step 2: Extend the decoder/encoder with `owner_id` and add a reusable range formatter that converts `[Int]?` into "1, 3–4" style strings.**
- [ ] **Step 3: Replace the info-row building logic (`buildInfoRows`) with a helper that calls the new formatter whenever `recommendedPlayers` is non-empty.**
- [ ] **Step 4: Verify `Game` instantiations (BGG parse results, manual constructors) still compile without extra arguments thanks to the default owner.**

### Task 3: Ensure Supabase inserts manual owner metadata

**Files:**
- Modify: `Services/SupabaseService.swift`

- [ ] **Step 1: Add a helper (e.g., `normalizedManualGame(_:)`) that pulls the authenticated user ID and, when `bggId == nil`, sets `owner_id` before upsert.**
- [ ] **Step 2: Invoke the helper from `upsertGame(_:)` so manual games inherit the session user before being inserted/upserted.**
- [ ] **Step 3: Keep `updateGame` usage unchanged (the object already carries `ownerId`).**
- [ ] **Step 4: Run any existing Swift tests that cover `Game`/service behavior (e.g., `xcodebuild test -scheme GameNight -destination 'platform=iOS Simulator,name=iPhone 15'` if feasible) or note why manual verification is required.


## Chunk 3: Manual editor UI behavior

### Task 4: Extend the manual editor with recommended-player chips and 30-minute blocks

**Files:**
- Modify: `Views/GameLibrary/GameDetailView.swift`

- [ ] **Step 1: In `ManualGameEditorSection`, change the min/max playtime steppers to add/subtract 30 minutes, clamp between e.g. 30 and 600, and keep `maxPlaytime >= minPlaytime`.**
- [ ] **Step 2: Insert a `Recommended Players` chip grid just below the player count steppers; chips are built from `range(minPlayers...maxPlayers)` and toggle membership in `game.recommendedPlayers`.**
- [ ] **Step 3: When min/max players change, prune the stored set to the new range (empty set becomes `nil` so the UI defaults to the entire range).**
- [ ] **Step 4: Tie the chip selection rendering to a helper that shows the new `recommendedPlayers` array, defaulting to the full range whenever it’s `nil`.**
- [ ] **Step 5: Ensure the newly introduced helpers (range formatter, chip binding) are well-commented and tested by running `swift test` if the helper logic is factored into testable functions.


## Chunk 4: Detail view ownership + toolbar restrictions

### Task 5: Surface the owner status in the detail view

**Files:**
- Modify: `Views/GameLibrary/GameDetailView.swift`

- [ ] **Step 1: Inject `@EnvironmentObject private var appState: AppState` so the view can inspect `currentUser`.**
- [ ] **Step 2: Compute `canEditManualGame` by combining `displayedGame.isManual` and `displayedGame.ownerId == appState.currentUser?.id`.**
- [ ] **Step 3: Guard the toolbar buttons so only the owner sees `Edit`/`Save` (guests can still view the manual badge).**
- [ ] **Step 4: Keep the rest of the detail sheet untouched so the manual editor shows only for the owner.**
- [ ] **Step 5: Manually test (or via lightweight UI test) that a guest navigating through an event can view but not edit the manual game, while the owner retains full editing rights.


## Verification & Handoff
- [ ] **Step 1:** Run `git status` to confirm only the planned files changed (migration, Game model, SupabaseService, GameDetailView, plan/spec doc). Remove any accidental files.
- [ ] **Step 2:** Commit in logical chunks (migration first, Swift changes second).
- [ ] **Step 3:** If the harness provides subagents, spawn one via superpowers:subagent-driven-development to implement the plan; otherwise, proceed here with superpowers:executing-plans.
- [ ] **Step 4:** After implementation, rerun any critical tests (e.g., `xcodebuild test ...` if feasible) and verify the UI manually.

**Plan complete and saved to `docs/superpowers/plans/2026-03-18-manual-game-library-plan.md`. Ready to execute?**
