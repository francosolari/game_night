# Game Detail Pages, Library Suggestions & Calendar Description — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend game data model for BGG parity, build game/designer/publisher detail pages with push navigation, add library suggestions in event creation, and generate rich calendar event descriptions.

**Architecture:** MVVM with shared reusable components. New Supabase tables for game relationships (expansions, families). BGG XML parser extended for additional link types. NavigationStack push navigation replaces sheet presentation for game detail.

**Tech Stack:** SwiftUI, Supabase (PostgreSQL), BGG XML API v2, EventKit

**Design Spec:** `docs/superpowers/specs/2026-03-18-game-detail-library-calendar-design.md`

---

## File Map

### New Files
| File | Responsibility |
|------|----------------|
| `Supabase/migrations/20260318_game_detail_tables.sql` | Migration: new columns on `games`, new tables `game_expansions`, `game_families`, `game_family_members` |
| `GameNight/GameNight/Models/GameFamily.swift` | `GameFamily` and `GameFamilyMember` Codable structs |
| `GameNight/GameNight/Models/GameExpansion.swift` | `GameExpansion` Codable struct |
| `GameNight/GameNight/Views/Components/FlowLayout.swift` | Extracted `FlowLayout` from GameLibraryView |
| `GameNight/GameNight/Views/Components/GameDetail/DetailHeroImage.swift` | Hero image with badge overlay |
| `GameNight/GameNight/Views/Components/GameDetail/InfoRowGroup.swift` | `InfoRowData` + `InfoRow` + `InfoRowGroup` grouped card |
| `GameNight/GameNight/Views/Components/GameDetail/TagFlowSection.swift` | Tag flow section (replaces `TagSection` from GameLibraryView) |
| `GameNight/GameNight/Views/Components/GameDetail/HorizontalGameScroll.swift` | Horizontal scrollable game cards with NavigationLink per card |
| `GameNight/GameNight/Views/Components/GameDetail/ExpandableGameGrid.swift` | Expandable game list with sort, NavigationLink per row |
| `GameNight/GameNight/Views/Components/GameDetail/SortFilterBar.swift` | Sort/filter chip bar |
| `GameNight/GameNight/Views/Components/GameDetail/RatingBadge.swift` | BGG rating badge |
| `GameNight/GameNight/Models/SortOption.swift` | `SortOption` enum + `CreatorRole` enum + `CreatorDestination` (shared types used by ViewModels and Views) |
| `GameNight/GameNight/Views/GameLibrary/GameDetailView.swift` | Full game detail page (replaces GameDetailSheet) |
| `GameNight/GameNight/Views/GameLibrary/DesignerDetailView.swift` | Designer detail page |
| `GameNight/GameNight/Views/GameLibrary/PublisherDetailView.swift` | Publisher detail page |
| `GameNight/GameNight/Views/GameLibrary/CreatorDetailContent.swift` | Shared layout for designer/publisher detail pages |
| `GameNight/GameNight/ViewModels/GameDetailViewModel.swift` | ViewModel: expansions, families, base game |
| `GameNight/GameNight/ViewModels/CreatorDetailViewModel.swift` | Shared ViewModel for designer/publisher pages |

### Modified Files
| File | Changes |
|------|---------|
| `GameNight/GameNight/Models/Game.swift` | Add `designers`, `publishers`, `artists`, `minAge`, `bggRank` fields + custom `init(from:)` decoder + update previews |
| `GameNight/GameNight/Services/BGGService.swift` | Parse designers, publishers, artists, expansions, families, minAge, bggRank from XML |
| `GameNight/GameNight/Services/SupabaseService.swift` | Add expansion/family/designer/publisher fetch methods + `fetchGameLibrary` to `EventEditingProviding` |
| `GameNight/GameNight/ViewModels/CreateEventViewModel.swift` | Add `libraryGames`, `loadLibrary()`, `libraryAutocompleteResults` |
| `GameNight/GameNight/Views/GameLibrary/GameLibraryView.swift` | Replace `.sheet` with `NavigationLink`, remove `GameDetailSheet`/`StatBox`/`TagSection`, extract `FlowLayout` |
| `GameNight/GameNight/Views/Events/CreateEventSteps/CreateEventGamesStep.swift` | Add library suggestions section + autocomplete |
| `GameNight/GameNight/Views/Components/AddToCalendarButton.swift` | Add `games` param + `calendarNotes()` static method |
| `GameNight/GameNight/Views/Events/EventDetailView.swift` | Pass games array to `AddToCalendarButton` |
| `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift` | Add `fetchGameLibrary` to `StubEventEditorService` |

---

## Task 1: Supabase Migration — New Columns + Tables

**Files:**
- Create: `Supabase/migrations/20260318_game_detail_tables.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- 1. Add new columns to games table
ALTER TABLE games
  ADD COLUMN IF NOT EXISTS designers text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS publishers text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS artists text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS min_age int,
  ADD COLUMN IF NOT EXISTS bgg_rank int;

-- 2. Backfill existing rows
UPDATE games SET designers = '{}' WHERE designers IS NULL;
UPDATE games SET publishers = '{}' WHERE publishers IS NULL;
UPDATE games SET artists = '{}' WHERE artists IS NULL;

-- 3. Create game_expansions table
CREATE TABLE IF NOT EXISTS game_expansions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  base_game_id uuid NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  expansion_game_id uuid NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT game_expansions_no_self CHECK (base_game_id != expansion_game_id),
  CONSTRAINT game_expansions_unique UNIQUE (base_game_id, expansion_game_id)
);
CREATE INDEX IF NOT EXISTS idx_game_expansions_base ON game_expansions(base_game_id);
CREATE INDEX IF NOT EXISTS idx_game_expansions_expansion ON game_expansions(expansion_game_id);

-- 4. Create game_families table
CREATE TABLE IF NOT EXISTS game_families (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bgg_family_id int UNIQUE NOT NULL,
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- 5. Create game_family_members junction table
CREATE TABLE IF NOT EXISTS game_family_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES game_families(id) ON DELETE CASCADE,
  game_id uuid NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT game_family_members_unique UNIQUE (family_id, game_id)
);
CREATE INDEX IF NOT EXISTS idx_game_family_members_family ON game_family_members(family_id);
CREATE INDEX IF NOT EXISTS idx_game_family_members_game ON game_family_members(game_id);

-- 6. RLS policies
ALTER TABLE game_expansions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read game_expansions"
  ON game_expansions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert game_expansions"
  ON game_expansions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update game_expansions"
  ON game_expansions FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated users can delete game_expansions"
  ON game_expansions FOR DELETE TO authenticated USING (true);

ALTER TABLE game_families ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read game_families"
  ON game_families FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert game_families"
  ON game_families FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update game_families"
  ON game_families FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated users can delete game_families"
  ON game_families FOR DELETE TO authenticated USING (true);

ALTER TABLE game_family_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read game_family_members"
  ON game_family_members FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert game_family_members"
  ON game_family_members FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update game_family_members"
  ON game_family_members FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated users can delete game_family_members"
  ON game_family_members FOR DELETE TO authenticated USING (true);
```

