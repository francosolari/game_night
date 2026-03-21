import Foundation

struct AppNotification: Identifiable, Codable {
    let id: UUID
    var userId: UUID
    var type: NotificationType
    var title: String
    var body: String?
    var metadata: [String: String]?
    var eventId: UUID?
    var inviteId: UUID?
    var groupId: UUID?
    var conversationId: UUID?
    var readAt: Date?
    var createdAt: Date

    // Joined relation
    var event: GameEvent?

    enum NotificationType: String, Codable, CaseIterable {
        case inviteReceived = "invite_received"
        case rsvpUpdate = "rsvp_update"
        case groupInvite = "group_invite"
        case timeConfirmed = "time_confirmed"
        case benchPromoted = "bench_promoted"
        case dmReceived = "dm_received"
        case textBlast = "text_blast"
        case gameConfirmed = "game_confirmed"
        case eventCancelled = "event_cancelled"

        var icon: String {
            switch self {
            case .inviteReceived: return "envelope.fill"
            case .rsvpUpdate: return "person.crop.circle.badge.checkmark"
            case .groupInvite: return "person.3.fill"
            case .timeConfirmed: return "calendar.badge.checkmark"
            case .benchPromoted: return "arrow.up.circle.fill"
            case .dmReceived: return "bubble.left.fill"
            case .textBlast: return "megaphone.fill"
            case .gameConfirmed: return "gamecontroller.fill"
            case .eventCancelled: return "xmark.circle.fill"
            }
        }
    }

    var isRead: Bool { readAt != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case body
        case metadata
        case eventId = "event_id"
        case inviteId = "invite_id"
        case groupId = "group_id"
        case conversationId = "conversation_id"
        case readAt = "read_at"
        case createdAt = "created_at"
        case event
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        type = try container.decode(NotificationType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        eventId = try container.decodeIfPresent(UUID.self, forKey: .eventId)
        inviteId = try container.decodeIfPresent(UUID.self, forKey: .inviteId)
        groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
        conversationId = try container.decodeIfPresent(UUID.self, forKey: .conversationId)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        event = try? container.decodeIfPresent(GameEvent.self, forKey: .event)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(eventId, forKey: .eventId)
        try container.encodeIfPresent(inviteId, forKey: .inviteId)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encodeIfPresent(conversationId, forKey: .conversationId)
        try container.encodeIfPresent(readAt, forKey: .readAt)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct NotificationPreferences: Codable {
    var id: UUID?
    var userId: UUID
    var invitesEnabled: Bool
    var textBlastsEnabled: Bool
    var dmsEnabled: Bool
    var rsvpUpdatesEnabled: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case invitesEnabled = "invites_enabled"
        case textBlastsEnabled = "text_blasts_enabled"
        case dmsEnabled = "dms_enabled"
        case rsvpUpdatesEnabled = "rsvp_updates_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID? = nil,
        userId: UUID,
        invitesEnabled: Bool = true,
        textBlastsEnabled: Bool = true,
        dmsEnabled: Bool = true,
        rsvpUpdatesEnabled: Bool = true,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.invitesEnabled = invitesEnabled
        self.textBlastsEnabled = textBlastsEnabled
        self.dmsEnabled = dmsEnabled
        self.rsvpUpdatesEnabled = rsvpUpdatesEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
