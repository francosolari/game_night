# Home Page & Calendar View Redesign

**Date:** 2026-03-18
**Status:** Draft

## Overview

Redesign the Home page's Upcoming section as a horizontal carousel, add a Calendar view accessible via navigation push from Home, and rebuild event cards using composable building blocks with size variants. Inspired by Partiful's event browsing UX.

## Goals

- Improve Home page real estate usage with a compact horizontal carousel
- Provide a dedicated Calendar view for browsing all events (grid + list modes)
- Redesign event cards with better visual hierarchy and info density
- Build a modular component system with size variants for reuse across contexts

## Non-Goals

- No changes to tab bar structure (stays at 5 tabs)
- No changes to event detail page
- No changes to Drafts, Pending Invites, Hosting, or Recently Viewed sections on Home
- No backend/API changes

---

## 1. Event Card Building Blocks

Composable SwiftUI views that accept a `ComponentSize` enum to adapt across contexts.

### 1.1 ComponentSize Enum

```swift
enum ComponentSize {
    case compact    // Carousel cards, tight spaces
    case standard   // List rows, calendar detail
    case expanded   // Future use (detail pages, etc.)
}
```

Each building block uses this to control font size, icon size, spacing, and detail level.

### 1.2 Building Blocks

#### EventDateLabel
- **Input:** `GameEvent` (reads `scheduleMode`, `timeOptions`, `confirmedTimeOptionId`)
- **Display:**
  - Fixed mode: relative date + time (e.g. "Sat 8pm", "Next Tue 8pm", "Tomorrow 7pm")
  - Poll mode: chart bar icon + "X time options"
- **Styling:** Terracotta accent color (`Theme.Colors.dateAccent`), capsule background with `dateAccent.opacity(0.15)`
- **Compact:** Shorter format, smaller font (caption)
- **Standard:** Full format, body font

