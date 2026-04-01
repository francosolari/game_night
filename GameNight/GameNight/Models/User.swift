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
    var gameLibraryPublic: Bool
    var marketingOptIn: Bool
    var contactsSynced: Bool
    var phoneVerified: Bool
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
        case gameLibraryPublic = "game_library_public"
        case marketingOptIn = "marketing_opt_in"
        case contactsSynced = "contacts_synced"
        case phoneVerified = "phone_verified"
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
        gameLibraryPublic: Bool = true,
        marketingOptIn: Bool = false,
        contactsSynced: Bool = false,
        phoneVerified: Bool = false,
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
        self.gameLibraryPublic = gameLibraryPublic
        self.marketingOptIn = marketingOptIn
        self.contactsSynced = contactsSynced
        self.phoneVerified = phoneVerified
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

// MARK: - Contact Source
/// Tracks how a contact was discovered — controls phone number visibility in the UI.
enum ContactSource: String, Hashable {
    case phonebook      // From device address book (synced or picked)
    case appConnection  // Discovered only through mutual events (FrequentContact RPC)
    case manual         // Typed in manually by the host
}

// MARK: - User Contact (for invite picker — never bulk uploaded)
struct UserContact: Identifiable, Hashable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var avatarUrl: String?
    var isAppUser: Bool
    /// The contact's Supabase auth user ID (only set for app users).
    /// Use this for DMs/RPC calls — `id` may be a saved_contacts row PK.
    var appUserId: UUID?
    /// How this contact was discovered — determines whether phone is visible in UI.
    var source: ContactSource

    init(id: UUID, name: String, phoneNumber: String, avatarUrl: String? = nil, isAppUser: Bool, appUserId: UUID? = nil, source: ContactSource = .phonebook) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.avatarUrl = avatarUrl
        self.isAppUser = isAppUser
        self.appUserId = appUserId
        self.source = source
    }

    static let preview = UserContact(
        id: UUID(),
        name: "Alex Chen",
        phoneNumber: "+1234567890",
        avatarUrl: nil,
        isAppUser: true,
        appUserId: UUID()
    )
}

// MARK: - Saved Contact (persisted in Supabase for reuse across events)
struct SavedContact: Identifiable, Codable, Hashable {
    let id: UUID
    var userId: UUID
    var name: String
    var phoneNumber: String
    var avatarUrl: String?
    var isAppUser: Bool
    var createdAt: Date?
    /// The contact's Supabase auth user ID (resolved from phone match). Not stored in DB.
    var appUserId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case phoneNumber = "phone_number"
        case avatarUrl = "avatar_url"
        case isAppUser = "is_app_user"
        case createdAt = "created_at"
        // appUserId is not in CodingKeys — set manually after fetch
    }

    var asUserContact: UserContact {
        UserContact(
            id: appUserId ?? id,
            name: name,
            phoneNumber: phoneNumber,
            avatarUrl: avatarUrl,
            isAppUser: isAppUser,
            appUserId: appUserId,
            source: .phonebook
        )
    }
}

// MARK: - Frequent Contact (from RPC — ranked by mutual events)
struct FrequentContact: Identifiable, Codable, Hashable {
    var id: String { contactPhone }
    let contactPhone: String
    let contactName: String
    let contactUserId: UUID?
    let contactAvatarUrl: String?
    let isAppUser: Bool
    let mutualEventCount: Int

    enum CodingKeys: String, CodingKey {
        case contactPhone = "contact_phone"
        case contactName = "contact_name"
        case contactUserId = "contact_user_id"
        case contactAvatarUrl = "contact_avatar_url"
        case isAppUser = "is_app_user"
        case mutualEventCount = "mutual_event_count"
    }
}

struct UserProfileSummary: Codable, Equatable {
    let userId: UUID
    let joinedAt: Date
    let hostedEventCount: Int
    let attendedEventCount: Int
    let groupCount: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case joinedAt = "joined_at"
        case hostedEventCount = "hosted_event_count"
        case attendedEventCount = "attended_event_count"
        case groupCount = "group_count"
    }
}
