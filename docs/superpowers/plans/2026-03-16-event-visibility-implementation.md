# Event Visibility Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add event-level `public` vs `private` visibility, private-event address masking until RSVP, guest-list hiding for public non-RSVP viewers, and RSVP deadline support without building discovery UI yet.

**Architecture:** Add the new event fields at the schema and model layer first, then centralize all visibility decisions in shared policy and formatting helpers. Wire host controls into create/edit, update feed fetching so private events do not leak into the upcoming list, and finally switch event surfaces to shared masked-location and guest-list rules.

**Tech Stack:** SwiftUI, XCTest, Supabase, SQL migrations, xcodebuild

---

## File Map

**Create:**
- `supabase/migrations/20260316_add_event_visibility_and_rsvp_deadline.sql`
- `GameNight/GameNight/Models/EventVisibility.swift`
- `GameNight/GameNight/Models/EventAccessPolicy.swift`
- `GameNight/GameNight/Models/EventLocationPresentation.swift`
- `GameNight/GameNightTests/Models/EventVisibilityTests.swift`
- `GameNight/GameNightTests/Models/EventAccessPolicyTests.swift`

**Modify:**
- `GameNight/GameNight/Models/GameEvent.swift`
- `GameNight/GameNight/Models/Invite.swift`
- `GameNight/GameNight/Services/SupabaseService.swift`
- `GameNight/GameNight/ViewModels/EventViewModel.swift`
- `GameNight/GameNight/ViewModels/HomeViewModel.swift`
- `GameNight/GameNight/ViewModels/HomeDataProviding.swift`
- `GameNight/GameNight/Views/Events/CreateEventView.swift`
- `GameNight/GameNight/Views/Events/EventDetailView.swift`
- `GameNight/GameNight/Views/Events/GuestListTabsView.swift`
- `GameNight/GameNight/Views/Components/EventCard.swift`
- `GameNight/GameNightTests/TestSupport/FixtureFactory.swift`
- `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift`
- `GameNight/GameNightTests/ViewModels/HomeViewModelTests.swift`

**Reference:**
- `docs/superpowers/specs/2026-03-16-event-visibility-design.md`
- `docs/superpowers/plans/2026-03-16-EVENTS.md`
- `docs/superpowers/specs/2026-03-15-invite-access-rls-design.md`

## Chunk 1: Schema And Core Model

### Task 1: Add the event visibility and RSVP deadline fields to the data model

**Files:**
- Create: `supabase/migrations/20260316_add_event_visibility_and_rsvp_deadline.sql`
- Create: `GameNight/GameNight/Models/EventVisibility.swift`
- Modify: `GameNight/GameNight/Models/GameEvent.swift`
- Modify: `GameNight/GameNightTests/TestSupport/FixtureFactory.swift`
- Create: `GameNight/GameNightTests/Models/EventVisibilityTests.swift`

- [ ] **Step 1: Write the failing model tests**

Add tests for:

```swift
func testGameEventDecodesMissingVisibilityAsPrivate()
func testGameEventRoundTripsVisibilityAndRSVPDeadline()
```

- [ ] **Step 2: Run the targeted model tests to confirm failure**

Run:

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:GameNightTests/EventVisibilityTests
```

Expected: decode or compile failure because `visibility` and `rsvpDeadline` do not exist yet.

- [ ] **Step 3: Add the SQL migration**

Create SQL that:

```sql
alter table public.events
add column visibility text not null default 'private',
add column rsvp_deadline timestamptz null;