- [ ] **Step 2: Apply migration via MCP**

Use `mcp__plugin_supabase_supabase__apply_migration` with the name `game_detail_tables` and the SQL above.

- [ ] **Step 3: Commit**

```bash
git add Supabase/migrations/20260318_game_detail_tables.sql
git commit -m "feat: add game detail tables migration (expansions, families, extended game fields)"
```

---

## Task 2: Extend Game Model + New Relationship Models

**Files:**
- Modify: `GameNight/GameNight/Models/Game.swift`
- Create: `GameNight/GameNight/Models/GameFamily.swift`
- Create: `GameNight/GameNight/Models/GameExpansion.swift`

- [ ] **Step 1: Add new fields to Game struct**

In `Game.swift`, add these properties after `mechanics`:

```swift
var designers: [String]
var publishers: [String]
var artists: [String]
var minAge: Int?
var bggRank: Int?
```

Add corresponding CodingKeys:

```swift
case designers
case publishers
case artists
case minAge = "min_age"
case bggRank = "bgg_rank"
```

- [ ] **Step 2: Add custom decoder to Game**

Add `init(from decoder: Decoder)` that uses `decodeIfPresent` with fallback to `[]` for `designers`, `publishers`, `artists`, and `decodeIfPresent` for `minAge`, `bggRank`. All existing fields decode as before. This is needed because existing cached data and un-backfilled rows may not have these columns.

```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    bggId = try container.decodeIfPresent(Int.self, forKey: .bggId)
    name = try container.decode(String.self, forKey: .name)
    yearPublished = try container.decodeIfPresent(Int.self, forKey: .yearPublished)
    thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
    imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
    minPlayers = try container.decodeIfPresent(Int.self, forKey: .minPlayers) ?? 1
    maxPlayers = try container.decodeIfPresent(Int.self, forKey: .maxPlayers) ?? 4
    recommendedPlayers = try container.decodeIfPresent([Int].self, forKey: .recommendedPlayers)
    minPlaytime = try container.decodeIfPresent(Int.self, forKey: .minPlaytime) ?? 30
    maxPlaytime = try container.decodeIfPresent(Int.self, forKey: .maxPlaytime) ?? 60
    complexity = try container.decodeIfPresent(Double.self, forKey: .complexity) ?? 0
    bggRating = try container.decodeIfPresent(Double.self, forKey: .bggRating)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
    mechanics = try container.decodeIfPresent([String].self, forKey: .mechanics) ?? []
    designers = try container.decodeIfPresent([String].self, forKey: .designers) ?? []
    publishers = try container.decodeIfPresent([String].self, forKey: .publishers) ?? []
    artists = try container.decodeIfPresent([String].self, forKey: .artists) ?? []
    minAge = try container.decodeIfPresent(Int.self, forKey: .minAge)
    bggRank = try container.decodeIfPresent(Int.self, forKey: .bggRank)
}
```

- [ ] **Step 3: Update Game.preview and Game.previewArk**

Add the new fields to both static preview instances:

```swift
designers: ["Paul Dennen"],
publishers: ["Dire Wolf"],
artists: ["Clay Brooks"],
minAge: 14,
bggRank: 6
```

- [ ] **Step 4: Update addManualGame in CreateEventViewModel**

The `addManualGame` method creates a `Game(...)` — add the new fields with defaults:

```swift
designers: [],
publishers: [],
artists: [],
minAge: nil,
bggRank: nil
```

- [ ] **Step 5: Create GameFamily.swift**

```swift
import Foundation

struct GameFamily: Identifiable, Codable, Hashable {
    let id: UUID
    var bggFamilyId: Int
    var name: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case bggFamilyId = "bgg_family_id"
        case name
        case createdAt = "created_at"
    }
}

struct GameFamilyMember: Identifiable, Codable {
    let id: UUID
    var familyId: UUID
    var gameId: UUID
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case gameId = "game_id"
        case createdAt = "created_at"
    }
}
```

- [ ] **Step 6: Create GameExpansion.swift**

```swift
import Foundation

struct GameExpansion: Identifiable, Codable {
    let id: UUID
    var baseGameId: UUID
    var expansionGameId: UUID
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case baseGameId = "base_game_id"
        case expansionGameId = "expansion_game_id"
        case createdAt = "created_at"
    }
}
```

- [ ] **Step 6.5: Search for all Game construction sites**

Run: `grep -rn "Game(" GameNight/GameNight/ --include="*.swift" | grep -v "Test" | grep -v ".build"` to find all `Game(...)` memberwise initializer calls. Each must be updated to include the new fields (`designers: [], publishers: [], artists: [], minAge: nil, bggRank: nil`). Known sites:
- `BGGService.swift` — `BGGGameDetailDelegate` (handled in Task 3)
- `CreateEventViewModel.swift` — `addManualGame` (handled in Step 4)
- `Game.swift` — `preview` and `previewArk` (handled in Step 3)

If additional construction sites are found, update them with the new default values.

- [ ] **Step 7: Build to verify compilation**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 8: Regenerate Xcode project and rebuild**

