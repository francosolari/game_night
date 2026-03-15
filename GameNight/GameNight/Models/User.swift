import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var phoneNumber: String
    var displayName: String
    var avatarUrl: String?
    var bio: String?
    var bggUsername: String?
    // Privacy settings
    var phoneVisible: Bool
    var discoverableByPhone: Bool
    var marketingOptIn: Bool
    var contactsSynced: Bool
    var privacyAcceptedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case phoneNumber = "phone_number"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case bggUsername = "bgg_username"
        case phoneVisible = "phone_visible"
        case discoverableByPhone = "discoverable_by_phone"
        case marketingOptIn = "marketing_opt_in"
        case contactsSynced = "contacts_synced"
        case privacyAcceptedAt = "privacy_accepted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        phoneNumber: String,
        displayName: String,
        avatarUrl: String? = nil,
        bio: String? = nil,
        bggUsername: String? = nil,
        phoneVisible: Bool = false,
        discoverableByPhone: Bool = true,
        marketingOptIn: Bool = false,
        contactsSynced: Bool = false,
        privacyAcceptedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.bggUsername = bggUsername
        self.phoneVisible = phoneVisible
        self.discoverableByPhone = discoverableByPhone
        self.marketingOptIn = marketingOptIn
        self.contactsSynced = contactsSynced
        self.privacyAcceptedAt = privacyAcceptedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Masked phone for display to other users
    var maskedPhone: String {
        guard phoneNumber.count >= 4 else { return "***" }
        let last4 = phoneNumber.suffix(4)
        return "***-***-\(last4)"
    }
}

// MARK: - Blocked User
struct BlockedUser: Identifiable, Codable {
    let id: UUID
    var blockerId: UUID
    var blockedId: UUID
    var blockedPhone: String?
    var reason: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
        case blockedPhone = "blocked_phone"
        case reason
        case createdAt = "created_at"
    }
}

// MARK: - User Contact (for invite picker — never bulk uploaded)
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
