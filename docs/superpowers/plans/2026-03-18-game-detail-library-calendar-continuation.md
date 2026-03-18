# Game Detail Pages, Library Suggestions & Calendar Description Continuation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish and verify the partially completed March 18 game-detail/library/calendar feature set without re-planning work that is already done.

**Architecture:** Continue from the existing design spec and implementation plan rather than restarting. Treat the repository state as three buckets: already committed foundations, staged-but-uncommitted feature work, and a small set of related unstaged integrations. Close the gap by stabilizing the current implementation, adding the missing database migration, and verifying behavior before any final merge/cleanup.

**Tech Stack:** SwiftUI, Supabase/Postgres, BGG XML integration, Xcode/xcodebuild, XCTest

**Design Spec:** `docs/superpowers/specs/2026-03-18-game-detail-library-calendar-design.md`
**Original Plan:** `docs/superpowers/plans/2026-03-18-game-detail-library-calendar.md`

---

## Current State Snapshot

### Already committed

- Docs/spec written:
  - `docs/superpowers/specs/2026-03-18-game-detail-library-calendar-design.md`
  - `docs/superpowers/plans/2026-03-18-game-detail-library-calendar.md`
- Data model groundwork committed:
  - `GameNight/GameNight/Models/Game.swift`
  - `GameNight/GameNight/Models/GameFamily.swift`
  - `GameNight/GameNight/Models/GameExpansion.swift`
- BGG parser groundwork committed:
  - `GameNight/GameNight/Services/BGGService.swift`

### Staged but not committed

- Shared game-detail UI components
- Game/designer/publisher detail views
- Game relations service methods
- Library suggestions in event creation
- Calendar description generation
- GameLibrary navigation swap from sheet to push navigation

### Unstaged but likely part of the same feature thread

- Home-tab navigation destinations in `GameNight/GameNight/App/ContentView.swift`
- Event detail game navigation in `GameNight/GameNight/Views/Events/EventDetailView.swift`
- Voting screen game navigation in `GameNight/GameNight/Views/Events/GameVotingView.swift`
- Manual-game edit affordance in `GameNight/GameNight/Views/GameLibrary/GameDetailView.swift`

### Still missing

- The migration planned in `Supabase/migrations/20260318_game_detail_tables.sql`
- Migration application to Supabase
- Full verification pass for the combined feature
- Final commit(s) for the staged/unstaged implementation

### Observed verification state on 2026-03-18