```bash
cd GameNight && xcodegen generate && cd ..
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 9: Commit**

```bash
git add GameNight/GameNight/Models/Game.swift GameNight/GameNight/Models/GameFamily.swift GameNight/GameNight/Models/GameExpansion.swift GameNight/GameNight/ViewModels/CreateEventViewModel.swift GameNight/project.yml
git commit -m "feat: extend Game model with BGG parity fields and add relationship models"
```

---

## Task 3: Extend BGG XML Parser

**Files:**
- Modify: `GameNight/GameNight/Services/BGGService.swift`

- [ ] **Step 1: Add new parsing fields to BGGGameDetailDelegate**

In `BGGGameDetailDelegate`, add instance variables:

```swift
private var designers: [String] = []
private var publishers: [String] = []
private var artists: [String] = []
private var minAge: Int?
private var bggRank: Int?
private var expansionBggIds: [(bggId: Int, name: String, isInbound: Bool)] = []
private var familyLinks: [(bggFamilyId: Int, name: String)] = []
```

Reset these in the `case "item":` start element (alongside existing resets for categories/mechanics). Add these explicit reset lines inside the `case "item":` `if attributeDict["type"] == "boardgame"` block:

```swift
designers = []
publishers = []
artists = []
minAge = nil
bggRank = nil
expansionBggIds = []
familyLinks = []
```

- [ ] **Step 2: Parse new link types in didStartElement**

In the `case "link":` handler, add:

```swift
if type == "boardgamedesigner" { designers.append(value) }
if type == "boardgamepublisher" { publishers.append(value) }
if type == "boardgameartist" { artists.append(value) }
if type == "boardgameexpansion", let bggId = Int(attributeDict["id"] ?? "") {
    let isInbound = attributeDict["inbound"] == "true"
    expansionBggIds.append((bggId: bggId, name: value, isInbound: isInbound))
}
if type == "boardgamefamily", let bggId = Int(attributeDict["id"] ?? "") {
    familyLinks.append((bggFamilyId: bggId, name: value))
}
```

- [ ] **Step 3: Parse minage and rank elements**

Add to `didStartElement`:

```swift
case "minage":
    if inItem { minAge = Int(attributeDict["value"] ?? "") }
case "rank":
    if inItem && attributeDict["name"] == "boardgame" {
        bggRank = Int(attributeDict["value"] ?? "")
    }
```

- [ ] **Step 4: Include new fields in Game construction**

In the `case "item":` end element, update the `Game(...)` constructor to include:

```swift
designers: designers,
publishers: publishers,
artists: artists,
minAge: minAge,
bggRank: bggRank
```

- [ ] **Step 5: Add parsed expansion/family data as a return type**

The BGG parser currently returns `[Game]`. We need the expansion and family link data too. Create a new struct:

```swift
struct BGGGameParseResult {
    let game: Game
    let expansionLinks: [(bggId: Int, name: String, isInbound: Bool)]
    let familyLinks: [(bggFamilyId: Int, name: String)]
}
```

Update `BGGGameDetailDelegate` to produce `[BGGGameParseResult]` instead of `[Game]`. Store the expansion/family data per-game.

Update `BGGXMLParser.parseMultipleGames` to return `[BGGGameParseResult]`. Add a convenience that extracts just `[Game]` for existing callers that don't need expansion data. Update `parseGameDetails` similarly.

Add a new method to `BGGService`:

```swift
func fetchGameDetailsWithRelations(bggId: Int) async throws -> BGGGameParseResult {
    let url = URL(string: "\(baseURL)/thing?id=\(bggId)&stats=1")!
    let (data, _) = try await session.data(from: url)
    let results = try BGGXMLParser.parseMultipleGamesWithRelations(data: data)
    guard let result = results.first else { throw BGGError.gameNotFound }
    return result
}
```

- [ ] **Step 6: Build to verify**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add GameNight/GameNight/Services/BGGService.swift
git commit -m "feat: extend BGG parser for designers, publishers, artists, expansions, families, minAge, bggRank"
```

---

## Task 4: SupabaseService — New Fetch Methods

**Files:**
- Modify: `GameNight/GameNight/Services/SupabaseService.swift`
- Modify: `GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift`

- [ ] **Step 1: Add fetchGameLibrary to EventEditingProviding protocol**

Add to the `EventEditingProviding` protocol:

```swift
func fetchGameLibrary() async throws -> [GameLibraryEntry]
```

- [ ] **Step 2: Add expansion/family/creator methods to SupabaseService**

Add these methods to `SupabaseService`:

```swift
// MARK: - Game Relations

func fetchExpansions(gameId: UUID) async throws -> [Game] {
    struct ExpansionLink: Decodable {
        let expansionGameId: String
        enum CodingKeys: String, CodingKey {
            case expansionGameId = "expansion_game_id"
        }
    }
    let links: [ExpansionLink] = try await client
        .from("game_expansions")
        .select("expansion_game_id")
        .eq("base_game_id", value: gameId.uuidString)
        .execute()
        .value
    guard !links.isEmpty else { return [] }
    let ids = links.map(\.expansionGameId)
    let games: [Game] = try await client
        .from("games")
        .select()
        .in("id", values: ids)
        .execute()
        .value
    return games
}

func fetchBaseGame(expansionGameId: UUID) async throws -> Game? {
    struct BaseLink: Decodable {
        let baseGameId: String
        enum CodingKeys: String, CodingKey {
            case baseGameId = "base_game_id"
        }
    }
    let links: [BaseLink] = try await client
        .from("game_expansions")
        .select("base_game_id")
        .eq("expansion_game_id", value: expansionGameId.uuidString)
        .execute()
        .value
    guard let link = links.first, let baseId = UUID(uuidString: link.baseGameId) else { return nil }
    let game: Game = try await client
        .from("games")
        .select()
        .eq("id", value: baseId.uuidString)
        .single()
        .execute()
        .value
    return game
}

func fetchFamilyMembers(gameId: UUID) async throws -> [(family: GameFamily, games: [Game])] {
    struct FamilyLink: Decodable {
        let familyId: String
        enum CodingKeys: String, CodingKey {
            case familyId = "family_id"
        }
    }
    let links: [FamilyLink] = try await client
        .from("game_family_members")
        .select("family_id")
        .eq("game_id", value: gameId.uuidString)
        .execute()
        .value
    guard !links.isEmpty else { return [] }

    // Fetch all families in parallel
    return try await withThrowingTaskGroup(of: (GameFamily, [Game]).self) { group in
        for link in links {
            group.addTask {
                let family: GameFamily = try await self.client
                    .from("game_families")
                    .select()
                    .eq("id", value: link.familyId)
                    .single()
                    .execute()
                    .value

                struct MemberLink: Decodable {
                    let gameId: String
                    enum CodingKeys: String, CodingKey {
                        case gameId = "game_id"
                    }
                }
                let memberLinks: [MemberLink] = try await self.client
                    .from("game_family_members")
                    .select("game_id")
                    .eq("family_id", value: link.familyId)
                    .execute()
                    .value
                let memberIds = memberLinks.map(\.gameId)
                let games: [Game] = try await self.client
                    .from("games")
                    .select()
                    .in("id", values: memberIds)
                    .execute()
                    .value
                return (family, games)
            }
        }

        var results: [(family: GameFamily, games: [Game])] = []
        for try await (family, games) in group {
            results.append((family: family, games: games))
        }
        return results
    }
}

private struct ExpansionLinkInsert: Encodable {
    let baseGameId: UUID
    let expansionGameId: UUID
    enum CodingKeys: String, CodingKey {
        case baseGameId = "base_game_id"
        case expansionGameId = "expansion_game_id"
    }
}

func upsertExpansionLinks(baseGameId: UUID, expansionGameIds: [UUID]) async throws {
    guard !expansionGameIds.isEmpty else { return }
    let inserts = expansionGameIds.map { ExpansionLinkInsert(baseGameId: baseGameId, expansionGameId: $0) }
    try await client
        .from("game_expansions")
        .upsert(inserts, onConflict: "base_game_id,expansion_game_id")
        .execute()
}

func upsertFamilyLinks(gameId: UUID, families: [(bggFamilyId: Int, name: String)]) async throws {
    for family in families {
        // Upsert family
        let familyEntry: [String: AnyJSON] = [
            "bgg_family_id": .int(family.bggFamilyId),
            "name": .string(family.name)
        ]
        let upsertedFamily: GameFamily = try await client
            .from("game_families")
            .upsert(familyEntry, onConflict: "bgg_family_id")
            .select()
            .single()
            .execute()
            .value

        // Upsert member link
        let memberEntry: [String: AnyJSON] = [
            "family_id": .string(upsertedFamily.id.uuidString),
            "game_id": .string(gameId.uuidString)
        ]
        try await client
            .from("game_family_members")
            .upsert(memberEntry, onConflict: "family_id,game_id")
            .execute()
    }
}

func fetchGamesByDesigner(name: String) async throws -> [Game] {
    let games: [Game] = try await client
        .from("games")
        .select()
        .filter("designers", operator: .cs, value: "{\"\(name)\"}")
        .order("bgg_rating", ascending: false)
        .limit(50)
        .execute()
        .value
    return games
}

func fetchGamesByPublisher(name: String) async throws -> [Game] {
    let games: [Game] = try await client
        .from("games")
        .select()
        .filter("publishers", operator: .cs, value: "{\"\(name)\"}")
        .order("bgg_rating", ascending: false)
        .limit(50)
        .execute()
        .value
    return games
}
```

