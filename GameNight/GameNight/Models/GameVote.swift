import Foundation

enum GameVoteType: String, Codable {
    case yes
    case maybe
    case no
}

struct GameVote: Identifiable, Codable {
    let id: UUID
    var eventId: UUID
    var gameId: UUID
    var userId: UUID
    var voteType: GameVoteType
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case gameId = "game_id"
        case userId = "user_id"
        case voteType = "vote_type"
        case createdAt = "created_at"
    }
}
