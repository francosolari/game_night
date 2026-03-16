# Event Edit Fix Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix published-event editing so it saves updates instead of inserts, allows save from any step, and fully edits existing invitees including the bench.

**Architecture:** Reuse the existing event form, but move primary-action decisions into `CreateEventViewModel` and introduce an editor-facing service interface for testability. Published edit saves diff related invite rows instead of rebuilding the event from scratch.

**Tech Stack:** SwiftUI, XCTest, Supabase Swift client, Xcode project configuration.

---

## Chunk 1: Regression Coverage

### Task 1: Add targeted edit-flow tests

**Files:**
- Modify: `GameNight/GameNight.xcodeproj/project.pbxproj`
- Create: `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift`

- [x] **Step 1: Add the failing edit-flow tests**
- [x] **Step 2: Add the new test file to the `GameNightTests` target**
- [x] **Step 3: Run the focused XCTest command and confirm the tests execute**

## Chunk 2: Edit Flow

### Task 2: Split create vs edit persistence

**Files:**
- Modify: `GameNight/GameNight/Services/SupabaseService.swift`
- Modify: `GameNight/GameNight/ViewModels/EventViewModel.swift`
- Modify: `GameNight/GameNight/Views/Events/CreateEventView.swift`
- Modify: `GameNight/GameNight/Views/Events/EventDetailView.swift`

- [x] **Step 1: Add an editor-facing service protocol and test stubs**
- [x] **Step 2: Preload published invites into edit mode**
- [x] **Step 3: Make published edit mode use `Save Changes` on every step**
- [x] **Step 4: Change edit saves to update existing rows instead of inserting the event again**
- [x] **Step 5: Diff invite mutations so existing, removed, and new invitees are handled explicitly**

## Chunk 3: Verification

### Task 3: Verify behavior

**Files:**
- Modify: `docs/superpowers/specs/2026-03-16-event-edit-fix-design.md`

- [x] **Step 1: Run focused tests**
  - `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameNightTests/CreateEventViewModelTests test`
- [x] **Step 2: Run an app build**
  - `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -destination 'generic/platform=iOS Simulator' build`
