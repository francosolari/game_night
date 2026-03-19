# I'm using the writing-plans skill to create the implementation plan.

# Awaiting Response Section Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an "Awaiting Response" carousel atop the home feed when a logged-in user has pending invites, keeping "Next Up" limited to events they have accepted/maybe-ed and ensuring the new section updates automatically when the user replies.

**Architecture:** Extend `HomeViewModel` to resolve pending invites into display-ready events, track which invites still need responses, and add a new SwiftUI section above "Next Up" that renders those pending events with an explicit RSVP call-to-action while leaving the existing carousel for already-accepted events.

**Tech Stack:** SwiftUI view model logic (`HomeViewModel.swift`), shared data layer (`SupabaseService.swift`), and view layout in `HomeView.swift` using the existing `VerticalEventCard`/`PendingInviteCard` components.

---

### Task 1: Expose pending-invite events on the view model

**Files:**
- Modify: `GameNight/GameNight/ViewModels/HomeViewModel.swift`

- [ ] **Step 1: Add `awaitingResponseEvents` state**
  ```swift
  @Published var awaitingResponseEvents: [(event: GameEvent, invite: Invite)] = []
  ```
  Expected: when pending invites are empty, this list stays empty.

- [ ] **Step 2: During `loadData`, collect pending invites**
  Track `pendingInviteEventIds` from `snapshot.myInvites.filter { $0.status == .pending }`. Fetch those events via `supabase.fetchEvents(ids:)` (reuse `mergeUpcomingEvents` logic if helpful) and pair each event with its Invite so the UI can show the RSVP status.

- [ ] **Step 3: Keep `upcomingEvents` clean**
  Remove pending invites from the `missingInviteEventIds` set (so they don’t go into "Next Up"). Keep merging accepted/maybe events into `upcomingEvents` as today.

- [ ] **Step 4: Error handling**
  If the pending invite fetch fails, log it but allow the home screen to render; awaitable events just stay empty.

- [ ] **Step 5: Unit-testable helpers (optional)**
  If feasible, add helper methods to `HomeViewModel` to compute pending IDs/events and test them in `GameNight/GameNightTests/ViewModels`.

### Task 2: Render the Awaiting Response carousel

**Files:**
- Modify: `GameNight/GameNight/Views/Home/HomeView.swift`

- [ ] **Step 1: Before the "Next Up" section, insert a new vertical stack**
  It should only render when `viewModel.awaitingResponseEvents` is non-empty; use `SectionHeader(title: "Awaiting Response")` for the title.

- [ ] **Step 2: Reuse `VerticalEventCard` (or a dedicated card)**
  For each pending event, pass the event along with its invite into the card. Include a visual indicator (e.g., `MyInviteBadge` or a button) that says "RSVP" or similar; you can detect `invite.status == .pending` to show the CTA.

- [ ] **Step 3: Ensure navigation taps still work**
  Tapping a pending event launches the event detail (same `navigationPath.append(event)` as in "Next Up"). Consider scrolling behavior like the existing carousel.

- [ ] **Step 4: Maintain spacing**
  Keep the new carousel above "Next Up" but below drafts/pending-floating section; reuse the same horizontal scroll + spacing logic for consistency.

### Task 3: Keep pending invites sync’d with responses

**Files:**
- Modify: `GameNight/GameNight/Views/Events/CreateEventView.swift` or whichever view handles RSVP (maybe `EventDetailView` or `PendingInviteCard`).

- [ ] **Step 1: After response success, reload home data**
  Ensure the code path that calls `HomeViewModel.loadData()` (likely via `appState` or the invite card) now refreshes the awaiting-response list so the event moves down to "Next Up". This may already happen when `loadData()` is triggered; confirm and add explicit calls if not.

- [ ] **Step 2: Optional: animate the transition**
  After accepting/maybe-ing, consider briefly showing a toast or simply refreshing the home view so the event reappears in the new section; keep behavior consistent with existing UI patterns.

### Task 4: Manual verification

**Files:**
- Manual (no files)

- [ ] **Step 1:** Run the app, create an event as User A, invite User B. On User B’s home screen, the new "Awaiting Response" carousel should appear at the top with that event.
- [ ] **Step 2:** Accept or Maybe the invite (via the detail or invite card). The event should disappear from "Awaiting Response" and show up in "Next Up" with the RSVP badge removed.
- [ ] **Step 3:** Test with multiple pending invites to ensure the carousel scrolls horizontally with consistent spacing.

**Plan complete. Ready to execute?**