alter table public.events
add constraint events_visibility_check
check (visibility in ('private', 'public'));
```

Include safe guards if the existing schema already has one of those pieces.

- [ ] **Step 4: Add `EventVisibility` and wire `GameEvent` to use it**

Implement:

```swift
enum EventVisibility: String, Codable, CaseIterable {
    case `private`
    case `public`
}
```

Add to `GameEvent`:

```swift
var visibility: EventVisibility
var rsvpDeadline: Date?
```

Decode missing `visibility` as `.private`.

- [ ] **Step 5: Update fixtures and preview data**

Update `FixtureFactory.makeEvent(...)` to accept:

```swift
visibility: EventVisibility = .private,
rsvpDeadline: Date? = nil
```

and pass them into `GameEvent`.

- [ ] **Step 6: Re-run the targeted model tests**

Run the same `xcodebuild ... -only-testing:GameNightTests/EventVisibilityTests` command.

Expected: PASS.

- [ ] **Step 7: Commit Chunk 1**

```bash
git add supabase/migrations/20260316_add_event_visibility_and_rsvp_deadline.sql GameNight/GameNight/Models/EventVisibility.swift GameNight/GameNight/Models/GameEvent.swift GameNight/GameNightTests/TestSupport/FixtureFactory.swift GameNight/GameNightTests/Models/EventVisibilityTests.swift
git commit -m "feat: add event visibility model"
```

## Chunk 2: Shared Access Rules And Location Formatting

### Task 2: Centralize what a viewer can see

**Files:**
- Create: `GameNight/GameNight/Models/EventAccessPolicy.swift`
- Create: `GameNight/GameNight/Models/EventLocationPresentation.swift`
- Modify: `GameNight/GameNight/ViewModels/EventViewModel.swift`
- Create: `GameNight/GameNightTests/Models/EventAccessPolicyTests.swift`

- [ ] **Step 1: Write failing policy and formatter tests**

Add tests for:

```swift
func testPrivateEventNonRSVPViewerCannotSeeFullAddress()
func testPrivateEventNonRSVPViewerSeesCustomLocationNameAndCityState()
func testPublicEventNonRSVPViewerCanSeeFullAddressButNotGuestList()
func testHostAlwaysSeesFullAddress()
func testMaskedLocationNeverLeaksStreetLineForPrivateHiddenMode()
```

- [ ] **Step 2: Run the targeted policy tests to confirm failure**

Run:

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:GameNightTests/EventAccessPolicyTests
```

Expected: compile failure because policy and formatter types do not exist.

- [ ] **Step 3: Implement `EventAccessPolicy`**

Design it around a viewer relationship:

```swift
enum EventViewerRole {
    case host
    case rsvpd
    case invitedNotRSVPd
    case publicViewer
}
```

Policy outputs should include:

```swift
var canViewFullAddress: Bool
var canViewGuestList: Bool
var canViewGuestCounts: Bool
var isRSVPClosed: Bool
```

Rules:

- private + host => full address, guest list
- private + RSVP'd => full address, guest list
- private + invitedNotRSVPd => masked address, existing guest-list behavior stays allowed unless product says otherwise
- public + publicViewer => full address, guest counts only

- [ ] **Step 4: Implement `EventLocationPresentation`**

Create a formatter that accepts:

```swift
init(locationName: String?, locationAddress: String?, canViewFullAddress: Bool)
```

and returns:

```swift
let title: String
let subtitle: String?
```

For private hidden mode:

- title = custom location name if present, else city/state
- subtitle = city/state only when custom location name exists
- never expose the street line

- [ ] **Step 5: Add convenience accessors in `EventViewModel`**

Add small computed helpers that translate current app state into the policy:

```swift
var viewerRole: EventViewerRole
var accessPolicy: EventAccessPolicy?
```

Keep the logic there thin. The rule definitions belong in the new model file.

- [ ] **Step 6: Re-run the targeted policy tests**

Run the same `xcodebuild ... -only-testing:GameNightTests/EventAccessPolicyTests` command.

Expected: PASS.

- [ ] **Step 7: Commit Chunk 2**

```bash
git add GameNight/GameNight/Models/EventAccessPolicy.swift GameNight/GameNight/Models/EventLocationPresentation.swift GameNight/GameNight/ViewModels/EventViewModel.swift GameNight/GameNightTests/Models/EventAccessPolicyTests.swift
git commit -m "feat: add event visibility policy helpers"
```

## Chunk 3: Host Create/Edit Controls And Persistence

### Task 3: Persist visibility and RSVP deadline through create and edit

**Files:**
- Modify: `GameNight/GameNight/ViewModels/EventViewModel.swift`
- Modify: `GameNight/GameNight/Views/Events/CreateEventView.swift`
- Modify: `GameNight/GameNight/Services/SupabaseService.swift`
- Modify: `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift`

- [ ] **Step 1: Write failing create/edit view-model tests**

Add tests for:

```swift
func testNewEventsDefaultToPrivateVisibility()
func testEditModePreloadsVisibilityAndRSVPDeadline()
func testSaveChangesPersistsVisibilityAndRSVPDeadline()
```

