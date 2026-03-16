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
    var scheduleMode: ScheduleMode
    var inviteStrategy: InviteStrategy
    var minPlayers: Int
    var maxPlayers: Int?
    var allowGameVoting: Bool
    var confirmedGameId: UUID?
    var coverImageUrl: String?
    var draftInvitees: [DraftInvitee]?
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
        case scheduleMode = "schedule_mode"
        case inviteStrategy = "invite_strategy"
        case minPlayers = "min_players"
        case maxPlayers = "max_players"
        case allowGameVoting = "allow_game_voting"
        case confirmedGameId = "confirmed_game_id"
        case coverImageUrl = "cover_image_url"
        case draftInvitees = "draft_invitees"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        hostId: UUID,
        host: User? = nil,
        title: String,
        description: String? = nil,
        location: String? = nil,
        locationAddress: String? = nil,
        status: EventStatus,
        games: [EventGame],
        timeOptions: [TimeOption],
        confirmedTimeOptionId: UUID? = nil,
        allowTimeSuggestions: Bool,
        scheduleMode: ScheduleMode,
        inviteStrategy: InviteStrategy,
        minPlayers: Int,
        maxPlayers: Int? = nil,
        allowGameVoting: Bool = false,
        confirmedGameId: UUID? = nil,
        coverImageUrl: String? = nil,
        draftInvitees: [DraftInvitee]? = nil,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.hostId = hostId
        self.host = host
        self.title = title
        self.description = description
        self.location = location
        self.locationAddress = locationAddress
        self.status = status
        self.games = games
        self.timeOptions = timeOptions
        self.confirmedTimeOptionId = confirmedTimeOptionId
        self.allowTimeSuggestions = allowTimeSuggestions
        self.scheduleMode = scheduleMode
        self.inviteStrategy = inviteStrategy
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.allowGameVoting = allowGameVoting
        self.confirmedGameId = confirmedGameId
        self.coverImageUrl = coverImageUrl
        self.draftInvitees = draftInvitees
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        hostId = try container.decode(UUID.self, forKey: .hostId)
        host = try? container.decodeIfPresent(User.self, forKey: .host)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        locationAddress = try container.decodeIfPresent(String.self, forKey: .locationAddress)
        status = try container.decode(EventStatus.self, forKey: .status)
        games = (try? container.decodeIfPresent([EventGame].self, forKey: .games)) ?? []
        timeOptions = (try? container.decodeIfPresent([TimeOption].self, forKey: .timeOptions)) ?? []
        confirmedTimeOptionId = try container.decodeIfPresent(UUID.self, forKey: .confirmedTimeOptionId)
        allowTimeSuggestions = try container.decode(Bool.self, forKey: .allowTimeSuggestions)
        scheduleMode = try container.decode(ScheduleMode.self, forKey: .scheduleMode)
        inviteStrategy = try container.decode(InviteStrategy.self, forKey: .inviteStrategy)
        minPlayers = try container.decode(Int.self, forKey: .minPlayers)
        maxPlayers = try container.decodeIfPresent(Int.self, forKey: .maxPlayers)
        allowGameVoting = try container.decodeIfPresent(Bool.self, forKey: .allowGameVoting) ?? false
        confirmedGameId = try container.decodeIfPresent(UUID.self, forKey: .confirmedGameId)
        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        draftInvitees = try container.decodeIfPresent([DraftInvitee].self, forKey: .draftInvitees)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    // Custom encode to skip nested relations (games, timeOptions, host)
    // which are separate tables and would break PostgREST inserts
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
        try container.encode(scheduleMode, forKey: .scheduleMode)
        try container.encode(inviteStrategy, forKey: .inviteStrategy)
        try container.encode(minPlayers, forKey: .minPlayers)
        try container.encodeIfPresent(maxPlayers, forKey: .maxPlayers)
        try container.encode(allowGameVoting, forKey: .allowGameVoting)
        try container.encodeIfPresent(confirmedGameId, forKey: .confirmedGameId)
        try container.encodeIfPresent(coverImageUrl, forKey: .coverImageUrl)
        try container.encodeIfPresent(draftInvitees, forKey: .draftInvitees)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Intentionally skip: host, games, timeOptions (separate tables)
    }
}

// MARK: - Schedule Mode
enum ScheduleMode: String, Codable {
    case fixed
    case poll
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
    var yesCount: Int
    var maybeCount: Int
    var noCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case game
        case isPrimary = "is_primary"
        case sortOrder = "sort_order"
        case yesCount = "yes_count"
        case maybeCount = "maybe_count"
        case noCount = "no_count"
    }

    init(id: UUID, gameId: UUID, game: Game? = nil, isPrimary: Bool, sortOrder: Int, yesCount: Int = 0, maybeCount: Int = 0, noCount: Int = 0) {
        self.id = id
        self.gameId = gameId
        self.game = game
        self.isPrimary = isPrimary
        self.sortOrder = sortOrder
        self.yesCount = yesCount
        self.maybeCount = maybeCount
        self.noCount = noCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        gameId = try container.decode(UUID.self, forKey: .gameId)
        game = try container.decodeIfPresent(Game.self, forKey: .game)
        isPrimary = try container.decode(Bool.self, forKey: .isPrimary)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        yesCount = try container.decodeIfPresent(Int.self, forKey: .yesCount) ?? 0
        maybeCount = try container.decodeIfPresent(Int.self, forKey: .maybeCount) ?? 0
        noCount = try container.decodeIfPresent(Int.self, forKey: .noCount) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(gameId, forKey: .gameId)
        try container.encode(isPrimary, forKey: .isPrimary)
        try container.encode(sortOrder, forKey: .sortOrder)
        // Skip: game, yesCount, maybeCount, noCount (joined/trigger-maintained)
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

// MARK: - Draft Invitee (stored as JSON in events.draft_invitees)
struct DraftInvitee: Codable, Identifiable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var userId: UUID?
    var tier: Int
    var groupId: UUID?
    var groupEmoji: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phoneNumber = "phone_number"
        case userId = "user_id"
        case tier
        case groupId = "group_id"
        case groupEmoji = "group_emoji"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        tier = try container.decode(Int.self, forKey: .tier)
        groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
        groupEmoji = try container.decodeIfPresent(String.self, forKey: .groupEmoji)
    }

    init(id: UUID, name: String, phoneNumber: String, userId: UUID?, tier: Int, groupId: UUID? = nil, groupEmoji: String? = nil) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.userId = userId
        self.tier = tier
        self.groupId = groupId
        self.groupEmoji = groupEmoji
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
    var maybeCount: Int

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
        case maybeCount = "maybe_count"
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

// MARK: - Time Option Vote Types
enum TimeOptionVoteType: String, Codable {
    case yes
    case maybe
    case no
}

struct TimeOptionVote: Codable {
    var timeOptionId: UUID
    var voteType: TimeOptionVoteType

    enum CodingKeys: String, CodingKey {
        case timeOptionId = "time_option_id"
        case voteType = "vote_type"
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
        scheduleMode: .fixed,
        inviteStrategy: InviteStrategy(type: .tiered, tierSize: 3, autoPromote: true),
        minPlayers: 3,
        maxPlayers: 4,
        allowGameVoting: false,
        confirmedGameId: nil,
        coverImageUrl: nil,
        draftInvitees: nil,
        deletedAt: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
}