- [ ] **Step 3: Add fetchGameLibrary stub to test service**

In `CreateEventViewModelTests.swift`, add to `StubEventEditorService`:

```swift
func fetchGameLibrary() async throws -> [GameLibraryEntry] {
    []
}
```

- [ ] **Step 4: Build + run tests**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add GameNight/GameNight/Services/SupabaseService.swift GameNight/GameNightTests/ViewModels/CreateEventViewModelTests.swift
git commit -m "feat: add Supabase methods for expansions, families, and creator queries"
```

---

## Task 5: Extract FlowLayout + Create Reusable Components

**Files:**
- Create: `GameNight/GameNight/Views/Components/FlowLayout.swift`
- Create: `GameNight/GameNight/Views/Components/GameDetail/DetailHeroImage.swift`
- Create: `GameNight/GameNight/Views/Components/GameDetail/InfoRowGroup.swift`
- Create: `GameNight/GameNight/Views/Components/GameDetail/HorizontalGameScroll.swift`
- Create: `GameNight/GameNight/Views/Components/GameDetail/ExpandableGameGrid.swift`
- Create: `GameNight/GameNight/Views/Components/GameDetail/SortFilterBar.swift`
- Create: `GameNight/GameNight/Views/Components/GameDetail/RatingBadge.swift`
- Modify: `GameNight/GameNight/Views/GameLibrary/GameLibraryView.swift` (remove FlowLayout, TagSection, StatBox)

- [ ] **Step 1: Extract FlowLayout to its own file**

Create `Views/Components/FlowLayout.swift` with the `FlowLayout` struct (currently at GameLibraryView.swift:531-571). Copy the struct verbatim.

- [ ] **Step 2: Create RatingBadge**

```swift
import SwiftUI

enum BadgeSize {
    case small, medium, large

    var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }

    var padding: EdgeInsets {
        switch self {
        case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
        case .medium: return EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        case .large: return EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        }
    }
}

struct RatingBadge: View {
    let rating: Double
    var size: BadgeSize = .medium

    var body: some View {
        Text(String(format: "%.1f", rating))
            .font(.system(size: size.fontSize, weight: .black))
            .foregroundColor(.white)
            .padding(size.padding)
            .background(
                RoundedRectangle(cornerRadius: size == .small ? 6 : 12)
                    .fill(Theme.Colors.success)
            )
    }
}
```

- [ ] **Step 3: Create DetailHeroImage**

```swift
import SwiftUI

struct DetailHeroImage: View {
    let imageUrl: String?
    var badge: Double?
    var fallbackInitials: String?
    var gradientColors: [Color] = [Theme.Colors.accent.opacity(0.5), Theme.Colors.primary.opacity(0.5)]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipped()
                } placeholder: {
                    fallbackView
                }
            } else {
                fallbackView
            }

            if let badge {
                RatingBadge(rating: badge, size: .large)
                    .padding(Theme.Spacing.lg)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
    }

    private var fallbackView: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if let initials = fallbackInitials {
                Text(initials)
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
    }
}
```

- [ ] **Step 4: Create InfoRowGroup**

Uses a data struct (`InfoRowData`) separate from the view (`InfoRow`) for proper MVVM separation:

```swift
import SwiftUI

struct InfoRowData: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
    var detail: String?
    var detailColor: Color?
}

struct InfoRow: View {
    let data: InfoRowData

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: data.icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 28)

            Text(data.value)
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)

            if let detail = data.detail {
                Text(detail)
                    .font(Theme.Typography.caption)
                    .foregroundColor(data.detailColor ?? Theme.Colors.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }
}

struct InfoRowGroup: View {
    let rows: [InfoRowData]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, rowData in
                InfoRow(data: rowData)
                if index < rows.count - 1 {
                    Divider()
                        .background(Theme.Colors.textTertiary.opacity(0.15))
                        .padding(.leading, 28 + Theme.Spacing.md + Theme.Spacing.lg)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.backgroundElevated)
        )
    }
}
```

- [ ] **Step 5: Create TagFlowSection**

In the same `Views/Components/GameDetail/` directory, this replaces the old `TagSection`:

Create in `InfoRowGroup.swift` or a separate file — keep it in `InfoRowGroup.swift` for simplicity since it's small:

Actually, create `Views/Components/GameDetail/TagFlowSection.swift`:

```swift
import SwiftUI

