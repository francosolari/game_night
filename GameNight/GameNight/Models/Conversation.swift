import Foundation

// MARK: - Conversation

struct Conversation: Identifiable, Codable {
    let id: UUID
    var lastMessageAt: Date?
    var createdAt: Date

    // Joined relations
    var participants: [ConversationParticipant]?
    var lastMessage: DirectMessage?

    enum CodingKeys: String, CodingKey {
        case id
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case participants
        case lastMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        lastMessageAt = try container.decodeIfPresent(Date.self, forKey: .lastMessageAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        participants = try? container.decodeIfPresent([ConversationParticipant].self, forKey: .participants)
        lastMessage = try? container.decodeIfPresent(DirectMessage.self, forKey: .lastMessage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(lastMessageAt, forKey: .lastMessageAt)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Conversation Participant

struct ConversationParticipant: Identifiable, Codable {
    let id: UUID
    var conversationId: UUID
    var userId: UUID
    var joinedAt: Date
    var lastReadAt: Date?

    // Joined relation
    var user: User?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case lastReadAt = "last_read_at"
        case user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        conversationId = try container.decode(UUID.self, forKey: .conversationId)
        userId = try container.decode(UUID.self, forKey: .userId)
        joinedAt = try container.decode(Date.self, forKey: .joinedAt)
        lastReadAt = try container.decodeIfPresent(Date.self, forKey: .lastReadAt)
        user = try? container.decodeIfPresent(User.self, forKey: .user)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(conversationId, forKey: .conversationId)
        try container.encode(userId, forKey: .userId)
        try container.encode(joinedAt, forKey: .joinedAt)
        try container.encodeIfPresent(lastReadAt, forKey: .lastReadAt)
    }
}

// MARK: - Direct Message

struct DirectMessage: Identifiable, Codable {
    let id: UUID
    var conversationId: UUID
    var senderId: UUID
    var content: String?
    var messageType: MessageType
    var metadata: MessageMetadata?
    var createdAt: Date

    // Joined relation
    var sender: User?

    enum MessageType: String, Codable {
        case text
        case invite
        case system
        case groupInvite = "group_invite"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case metadata
        case createdAt = "created_at"
        case sender
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        conversationId = try container.decode(UUID.self, forKey: .conversationId)
        senderId = try container.decode(UUID.self, forKey: .senderId)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        messageType = try container.decodeIfPresent(MessageType.self, forKey: .messageType) ?? .text
        metadata = try? container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sender = try? container.decodeIfPresent(User.self, forKey: .sender)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(conversationId, forKey: .conversationId)
        try container.encode(senderId, forKey: .senderId)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encode(messageType, forKey: .messageType)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Message Metadata (for invite cards)

struct MessageMetadata: Codable {
    var eventId: String?
    var inviteId: String?
    var eventTitle: String?
    var coverImageUrl: String?
    var hostName: String?
    var timeLabel: String?
    var inviteToken: String?
    var groupId: String?
    var groupName: String?
    var groupEmoji: String?
    var memberId: String?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case inviteId = "invite_id"
        case eventTitle = "event_title"
        case coverImageUrl = "cover_image_url"
        case hostName = "host_name"
        case timeLabel = "time_label"
        case inviteToken = "invite_token"
        case groupId = "group_id"
        case groupName = "group_name"
        case groupEmoji = "group_emoji"
        case memberId = "member_id"
    }
}

// MARK: - Conversation Summary (from RPC)

struct ConversationSummary: Identifiable, Codable {
    var id: UUID { conversationId }
    var conversationId: UUID
    var lastMessageAt: Date?
    var otherUserId: UUID
    var otherDisplayName: String
    var otherAvatarUrl: String?
    var lastMessageContent: String?
    var lastMessageType: String?
    var lastMessageSenderId: UUID?
    var lastMessageCreatedAt: Date?
    var unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case lastMessageAt = "last_message_at"
        case otherUserId = "other_user_id"
        case otherDisplayName = "other_display_name"
        case otherAvatarUrl = "other_avatar_url"
        case lastMessageContent = "last_message_content"
        case lastMessageType = "last_message_type"
        case lastMessageSenderId = "last_message_sender_id"
        case lastMessageCreatedAt = "last_message_created_at"
        case unreadCount = "unread_count"
    }
}
