import Foundation

struct ActivityFeedItem: Identifiable, Codable {
    let id: UUID
    var eventId: UUID
    var userId: UUID
    var user: User?
    var type: ActivityType
    var content: String?
    var parentId: UUID?
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    // Client-side only: populated by grouping flat results by parentId
    var replies: [ActivityFeedItem]?

    enum ActivityType: String, Codable {
        case comment
        case rsvpUpdate = "rsvp_update"
        case announcement
    }

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case user
        case type
        case content
        case parentId = "parent_id"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(userId, forKey: .userId)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Skip: user, replies (joined relations)
    }
}