struct TagFlowSection: View {
    let title: String
    let tags: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .chipStyle(color: color)
                }
            }
        }
    }
}
```

- [ ] **Step 6: Create HorizontalGameScroll**

```swift
import SwiftUI

struct HorizontalGameScroll: View {
    let title: String
    let games: [Game]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !title.isEmpty {
                Text(title)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .textCase(.uppercase)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(games) { game in
                        NavigationLink(value: game) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                GameThumbnail(url: game.thumbnailUrl, size: 80)

                                Text(game.name)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(2)

                                if let year = game.yearPublished {
                                    Text(String(year))
                                        .font(Theme.Typography.caption2)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                            }
                            .frame(width: 100)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 6.5: Create shared type definitions (SortOption, CreatorRole, CreatorDestination)**

Create `GameNight/GameNight/Models/SortOption.swift`:

```swift
import Foundation

enum SortOption: String, CaseIterable, Identifiable, Hashable {
    case topRated = "Top Rated"
    case byYear = "By Year"
    case byWeight = "By Weight"

    var id: String { rawValue }
}

enum CreatorRole: String, Hashable {
    case designer = "Game Designer"
    case publisher = "Publisher"
}

struct CreatorDestination: Hashable {
    let name: String
    let role: CreatorRole
}
```

These types are used by ViewModels (`CreatorDetailViewModel`) and Views (`SortFilterBar`, `GameDetailView`), so they belong in the Models layer.

- [ ] **Step 7: Create SortFilterBar**

```swift
import SwiftUI

struct SortFilterBar: View {
    let options: [SortOption]
    @Binding var selected: SortOption

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(options) { option in
                    Button {
                        selected = option
                    } label: {
                        Text(option.rawValue)
                            .chipStyle(
                                color: Theme.Colors.primary,
                                isSelected: selected == option
                            )
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 8: Create ExpandableGameGrid**

```swift
import SwiftUI

struct ExpandableGameGrid: View {
    let games: [Game]
    var initialCount: Int = 5
    let sortMode: SortOption
    @State private var isExpanded = false

    private var sortedGames: [Game] {
        switch sortMode {
        case .topRated:
            return games.sorted { ($0.bggRating ?? 0) > ($1.bggRating ?? 0) }
        case .byYear:
            return games.sorted { ($0.yearPublished ?? 0) > ($1.yearPublished ?? 0) }
        case .byWeight:
            return games.sorted { $0.complexity > $1.complexity }
        }
    }

    private var displayedGames: [Game] {
        isExpanded ? sortedGames : Array(sortedGames.prefix(initialCount))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(displayedGames) { game in
                NavigationLink(value: game) {
                    HStack(spacing: Theme.Spacing.md) {
                        GameThumbnail(url: game.thumbnailUrl, size: 48)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.name)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)

                            HStack(spacing: Theme.Spacing.sm) {
                                if let year = game.yearPublished {
                                    Text(String(year))
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                                Text(String(format: "%.1f", game.complexity))
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }

                        Spacer()

                        if let rating = game.bggRating {
                            RatingBadge(rating: rating, size: .small)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.backgroundElevated)
                    )
                }
                .buttonStyle(.plain)
            }

            if !isExpanded && sortedGames.count > initialCount {
                Button {
                    withAnimation { isExpanded = true }
                } label: {
                    Text("Show All \(sortedGames.count) Games")
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.primary.opacity(0.1))
                        )
                }
            }
        }
    }
}
```

- [ ] **Step 9: Remove FlowLayout, TagSection, StatBox from GameLibraryView**

In `GameLibraryView.swift`, delete:
- `FlowLayout` struct (lines 531-571) — now in `FlowLayout.swift`
- `TagSection` struct (lines 508-528) — replaced by `TagFlowSection`
- `StatBox` struct (lines 482-506) — replaced by `InfoRowGroup`

Update imports if needed. The `GameDetailSheet` reference (`.sheet(item: $selectedGame) { game in GameDetailSheet(game: game) }`) stays for now — it gets replaced in Task 7.

- [ ] **Step 10: Verify project.yml covers new GameDetail/ subdirectory**

Check `GameNight/project.yml` — the `sources` section uses `path: GameNight` which recursively includes all Swift files. The new `Views/Components/GameDetail/` subdirectory is automatically covered. If `project.yml` ever switches to explicit directory listing, this subdirectory would need to be added.

- [ ] **Step 11: Regenerate project, build, test**

```bash
cd GameNight && xcodegen generate && cd ..
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 12: Commit**

```bash
git add GameNight/GameNight/Views/Components/FlowLayout.swift GameNight/GameNight/Views/Components/GameDetail/ GameNight/GameNight/Views/GameLibrary/GameLibraryView.swift GameNight/project.yml
git commit -m "feat: extract FlowLayout and create reusable game detail components"
```

---

## Task 6: GameDetailViewModel + CreatorDetailViewModel

**Files:**
- Create: `GameNight/GameNight/ViewModels/GameDetailViewModel.swift`
- Create: `GameNight/GameNight/ViewModels/CreatorDetailViewModel.swift`

- [ ] **Step 1: Create GameDetailViewModel**

```swift
import Foundation
// NOTE: CreatorRole is defined in Models/SortOption.swift

@MainActor
final class GameDetailViewModel: ObservableObject {
    @Published var game: Game
    @Published var expansions: [Game] = []
    @Published var baseGame: Game?
    @Published var families: [(family: GameFamily, games: [Game])] = []
    @Published var isLoading = true

    private let supabase: SupabaseService

    init(game: Game, supabase: SupabaseService = .shared) {
        self.game = game
        self.supabase = supabase
    }

    func loadRelatedData() async {
        isLoading = true
        async let expansionsResult = supabase.fetchExpansions(gameId: game.id)
        async let baseGameResult = supabase.fetchBaseGame(expansionGameId: game.id)
        async let familiesResult = supabase.fetchFamilyMembers(gameId: game.id)

        do {
            expansions = try await expansionsResult
            baseGame = try await baseGameResult
            families = try await familiesResult
        } catch {
            // Non-critical — detail page still shows game info
        }
        isLoading = false
    }
}
```

- [ ] **Step 2: Create CreatorDetailViewModel**