- [ ] **Step 2: Run the targeted create/edit tests to confirm failure**

Run:

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:GameNightTests/CreateEventViewModelTests/testNewEventsDefaultToPrivateVisibility -only-testing:GameNightTests/CreateEventViewModelTests/testEditModePreloadsVisibilityAndRSVPDeadline -only-testing:GameNightTests/CreateEventViewModelTests/testSaveChangesPersistsVisibilityAndRSVPDeadline
```

Expected: compile failure or assertion failure because the fields are not part of the create/edit flow yet.

- [ ] **Step 3: Add the new published state to the create/edit view model**

Add to `CreateEventViewModel`:

```swift
@Published var visibility: EventVisibility = .private
@Published var rsvpDeadline: Date? = nil
```

Preload them from `eventToEdit`.

- [ ] **Step 4: Persist the new fields through `buildEvent()` and save flows**

Update the event construction path so create and update both pass:

```swift
visibility: visibility,
rsvpDeadline: rsvpDeadline
```

Keep backward compatibility for existing drafts and published edits.

- [ ] **Step 5: Add the host UI controls in `CreateEventView`**

Add an event-level section in the details step with:

- segmented or pill-style `Private` / `Public`
- helper copy that explains full-address exposure
- RSVP deadline picker with an obvious way to clear it

Keep it separate from the location sheet.

- [ ] **Step 6: Re-run the targeted create/edit tests**

Run the same `xcodebuild ... -only-testing:GameNightTests/CreateEventViewModelTests/...` command.

Expected: PASS.

- [ ] **Step 7: Run a simulator build for UI integration**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit Chunk 3**

```bash
git add GameNight/GameNight/ViewModels/EventViewModel.swift GameNight/GameNight/Views/Events/CreateEventView.swift GameNight/GameNight/Services/SupabaseService.swift GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift
git commit -m "feat: add event visibility host controls"
```

## Chunk 4: Home Feed Visibility Rules

### Task 4: Stop leaking private events into the shared upcoming feed

**Files:**
- Modify: `GameNight/GameNight/Models/Invite.swift`
- Modify: `GameNight/GameNight/Services/SupabaseService.swift`
- Modify: `GameNight/GameNight/ViewModels/HomeDataProviding.swift`
- Modify: `GameNight/GameNight/ViewModels/HomeViewModel.swift`
- Modify: `GameNight/GameNightTests/ViewModels/HomeViewModelTests.swift`

- [ ] **Step 1: Write failing home-view-model tests**

Add tests for:

```swift
func testLoadDataMergesAcceptedPrivateInviteEventsIntoUpcoming()
func testLoadDataDoesNotSurfacePendingPrivateInvitesInUpcoming()
func testLoadDataKeepsPublicEventsVisible()
```

- [ ] **Step 2: Run the targeted home tests to confirm failure**

Run:

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:GameNightTests/HomeViewModelTests
```

Expected: failure because the loader cannot yet merge accepted private events separately from the public feed.

- [ ] **Step 3: Add event-fetch support for invite-linked events**

Choose the least invasive path:

- keep `fetchUpcomingEvents()` for host-owned and public events
- add `fetchEvents(ids: [UUID])` to `HomeDataProviding` and `SupabaseService`

Implement a query like:

```swift
.in("id", values: ids.map(\.uuidString))
```

for accepted/maybe invite event IDs.

- [ ] **Step 4: Make `HomeViewModel` merge visible invite events into upcoming**

Rules:

- include public events from `fetchUpcomingEvents()`
- include hosted events even if private
- include private invite events only when invite status is `.accepted` or `.maybe`
- do not include pending private invites in `Upcoming`; keep them in `Pending Invites`
- de-duplicate by event id

- [ ] **Step 5: Re-run the targeted home tests**

Run the same `xcodebuild ... -only-testing:GameNightTests/HomeViewModelTests` command.

Expected: PASS.

- [ ] **Step 6: Commit Chunk 4**

```bash
git add GameNight/GameNight/Models/Invite.swift GameNight/GameNight/Services/SupabaseService.swift GameNight/GameNight/ViewModels/HomeDataProviding.swift GameNight/GameNight/ViewModels/HomeViewModel.swift GameNight/GameNightTests/ViewModels/HomeViewModelTests.swift
git commit -m "feat: enforce home visibility rules"
```