- `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - Result: `BUILD SUCCEEDED`
- `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GameNightTests/CreateEventViewModelTests test`
  - Result: 2 failing tests
  - Failures:
    - `testCanProceedGamesStepRequiresSelectedGames`
    - `testCanProceedInvitesStepRequiresInvitees`
  - Likely cause: `CreateEventViewModel.canProceed` currently treats `.games` and `.invites` as optional steps

---

## Task 1: Stabilize the Current Feature Slice

**Files:**
- Review staged: `GameNight/GameNight/Services/SupabaseService.swift`
- Review staged: `GameNight/GameNight/ViewModels/CreateEventViewModel.swift`
- Review staged: `GameNight/GameNight/ViewModels/CreatorDetailViewModel.swift`
- Review staged: `GameNight/GameNight/ViewModels/GameDetailViewModel.swift`
- Review staged: `GameNight/GameNight/Views/Components/AddToCalendarButton.swift`
- Review staged: `GameNight/GameNight/Views/Components/FlowLayout.swift`
- Review staged: `GameNight/GameNight/Views/Components/GameDetail/DetailHeroImage.swift`
- Review staged: `GameNight/GameNight/Views/Components/GameDetail/ExpandableGameGrid.swift`
- Review staged: `GameNight/GameNight/Views/Components/GameDetail/HorizontalGameScroll.swift`
- Review staged: `GameNight/GameNight/Views/Components/GameDetail/InfoRowGroup.swift`
- Review staged: `GameNight/GameNight/Views/Components/GameDetail/RatingBadge.swift`
- Review staged: `GameNight/GameNight/Views/Components/GameDetail/SortFilterBar.swift`
- Review staged: `GameNight/GameNight/Views/Components/GameDetail/TagFlowSection.swift`
- Review staged: `GameNight/GameNight/Views/Events/CreateEventSteps/CreateEventGamesStep.swift`
- Review staged: `GameNight/GameNight/Views/Events/EventDetailView.swift`
- Review staged: `GameNight/GameNight/Views/GameLibrary/CreatorDetailContent.swift`
- Review staged: `GameNight/GameNight/Views/GameLibrary/DesignerDetailView.swift`
- Review staged: `GameNight/GameNight/Views/GameLibrary/GameDetailView.swift`
- Review staged: `GameNight/GameNight/Views/GameLibrary/GameLibraryView.swift`
- Review staged: `GameNight/GameNight/Views/GameLibrary/PublisherDetailView.swift`
- Review staged: `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift`
- Review unstaged: `GameNight/GameNight/App/ContentView.swift`
- Review unstaged: `GameNight/GameNight/Views/Events/GameVotingView.swift`

- [ ] **Step 1: Remove the whitespace-only staging defect**
  - Fix the `new blank line at EOF` issue in `GameNight/GameNight/Views/GameLibrary/GameLibraryView.swift`.

- [ ] **Step 2: Decide which unstaged files belong to this feature**
  - Include these if the goal is end-to-end navigation from non-library surfaces:
    - `GameNight/GameNight/App/ContentView.swift`
    - `GameNight/GameNight/Views/Events/EventDetailView.swift` (unstaged portion)
    - `GameNight/GameNight/Views/Events/GameVotingView.swift`
  - Exclude unrelated repo hygiene files from this feature commit:
    - `.gitignore`
    - `CLAUDE.md`

- [ ] **Step 3: Decide whether manual game editing is in scope**
  - `GameNight/GameNight/Views/GameLibrary/GameDetailView.swift` has an unstaged manual edit sheet for games without `bggId`.
  - Keep it only if manual-library entries are intended to remain editable from the new detail page.
  - Otherwise drop that unstaged delta and keep the detail page read-only for this feature slice.

- [ ] **Step 4: Create a coherent implementation commit for the UI/service layer**
  - Stage only files that belong to this feature.
  - Commit with a message similar to:
    - `feat: add game detail navigation and library/calendar enhancements`

---

## Task 2: Add the Missing Database Migration

**Files:**
- Create: `Supabase/migrations/20260318_game_detail_tables.sql`

- [ ] **Step 1: Add the migration file that the original plan expected**
  - Include:
    - new `games` columns: `designers`, `publishers`, `artists`, `min_age`, `bgg_rank`
    - backfill updates for nullable arrays
    - `game_expansions`
    - `game_families`
    - `game_family_members`
    - indexes
    - RLS enablement and authenticated policies

- [ ] **Step 2: Apply the migration to Supabase**
  - Use the Supabase MCP migration tool instead of raw ad hoc SQL.

- [ ] **Step 3: Verify schema availability in code assumptions**
  - Confirm the staged `SupabaseService` methods rely only on fields/tables created by this migration.

- [ ] **Step 4: Commit the migration separately**
  - Commit with a message similar to:
    - `feat: add game detail relationship tables and game metadata columns`

---

## Task 3: Resolve the `canProceed` Contract Drift

**Files:**
- Review/modify: `GameNight/GameNight/ViewModels/CreateEventViewModel.swift`
- Review/modify: `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift`

- [ ] **Step 1: Confirm intended product behavior**
  - Current implementation:
    - `.games` is optional
    - `.invites` is optional
  - Current tests still expect both steps to block progress when empty.

- [ ] **Step 2: Pick one consistent contract**
  - If optional is correct:
    - update the two tests to assert `true`
    - ensure button labels like `Add Game Later` and `Invite Later` remain aligned
  - If required is correct:
    - restore `canProceed` gating and verify downstream step navigation still works

- [ ] **Step 3: Commit the behavior/test alignment**
  - Keep this as a separate commit if it is not specific to the game-detail feature itself.

---

## Task 4: Add Focused Regression Coverage

**Files:**
- Review/modify: `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift`
- Create or extend tests near existing coverage for:
  - `GameNight/GameNight/Views/Components/AddToCalendarButton.swift`
  - `GameNight/GameNight/ViewModels/GameDetailViewModel.swift`
  - `GameNight/GameNight/ViewModels/CreatorDetailViewModel.swift`

- [ ] **Step 1: Add coverage for library suggestions**
  - Verify `loadLibrary()` populates `libraryGames`.
  - Verify `libraryAutocompleteResults` filters case-insensitively.

- [ ] **Step 2: Add coverage for calendar notes generation**
  - Verify:
    - no games
    - one primary game
    - multiple games
    - host name included

- [ ] **Step 3: Add at least one smoke-level relation test if practical**
  - Prefer ViewModel/unit-level tests over UI snapshot work.

---

## Task 5: End-to-End Verification

**Files:**
- Verify all feature files above

- [ ] **Step 1: Build app**
  - Run:
    - `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`

- [ ] **Step 2: Run targeted tests**
  - Run:
    - `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GameNightTests/CreateEventViewModelTests test`

- [ ] **Step 3: Run any new targeted tests added in Task 4**

- [ ] **Step 4: Manually verify navigation paths**
  - Game Library → Game detail
  - Game detail → Designer detail
  - Game detail → Publisher detail
  - Event detail → Game detail
  - Game voting → Game detail

- [ ] **Step 5: Manually verify data-backed sections with realistic data**
  - expansion list
  - family sections
  - library suggestion rows
  - calendar description output

---

## Recommended Execution Order

1. Stabilize and commit the current staged/unstaged app-layer work.
2. Add and apply the missing migration.
3. Resolve the `canProceed` test/behavior mismatch.
4. Add focused regression tests.
5. Re-run build/tests and only then proceed to final integration cleanup.

---

## Notes for the Next Worker

- Do not restart from the brainstorm HTML; the spec and plan already captured it.
- Do not treat the absence of a docs artifact in `docs/superpowers` as the problem. The real incomplete work is the uncommitted implementation plus the missing migration.
- Ignore unrelated repo hygiene changes unless they are necessary to complete verification on this machine.
