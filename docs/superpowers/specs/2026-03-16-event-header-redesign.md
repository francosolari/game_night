# Design Spec: Event Header Date & Time Redesign

Redesign the event header to prominently display the date, start time, and relative "time away" indicator directly next to the event title.

## Goals
- Improve visibility of event scheduling information at the top of the event page.
- Provide clear relative time context (e.g., "3 days away", "1 month away").
- Clean up the hero header layout by integrating disparate date/time elements.

## Proposed Changes

### 1. View Model / Data Layer
- **Relative Time Logic**: Add a helper to `Date` or `TimeOption` to calculate the distance from today.
  - If < 30 days: `X days away` (with special cases for "Today" and "Tomorrow").
  - If >= 30 days: `X month(s) away`.
- **Date Formatting**: Ensure "Mon, Mar 16" style formatting is available.

### 2. EventDetailView (EventHeroHeader)
- **Title Row**:
  - Display the event title followed by the date and start time.
  - Format: `[Title] • [Day], [Month] [Day] • [Time]`
  - Font: `headlineMedium` (size 18), larger than status pills (size 11).
- **Relative Time Row**:
  - Add a secondary line below the title/date row for the "X days away" indicator.
  - Font: `callout` or `subheadline`, slightly muted color.
- **Layout Cleanup**:
  - The current `DateBadge` (calendar style) will be kept in the code but hidden/removed from the active layout to reduce clutter, as requested for A/B testing.
  - The existing location line will remain but without the redundant time display.

### 3. Testing & Verification
- Verify layout on various screen sizes (SE to Pro Max).
- Test date logic with mock events:
  - Event today.
  - Event tomorrow.
  - Event in 15 days.
  - Event in 45 days.

## Trade-offs & Considerations
- **Space**: Long titles might cause the date/time to wrap or truncate. We will prioritize the title but ensure the date remains legible.
- **A/B Testing**: The `DateBadge` component and its injection point in the header will be preserved in the codebase for easy restoration if preferred later.

## Approval
- [ ] User Approved
