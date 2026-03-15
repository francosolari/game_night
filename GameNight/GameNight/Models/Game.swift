import Foundation

struct Game: Identifiable, Codable, Hashable {
    let id: UUID
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

    enum CodingKeys: String, CodingKey {
        case id
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
        mechanics: ["Deck Building", "Worker Placement"]
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
        mechanics: ["Hand Management", "Card Drafting"]
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
struct BGGSearchResult: Identifiable, Hashable {
    let id: Int // BGG ID
    let name: String
    let yearPublished: Int?
    let thumbnailUrl: String?
}
