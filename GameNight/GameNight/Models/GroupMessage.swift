import Foundation

struct GroupMessage: Identifiable, Codable {
    let id: UUID
    var groupId: UUID
    var userId: UUID
    var user: User?
    var content: String
    var parentId: UUID?
    var createdAt: Date
    var updatedAt: Date

    // Client-side only: populated by grouping flat results by parentId
    var replies: [GroupMessage]?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case user
        case content
        case parentId = "parent_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(),
        groupId: UUID,
        userId: UUID,
        user: User? = nil,
        content: String,
        parentId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        replies: [GroupMessage]? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.userId = userId
        self.user = user
        self.content = content
        self.parentId = parentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.replies = replies
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        groupId = try container.decode(UUID.self, forKey: .groupId)
        userId = try container.decode(UUID.self, forKey: .userId)
        user = try? container.decodeIfPresent(User.self, forKey: .user)
        content = try container.decode(String.self, forKey: .content)
        parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        replies = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(userId, forKey: .userId)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Skip: user, replies (joined relations)
    }
}
