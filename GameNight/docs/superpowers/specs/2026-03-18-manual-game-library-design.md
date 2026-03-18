# Manual Game Library Privacy and Editor UX

## Background
Manual games are currently created and edited inside a user's personal library, but the underlying `games` row is shared, so any designer/publisher or metadata edits can leak to other users. Meanwhile, guests of events that reference manual games still need to see those games, and we want to keep the existing BGG-backed rows untouched. We also want the manual editor to behave more like the BGG data (30-minute time ticks and specific recommended player ranges).

## Goals
1. Treat manual games as private per-user records that never affect the shared BGG catalogue, yet continue to reuse the existing `games` + `game_library` tables.
2. Allow guests of an event to view a manual game, but only let the owning user edit it (no one else can ever mutate that row).
3. Make the manual editor enforce 30-minute increments for min/max playtime and surface a recommender that lets the user select any combination of player counts within the min/max range.
4. Surface whether a game comes from the manual cache vs BGG in the UI (badge/label). No edit UI is shown for non-manual records.

## Data model changes
### `games` table
- Add nullable `owner_id UUID REFERENCES users(id)` and index on `(owner_id)`.
- Manual games are rows where `bgg_id` is `NULL` and `owner_id` matches the creating user. BGG rows keep `owner_id = NULL`.

### Row-Level Security
Update `games` policies so that:
- `SELECT` allows rows that are public (`owner_id IS NULL`) plus those owned by the current user or visible because the user is the host/invitee of an event that references the row. This keeps manual rows invisible to unrelated accounts while letting event guests read them.
- `INSERT` requires either the row to be an owned manual (owner_id = auth.uid()) or a shared record (owner_id IS NULL).
- `UPDATE` only allows modifications when `owner_id = auth.uid()` or the row has `owner_id IS NULL`. This protects manual rows from other users while still allowing BGG rows to be refreshed by any authenticated client.

### Migrations
Create a new migration that adds the `owner_id` column (default `NULL`), backfills existing rows, and adds the necessary policy/index changes.

## Application changes
### Models
- Extend `Game` with `ownerId: UUID?` and convenience properties like `isManual` and `isMutable(by:)`.
- Include `ownerId` in the decoder/encoder so `game_library` fetches can hydrate it.

### Services
- `SupabaseService.upsertGame` should send the `owner_id` with the payload when `game.bggId == nil` and the caller holds the current user ID.
- Manual creation flows (`GameLibraryViewModel.addManualGame`, `CreateEventViewModel.addManualGame`) must set `ownerId` to the session user.
- Downstream callers that mutate manual games (manual editor, event manual settings) must keep the owner ID intact so RLS recognizes the row belongs to the current session.

### Manual editor UX
- The manual editing sheet (GameDetail manual editor and the event creation manual settings) shows the owned manual badge and only enables editing when `game.isManual && game.ownerId == currentUserId`.
- The min/max playtime steppers increment by 30 minutes (range 30‑600) and clamp. Changing the min automatically bumps the max if needed.
- Directly beneath the player-count steppers, insert a `Recommended Players` chip group that defaults to the entire `[minPlayers...maxPlayers]` range when `recommendedPlayers` is `nil`. The user can toggle any individual count (e.g., select 1, 3, 4) and the resulting `[Int]?` is stored alongside the manual game.
- Update the display formatting `playerString(from:)`/`buildInfoRows` so the info row renders the selected set as ranges (e.g., `[1,3,4] -> "Best: 1, 3–4"`).

### Manual game visibility
- Non-manual games (BGG rows) do not show the editing controls.
- Manual games should continue to surface a `Manual Library Game` label in the detail hero metadata so users can see the difference.
- Event detail/guest views and library lists should render manual games identically except for the absence of edit controls for non-owners.

## Testing
1. Create a manual game, edit designers/publishers and save; verify the row’s `owner_id` equals that user and another user can’t access or edit it.
2. Add the manual game to an event, open the event as a guest/invitee, and confirm the game shows up in the event list and detail but the guest sees no edit controls.
3. Adjust min/max playtime to 30-minute increments and confirm the recommended players chips update when the range changes.
4. Save a recommendation such as `[1, 3, 4]` and ensure the info row renders `Best: 1, 3–4` once persisted.
5. Verify existing BGG rows remain editable from the shared cache (the old flows should still work after `owner_id` defaults to `NULL`).

## Next steps
1. Implement the migration and Supabase policy updates.
2. Extend the `Game` model and Supabase service to carry `ownerId`.
3. Update the manual edit flows and UI chips for recommended players and 30-minute playtime increments.
4. Add tests for privacy, guest visibility, and UI behavior.
