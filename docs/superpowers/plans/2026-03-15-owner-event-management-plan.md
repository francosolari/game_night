# Owner Event Management Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add owner-only event edit/delete controls, reuse the event form for editing, and implement backend soft delete that hides deleted events from normal app reads.

**Architecture:** Add `deleted_at` to `events`, update event reads and RLS to exclude deleted rows, add a soft-delete service method, and extend the existing event form with an edit mode. Owner actions live in the event detail screen and are hidden from non-owners.

**Tech Stack:** Supabase Postgres migrations and RLS, SwiftUI, Supabase Swift client.

---

## Chunk 1: Backend Soft Delete

### Task 1: Add soft-delete support to `events`

**Files:**
- Create: `Supabase/migrations/005_event_soft_delete.sql`

- [x] **Step 1: Write the migration**

Add:
- `events.deleted_at timestamptz null`
- updated `events` select policies that exclude deleted rows

- [x] **Step 2: Apply remotely with Supabase MCP**

Expected:
- migration succeeds
- deleted events are no longer returned by normal event reads

## Chunk 2: Client Data Flow

### Task 2: Add service support for edit and soft delete

**Files:**
- Modify: `GameNight/GameNight/Services/SupabaseService.swift`
- Modify: `GameNight/GameNight/Models/GameEvent.swift`

- [x] **Step 1: Add `deletedAt` to the event model**

Ensure decode compatibility with the new backend column.

- [x] **Step 2: Filter normal event reads**

Update:
- `fetchUpcomingEvents()`
- `fetchMyEvents()`
- `fetchEvent(id:)`

- [x] **Step 3: Add `softDeleteEvent(id:)`**

Update the row with:
- `deleted_at = now`
- `status = cancelled`
- `updated_at = now`

## Chunk 3: Edit Mode

### Task 3: Reuse the create form for editing

**Files:**
- Modify: `GameNight/GameNight/ViewModels/EventViewModel.swift`
- Modify: `GameNight/GameNight/Views/Events/CreateEventView.swift`

- [x] **Step 1: Add edit mode to the create-event view model**

Support:
- preloading an existing event
- preserving `event.id` and `hostId`
- save path that calls `updateEvent(...)`

- [x] **Step 2: Update the event form UI for edit mode**

Change:
- title
- submit CTA
- success handling

- [x] **Step 3: Keep invite editing out of scope**

Existing invite creation behavior should remain create-only.

## Chunk 4: Owner Controls

### Task 4: Add owner-only actions in event detail

**Files:**
- Modify: `GameNight/GameNight/Views/Events/EventDetailView.swift`
- Modify: `GameNight/GameNight/App/AppState.swift` if needed for refresh plumbing

- [x] **Step 1: Detect ownership**

Use `currentUser.id == event.hostId`.

- [x] **Step 2: Add `Edit Event` action**

Present the edit form in a sheet or navigation flow.

- [x] **Step 3: Add `Delete Event` action**

Show destructive confirmation, soft delete on confirm, dismiss detail on success.

- [x] **Step 4: Refresh after edit/delete**

Ensure the detail screen reloads after edit and the home screen no longer shows deleted events.

## Chunk 5: Verification

### Task 5: Verify behavior

**Files:**
- Modify: `docs/superpowers/specs/2026-03-15-owner-event-management-design.md`

- [x] **Step 1: Build the iOS app**

Run:
`xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/gamenight-derived build`

Expected:
- build succeeds

- [x] **Step 2: Record current rollout state**

Document:
- migration applied or not
- build result
- any deferred cleanup

Current state:
- `Supabase/migrations/005_event_soft_delete.sql` created locally
- remote migration `event_soft_delete` applied successfully via Supabase MCP
- owner-only edit/delete controls implemented in the app
- delete now shows a blocking in-progress state and a visible error if the backend update fails
- soft delete no longer requests the updated row back from PostgREST, avoiding the expected RLS failure once the row becomes hidden
- `softDeleteEvent` now explicitly uses `returning: .minimal` because the Supabase Swift `update(...)` default is `representation`
- edit mode reuses the create-event flow and intentionally does not modify invite lists
- normal event reads now exclude rows where `deleted_at` is set
- `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/gamenight-derived build` succeeded on 2026-03-15
