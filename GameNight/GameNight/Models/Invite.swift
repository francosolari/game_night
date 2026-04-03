import Foundation
import SwiftUI

struct Invite: Identifiable, Codable {
    let id: UUID
    var eventId: UUID
    var event: GameEvent?       // Joined relation
    var hostUserId: UUID?
    var userId: UUID?           // nil for non-app users
    var phoneNumber: String
    var displayName: String?
    var status: InviteStatus
    var tier: Int               // 1 = first tier, 2 = waitlist, etc.
    var tierPosition: Int       // Position within tier
    var isActive: Bool          // Currently being invited (vs waiting)
    var respondedAt: Date?
    var selectedTimeOptionIds: [UUID]
    var suggestedTimes: [TimeOption]?
    var sentVia: DeliveryMethod
    var inviteToken: String?
    var promotedAt: Date?
    var promotedFromTier: Int?
    var smsDeliveryStatus: SMSStatus?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case event
        case hostUserId = "host_user_id"
        case userId = "user_id"
        case phoneNumber = "phone_number"
        case displayName = "display_name"
        case status
        case tier
        case tierPosition = "tier_position"
        case isActive = "is_active"
        case respondedAt = "responded_at"
        case selectedTimeOptionIds = "selected_time_option_ids"
        case suggestedTimes = "suggested_times"
        case inviteToken = "invite_token"
        case promotedAt = "promoted_at"
        case promotedFromTier = "promoted_from_tier"
        case sentVia = "sent_via"
        case smsDeliveryStatus = "sms_delivery_status"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        eventId = try container.decode(UUID.self, forKey: .eventId)
        event = try? container.decodeIfPresent(GameEvent.self, forKey: .event)
        hostUserId = try container.decodeIfPresent(UUID.self, forKey: .hostUserId)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        status = try container.decodeIfPresent(InviteStatus.self, forKey: .status) ?? .pending
        tier = try container.decodeIfPresent(Int.self, forKey: .tier) ?? 1
        tierPosition = try container.decodeIfPresent(Int.self, forKey: .tierPosition) ?? 0
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        respondedAt = try container.decodeIfPresent(Date.self, forKey: .respondedAt)
        selectedTimeOptionIds = (try? container.decodeIfPresent([UUID].self, forKey: .selectedTimeOptionIds)) ?? []
        suggestedTimes = try container.decodeIfPresent([TimeOption].self, forKey: .suggestedTimes)
        inviteToken = try container.decodeIfPresent(String.self, forKey: .inviteToken)
        promotedAt = try container.decodeIfPresent(Date.self, forKey: .promotedAt)
        promotedFromTier = try container.decodeIfPresent(Int.self, forKey: .promotedFromTier)
        sentVia = try container.decodeIfPresent(DeliveryMethod.self, forKey: .sentVia) ?? .sms
        smsDeliveryStatus = try container.decodeIfPresent(SMSStatus.self, forKey: .smsDeliveryStatus)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    init(
        id: UUID,
        eventId: UUID,
        event: GameEvent? = nil,
        hostUserId: UUID? = nil,
        userId: UUID? = nil,
        phoneNumber: String,
        displayName: String? = nil,
        status: InviteStatus,
        tier: Int,
        tierPosition: Int,
        isActive: Bool,
        respondedAt: Date? = nil,
        selectedTimeOptionIds: [UUID],
        suggestedTimes: [TimeOption]? = nil,
        inviteToken: String? = nil,
        promotedAt: Date? = nil,
        promotedFromTier: Int? = nil,
        sentVia: DeliveryMethod,
        smsDeliveryStatus: SMSStatus? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.eventId = eventId
        self.event = event
        self.hostUserId = hostUserId
        self.userId = userId
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.status = status
        self.tier = tier
        self.tierPosition = tierPosition
        self.isActive = isActive
        self.respondedAt = respondedAt
        self.selectedTimeOptionIds = selectedTimeOptionIds
        self.suggestedTimes = suggestedTimes
        self.inviteToken = inviteToken
        self.promotedAt = promotedAt
        self.promotedFromTier = promotedFromTier
        self.sentVia = sentVia
        self.smsDeliveryStatus = smsDeliveryStatus
        self.createdAt = createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(eventId, forKey: .eventId)
        try container.encodeIfPresent(hostUserId, forKey: .hostUserId)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encode(status, forKey: .status)
        try container.encode(tier, forKey: .tier)
        try container.encode(tierPosition, forKey: .tierPosition)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(respondedAt, forKey: .respondedAt)
        try container.encode(selectedTimeOptionIds, forKey: .selectedTimeOptionIds)
        try container.encodeIfPresent(suggestedTimes, forKey: .suggestedTimes)
        try container.encodeIfPresent(inviteToken, forKey: .inviteToken)
        try container.encodeIfPresent(promotedAt, forKey: .promotedAt)
        try container.encodeIfPresent(promotedFromTier, forKey: .promotedFromTier)
        try container.encode(sentVia, forKey: .sentVia)
        try container.encodeIfPresent(smsDeliveryStatus, forKey: .smsDeliveryStatus)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

enum InviteStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case declined
    case maybe
    case expired
    case waitlisted

    var displayLabel: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Going"
        case .declined: return "Can't Go"
        case .maybe: return "Maybe"
        case .expired: return "Expired"
        case .waitlisted: return "Waitlisted"
        }
    }

    /// First-person label for RSVP display ("You're going" vs "Going")
    var rsvpDisplayLabel: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "You're going"
        case .declined: return "Can't go"
        case .maybe: return "Maybe"
        case .expired: return "Expired"
        case .waitlisted: return "Waitlisted"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        case .expired: return "clock.badge.exclamationmark.fill"
        case .waitlisted: return "list.number"
        }
    }

    var color: Color {
        switch self {
        case .accepted: return Theme.Colors.success
        case .declined: return Theme.Colors.error
        case .maybe: return Theme.Colors.warning
        case .pending: return Theme.Colors.textTertiary
        case .expired: return Theme.Colors.textTertiary
        case .waitlisted: return Theme.Colors.accent
        }
    }
}

