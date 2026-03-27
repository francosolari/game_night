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

    // Only encode columns that exist on the groups table (skip joined relations)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Intentionally skip: members — it's a joined relation via group_members, not a column
    }

    var memberCount: Int { members.filter(\.isAccepted).count }

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

enum GroupMemberStatus: String, Codable {
    case pending
    case accepted
    case declined
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
    var status: GroupMemberStatus
    var invitedBy: UUID?

    var isAccepted: Bool { status == .accepted }
    var isPending: Bool { status == .pending }

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case phoneNumber = "phone_number"
        case displayName = "display_name"
        case tier
        case sortOrder = "sort_order"
        case addedAt = "added_at"
        case status
        case invitedBy = "invited_by"
    }

    init(id: UUID, groupId: UUID, userId: UUID? = nil, phoneNumber: String, displayName: String? = nil,
         tier: Int = 1, sortOrder: Int = 0, addedAt: Date = Date(),
         status: GroupMemberStatus = .pending, invitedBy: UUID? = nil) {
        self.id = id
        self.groupId = groupId
        self.userId = userId
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.tier = tier
        self.sortOrder = sortOrder
        self.addedAt = addedAt
        self.status = status
        self.invitedBy = invitedBy
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

// MARK: - Group Invite Preview (from RPC)

struct GroupInvitePreview: Codable {
    let group: GroupPreviewInfo
    let owner: GroupMemberPreview
    let members: [GroupMemberPreview]

    /// Total count including the owner
    var totalMemberCount: Int { members.count + 1 }
}

struct GroupPreviewInfo: Codable {
    let id: UUID
    let name: String
    let emoji: String
    let description: String?
    let ownerId: UUID

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, description
        case ownerId = "owner_id"
    }
}

struct GroupMemberPreview: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let avatarUrl: String?
    let topGames: [GamePreviewInfo]

    var userId: UUID? { nil }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case topGames = "top_games"
    }
}

struct GamePreviewInfo: Codable {
    let name: String
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case name
        case thumbnailUrl = "thumbnail_url"
    }
}
