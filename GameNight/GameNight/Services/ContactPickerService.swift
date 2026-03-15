import Foundation
import Contacts

/// Privacy-first contact picker.
/// CRITICAL: We NEVER upload or store the user's full address book.
/// Only contacts the user explicitly selects for an invite are sent to the server.
actor ContactPickerService {
    static let shared = ContactPickerService()

    private let store = CNContactStore()

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

            contacts.append(UserContact(
                id: UUID(),
                name: name,
                phoneNumber: Self.normalizePhone(phone),
                avatarUrl: nil,
                isAppUser: false
            ))
        }

        return contacts
    }

    /// Checks which of the SELECTED contacts (not all) are already app users.
    /// Only the phone numbers the user chose to invite are sent to the server.
    func checkAppUsers(for selectedContacts: [UserContact]) async -> [UserContact] {
        // Only send the phones the user explicitly picked
        let phones = selectedContacts.map(\.phoneNumber)
        guard !phones.isEmpty else { return selectedContacts }

        do {
            struct PhoneCheck: Decodable {
                let phone_number: String
                let id: UUID
            }

            let results: [PhoneCheck] = try await SupabaseService.shared.client
                .from("users")
                .select("phone_number, id")
                .in("phone_number", values: phones)
                .execute()
                .value

            let appUserPhones = Set(results.map(\.phone_number))

            return selectedContacts.map { contact in
                var updated = contact
                updated.isAppUser = appUserPhones.contains(contact.phoneNumber)
                return updated
            }
        } catch {
            return selectedContacts
        }
    }

    // MARK: - Phone normalization

    static func normalizePhone(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        if digits.count == 10 {
            return "+1\(digits)"  // Default US
        }
        if digits.hasPrefix("1") && digits.count == 11 {
            return "+\(digits)"
        }
        if raw.hasPrefix("+") {
            return "+\(digits)"
        }
        return "+\(digits)"
    }
}
