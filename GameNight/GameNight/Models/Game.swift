import Foundation

struct Game: Identifiable, Codable, Hashable {
    let id: UUID
    var ownerId: UUID?
    var bggId: Int?
    var name: String
    var yearPublished: Int?
    var thumbnailUrl: String?
    var imageUrl: String?
    var minPlayers: Int
    var maxPlayers: Int
    var recommendedPlayers: [Int]? // From BGG poll data
    var minPlaytime: Int  // minutes
    var maxPlaytime: Int  // minutes
    var complexity: Double // BGG weight 1.0-5.0
    var bggRating: Double?
    var description: String?
    var categories: [String]
    var mechanics: [String]
    var designers: [String]
    var publishers: [String]
    var artists: [String]
    var minAge: Int?
    var bggRank: Int?
    var bggLastSynced: Date?

    var isManual: Bool {
        bggId == nil && ownerId != nil
    }

    func isEditable(by userId: UUID?) -> Bool {
        isManual && ownerId == userId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case bggId = "bgg_id"
        case name
        case yearPublished = "year_published"
        case thumbnailUrl = "thumbnail_url"
        case imageUrl = "image_url"
        case minPlayers = "min_players"
        case maxPlayers = "max_players"
        case recommendedPlayers = "recommended_players"
        case minPlaytime = "min_playtime"
        case maxPlaytime = "max_playtime"
        case complexity
        case bggRating = "bgg_rating"
        case description
        case categories
        case mechanics
        case designers
        case publishers
        case artists
        case minAge = "min_age"
        case bggRank = "bgg_rank"
        case bggLastSynced = "bgg_last_synced"
    }

    init(
        id: UUID,
        ownerId: UUID? = nil,
        bggId: Int? = nil,
        name: String,
        yearPublished: Int? = nil,
        thumbnailUrl: String? = nil,
        imageUrl: String? = nil,
        minPlayers: Int = 1,
        maxPlayers: Int = 4,
        recommendedPlayers: [Int]? = nil,
        minPlaytime: Int = 30,
        maxPlaytime: Int = 60,
        complexity: Double = 0,
        bggRating: Double? = nil,
        description: String? = nil,
        categories: [String] = [],
        mechanics: [String] = [],
        designers: [String] = [],
        publishers: [String] = [],
        artists: [String] = [],
        minAge: Int? = nil,
        bggRank: Int? = nil,
        bggLastSynced: Date? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.bggId = bggId
        self.name = name
        self.yearPublished = yearPublished
        self.thumbnailUrl = thumbnailUrl
        self.imageUrl = imageUrl
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.recommendedPlayers = recommendedPlayers
        self.minPlaytime = minPlaytime
        self.maxPlaytime = maxPlaytime
        self.complexity = complexity
        self.bggRating = bggRating
        self.description = description
        self.categories = categories
        self.mechanics = mechanics
        self.designers = designers
        self.publishers = publishers
        self.artists = artists
        self.minAge = minAge
        self.bggRank = bggRank
        self.bggLastSynced = bggLastSynced
    }

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
        ownerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId)
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
        bggLastSynced = try container.decodeIfPresent(Date.self, forKey: .bggLastSynced)
    }

    var playerCountDisplay: String {
        if minPlayers == maxPlayers {
            return "\(minPlayers) players"
        }
        return "\(minPlayers)-\(maxPlayers) players"
    }

    var playtimeDisplay: String {
        if minPlaytime == maxPlaytime {
            return "\(minPlaytime) min"
        }
        return "\(minPlaytime)-\(maxPlaytime) min"
    }

    var complexityLabel: String {
        Theme.Colors.complexityLabel(complexity)
    }

    static func formatPlayerRanges(_ values: [Int]?) -> String? {
        guard let values = values, !values.isEmpty else { return nil }
        let sorted = Array(Set(values)).sorted()
        var ranges: [String] = []
        var rangeStart = sorted[0]
        var rangeEnd = rangeStart

        for value in sorted.dropFirst() {
            if value == rangeEnd + 1 {
                rangeEnd = value
            } else {
                ranges.append(rangeStart == rangeEnd ? "\(rangeStart)" : "\(rangeStart)–\(rangeEnd)")
                rangeStart = value
                rangeEnd = value
            }
        }
        ranges.append(rangeStart == rangeEnd ? "\(rangeStart)" : "\(rangeStart)–\(rangeEnd)")
        return ranges.joined(separator: ", ")
    }

    static let preview = Game(
        id: UUID(),
        bggId: 397598,
        name: "Dune: Imperium",
        yearPublished: 2020,
        thumbnailUrl: nil,
        imageUrl: nil,
        minPlayers: 1,
        maxPlayers: 4,
        recommendedPlayers: [3, 4],
        minPlaytime: 60,
        maxPlaytime: 120,
        complexity: 3.04,
        bggRating: 8.3,
        description: "Deck-building meets worker placement in the world of Dune.",
        categories: ["Science Fiction", "Strategy"],
        mechanics: ["Deck Building", "Worker Placement"],
        designers: ["Paul Dennen"],
        publishers: ["Dire Wolf"],
        artists: ["Clay Brooks"],
        minAge: 14,
        bggRank: 6
    )

    static let previewArk = Game(
        id: UUID(),
        bggId: 342942,
        name: "Ark Nova",
        yearPublished: 2021,
        thumbnailUrl: nil,
        imageUrl: nil,
        minPlayers: 1,
        maxPlayers: 4,
        recommendedPlayers: [3],
        minPlaytime: 90,
        maxPlaytime: 150,
        complexity: 3.71,
        bggRating: 8.5,
        description: "Build a modern zoo to support conservation projects.",
        categories: ["Animals", "Strategy"],
        mechanics: ["Hand Management", "Card Drafting"],
        designers: ["Mathias Wigge"],
        publishers: ["Capstone Games"],
        artists: ["Loïc Billiau"],
        minAge: 14,
        bggRank: 7
    )
}

// MARK: - Game Library
struct GameLibraryEntry: Identifiable, Codable {
    let id: UUID
    var userId: UUID
    var gameId: UUID
    var game: Game?
    var categoryId: UUID?
    var notes: String?
    var rating: Int? // User's personal rating
    var playCount: Int
    var addedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case gameId = "game_id"
        case game
        case categoryId = "category_id"
        case notes
        case rating
        case playCount = "play_count"
        case addedAt = "added_at"
    }
}

struct GameCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var userId: UUID
    var name: String
    var icon: String? // SF Symbol name
    var sortOrder: Int
    var isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case icon
        case sortOrder = "sort_order"
        case isDefault = "is_default"
    }

    static let defaultCategories = [
        "Favorites",
        "Strategy",
        "Party Games",
        "Co-op",
        "Two Player",
        "Family",
        "Quick Games",
        "Campaign / Legacy"
    ]
}

// MARK: - BGG Search Result
struct BGGSearchResult: Identifiable, Codable, Hashable {
    let id: Int // BGG ID
    let name: String
    let yearPublished: Int?
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "bgg_id"
        case name
        case yearPublished = "year_published"
        case thumbnailUrl = "thumbnail_url"
    }
}