```swift
import Foundation

@MainActor
final class CreatorDetailViewModel: ObservableObject {
    @Published var name: String
    @Published var role: CreatorRole
    @Published var games: [Game] = []
    @Published var isLoading = true
    @Published var sortMode: SortOption = .topRated
    @Published var isExpanded = false

    private let supabase: SupabaseService
    private var hasMoreGames = false

    var displayedGames: [Game] {
        let sorted: [Game]
        switch sortMode {
        case .topRated:
            sorted = games.sorted { ($0.bggRating ?? 0) > ($1.bggRating ?? 0) }
        case .byYear:
            sorted = games.sorted { ($0.yearPublished ?? 0) > ($1.yearPublished ?? 0) }
        case .byWeight:
            sorted = games.sorted { $0.complexity > $1.complexity }
        }
        return isExpanded ? sorted : Array(sorted.prefix(5))
    }

    var showExpandButton: Bool {
        !isExpanded && (games.count > 5 || hasMoreGames)
    }

    var subtitle: String {
        "\(role.rawValue) · \(games.count)\(hasMoreGames ? "+" : "") games"
    }

    var averageRating: Double? {
        let rated = games.compactMap(\.bggRating)
        guard !rated.isEmpty else { return nil }
        return rated.reduce(0, +) / Double(rated.count)
    }

    var averageWeight: Double? {
        let weights = games.map(\.complexity).filter { $0 > 0 }
        guard !weights.isEmpty else { return nil }
        return weights.reduce(0, +) / Double(weights.count)
    }

    init(name: String, role: CreatorRole, supabase: SupabaseService = .shared) {
        self.name = name
        self.role = role
        self.supabase = supabase
    }

    func loadGames() async {
        isLoading = true
        do {
            switch role {
            case .designer:
                games = try await supabase.fetchGamesByDesigner(name: name)
            case .publisher:
                games = try await supabase.fetchGamesByPublisher(name: name)
            }
            hasMoreGames = games.count == 50
        } catch {
            // Non-critical
        }
        isLoading = false
    }

    func loadAllGames() async {
        // Re-fetch without limit — requires adding unlimited fetch methods
        // For now, the initial 50 is sufficient
        isExpanded = true
    }
}
```

- [ ] **Step 3: Regenerate project, build**

```bash
cd GameNight && xcodegen generate && cd ..
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add GameNight/GameNight/ViewModels/GameDetailViewModel.swift GameNight/GameNight/ViewModels/CreatorDetailViewModel.swift GameNight/project.yml
git commit -m "feat: add GameDetailViewModel and CreatorDetailViewModel"
```

---

## Task 7: GameDetailView + Navigation Refactor

**Files:**
- Create: `GameNight/GameNight/Views/GameLibrary/GameDetailView.swift`
- Modify: `GameNight/GameNight/Views/GameLibrary/GameLibraryView.swift`

- [ ] **Step 1: Create GameDetailView**

Full game detail page following Layout B from spec. Structure (top to bottom):
1. `DetailHeroImage` with rating badge
2. Title cluster with designer/publisher as `NavigationLink`
3. `InfoRowGroup` with players, time, weight, age
4. `TagFlowSection` for categories and mechanics
5. Expandable description
6. "Expansion for [Base Game]" link (if applicable)
7. "Part of [Family]" link (if applicable)
8. `HorizontalGameScroll` for expansions

```swift
import SwiftUI

struct GameDetailView: View {
    @StateObject private var viewModel: GameDetailViewModel
    @State private var isDescriptionExpanded = false

    init(game: Game) {
        _viewModel = StateObject(wrappedValue: GameDetailViewModel(game: game))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // 1. Hero image with rating badge
                DetailHeroImage(
                    imageUrl: viewModel.game.imageUrl,
                    badge: viewModel.game.bggRating
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // 2. Title cluster
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(viewModel.game.name)
                            .font(Theme.Typography.displayMedium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        HStack(spacing: Theme.Spacing.sm) {
                            if let designer = viewModel.game.designers.first {
                                NavigationLink(value: CreatorDestination(name: designer, role: .designer)) {
                                    Text(designer)
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                            if let publisher = viewModel.game.publishers.first {
                                if !viewModel.game.designers.isEmpty {
                                    Text("·")
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                                NavigationLink(value: CreatorDestination(name: publisher, role: .publisher)) {
                                    Text(publisher)
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                            if let year = viewModel.game.yearPublished {
                                Text("·")
                                    .foregroundColor(Theme.Colors.textTertiary)
                                Text(String(year))
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }
                    }

                    // 3. Info rows
                    InfoRowGroup(rows: buildInfoRows())

                    // 4. Tags
                    if !viewModel.game.categories.isEmpty {
                        TagFlowSection(title: "Categories", tags: viewModel.game.categories, color: Theme.Colors.primary)
                    }
                    if !viewModel.game.mechanics.isEmpty {
                        TagFlowSection(title: "Mechanics", tags: viewModel.game.mechanics, color: Theme.Colors.accent)
                    }

                    // 5. Description
                    if let desc = viewModel.game.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(desc)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(isDescriptionExpanded ? nil : 3)

                            Button(isDescriptionExpanded ? "Show less" : "Read more") {
                                withAnimation { isDescriptionExpanded.toggle() }
                            }
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(Theme.Colors.primary)
                        }
                    }

                    // 6. Base game link
                    if let baseGame = viewModel.baseGame {
                        NavigationLink(value: baseGame) {
                            HStack {
                                Image(systemName: "arrow.turn.up.left")
                                    .foregroundColor(Theme.Colors.accent)
                                Text("Expansion for \(baseGame.name)")
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundColor(Theme.Colors.accent)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.backgroundElevated)
                            )
                        }
                    }

                    // 7. Family links
                    ForEach(viewModel.families, id: \.family.id) { familyData in
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Part of \(familyData.family.name)")
                                .font(Theme.Typography.label)
                                .foregroundColor(Theme.Colors.textTertiary)
                                .textCase(.uppercase)

                            HorizontalGameScroll(
                                title: "",
                                games: familyData.games.filter { $0.id != viewModel.game.id }
                            )
                        }
                    }

                    // 8. Expansions
                    if !viewModel.expansions.isEmpty {
                        HorizontalGameScroll(
                            title: "Expansions",
                            games: viewModel.expansions
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding(.bottom, 100)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // NOTE: .navigationDestination is registered in GameLibraryView's NavigationStack, not here
        .task {
            await viewModel.loadRelatedData()
        }
    }

    private func buildInfoRows() -> [InfoRowData] {
        var rows: [InfoRowData] = []

        // Players
        let bestStr = viewModel.game.recommendedPlayers.map { recs in
            recs.isEmpty ? nil : "Best: \(recs.map(String.init).joined(separator: "–"))"
        } ?? nil
        rows.append(InfoRowData(
            icon: "person.2.fill",
            label: "Players",
            value: viewModel.game.playerCountDisplay,
            detail: bestStr,
            detailColor: Theme.Colors.success
        ))

        // Playtime
        rows.append(InfoRowData(
            icon: "clock.fill",
            label: "Time",
            value: viewModel.game.playtimeDisplay
        ))

        // Weight
        rows.append(InfoRowData(
            icon: "scalemass.fill",
            label: "Weight",
            value: String(format: "%.2f / 5", viewModel.game.complexity),
            detail: viewModel.game.complexityLabel,
            detailColor: Theme.Colors.warning
        ))

        // Age
        if let age = viewModel.game.minAge {
            rows.append(InfoRowData(
                icon: "number.circle",
                label: "Age",
                value: "Ages \(age)+"
            ))
        }

        return rows
    }
}
// NOTE: CreatorDestination and CreatorRole are defined in Models/SortOption.swift
```

