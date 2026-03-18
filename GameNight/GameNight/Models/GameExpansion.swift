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
