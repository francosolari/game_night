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