- [ ] **Step 2: Refactor GameLibraryView — replace sheet with NavigationLink**

In `GameLibraryView.swift`:
1. Remove `@State private var selectedGame: Game?`
2. Remove `.sheet(item: $selectedGame) { game in GameDetailSheet(game: game) }`
3. Remove the entire `GameDetailSheet` struct
4. Change `GameCard(game: game, onTap: { selectedGame = game })` to wrap in `NavigationLink`:

```swift
NavigationLink(value: game) {
    GameCard(game: game, onTap: {})
}
.buttonStyle(.plain)
```

5. Add all `.navigationDestination` modifiers to the `NavigationStack` in `GameLibraryView` — these must be registered exactly once at the stack level, NOT inside child destination views:

```swift
.navigationDestination(for: Game.self) { game in
    GameDetailView(game: game)
}
.navigationDestination(for: CreatorDestination.self) { dest in
    if dest.role == .designer {
        DesignerDetailView(name: dest.name)
    } else {
        PublisherDetailView(name: dest.name)
    }
}
```

**Important:** Do NOT add `.navigationDestination` inside `GameDetailView`, `DesignerDetailView`, `PublisherDetailView`, or `CreatorDetailContent`. SwiftUI requires a single registration per type per NavigationStack. Duplicate registrations cause runtime warnings and undefined behavior on iOS 17+.

- [ ] **Step 3: Regenerate, build**

```bash
cd GameNight && xcodegen generate && cd ..
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add GameNight/GameNight/Views/GameLibrary/GameDetailView.swift GameNight/GameNight/Views/GameLibrary/GameLibraryView.swift GameNight/project.yml
git commit -m "feat: add GameDetailView with push navigation, replace sheet in GameLibraryView"
```

---

## Task 8: Designer + Publisher Detail Pages

**Files:**
- Create: `GameNight/GameNight/Views/GameLibrary/DesignerDetailView.swift`
- Create: `GameNight/GameNight/Views/GameLibrary/PublisherDetailView.swift`

- [ ] **Step 1: Create DesignerDetailView**

```swift
import SwiftUI

struct DesignerDetailView: View {
    @StateObject private var viewModel: CreatorDetailViewModel

    init(name: String) {
        _viewModel = StateObject(wrappedValue: CreatorDetailViewModel(name: name, role: .designer))
    }

    var body: some View {
        CreatorDetailContent(viewModel: viewModel)
            .task { await viewModel.loadGames() }
    }
}
```

- [ ] **Step 2: Create PublisherDetailView**

```swift
import SwiftUI

struct PublisherDetailView: View {
    @StateObject private var viewModel: CreatorDetailViewModel

    init(name: String) {
        _viewModel = StateObject(wrappedValue: CreatorDetailViewModel(name: name, role: .publisher))
    }

    var body: some View {
        CreatorDetailContent(viewModel: viewModel)
            .task { await viewModel.loadGames() }
    }
}
```

- [ ] **Step 3: Create shared CreatorDetailContent**

Put this in either DesignerDetailView.swift or a shared file. It's the common layout:

```swift
struct CreatorDetailContent: View {
    @ObservedObject var viewModel: CreatorDetailViewModel

    private var initials: String {
        viewModel.name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // 1. Hero with initials
                DetailHeroImage(
                    imageUrl: nil,
                    fallbackInitials: initials,
                    gradientColors: [Theme.Colors.accent.opacity(0.6), Theme.Colors.primary.opacity(0.4)]
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // 2. Title
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(viewModel.name)
                            .font(Theme.Typography.displayMedium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text(viewModel.subtitle)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }

                    // 3. Stats
                    if !viewModel.games.isEmpty {
                        InfoRowGroup(rows: buildStatsRows())
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Theme.Colors.primary)
                            .frame(maxWidth: .infinity)
                    } else if viewModel.games.isEmpty {
                        Text("No games found in the database yet.")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textTertiary)
                    } else {
                        // 4. Sort bar
                        SortFilterBar(
                            options: SortOption.allCases,
                            selected: $viewModel.sortMode
                        )

                        // 5. Game grid
                        ExpandableGameGrid(
                            games: viewModel.games,
                            sortMode: viewModel.sortMode
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding(.bottom, 100)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // NOTE: .navigationDestination is registered in GameLibraryView's NavigationStack, not here
    }

    private func buildStatsRows() -> [InfoRowData] {
        var rows: [InfoRowData] = []
        if let avg = viewModel.averageRating {
            rows.append(InfoRowData(
                icon: "star.fill",
                label: "Avg. Rating",
                value: String(format: "Avg. Rating: %.1f", avg)
            ))
        }
        if let avgWeight = viewModel.averageWeight {
            rows.append(InfoRowData(
                icon: "scalemass.fill",
                label: "Avg. Weight",
                value: String(format: "Avg. Weight: %.1f / 5", avgWeight)
            ))
        }
        return rows
    }
}
```

- [ ] **Step 4: Regenerate, build**

```bash
cd GameNight && xcodegen generate && cd ..
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add GameNight/GameNight/Views/GameLibrary/DesignerDetailView.swift GameNight/GameNight/Views/GameLibrary/PublisherDetailView.swift GameNight/project.yml
git commit -m "feat: add Designer and Publisher detail pages with shared CreatorDetailContent"
```

