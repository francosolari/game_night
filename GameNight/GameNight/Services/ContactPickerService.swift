import Foundation
import Contacts

/// Privacy-first contact picker.
/// CRITICAL: We NEVER upload or store the user's full address book.
/// Only contacts the user explicitly selects for an invite are sent to the server.
actor ContactPickerService {
    static let shared = ContactPickerService()

    private let store = CNContactStore()

    /// Local cache directory for contact thumbnail images.
    private static let avatarCacheDir: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("contact-avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Permission

    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestAccess() async throws -> Bool {
        try await store.requestAccess(for: .contacts)
    }

    // MARK: - Fetch contacts (local only, never uploaded)
    /// Fetches contacts from the device. These are displayed locally for the user
    /// to pick from. We NEVER send this list to any server.
    func fetchLocalContacts() async throws -> [UserContact] {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName

        var contacts: [UserContact] = []

        try store.enumerateContacts(with: request) { contact, _ in
            // Only include contacts with phone numbers
            guard let phone = contact.phoneNumbers.first?.value.stringValue else { return }

            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            guard !name.isEmpty else { return }

            let normalizedPhone = PhoneNumberFormatter.normalizeToE164(phone)

            // Cache thumbnail to disk if available
            var avatarUrl: String? = nil
            if let imageData = contact.thumbnailImageData {
                avatarUrl = Self.cacheContactThumbnail(imageData, phone: normalizedPhone)
            }

            contacts.append(UserContact(
                id: UUID(),
                name: name,
                phoneNumber: normalizedPhone,
                avatarUrl: avatarUrl,
                isAppUser: false
            ))
        }

        return contacts
    }

    func fetchContacts(withIdentifiers identifiers: [String]) async throws -> [UserContact] {
        guard !identifiers.isEmpty else { return [] }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]

        let predicate = CNContact.predicateForContacts(withIdentifiers: identifiers)
        let rawContacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)

        return rawContacts.compactMap { contact in
            guard let phone = contact.phoneNumbers.first?.value.stringValue else { return nil }

            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            guard !name.isEmpty else { return nil }

            let normalizedPhone = PhoneNumberFormatter.normalizeToE164(phone)

            var avatarUrl: String? = nil
            if let imageData = contact.thumbnailImageData {
                avatarUrl = Self.cacheContactThumbnail(imageData, phone: normalizedPhone)
            }

            return UserContact(
                id: UUID(),
                name: name,
                phoneNumber: normalizedPhone,
                avatarUrl: avatarUrl,
                isAppUser: false
            )
        }
    }

    /// Checks which of the SELECTED contacts (not all) are already app users.
    /// Only the phone numbers the user chose to invite are sent to the server.
    func checkAppUsers(for selectedContacts: [UserContact]) async -> [UserContact] {
        guard !selectedContacts.isEmpty else { return selectedContacts }

        // DB stores phones as digits-only (e.g. "19546080345"), iOS normalizes to E.164 ("+19546080345").
        // Strip non-digits for the query so both sides match.
        let digitsOnly = selectedContacts.map { $0.phoneNumber.filter(\.isNumber) }
        guard !digitsOnly.isEmpty else { return selectedContacts }

        do {
            struct PhoneCheck: Decodable {
                let phone_number: String
            }

            let results: [PhoneCheck] = try await SupabaseService.shared.client
                .from("users")
                .select("phone_number")
                .in("phone_number", values: digitsOnly)
                .execute()
                .value

            let appUserPhones = Set(results.map(\.phone_number))

            return selectedContacts.map { contact in
                var updated = contact
                updated.isAppUser = appUserPhones.contains(contact.phoneNumber.filter(\.isNumber))
                return updated
            }
        } catch {
            return selectedContacts
        }
    }

    /// Builds a phone→name map from all device contacts (digits-only phone key).
    /// Used to resolve how the current user sees other people (contact name > display_name).
    /// Only reads contacts if permission was already granted — never triggers a permission prompt.
    func buildContactNameMap() async -> [String: String] {
        guard authorizationStatus == .authorized else { return [:] }
        let contacts = (try? await fetchLocalContacts()) ?? []
        var map: [String: String] = [:]
        for contact in contacts {
            let key = PhoneNumberFormatter.normalizedForComparison(contact.phoneNumber)
            if !key.isEmpty {
                map[key] = contact.name
            }
        }
        return map
    }

    // MARK: - Phone normalization

    /// Normalizes phone numbers to E.164 format (with +).
    /// Delegates to PhoneNumberFormatter for consistency.
    static func normalizePhone(_ raw: String) -> String {
        PhoneNumberFormatter.normalizeToE164(raw)
    }

    // MARK: - Thumbnail Cache

    /// Saves contact thumbnail to disk cache and returns the file URL string.
    /// Uses phone number hash as filename for stable lookup.
    private static func cacheContactThumbnail(_ data: Data, phone: String) -> String? {
        let key = phone.filter(\.isNumber)
        guard !key.isEmpty else { return nil }
        let fileURL = avatarCacheDir.appendingPathComponent("\(key).jpg")
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL.absoluteString
        } catch {
            return nil
        }
    }

    /// Returns a cached thumbnail URL for a phone number, if available.
    static func cachedAvatarUrl(for phone: String) -> String? {
        let key = phone.filter(\.isNumber)
        guard !key.isEmpty else { return nil }
        let fileURL = avatarCacheDir.appendingPathComponent("\(key).jpg")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL.absoluteString
        }
        return nil
    }
}
