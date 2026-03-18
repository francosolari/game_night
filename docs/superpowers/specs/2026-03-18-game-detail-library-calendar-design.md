# Design: Game Detail Pages, Library Suggestions, Calendar Description

**Date:** 2026-03-18
**Status:** Approved
**Scope:** Extended game data model, game/designer/publisher detail pages, library suggestions in event creation, calendar event description generation

---

## 1. Data Model — BGG Parity + Game Relationships

### 1a. Extend `Game` model

Add new fields to `Game` struct and `games` Supabase table:

| Field | Type | Description |
|-------|------|-------------|
| `designers` | `[String]` | Game designer names from BGG |
| `publishers` | `[String]` | Publisher names from BGG |
| `artists` | `[String]` | Artist names from BGG |
| `minAge` | `Int?` | Minimum recommended age |
| `bggRank` | `Int?` | Overall BGG rank |

New columns in `games` table: `designers text[] default '{}'`, `publishers text[] default '{}'`, `artists text[] default '{}'`, `min_age int`, `bgg_rank int`.

**Migration must backfill existing rows:** `UPDATE games SET designers = '{}' WHERE designers IS NULL; UPDATE games SET publishers = '{}' WHERE publishers IS NULL; UPDATE games SET artists = '{}' WHERE artists IS NULL;` — the `DEFAULT` only applies to new inserts.

**Swift Codable safety:** `designers`, `publishers`, and `artists` decode with `decodeIfPresent` and fallback to `[]` to handle rows that haven't been backfilled or pre-existing cached data. **Note:** The current `Game` struct has no custom `init(from decoder:)` — one must be added, handling all 17+ existing fields plus the new ones. This is a non-trivial but mechanical change.

### 1b. New Supabase tables

**`game_expansions`** — Links base games to their expansions.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK, default gen_random_uuid() |
| `base_game_id` | `uuid` | FK → games(id) ON DELETE CASCADE |
| `expansion_game_id` | `uuid` | FK → games(id) ON DELETE CASCADE |
| `created_at` | `timestamptz` | default now() |

Unique constraint on `(base_game_id, expansion_game_id)`. CHECK constraint: `base_game_id != expansion_game_id`. Indexes on `base_game_id` and `expansion_game_id`.

**`game_families`** — BGG family/series metadata.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK, default gen_random_uuid() |
| `bgg_family_id` | `int` | UNIQUE, NOT NULL |
| `name` | `text` | NOT NULL |
| `created_at` | `timestamptz` | default now() |

**`game_family_members`** — Junction: games ↔ families.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK, default gen_random_uuid() |
| `family_id` | `uuid` | FK → game_families(id) ON DELETE CASCADE |
| `game_id` | `uuid` | FK → games(id) ON DELETE CASCADE |
| `created_at` | `timestamptz` | default now() |

Unique constraint on `(family_id, game_id)`. Indexes on `family_id` and `game_id`.

### 1c. BGG XML Parser Changes

Parse additional `<link>` types from BGG's `/thing` endpoint:

