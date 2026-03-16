# INVITE LINKS

## Purpose

Capture the future invite-link flow for Game Night so hosts can share events with people who do not already have the app.

This is a planning document only. It should guide later implementation without forcing rushed backend or link-routing decisions right now.

## Core Goal

A host should be able to tap `Copy Link` on an event and share a single invite URL.

That link should work for:

- existing users with the app
- existing users without the app open
- people who have never installed the app

The link flow should reduce friction for public and private event growth.

## Product Shape

Hosts should have two main invite paths:

- direct invites
  - contacts, phone numbers, manual selection
- shareable invite links
  - copy link
  - paste into text, group chat, Discord, WhatsApp, email, etc.

Invite links should not replace direct invites. They should complement them.

## URL Model

The app already has a domain. Later implementation should use that domain for canonical invite URLs.

Working shape:

- `https://<domain>/e/<event-or-invite-token>`

The token should be opaque and non-guessable. Do not expose raw event IDs directly for private links if it weakens privacy or abuse controls.

## Public vs Private Event Behavior

### Public Events

Public-event links can resolve directly to the event page.

They should preserve the current public-event rules:

- full event details visible
- guest counts visible
- guest identities hidden until RSVP

### Private Events

Private-event links should still respect private-event privacy:

- exact address hidden until RSVP
- custom location label can still be shown
- guest identities hidden unless allowed

Private links should grant access to the event shell and RSVP flow, but not silently bypass privacy rules.

## Link Types

There are likely two future link categories:

- event link
  - points to the event itself
  - useful for public events and simple sharing
- invite link
  - tied to an invite token or invite policy
  - better for private events and attribution

Recommendation:

- use invite-link architecture internally even if the product copy simply says `Copy Link`
- that leaves room for expiry, revocation, guest attribution, and analytics later

## Guest Experience

When someone opens the link:

1. If the app is installed, route into the event or RSVP flow.
2. If the app is not installed, open a lightweight web landing page.
3. That page should explain the event, show allowed preview data, and drive:
   - open app
   - install app
   - continue RSVP

The landing page should not require immediate account creation before showing basic event context.

## RSVP And Account Creation

The eventual flow should support:

- viewing basic event info from the link
- creating or signing into an account only when needed
- preserving the original invite token across install/sign-in
- finishing RSVP after auth without losing context

This means the invite token needs a durable handoff path across:

- Safari or webview
- App Store install
- first app launch
- sign in / sign up

## Security Requirements

Invite links should be designed for revocation and abuse control from the start.

Future needs:

- opaque tokens
- ability to disable or rotate a link
- optional expiration
- optional host control over how many people a link can admit
- optional guest attribution if a new attendee came through a specific link

## Backend Direction

Likely future components:

- `invite_links` table or equivalent token store
- optional token-to-event mapping with metadata
- link status: active, revoked, expired
- optional `created_by_user_id`
- optional `max_uses` and `use_count`
- deep-link resolution endpoint or edge function

The backend should become the source of truth for whether a link is still valid.

## App Surfaces To Add Later

- event detail: `Copy Link`
- optional share sheet: `Share`
- host settings: regenerate / disable link
- optional analytics: link opens, successful RSVPs from link

## Relationship To Direct Invites

Direct invites should continue to exist because they support:

- contact-based RSVP tracking
- waitlist / tiered invite flows
- known recipient targeting

Invite links solve a different problem:

- low-friction distribution
- off-platform sharing
- people without the app yet

## Recommended Rollout

1. Add host-side `Copy Link` UI.
2. Add basic tokenized link generation.
3. Add app deep-link handling.
4. Add fallback web landing page.
5. Add token revocation / regeneration.
6. Add analytics and link policy controls only if needed.

## Open Questions

- Should each event have one canonical link or multiple links?
- Should private-event links be individually revocable?
- Should guest-invited links be distinct from host-generated links?
- Do public events need a browsable canonical URL separate from invite links?
- Should a copied link automatically count the opener as pending only after auth, or only after RSVP?

## Recommendation

Build invite links as a tokenized share system, not just a raw event URL. That gives the product room to support private sharing, attribution, revocation, and install-to-RSVP handoff without redesigning later.