enum DeliveryMethod: String, Codable {
    case push
    case sms
    case both
}

enum SMSStatus: String, Codable {
    case queued
    case sent
    case delivered
    case failed
    case undelivered
}

enum PollRSVP {
    /// Derives the invite RSVP status from poll votes.
    /// - Returns: `nil` when no votes are selected yet.
    static func derivedStatus(from votes: [UUID: TimeOptionVoteType]) -> InviteStatus? {
        guard !votes.isEmpty else { return nil }
        if votes.values.contains(.yes) {
            return .accepted
        }
        if votes.values.contains(.maybe) {
            return .maybe
        }
        return .declined
    }
}

// MARK: - Invite Summary (for event detail view)
struct InviteSummary {
    var total: Int
    var accepted: Int
    var declined: Int
    var pending: Int
    var maybe: Int
    var waitlisted: Int
    var acceptedUsers: [InviteUser]
    var pendingUsers: [InviteUser]
    var maybeUsers: [InviteUser]
    var declinedUsers: [InviteUser]
    var waitlistedUsers: [InviteUser]

    struct InviteUser: Identifiable {
        let id: UUID
        var userId: UUID?
        var name: String
        var phoneNumber: String?
        var avatarUrl: String?
        var status: InviteStatus
        var tier: Int
        var inviteToken: String?
        var promotedAt: Date?
    }
}

// MARK: - Preview Data
extension Invite {
    static let preview = Invite(
        id: UUID(),
        eventId: UUID(),
        hostUserId: UUID(),
        userId: UUID(),
        phoneNumber: "+1234567890",
        displayName: "Jordan",
        status: .pending,
        tier: 1,
        tierPosition: 0,
        isActive: true,
        respondedAt: nil,
        selectedTimeOptionIds: [],
        suggestedTimes: nil,
        inviteToken: "abc123def456",
        sentVia: .both,
        smsDeliveryStatus: .delivered,
        createdAt: Date()
    )
}
