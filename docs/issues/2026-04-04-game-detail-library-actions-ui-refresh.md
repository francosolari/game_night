# Game Detail Library Actions: UI Not Updating Reliably

## Date
2026-04-04

## Summary
From the Game Detail screen on iOS, `Add to Wishlist` / `Add to Collection` mutations succeed in Supabase, but visual feedback can fail or lag. In the same session, detail loading also became slow and reported query timeout on relation refresh.

## Symptoms
- User taps wishlist/collection controls and data changes persist, but pills/badges do not reliably update.
- Intermittent long load on Game Detail.
- Console included:
  - `canceling statement due to statement timeout`
  - `AttributeGraph: cycle detected...`
  - `Modifying state during view update...`
  - `Publishing changes from within view updates is not allowed...`

## Confirmed From Logs
- Toggle actions executed successfully:
  - wishlist add/remove IDs returned
  - collection add ID returned
  - wishlist removed when moving to collection
- State refresh eventually resolved correct values (e.g. `isInCollection=true`, `isInWishlist=false`).

## Likely Root Causes
- SwiftUI view update cycle / identity churn on Game Detail causing state publication during rendering.
- Additional async relation refresh round-trip can stall under DB timeout.
- UI state and loading tasks may race when navigating rapidly between game details.

## What Was Reverted For Stability/Speed
- Removed troubleshooting debug prints from Game Detail actions/view model.
- Removed extra inline success-message state (`actionMessage`).
- Removed second post-hydration relation refresh pass in `loadRelatedData` to avoid timeout-prone extra query wave.
- Restored faster concurrent library/wishlist state fetch in `refreshLibraryState`.

## Next Investigation (deferred)
1. Reproduce on a clean branch with minimal instrumentation only around view identity/lifecycle.
2. Inspect navigation/path identity for repeated `GameDetailView` instantiation.
3. Audit any mutations occurring synchronously during render paths.
4. Add UI-level test (or snapshot-state test harness) for immediate pill state transition after successful toggle.