---

## Task 9: Library Suggestions in CreateEventGamesStep

**Files:**
- Modify: `GameNight/GameNight/ViewModels/CreateEventViewModel.swift`
- Modify: `GameNight/GameNight/Views/Events/CreateEventSteps/CreateEventGamesStep.swift`

- [ ] **Step 1: Add library properties to CreateEventViewModel**

Add after the `manualGameName` property:

```swift
@Published var libraryGames: [Game] = []
```

Add `loadLibrary()` method:

```swift
func loadLibrary() async {
    do {
        let entries = try await supabase.fetchGameLibrary()
        libraryGames = entries.compactMap(\.game)
    } catch {
        // Non-critical
    }
}
```

Add computed property:

```swift
var libraryAutocompleteResults: [Game] {
    guard !manualGameName.isEmpty else { return [] }
    let query = manualGameName.lowercased()
    return libraryGames.filter { $0.name.lowercased().contains(query) }
}
```

- [ ] **Step 2: Add library suggestions UI to CreateEventGamesStep**

After the manual entry section and before the search results, add:

```swift
// Library autocomplete (when typing)
if !viewModel.libraryAutocompleteResults.isEmpty {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        Text("From Library")
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.accent)

        ForEach(viewModel.libraryAutocompleteResults.prefix(4)) { game in
            Button {
                let eventGame = EventGame(
                    id: UUID(),
                    gameId: game.id,
                    game: game,
                    isPrimary: viewModel.selectedGames.isEmpty,
                    sortOrder: viewModel.selectedGames.count
                )
                viewModel.selectedGames.append(eventGame)
                viewModel.manualGameName = ""
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    GameThumbnail(url: game.thumbnailUrl, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.name)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        if let year = game.yearPublished {
                            Text("(\(String(year)))")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    Spacer()
                    Text("Library")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.Colors.accent.opacity(0.12)))
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.backgroundElevated)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
```

After the search results section and before the selected games section, add the "From Your Library" suggestions section:

```swift
// From Your Library section (when no games selected)
if viewModel.selectedGames.isEmpty && !viewModel.libraryGames.isEmpty && viewModel.manualGameName.isEmpty {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        Text("From Your Library")
            .font(Theme.Typography.headlineMedium)
            .foregroundColor(Theme.Colors.textPrimary)

        ForEach(viewModel.libraryGames.prefix(6)) { game in
            Button {
                let eventGame = EventGame(
                    id: UUID(),
                    gameId: game.id,
                    game: game,
                    isPrimary: viewModel.selectedGames.isEmpty,
                    sortOrder: viewModel.selectedGames.count
                )
                viewModel.selectedGames.append(eventGame)
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    GameThumbnail(url: game.thumbnailUrl, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.name)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        if let year = game.yearPublished {
                            Text("(\(String(year)))")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    Spacer()
                    Image(systemName: "plus.circle")
                        .foregroundColor(Theme.Colors.primary)
                }
                .padding(Theme.Spacing.sm)
            }
            .buttonStyle(.plain)
        }
    }
}
```

Add `.task { await viewModel.loadLibrary() }` to the `CreateEventGamesStep` body.

- [ ] **Step 3: Build + run tests**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

- [ ] **Step 4: Commit**

```bash
git add GameNight/GameNight/ViewModels/CreateEventViewModel.swift GameNight/GameNight/Views/Events/CreateEventSteps/CreateEventGamesStep.swift
git commit -m "feat: add library suggestions and autocomplete in CreateEventGamesStep"
```

---

## Task 10: Calendar Event Description

**Files:**
- Modify: `GameNight/GameNight/Views/Components/AddToCalendarButton.swift`
- Modify: `GameNight/GameNight/Views/Events/EventDetailView.swift`

- [ ] **Step 1: Add games parameter and calendarNotes builder to AddToCalendarButton**

Add a new parameter after `notes`:

```swift
var games: [EventGame] = []
var hostName: String?
```

Add a static method:

```swift
static func calendarNotes(
    title: String,
    games: [EventGame],
    description: String?,
    hostName: String?
) -> String {
    var lines: [String] = []

    if let primary = games.first(where: { $0.isPrimary })?.game?.name ?? games.first?.game?.name {
        lines.append("Game Night: \(primary)")
        let others = games.filter { ($0.game?.name ?? "") != primary }.compactMap(\.game?.name)
        if !others.isEmpty {
            lines.append("Also playing: \(others.joined(separator: ", "))")
        }
    } else {
        lines.append("Game Night")
    }

    if let description, !description.isEmpty {
        lines.append("")
        lines.append(description)
    }

    lines.append("")
    if let hostName {
        lines.append("Hosted by \(hostName) on CardboardWithMe")
    } else {
        lines.append("Hosted on CardboardWithMe")
    }

    return lines.joined(separator: "\n")
}
```

Update the body to use `calendarNotes` for all calendar outputs — replace `notes` references with the generated notes:

```swift
private var resolvedNotes: String {
    Self.calendarNotes(title: title, games: games, description: notes, hostName: hostName)
}
```

Use `resolvedNotes` in `CalendarEventComposer`, Google Calendar URL builder, and ICS generator instead of `notes`.

- [ ] **Step 2: Update EventDetailView to pass games and host**

In `EventDetailView.swift`, update the `AddToCalendarButton` call (around line 167):

```swift
AddToCalendarButton(
    title: event.title,
    startDate: timeOption.startTime,
    endDate: timeOption.endTime,
    location: event.locationAddress ?? event.location,
    notes: event.description,
    games: event.games,
    hostName: event.host?.displayName
)
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add GameNight/GameNight/Views/Components/AddToCalendarButton.swift GameNight/GameNight/Views/Events/EventDetailView.swift
git commit -m "feat: generate rich calendar event descriptions with games and host info"
```

---

## Task 11: Final Build Verification + Test Run

- [ ] **Step 1: Regenerate Xcode project**

```bash
cd GameNight && xcodegen generate && cd ..
```

- [ ] **Step 2: Full build**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -10
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild -project GameNight/GameNight.xcodeproj -scheme GameNight -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 2 pre-existing test failures (`testCanProceedGamesStepRequiresSelectedGames`, `testCanProceedInvitesStepRequiresInvitees`). No new failures.

- [ ] **Step 4: Fix any compilation or test issues**

- [ ] **Step 5: Final commit if needed**

```bash
git add -A
git commit -m "chore: final adjustments for game detail feature"
```
