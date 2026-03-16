# Event Visibility Design

## Goal

Add an event-level visibility model that matches the intended Partiful-style behavior:

- `private` events hide the exact street address until a guest RSVPs.
- `public` events expose the full event to everyone except the guest list.
- Hosts always see the full event.
- Discovery UI is out of scope for this pass, but the model must support it later.

This pass should also add RSVP deadline support because it is a closely related host control and an important gap.

## Current State

- `GameEvent` has no visibility field.
- Location privacy is currently implied only by UI copy, not enforced by an event-level model.
- The app renders event location in multiple places, especially `EventDetailView` and summary cards.
- There is no RSVP deadline in the event model or host editing flow.
- The current backend shape appears centered on a single event record plus related invites, time options, and event games.

## Product Rules

### Event Visibility

- `private`
  - Event behaves like today from an invitation/access standpoint.
  - Non-host, non-RSVP viewers can still see the event shell: title, description, date/time, game list, RSVP counts, and custom location name if provided.
  - Exact address is hidden until RSVP.
  - If a custom location name exists, it is shown before RSVP.
  - If no custom location name exists, location should degrade to approximate city/state only.

- `public`
  - Event is intended to be discoverable and browsable in the future.
  - Non-RSVP viewers can see the full event details, including full location.
  - Guest list identities remain hidden unless the viewer has RSVP'd.
  - Aggregate counts such as going/interested are still visible.

### Location Privacy

- Hosts always see the full address.
- RSVP'd viewers always see the full address.
- For private events, all other viewers see:
  - custom location name, if present
  - city/state approximation derived from `locationAddress`
  - never the street line
- The masking rule must be centralized so cards, detail screens, and future public feeds stay consistent.

### Guest List Privacy

- Public visibility does not imply public guest identities.
- Non-RSVP viewers of public events can see attendance counts but not the guest list.
- Private events continue to follow existing invite-based access expectations, but guest list visibility should still flow through the same permission helper.

### RSVP Deadline

- Events may optionally define an RSVP deadline timestamp.
- After the deadline, the UI should clearly communicate that RSVPs are closed or restricted according to the event rules chosen in implementation.
- This design pass includes the field, model plumbing, create/edit UI, and display logic.
- Enforcement details should be handled consistently in the backend and app logic.

## Recommended Approach

Use a first-class event visibility field plus shared presentation helpers, not ad hoc masking in individual views.

Why:

- It matches the product model better than a location-only switch.
- It provides a clean base for future discovery and public browsing.
- It avoids leaking exact address details through one forgotten UI path.
- It keeps the later `EVENTS` parent/child structure compatible with one privacy model.

## Data Model Changes

### App Model

Add the following to `GameEvent`:

- `visibility: EventVisibility`
- `rsvpDeadline: Date?`

Add a new enum:

- `EventVisibility`
  - `private`
  - `public`

Coding rules:

- Default decode fallback should be `private` for backward compatibility if older rows do not have the field yet.
- Encode/decode should map cleanly to backend column names such as `visibility` and `rsvp_deadline`.

### Backend / Database

Add columns to `events`:

- `visibility text not null default 'private'`
- `rsvp_deadline timestamptz null`

Constraints:

- `visibility` should be constrained to supported values.
- Existing rows should backfill to `private`.

Future compatibility:

- This field should be treated as the event's core audience model so future discovery queries can filter on it directly.

## Permission Model

Introduce a single event-visibility policy helper in app code, and later mirror the same logic server-side.

Suggested capabilities:

- canViewFullAddress
- canViewApproximateAddress
- canViewGuestList
- canViewPublicEventContent
- isRSVPClosed

Inputs:

- event visibility
- viewer relationship: host, RSVP'd guest, invited guest, anonymous/public viewer
- RSVP deadline state

This should produce a single source of truth for all event presentation branches.

## UI Changes

### Create / Edit Event

Add a privacy section at the event level, not inside the location flow:

- Audience / Privacy control with `Private` and `Public`
- Short helper copy explaining each mode
- Optional RSVP deadline control in the host flow

Behavior:

- New events default to `Private`
- Editing preserves the saved value
- The location picker and edit sheet no longer own visibility

### Event Detail

Update location rendering to use the visibility helper:

- Host or RSVP'd viewer: full location
- Private, not RSVP'd: location name plus city/state only
- Public: full location

Update guest-list area:

- Public, not RSVP'd: show counts, hide identities
- Private: preserve existing access expectations, but use the same helper

### Event Cards / Feed Surfaces

Any place showing event location should use the same masked-location formatter.

That includes:

- event cards
- headers / hero summaries
- any invite preview or activity surface that exposes location text

## Formatting Rules For Masked Location

Create a formatter that returns:

- `title`
  - custom location name if available
  - otherwise city/state if private and hidden
  - otherwise location name or street line depending on saved data
- `subtitle`
  - city/state when exact address is hidden
  - full address line when allowed

For private hidden mode, the formatter must never include the street line.

## Backend / API Behavior

This should not rely only on client masking.

Minimum backend requirements for this pass:

- Persist `visibility` and `rsvp_deadline`
- Return them in fetch/create/update paths
- Prepare service-layer logic so future public-event fetches can safely mask guest lists and, if needed, exact location for non-authorized viewers

Even if full public browsing is not implemented now, the data contract should be shaped so it can support anonymous or broader read surfaces later without redesigning the event model.

## Testing

### Unit Tests

- `GameEvent` encode/decode for `visibility` and `rsvpDeadline`
- permission helper cases:
  - host + private
  - RSVP'd + private
  - non-RSVP + private
  - non-RSVP + public
  - guest list visibility across the same cases
- masked location formatter for:
  - custom location name + full address
  - no custom location name
  - malformed or incomplete address strings

### UI / View-Model Verification

- Create/edit retains visibility choice
- Create/edit retains RSVP deadline
- Event detail hides full address correctly for private non-RSVP viewers
- Event cards never leak hidden addresses

### Build Verification

- Targeted tests for formatting and permission logic
- Simulator build after UI integration

## Out Of Scope

- Public-event discovery UI
- Search/browse surfaces for games
- Multi-table or child-event seat signup
- Public activity-feed redesign
- Payments / pitch-in

## Risks

- Address masking can leak through one unconverted view if the formatter is not centralized.
- Public events will eventually need backend read policies, not just app logic.
- RSVP deadline semantics need a clear decision for whether editing an RSVP remains allowed after cutoff.

## Follow-On Work

- Discovery feed for public events
- Search by game and open seats
- Public-event activity-feed rules
- Parent event plus child table model described in the `EVENTS` future document

## References

- Partiful Help: "What is a Public Event?"
- Partiful Help: "Can my guests see the event location before they RSVP?"
- Partiful Help: "How can I set a deadline for my guests to RSVP by?"
- Partiful Help: "How do I find events to go to?"
- Partiful Help: "I don't see the Activity Feed on my public event!"
