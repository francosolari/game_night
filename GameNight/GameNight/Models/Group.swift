import Foundation

struct GameGroup: Identifiable, Codable {
    let id: UUID
    var ownerId: UUID
    var name: String
    var emoji: String?
    var description: String?
    var members: [GroupMember]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case emoji
        case description
        case members
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var memberCount: Int { members.count }

    static let preview = GameGroup(
        id: UUID(),
        ownerId: UUID(),
        name: "Dune Crew",
        emoji: "🏜️",
        description: "The squad that plays Dune Imperium",
        members: [
            .preview,
            GroupMember(id: UUID(), groupId: UUID(), userId: UUID(), phoneNumber: "+1234567891", displayName: "Sam", tier: 1, sortOrder: 1, addedAt: Date()),
            GroupMember(id: UUID(), groupId: UUID(), userId: UUID(), phoneNumber: "+1234567892", displayName: "Riley", tier: 1, sortOrder: 2, addedAt: Date()),
            GroupMember(id: UUID(), groupId: UUID(), userId: UUID(), phoneNumber: "+1234567893", displayName: "Casey", tier: 2, sortOrder: 3, addedAt: Date()),
        ],
        createdAt: Date(),
        updatedAt: Date()
    )
}

struct GroupMember: Identifiable, Codable, Hashable {
    let id: UUID
    var groupId: UUID
    var userId: UUID?
    var phoneNumber: String
    var displayName: String?
    var tier: Int           // Default invite tier for this group
    var sortOrder: Int
    var addedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case phoneNumber = "phone_number"
        case displayName = "display_name"
        case tier
        case sortOrder = "sort_order"
        case addedAt = "added_at"
    }

    static let preview = GroupMember(
        id: UUID(),
        groupId: UUID(),
        userId: UUID(),
        phoneNumber: "+1234567890",
        displayName: "Alex",
        tier: 1,
        sortOrder: 0,
        addedAt: Date()
    )
}
