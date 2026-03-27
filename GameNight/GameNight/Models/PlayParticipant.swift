import Foundation

struct PlayParticipant: Identifiable, Codable {
    let id: UUID
    var playId: UUID
    var userId: UUID?
    var phoneNumber: String?
    var displayName: String
    var placement: Int?
    var isWinner: Bool
    var score: Int?
    var team: String?
    var startPosition: String?
    var color: String?
    var newToGame: Bool?
    var bggRating: Double?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case playId = "play_id"
        case userId = "user_id"
        case phoneNumber = "phone_number"
        case displayName = "display_name"
        case placement
        case isWinner = "is_winner"
        case score
        case team
        case startPosition = "start_position"
        case color
        case newToGame = "new_to_game"
        case bggRating = "bgg_rating"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        playId: UUID = UUID(),
        userId: UUID? = nil,
        phoneNumber: String? = nil,
        displayName: String,
        placement: Int? = nil,
        isWinner: Bool = false,
        score: Int? = nil,
        team: String? = nil,
        startPosition: String? = nil,
        color: String? = nil,
        newToGame: Bool? = nil,
        bggRating: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.playId = playId
        self.userId = userId
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.placement = placement
        self.isWinner = isWinner
        self.score = score
        self.team = team
        self.startPosition = startPosition
        self.color = color
        self.newToGame = newToGame
        self.bggRating = bggRating
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        playId = try container.decode(UUID.self, forKey: .playId)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        displayName = try container.decode(String.self, forKey: .displayName)
        placement = try container.decodeIfPresent(Int.self, forKey: .placement)
        isWinner = try container.decodeIfPresent(Bool.self, forKey: .isWinner) ?? false
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        team = try container.decodeIfPresent(String.self, forKey: .team)
        startPosition = try container.decodeIfPresent(String.self, forKey: .startPosition)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        newToGame = try container.decodeIfPresent(Bool.self, forKey: .newToGame)
        bggRating = try container.decodeIfPresent(Double.self, forKey: .bggRating)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    static let preview = PlayParticipant(
        id: UUID(),
        playId: UUID(),
        userId: UUID(),
        displayName: "Alex",
        isWinner: false
    )
}
