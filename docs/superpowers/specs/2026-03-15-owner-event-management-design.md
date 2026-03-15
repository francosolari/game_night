# Owner Event Management Design

**Problem**

Event owners can create events, but there is no owner-only way to edit or delete them from the app. The user wants delete to feel permanent in the product while remaining recoverable in the backend.

**Approved Approach**

Use owner-only controls in the event detail screen, reuse the existing create-event flow for editing, and implement backend soft delete with a dedicated `deleted_at` column on `events`.

**Scope**

- Add owner-only `Edit Event` and `Delete Event` actions to the event detail screen
- Reuse the existing multi-step event form for edit mode
- Soft delete events in the database by setting `deleted_at`
- Hide soft-deleted events from normal host and guest reads

**Architecture**

`events.deleted_at` becomes the backend source of truth for deletion. App reads treat `deleted_at is not null` as deleted. The owner UI is added to `EventDetailView`, and the form logic in `CreateEventView` / `CreateEventViewModel` gains an edit mode that preloads an existing event and saves through `updateEvent(...)`.

This keeps the visible behavior simple:

- owners can edit their own events
- owners can delete their own events
- deleted events disappear from home, detail, and invite-based reads

**Behavior**

Edit:

- visible only when `event.hostId == currentUser.id`
- opens the existing event form in edit mode
- preloads details, games, time options, scheduling settings, and player settings
- saves by updating the existing `events` row

Delete:

- visible only for the owner
- requires destructive confirmation
- sets `deleted_at` and `updated_at`
- should also set `status = 'cancelled'` for backend clarity
- returns the owner to the previous screen

For this first pass, invite list editing is intentionally out of scope. Existing invites remain attached unless the event is deleted.

**Data Model**

Add to `events`:

- `deleted_at timestamptz null`

Soft deletion semantics:

- `deleted_at is null` means active
- `deleted_at is not null` means hidden from product reads

**Query Rules**

Normal event reads must exclude soft-deleted rows:

- `fetchUpcomingEvents()`
- `fetchMyEvents()`
- `fetchEvent(id:)`

Invite and participant driven event visibility should also stop surfacing deleted events. The most robust place to enforce that is in event RLS so joined reads cannot accidentally expose deleted rows.

**UI Design**

`EventDetailView`

- add a trailing owner menu or toolbar button
- actions: `Edit Event`, `Delete Event`

`CreateEventView`

- add mode support:
  - create mode keeps current behavior
  - edit mode changes navigation title and submit CTA, for example `Save Changes`
- on successful edit, dismiss back to detail and refresh the event

**Backend Access Control**

- only the owner may update or soft-delete an event
- RLS for `events` should continue allowing host writes and participant reads, but only for rows where `deleted_at is null`
- owner updates to a deleted event should not be part of the normal flow

**Migration**

1. Add `deleted_at` to `events`
2. Replace event select policies to require `deleted_at is null`
3. Keep host update policies owner-only
4. Apply remotely via Supabase MCP

**Verification**

- owner sees edit/delete controls on their own event only
- non-owner does not see those controls
- owner can edit and persist event changes
- owner can delete an event and it disappears from home
- fetching a deleted event no longer returns it through normal reads
- build still succeeds

**Notes**

- This is separate from invite delivery/SMS behavior
- A later phase can add restore/admin tooling if needed, but that is intentionally out of scope

**Implementation Status**

- `Supabase/migrations/005_event_soft_delete.sql` created and applied remotely as `event_soft_delete` via Supabase MCP
- `GameEvent` now carries `deletedAt`, and normal event fetches exclude rows where `deleted_at` is set
- `EventDetailView` now exposes owner-only `Edit Event` and `Delete Event` actions
- the delete flow now uses user-facing irreversible copy, shows an in-progress state, and surfaces backend failures instead of failing silently
- the soft-delete write path no longer tries to read back the deleted row, because that row is intentionally hidden by `events_select` once `deleted_at` is set
- `softDeleteEvent` explicitly uses `returning: .minimal` to override the Supabase Swift update default of `representation`
- `CreateEventView` / `CreateEventViewModel` now support edit mode and reuse the existing event form
- Invite list editing remains intentionally out of scope for this pass
- Verified with `xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/gamenight-derived build` on 2026-03-15
