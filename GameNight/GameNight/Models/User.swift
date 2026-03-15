import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var phoneNumber: String
    var displayName: String
    var avatarUrl: String?
    var bio: String?
    var bggUsername: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case phoneNumber = "phone_number"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case bggUsername = "bgg_username"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserContact: Identifiable, Hashable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var avatarUrl: String?
    var isAppUser: Bool

    static let preview = UserContact(
        id: UUID(),
        name: "Alex Chen",
        phoneNumber: "+1234567890",
        avatarUrl: nil,
        isAppUser: true
    )
}
