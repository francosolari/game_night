import Foundation

struct GameEvent: Identifiable, Codable {
    let id: UUID
    var hostId: UUID
    var host: User?
    var title: String
    var description: String?
    var location: String?
    var locationAddress: String?
    var status: EventStatus
    var games: [EventGame]
    var timeOptions: [TimeOption]
    var confirmedTimeOptionId: UUID?
    var allowTimeSuggestions: Bool
    var inviteStrategy: InviteStrategy
    var minPlayers: Int
    var maxPlayers: Int?
    var coverImageUrl: String?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case host
        case title
        case description
        case location
        case locationAddress = "location_address"
        case status
        case games
        case timeOptions = "time_options"
        case confirmedTimeOptionId = "confirmed_time_option_id"
        case allowTimeSuggestions = "allow_time_suggestions"
        case inviteStrategy = "invite_strategy"
        case minPlayers = "min_players"
        case maxPlayers = "max_players"
        case coverImageUrl = "cover_image_url"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Only encode columns that exist on the events table (skip related objects)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(hostId, forKey: .hostId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(locationAddress, forKey: .locationAddress)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(confirmedTimeOptionId, forKey: .confirmedTimeOptionId)
        try container.encode(allowTimeSuggestions, forKey: .allowTimeSuggestions)
        try container.encode(inviteStrategy, forKey: .inviteStrategy)
        try container.encode(minPlayers, forKey: .minPlayers)
        try container.encodeIfPresent(maxPlayers, forKey: .maxPlayers)
        try container.encodeIfPresent(coverImageUrl, forKey: .coverImageUrl)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Intentionally skip: host, games, timeOptions — these are related tables, not columns
    }
}

enum EventStatus: String, Codable {
    case draft
    case published
    case confirmed    // Time and players locked in
    case inProgress = "in_progress"
    case completed
    case cancelled
}

// MARK: - Event Game (game attached to an event)
struct EventGame: Identifiable, Codable, Hashable {
    let id: UUID
    var gameId: UUID
    var game: Game?
    var isPrimary: Bool // Star indicator
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case game
        case isPrimary = "is_primary"
        case sortOrder = "sort_order"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(gameId, forKey: .gameId)
        try container.encode(isPrimary, forKey: .isPrimary)
        try container.encode(sortOrder, forKey: .sortOrder)
        // Skip: game — it's a joined relation, not a column
    }
}

// MARK: - Invite Strategy
struct InviteStrategy: Codable {
    var type: InviteType
    var tierSize: Int?       // How many in first tier
    var autoPromote: Bool    // Auto-invite next tier on decline

    enum InviteType: String, Codable {
        case allAtOnce = "all_at_once"
        case tiered
    }
}

// MARK: - Time Options
struct TimeOption: Identifiable, Codable, Hashable {
    let id: UUID
    var eventId: UUID?
    var date: Date
    var startTime: Date
    var endTime: Date?
    var label: String?  // e.g. "Monday Evening", "Tuesday Night"
    var isSuggested: Bool  // true if suggested by invitee
    var suggestedBy: UUID?
    var voteCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case label
        case isSuggested = "is_suggested"
        case suggestedBy = "suggested_by"
        case voteCount = "vote_count"
    }

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: startTime)
        if let endTime {
            return "\(start) - \(formatter.string(from: endTime))"
        }
        return start
    }
}

// MARK: - Preview Data
extension GameEvent {
    static let preview = GameEvent(
        id: UUID(),
        hostId: UUID(),
        host: nil,
        title: "Dune Imperium Night",
        description: "Let's play some Dune! Bringing snacks and drinks.",
        location: "Alex's Place",
        locationAddress: "123 Main St",
        status: .published,
        games: [
            EventGame(id: UUID(), gameId: UUID(), game: .preview, isPrimary: true, sortOrder: 0),
            EventGame(id: UUID(), gameId: UUID(), game: .previewArk, isPrimary: false, sortOrder: 1)
        ],
        timeOptions: [],
        confirmedTimeOptionId: nil,
        allowTimeSuggestions: true,
        inviteStrategy: InviteStrategy(type: .tiered, tierSize: 3, autoPromote: true),
        minPlayers: 3,
        maxPlayers: 4,
        coverImageUrl: nil,
        deletedAt: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
}
