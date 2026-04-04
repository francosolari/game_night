import Foundation

struct Play: Identifiable, Codable, Hashable {
    static func == (lhs: Play, rhs: Play) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: UUID
    var eventId: UUID?
    var groupId: UUID?
    var gameId: UUID
    var loggedBy: UUID
    var playedAt: Date
    var durationMinutes: Int?
    var notes: String?
    var isCooperative: Bool
    var cooperativeResult: CooperativeResult?
    var bggPlayId: Int?
    var quantity: Int?
    var location: String?
    var incomplete: Bool?
    var participants: [PlayParticipant]
    var game: Game?
    var logger: User?
    var createdAt: Date
    var updatedAt: Date

    enum CooperativeResult: String, Codable {
        case won
        case lost
    }

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case groupId = "group_id"
        case gameId = "game_id"
        case loggedBy = "logged_by"
        case playedAt = "played_at"
        case durationMinutes = "duration_minutes"
        case notes
        case isCooperative = "is_cooperative"
        case cooperativeResult = "cooperative_result"
        case bggPlayId = "bgg_play_id"
        case quantity
        case location
        case incomplete
        case participants = "play_participants"
        case game
        case logger = "logged_by_user"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        eventId: UUID? = nil,
        groupId: UUID? = nil,
        gameId: UUID,
        loggedBy: UUID,
        playedAt: Date = Date(),
        durationMinutes: Int? = nil,
        notes: String? = nil,
        isCooperative: Bool = false,
        cooperativeResult: CooperativeResult? = nil,
        bggPlayId: Int? = nil,
        quantity: Int? = nil,
        location: String? = nil,
        incomplete: Bool? = nil,
        participants: [PlayParticipant] = [],
        game: Game? = nil,
        logger: User? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.groupId = groupId
        self.gameId = gameId
        self.loggedBy = loggedBy
        self.playedAt = playedAt
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.isCooperative = isCooperative
        self.cooperativeResult = cooperativeResult
        self.bggPlayId = bggPlayId
        self.quantity = quantity
        self.location = location
        self.incomplete = incomplete
        self.participants = participants
        self.game = game
        self.logger = logger
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        eventId = try container.decodeIfPresent(UUID.self, forKey: .eventId)
        groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
        gameId = try container.decode(UUID.self, forKey: .gameId)
        loggedBy = try container.decode(UUID.self, forKey: .loggedBy)
        playedAt = try container.decode(Date.self, forKey: .playedAt)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isCooperative = try container.decodeIfPresent(Bool.self, forKey: .isCooperative) ?? false
        cooperativeResult = try container.decodeIfPresent(CooperativeResult.self, forKey: .cooperativeResult)
        bggPlayId = try container.decodeIfPresent(Int.self, forKey: .bggPlayId)
        quantity = try container.decodeIfPresent(Int.self, forKey: .quantity)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        incomplete = try container.decodeIfPresent(Bool.self, forKey: .incomplete)
        participants = (try? container.decodeIfPresent([PlayParticipant].self, forKey: .participants)) ?? []
        game = try? container.decodeIfPresent(Game.self, forKey: .game)
        logger = try? container.decodeIfPresent(User.self, forKey: .logger)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(eventId, forKey: .eventId)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encode(gameId, forKey: .gameId)
        try container.encode(loggedBy, forKey: .loggedBy)
        try container.encode(playedAt, forKey: .playedAt)
        try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(isCooperative, forKey: .isCooperative)
        try container.encodeIfPresent(cooperativeResult, forKey: .cooperativeResult)
        try container.encodeIfPresent(bggPlayId, forKey: .bggPlayId)
        try container.encodeIfPresent(quantity, forKey: .quantity)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(incomplete, forKey: .incomplete)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Skip: participants, game, logger (joined relations)
    }

    var winnerNames: [String] {
        participants.filter(\.isWinner).map(\.displayName)
    }

    static let preview = Play(
        id: UUID(),
        gameId: UUID(),
        loggedBy: UUID(),
        playedAt: Date(),
        participants: [
            .preview,
            PlayParticipant(id: UUID(), playId: UUID(), displayName: "Sam", isWinner: true)
        ],
        game: .preview,
        createdAt: Date(),
        updatedAt: Date()
    )
}