| BGG link type | Maps to |
|--------------|---------|
| `boardgamedesigner` | `designers` array on Game |
| `boardgamepublisher` | `publishers` array on Game |
| `boardgameartist` | `artists` array on Game |
| `boardgameexpansion` | Insert into `game_expansions`. On a base game's page, expansion links have NO `inbound` attribute → the linked game is the expansion (`expansion_game_id`). On an expansion's page, the base game link has `inbound="true"` → the linked game is the base (`base_game_id`). Store the BGG ID of the linked game; the actual `games` row may not exist yet — upsert a stub row into `games` with just `bgg_id` and `name` (from the link's `value` attribute), then create the expansion link. The stub gets fully populated when the user navigates to that game's detail page. |
| `boardgamefamily` | Insert into `game_families` + `game_family_members` |

Also parse:
- `<minage value="14"/>` → `minAge`
- `<ranks><rank type="subtype" name="boardgame" value="6"/></ranks>` → `bggRank`

### 1d. SupabaseService additions

- `fetchExpansions(gameId: UUID) async throws -> [Game]` — fetch expansion games for a base game
- `fetchBaseGame(expansionGameId: UUID) async throws -> Game?` — fetch the base game for an expansion
- `fetchFamilyMembers(gameId: UUID) async throws -> [(family: GameFamily, games: [Game])]` — fetch series/family games
- `upsertExpansionLinks(baseGameId: UUID, expansionGameIds: [UUID]) async throws`
- `upsertFamilyLinks(gameId: UUID, families: [(bggFamilyId: Int, name: String)]) async throws`
- `fetchGamesByDesigner(name: String) async throws -> [Game]` — uses PostgreSQL `@>` (contains) operator on `text[]` column: `.filter("designers", operator: .cs, value: "{\"" + name + "\"}")`
- `fetchGamesByPublisher(name: String) async throws -> [Game]` — same approach with `publishers` column

---

### 1e. RLS Policies for New Tables

All three tables (`game_expansions`, `game_families`, `game_family_members`) contain public game metadata, not user-private data:
- **SELECT**: Allow for all authenticated users (public read).
- **INSERT/UPDATE/DELETE**: Allow for authenticated users (any authenticated user can trigger an upsert when fetching a game from BGG).

### 1f. Migration Checklist

The migration file must:
1. Add new columns to `games` with defaults
2. Backfill existing rows with empty arrays
3. Create `game_expansions`, `game_families`, `game_family_members` tables
4. Add CHECK constraints and indexes on FK columns
5. Enable RLS and create policies on all three new tables

---

## 2. Game Detail Page

### Layout: "Rating Badge + Stacked Info Rows" (Layout B)

Full-screen NavigationLink destination (not a sheet — enables push navigation for expansions/designers/publishers).

**Structure top to bottom:**

1. **HeroImageHeader** — Full-width game box art (`imageUrl`). BGG rating as a floating green badge (bottom-left overlay).
2. **Title cluster** — Game name (displayMedium), designer and publisher as accent-colored NavigationLinks, year in textTertiary.
3. **InfoRowGroup** — Grouped card with SF Symbol icon rows:
   - `person.2.fill` — "1–4 Players" with "Best: 3–4" in success color
   - `clock.fill` — "60–120 min"
   - `scalemass.fill` — "3.08 / 5" in complexity color with label (e.g. "Medium-Heavy")
   - `number.circle` — "Ages 14+"
4. **TagFlowSection** — Categories (primary color chips) and mechanics (accent color chips) using FlowLayout.
5. **Description** — Expandable text, truncated to 3 lines with "Read more".
6. **"Expansion for [Base Game]"** — Only shown if this game is an expansion. NavigationLink to base game.
7. **"Part of [Family Name]"** — If game belongs to a BGG family. NavigationLink to a filtered list of family games.
8. **HorizontalGameScroll** — "Expansions" section. Each card: thumbnail, name, year. Tappable → pushes that game's detail page.

### SF Symbol mapping

| Data | SF Symbol |
|------|-----------|
| Players | `person.2.fill` |
| Play time | `clock.fill` |
| Complexity/Weight | `scalemass.fill` |
| Age | `number.circle` |
| Rating | `star.fill` |
| Designer | `pencil.and.outline` |
| Publisher | `building.2` |
| Year | `calendar` |

---

## 3. Designer & Publisher Detail Pages

Same structural layout, using shared reusable components.

**Structure:**

1. **HeroImageHeader** — Gradient background with initials avatar (no image available from BGG). Accent color gradient.
2. **Title** — Name (displayMedium), role subtitle ("Game Designer · 12 games" or "Publisher · 45 games").
3. **InfoRowGroup** — Stats:
   - `star.fill` — "Avg. Rating: 7.8"
   - `scalemass.fill` — "Avg. Weight: 2.9 / 5"
4. **SortFilterBar** — Horizontal chips: "Top Rated" (default), "By Year", "By Weight". Tapping re-sorts the game list.
5. **ExpandableGameGrid** — Top 5 games by BGG rating in compact rows (thumbnail, name, year, weight, rating badge). "Show All X Games" button expands to full list inline.

Each game row is a NavigationLink → game detail page.

---

## 4. Reusable Components

All placed in `Views/Components/GameDetail/`:

| Component | Props | Used By |
|-----------|-------|---------|
| `DetailHeroImage` | `imageUrl: String?`, `badge: String?`, `fallbackInitials: String?`, `gradientColors: [Color]` | Game, Designer, Publisher pages |
| `InfoRow` | `icon: String`, `label: String`, `value: String`, `detail: String?`, `detailColor: Color?` | All detail pages |
| `InfoRowGroup` | `rows: [InfoRow]` | All detail pages |
| `HorizontalGameScroll` | `title: String`, `games: [Game]`, `onSelect: (Game) -> Void` | Game page (expansions), Family list |
| `TagFlowSection` | `title: String`, `tags: [String]`, `color: Color` | Game page. Replaces existing `TagSection` from GameLibraryView. |
| `ExpandableGameGrid` | `games: [Game]`, `initialCount: Int`, `sortMode: SortMode`, `onSelect: (Game) -> Void` | Designer, Publisher pages |
| `SortFilterBar` | `options: [SortOption]`, `selected: Binding<SortOption>` | Designer, Publisher pages |
| `RatingBadge` | `rating: Double`, `size: BadgeSize` | Game rows, hero overlay |

---

## 5. ViewModels for Detail Pages

### GameDetailViewModel

Manages async loading for the game detail page:
- `@Published var game: Game` (passed in on init)
- `@Published var expansions: [Game] = []`
- `@Published var baseGame: Game?`
- `@Published var families: [(family: GameFamily, games: [Game])] = []`
- `@Published var isLoading = true`
- `loadRelatedData()` — fetches expansions, base game, and families in parallel

### CreatorDetailViewModel

Shared ViewModel for both Designer and Publisher detail pages:
- `@Published var name: String`
- `@Published var role: CreatorRole` (enum: `.designer`, `.publisher`)
- `@Published var games: [Game] = []`
- `@Published var isLoading = true`
- `@Published var sortMode: SortMode = .topRated`
- `@Published var isExpanded = false`
- `var displayedGames: [Game]` — computed, returns sorted + limited (top 5 or all if expanded)
- `loadGames()` — fetches via `fetchGamesByDesigner` or `fetchGamesByPublisher`
- For prolific creators (700+ games), the Supabase query should `ORDER BY bgg_rating DESC NULLS LAST LIMIT 50` to keep initial load fast. If exactly 50 results are returned, show the "Show All" button. Tapping it fetches without limit. This avoids an extra COUNT query.

---

## 6. Library Suggestions in CreateEventGamesStep

### 6a. Library games section (below manual entry)

When `selectedGames` is empty, show a "From Your Library" section below the manual entry field:
- Load user's game library on appear via `SupabaseService.fetchGameLibrary()`
- Display up to 6 games as compact rows (GameThumbnail + name + year)
- Tapping a library game adds it directly to `selectedGames` (uses the full Game record)
- Section hides once at least one game is selected
- If the user has zero games in their library, do not show the section header at all

### 6b. Autocomplete from library

When typing in the manual game name field:
- Filter the loaded library entries by name (case-insensitive contains)
- Show matching library games as suggestions above BGG search results
- Styled distinctly with a "From Library" label
- Selecting a match adds the full game record directly (same as 5a)
- If no library match, manual entry and BGG search work as before

### ViewModel changes

- Add `libraryGames: [Game]` property to `CreateEventViewModel`
- Add `loadLibrary()` method that fetches via `SupabaseService.fetchGameLibrary()` and extracts the Game objects
- Add `libraryAutocompleteResults` computed property filtering by `manualGameName`
- Add protocol method `fetchGameLibrary() async throws -> [GameLibraryEntry]` to `EventEditingProviding`

---

## 7. Calendar Event Description

Update `AddToCalendarButton` to generate a description from event data.

**Format:**

Single game:
```
Game Night: Dune: Imperium

Hosted by Alex on CardboardWithMe
```

Multiple games:
```
Game Night: Dune: Imperium
Also playing: Ark Nova, Clank!

Hosted by Alex on CardboardWithMe
```

No games:
```
Game Night

Hosted by Alex on CardboardWithMe
```

The host's display name is always included when available (from `event.host?.displayName`). Falls back to "Hosted on CardboardWithMe" when host info is unavailable.

The event's own `description` field, if present, is appended after the game info and before the boilerplate.

### Implementation

Add a static method or computed property that builds the notes string from the event's title, games array, and description. Pass this as the `notes` parameter to `AddToCalendarButton` instead of just `event.description`.

---

## 8. Navigation Architecture

The current `GameDetailSheet` is presented as a `.sheet`. This needs to change to a `NavigationLink` destination to support push navigation chains (game → designer → game → expansion).

- `GameLibraryView` wraps content in `NavigationStack` (already does)
- Replace `.sheet(item: $selectedGame)` with `NavigationLink` on each `GameCard`
- `GameDetailView` (renamed from `GameDetailSheet`) becomes a regular view pushed onto the stack
- Designer/Publisher taps push `DesignerDetailView` / `PublisherDetailView` onto the same stack
- Expansion taps push another `GameDetailView`

---

## 9. Files to Create

| File | Purpose |
|------|---------|
| `Views/Components/GameDetail/DetailHeroImage.swift` | Hero image with badge overlay |
| `Views/Components/GameDetail/InfoRowGroup.swift` | Grouped info rows component |
| `Views/Components/GameDetail/HorizontalGameScroll.swift` | Horizontal game card scroll |
| `Views/Components/GameDetail/ExpandableGameGrid.swift` | Expandable game list with sort |
| `Views/Components/GameDetail/SortFilterBar.swift` | Sort/filter chip bar |
| `Views/Components/GameDetail/RatingBadge.swift` | BGG rating badge |
| `Views/GameLibrary/GameDetailView.swift` | Full game detail page (replaces GameDetailSheet) |
| `Views/GameLibrary/DesignerDetailView.swift` | Designer detail page |
| `Views/GameLibrary/PublisherDetailView.swift` | Publisher detail page |
| `Models/GameFamily.swift` | GameFamily + GameFamilyMember models |
| `Models/GameExpansion.swift` | GameExpansion model |
| `ViewModels/GameDetailViewModel.swift` | ViewModel for game detail page (expansions, families, base game) |
| `ViewModels/CreatorDetailViewModel.swift` | Shared ViewModel for designer/publisher pages |
| `Views/Components/FlowLayout.swift` | Extract FlowLayout from GameLibraryView into reusable file |

## 10. Files to Modify

| File | Changes |
|------|---------|
| `Models/Game.swift` | Add designers, publishers, artists, minAge, bggRank fields + CodingKeys. Update `Game.preview` and `Game.previewArk` with new fields. |
| `Services/BGGService.swift` | Parse designers, publishers, artists, expansions, families, minAge, bggRank from XML |
| `Services/SupabaseService.swift` | Add expansion/family/designer/publisher fetch methods. Add `fetchGameLibrary` to `EventEditingProviding` protocol. |
| `ViewModels/CreateEventViewModel.swift` | Add libraryGames, loadLibrary(), libraryAutocompleteResults |
| `ViewModels/GameLibraryViewModel.swift` | No changes needed (already loads library) |
| `Views/GameLibrary/GameLibraryView.swift` | Replace sheet with NavigationLink, remove GameDetailSheet + StatBox + TagSection (replaced by reusable components), extract FlowLayout to own file |
| `Views/Events/CreateEventSteps/CreateEventGamesStep.swift` | Add library suggestions section + autocomplete |
| `Views/Components/AddToCalendarButton.swift` | Accept games array, generate description |
| `Views/Events/EventDetailView.swift` | Pass games to AddToCalendarButton |
| `GameNightTests/ViewModels/CreateEventViewModelTests.swift` | Add fetchGameLibrary to test stub |
| `Supabase/migrations/` | New migration for game_expansions, game_families, game_family_members tables + new columns on games |