#### EventLocationLabel
- **Input:** `GameEvent`, optional `Invite` (for RSVP status)
- **Logic:** Reuse existing `EventAccessPolicy` (in `Models/EventAccessPolicy.swift`) to determine location visibility. Specifically use `EventAccessPolicy.canViewFullAddress` to decide between city-only and full location display:
  - If no location set: show "TBD"
  - If `canViewFullAddress` is false (not RSVP'd): extract and show city only from `location` or `locationAddress`
  - If `canViewFullAddress` is true (accepted/maybe): show full `location` name
- **Display:** Map pin icon + location text in `textSecondary`
- **Compact:** Single line, truncated
- **Standard:** Single line, slightly more room

#### PlayerCountIndicator
- **Input:** Confirmed RSVP count (Int — count of `.accepted` invites only; `.maybe` does NOT count toward filled slots), `minPlayers` (Int), `maxPlayers` (Int?)
- **Adaptive display based on max player count:**
  - **≤6 max players:** Row of meeple/person SF Symbol icons
    - Filled icons in `success` color (sage) = confirmed RSVPs
    - Outlined icons up to `minPlayers` in `success` color = spots needed to meet minimum
    - Outlined icons from `minPlayers` to `maxPlayers` in `textTertiary` = optional spots
  - **>6 max players (or nil max):** Compact text display
    - Format: "4/6-10" where current count is `textPrimary`, min is `success` color, max is `textTertiary`
    - Thin progress bar underneath, filled proportionally to current/max
    - Subtle marker line at the min threshold on the progress bar
- **Compact:** Smaller icons (12pt) or smaller text (caption2)
- **Standard:** Regular icons (16pt) or body text

#### GameInfoCompact
- **Input:** `[EventGame]`, `ComponentSize`
- **Display:** Primary game name (lineLimit 1) + `ComplexityDot` + playtime estimate
- **Compact:** Shows 1 primary game only, caption font
- **Standard:** Shows up to 2 games, body font
- **Yellow star indicator** if `isPrimary` (existing pattern, yellow for subtle emphasis only)

#### HostBadge
- **Input:** `User?` (host), `Bool` (isCurrentUserHost)
- **Display:** Small circular `AvatarView` + host name text, or "You · Hosting" if current user
- **Compact:** 16pt avatar, caption font
- **Standard:** 20pt avatar, subheadline font

#### InviteStatusBadge
- **Existing component** — reuse as-is. Already displays capsule with icon + label colored by RSVP status.

---

## 2. Card Layout Shells

Two layout shells that compose the building blocks.

### 2.1 CompactEventCard

**Used in:** Home carousel, Calendar day detail section

**Layout:**
```
┌─────────────────────────────────────┐
│ ┌──────────┐  EventDateLabel        │
│ │          │  Event Title (bold)    │
│ │  Cover   │  EventLocationLabel   │
│ │  Image   │  GameInfoCompact      │
│ │          │  HostBadge + Players  │
│ └──────────┘                        │
│        InviteStatusBadge (overlay)  │
└─────────────────────────────────────┘
```

- Image: ~40% width, square with rounded corners, clipped
- `InviteStatusBadge` overlaid on top-right corner of the image
- Right stack: vertical stack of building blocks, all using `.compact` size
- Height: constrained to ~120-140pt
- Background: `Theme.Colors.cardBackground` with `Theme.CornerRadius` applied
- If no cover image, show primary game thumbnail or gradient placeholder

### 2.2 ListEventCard

**Used in:** Calendar list mode

**Layout:**
```
┌──────────────────────────────────────────────┐
│ ┌────────┐  EventDateLabel                   │
│ │ Cover  │  Event Title (bold, 1 line)       │
│ │ Image  │  EventLocationLabel               │
│ │ 80x80  │  GameInfoCompact (up to 2 games)  │
│ └────────┘  HostBadge + PlayerCountIndicator │
└──────────────────────────────────────────────┘
```

- Image: 80pt square, rounded corners
- Right side uses `.standard` size building blocks
- More vertical breathing room than CompactEventCard
- Same card background and corner radius styling
- `InviteStatusBadge` overlaid on image corner

### 2.3 Inputs

Both shells take:
- `GameEvent` — the event data (includes `minPlayers`, `maxPlayers` fields used by `PlayerCountIndicator`)
- `Invite?` — current user's invite (for RSVP status, location visibility)
- `User?` — current user (to determine if hosting)
- `Int` — confirmed RSVP count for player indicator (count of `.accepted` invites, computed by the parent view/viewmodel)

---

## 3. Home Page Changes

### 3.1 Carousel Section ("Next Up")

**Replaces** the current vertical `LazyVStack` of `EventCard` views in the Upcoming section.

- **Header:** "Next Up" title (left) + "View all" button (right)
- **"View all"** triggers `NavigationLink` push to `CalendarView`
- **Carousel:** `ScrollView(.horizontal, showsIndicators: false)` with `scrollTargetLayout()` for snap behavior
- **Card sizing:** Width calculated as `(screenWidth - horizontalPadding * 2 - interItemSpacing) / 2.15` so two cards are fully visible with a peek of the third
- **Content:** `CompactEventCard` instances, sorted by date ascending, future/today events only
- **Empty state:** Existing `EmptyStateView` with dice icon if no upcoming events

### 3.2 Home Tab Reset Behavior

When the Home tab bar button is tapped while already on the Home tab:
- Reset the `NavigationPath` to empty, popping back to root `HomeView`
- This ensures tapping Home always returns to the base Home page, even if the user is deep in an event detail or Calendar view

**Implementation:** Lift the `NavigationStack` out of `HomeView` (which currently owns it at line 10) and into `MainTabView`. `MainTabView` owns the `@State var homeNavigationPath: NavigationPath` and passes it as a binding to `HomeView`. Track selected tab — on Home tab tap, check if already selected; if so, set `homeNavigationPath` to empty. `HomeView` becomes a plain `ScrollView` content view without its own `NavigationStack`.

### 3.3 Sections Unchanged

- Header (greeting, notifications, chat icons)
- Drafts section (horizontal scroll of DraftCards)
- Pending Invites section (horizontal scroll of PendingInviteCards)
- Hosting section
- Recently Viewed section

---

## 4. Calendar View

`CalendarView` is pushed onto the Home `NavigationStack` via the "View all" button.

### 4.1 Header

- **Title:** Current month name ("March") — large, bold, top-left
- **Actions (top-right):**
  - Search icon (magnifying glass) — toggles search bar
  - Filter icon (line.3.horizontal.decrease) — opens filter sheet
  - "Today" button — scrolls to current month in grid mode, scrolls to today section in list mode

### 4.2 Calendar Grid Mode (Default)

- Standard 7-column grid layout (Sun–Sat headers)
- Swipe horizontally or vertically to navigate months
- **Today** highlighted with a subtle accent ring/background
- **Days with events** show:
  - A small (~16pt) SF Symbol icon based on primary game's `categories` field (the `Game` model has `categories: [String]`). Map the first matching category string:
    - Contains "Strategy" or "Board": `dice` icon
    - Contains "Card": `suit.spade` icon
    - Contains "Puzzle" or "Escape": `puzzlepiece` icon
    - Contains "Party" or "Social": `person.3` icon
    - Fallback (no match or no primary game): `gamecontroller` icon
  - A tiny RSVP-status colored dot underneath the icon:
    - Sage (success) = accepted/going
    - Terracotta (dateAccent) = pending/invited
    - Warning color = maybe
    - TextTertiary = declined/expired
- **Tapping a day** with events: scrolls to or expands a detail section below the grid showing `CompactEventCard`(s) for that day
- Days without events show just the date number

### 4.3 List Mode

Toggled via a floating button cluster in the bottom-right corner (two icons: calendar grid icon + list icon, active state indicated).

- **Chronological list** grouped by day headers (e.g. "Saturday March 21")
- Each event rendered as a `ListEventCard`
- **"Today" divider:** A horizontal line with "Today" label centered, separating past from future events
- **Auto-anchor:** On open, scrolls to the "Today" divider
- **Past events:** Shown above Today with slightly reduced opacity (~0.7)
- **Scrollable:** All events are loaded in-memory (CalendarViewModel fetches all events client-side), rendered in a single scrollable list — no pagination needed

### 4.4 Filter Sheet

Presented as a bottom sheet when the filter icon is tapped.

**Filter categories (checkboxes, all ON by default except "Not going"):**

| Category | Statuses Included |
|---|---|
| My events | Events where current user is host |
| Attending | accepted |
| Deciding | pending, maybe |
| Waiting on host | waitlisted |
| Not going (OFF by default) | declined, expired (InviteStatus values); also includes events with EventStatus.cancelled |

- **"Reset"** button (bottom-left) — restores defaults
- **"Done"** button (bottom-right) — applies filters and dismisses
- Filters apply to both grid and list modes

### 4.5 Search

- Tapping the search icon expands an inline search bar below the header
- Filters events by: event title, game name, host name
- Results shown in list format regardless of current mode
- Dismissing search returns to the previous mode

---

## 5. Data & ViewModel Considerations

### CalendarViewModel

- Fetches all events for the current user (hosted + invited)
- Groups events by date for grid display
- Manages filter state (set of active filter categories)
- Manages search query and filtered results
- Handles month navigation state
- Computes RSVP counts per event from invite data

### HomeViewModel Changes

- Existing `upcomingEvents` array is reused for the carousel
- No new data fetching needed — carousel uses the same events, just displayed differently
- Add "View all" navigation trigger

### Navigation Path

- `MainTabView` owns the `NavigationStack(path: $homeNavigationPath)` wrapping `HomeView`
- `HomeView` receives `homeNavigationPath` as a `Binding` — it no longer creates its own `NavigationStack`
- `CalendarView` is a navigation destination within that stack
- Event detail pages are also navigation destinations (already exist)
- Home tab reset clears `homeNavigationPath`

---

## 6. File Structure

```
Views/
  Home/
    HomeView.swift              (modified — carousel + view all)
  Calendar/
    CalendarView.swift          (new — main calendar container)
    CalendarGridView.swift      (new — month grid)
    CalendarListView.swift      (new — list mode)
    CalendarFilterSheet.swift   (new — filter bottom sheet)
    CalendarDayDetailView.swift (new — expanded day detail below grid)
  Components/
    EventCard.swift             (deprecated/replaced)
    CompactEventCard.swift      (new — carousel + calendar day card)
    ListEventCard.swift         (new — calendar list row card)
    EventCardBlocks/
      ComponentSize.swift       (new — size enum)
      EventDateLabel.swift      (new)
      EventLocationLabel.swift  (new)
      PlayerCountIndicator.swift(new)
      GameInfoCompact.swift     (new)
      HostBadge.swift           (new)
ViewModels/
  CalendarViewModel.swift       (new)
  HomeViewModel.swift           (modified)
App/
  ContentView.swift             (modified — home tab reset behavior)
```

---

## 7. Theme Usage

All new components use existing semantic colors from `Theme.Colors`:
- `dateAccent` (terracotta) for dates
- `success` (sage) for confirmed/going states
- `cardBackground` for card surfaces
- `textPrimary`, `textSecondary`, `textTertiary` for text hierarchy
- `highlight` (yellow) only for primary game star indicator
- `primaryAction` (sage) for CTA buttons like "Today", "Done"
- Status colors for RSVP indicators (existing `InviteStatus` color mapping)

No new colors or theme additions needed.
