import Foundation

struct Invite: Identifiable, Codable {
    let id: UUID
    var eventId: UUID
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
    var smsDeliveryStatus: SMSStatus?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
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
        case sentVia = "sent_via"
        case smsDeliveryStatus = "sms_delivery_status"
        case createdAt = "created_at"
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
    var declinedUsers: [InviteUser]
    var waitlistedUsers: [InviteUser]

    struct InviteUser: Identifiable {
        let id: UUID
        var name: String
        var avatarUrl: String?
        var status: InviteStatus
        var tier: Int
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
        sentVia: .both,
        smsDeliveryStatus: .delivered,
        createdAt: Date()
    )
}