## Chunk 5: Event Surfaces And Guest List Presentation

### Task 5: Apply the shared rules to event detail and cards

**Files:**
- Modify: `GameNight/GameNight/Views/Events/EventDetailView.swift`
- Modify: `GameNight/GameNight/Views/Events/GuestListTabsView.swift`
- Modify: `GameNight/GameNight/Views/Components/EventCard.swift`
- Modify: `GameNight/GameNight/ViewModels/EventViewModel.swift`

- [ ] **Step 1: Add a failing guest-list presentation test or view-model assertion**

If a new unit test file is easier, add one. Minimum cases:

```swift
func testPublicNonRSVPViewerSeesGuestCountsButNotNames()
func testPrivateNonRSVPViewerSeesMaskedAddress()
```

If pure view tests are too heavy, test the policy-facing state in `EventViewModel`.

- [ ] **Step 2: Run the targeted test to confirm failure**

Use the smallest `xcodebuild ... -only-testing:` command that covers the new assertions.

- [ ] **Step 3: Update `GuestListTabsView` to support count-only mode**

Add an explicit mode such as:

```swift
enum GuestListVisibilityMode {
    case fullList
    case countsOnly(message: String)
}
```

In counts-only mode:

- keep the tab counts
- replace the user rows with explanatory copy
- do not render names or avatars

- [ ] **Step 4: Update `EventDetailView` to use the shared policy and masked location formatter**

Use the formatter for:

- header location line
- location card title/subtitle

Use the guest-list mode from the access policy.

- [ ] **Step 5: Update `EventCard` to use the masked location formatter**

Do not render `event.location` directly anymore. Always derive the display strings from `EventLocationPresentation`.

- [ ] **Step 6: Re-run the targeted tests**

Run the smallest relevant `xcodebuild ... -only-testing:` command for the new coverage.

Expected: PASS.

- [ ] **Step 7: Run a full simulator build**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Review the diff for unintended location leaks**

Run:

```bash
git diff -- GameNight/GameNight/Views/Events/EventDetailView.swift GameNight/GameNight/Views/Events/GuestListTabsView.swift GameNight/GameNight/Views/Components/EventCard.swift GameNight/GameNight/Models/EventLocationPresentation.swift
```

Confirm every event-location rendering path now goes through the shared formatter.

- [ ] **Step 9: Commit Chunk 5**

```bash
git add GameNight/GameNight/Views/Events/EventDetailView.swift GameNight/GameNight/Views/Events/GuestListTabsView.swift GameNight/GameNight/Views/Components/EventCard.swift GameNight/GameNight/ViewModels/EventViewModel.swift
git commit -m "feat: apply event visibility to event surfaces"
```

## Chunk 6: Final Verification

### Task 6: Verify schema, tests, and app build

**Files:**
- Verify: `supabase/migrations/20260316_add_event_visibility_and_rsvp_deadline.sql`
- Verify: `GameNight/GameNight/Models/GameEvent.swift`
- Verify: `GameNight/GameNight/ViewModels/EventViewModel.swift`
- Verify: `GameNight/GameNight/Views/Events/CreateEventView.swift`
- Verify: `GameNight/GameNight/Views/Events/EventDetailView.swift`

- [ ] **Step 1: Run focused model and view-model tests**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:GameNightTests/EventVisibilityTests -only-testing:GameNightTests/EventAccessPolicyTests -only-testing:GameNightTests/CreateEventViewModelTests -only-testing:GameNightTests/HomeViewModelTests
```

- [ ] **Step 2: Run the simulator build**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

- [ ] **Step 3: Apply the migration to the Supabase project**

Use the migration tool with the SQL from:

`supabase/migrations/20260316_add_event_visibility_and_rsvp_deadline.sql`

Then verify the new columns exist.

- [ ] **Step 4: Smoke test the app manually**

Verify:

- new event defaults to `Private`
- private event hides street address before RSVP
- private event still shows custom location name before RSVP
- public event shows full address before RSVP
- public event hides guest names but shows counts when viewer is not RSVP'd
- accepted private invite event still appears in `Upcoming`
- pending private invite stays only in `Pending Invites`
- RSVP deadline saves and reloads

- [ ] **Step 5: Commit any remaining fixes**

```bash
git add -A
git commit -m "test: verify event visibility flow"
```
