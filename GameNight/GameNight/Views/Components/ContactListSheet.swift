import SwiftUI

/// Reusable contact list that combines saved contacts, frequent contacts, and device import.
/// Uses multi-select with shared ContactRow component (checkboxes + "Add (N)" button).
struct ContactListSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var savedContacts: [SavedContact] = []
    @State private var frequentContacts: [FrequentContact] = []
    @State private var groupMemberContacts: [UserContact] = []
    @State private var currentUserId: UUID?
    @State private var currentUserPhone: String?
    @State private var isLoading = true
    @State private var showDevicePicker = false
    @State private var selectedPhones = Set<String>()
    @State private var importedContacts: [UserContact] = []

    /// Phone numbers already in the invite list — these contacts won't be shown
    let excludedPhones: Set<String>
    let onSelect: ([UserContact]) -> Void

    private var allContacts: [UserContact] {
        // Normalize excluded phones for consistent comparison
        let normalizedExcluded = excludedPhones.map { PhoneNumberFormatter.normalizedForComparison($0) }
        var seen = Set(normalizedExcluded)

        if let currentUserPhone {
            seen.insert(PhoneNumberFormatter.normalizedForComparison(currentUserPhone))
        }

        // Build set of phonebook phones so we can detect if a frequent contact
        // is also in the user's address book (phonebook supersedes appConnection)
        let phonebookPhones: Set<String> = {
            var phones = Set<String>()
            for sc in savedContacts {
                phones.insert(PhoneNumberFormatter.normalizedForComparison(sc.phoneNumber))
            }
            for ic in importedContacts {
                phones.insert(PhoneNumberFormatter.normalizedForComparison(ic.phoneNumber))
            }
            return phones
        }()

        // Build a map of normalized phone → mutual event count for relevance sorting
        let mutualEventCounts: [String: Int] = {
            var map: [String: Int] = [:]
            for fc in frequentContacts {
                let normalized = PhoneNumberFormatter.normalizedForComparison(fc.contactPhone)
                map[normalized] = fc.mutualEventCount
            }
            return map
        }()

        var result: [UserContact] = []

        for fc in frequentContacts {
            if let currentUserId, fc.contactUserId == currentUserId {
                continue
            }
            let normalizedPhone = PhoneNumberFormatter.normalizedForComparison(fc.contactPhone)
            guard !seen.contains(normalizedPhone) else { continue }
            seen.insert(normalizedPhone)
            let isFromPhonebook = phonebookPhones.contains(normalizedPhone)
            result.append(UserContact(
                id: UUID(),
                name: fc.contactName,
                phoneNumber: fc.contactPhone,
                avatarUrl: fc.contactAvatarUrl,
                isAppUser: fc.isAppUser,
                appUserId: fc.contactUserId,
                source: isFromPhonebook ? .phonebook : .appConnection
            ))
        }

        for sc in savedContacts {
            let normalizedPhone = PhoneNumberFormatter.normalizedForComparison(sc.phoneNumber)
            guard !seen.contains(normalizedPhone) else { continue }
            seen.insert(normalizedPhone)
            result.append(sc.asUserContact)
        }

        for ic in importedContacts {
            let normalizedPhone = PhoneNumberFormatter.normalizedForComparison(ic.phoneNumber)
            guard !seen.contains(normalizedPhone) else { continue }
            seen.insert(normalizedPhone)
            result.append(ic)
        }

        // Group members — people from user's groups
        for gm in groupMemberContacts {
            let normalizedPhone = PhoneNumberFormatter.normalizedForComparison(gm.phoneNumber)
            guard !seen.contains(normalizedPhone) else { continue }
            seen.insert(normalizedPhone)
            result.append(gm)
        }

        // Sort by relevance: mutuals → app users → alphabetical
        return result.sorted { a, b in
            let aPhone = PhoneNumberFormatter.normalizedForComparison(a.phoneNumber)
            let bPhone = PhoneNumberFormatter.normalizedForComparison(b.phoneNumber)

            let aMutuals = mutualEventCounts[aPhone] ?? 0
            let bMutuals = mutualEventCounts[bPhone] ?? 0

            // First: prioritize by mutual event count (descending)
            if aMutuals != bMutuals {
                return aMutuals > bMutuals
            }

            // Second: prioritize app users
            if a.isAppUser != b.isAppUser {
                return a.isAppUser
            }

            // Third: alphabetical
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private var filteredContacts: [UserContact] {
        if searchText.isEmpty { return allContacts }
        return allContacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phoneNumber.contains(searchText)
        }
    }

    private var appUserContacts: [UserContact] {
        filteredContacts.filter { $0.isAppUser }
    }

    private var otherContacts: [UserContact] {
        filteredContacts.filter { !$0.isAppUser }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBar(text: $searchText, placeholder: "Search contacts...")
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)

                if isLoading {
                    Spacer()
                    ProgressView().tint(Theme.Colors.primary)
                    Spacer()
                } else if filteredContacts.isEmpty && searchText.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Import more from phone
                            Button {
                                showDevicePicker = true
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 14))
                                    Text("Import from Phone")
                                        .font(Theme.Typography.calloutMedium)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(Theme.Colors.primary)
                                .padding(.horizontal, Theme.Spacing.xl)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(Theme.Colors.primary.opacity(0.08))
                            }

                            if !appUserContacts.isEmpty {
                                sectionHeader("Game Night")
                                ForEach(appUserContacts) { contact in
                                    ContactRow(
                                        contact: contact,
                                        isSelected: selectedPhones.contains(selectionKey(for: contact))
                                    ) {
                                        toggleSelection(contact)
                                    }
                                }
                            }

                            if !otherContacts.isEmpty {
                                sectionHeader("Contacts")
                                ForEach(otherContacts) { contact in
                                    ContactRow(
                                        contact: contact,
                                        isSelected: selectedPhones.contains(selectionKey(for: contact))
                                    ) {
                                        toggleSelection(contact)
                                    }
                                }
                            }

                            if filteredContacts.isEmpty && !searchText.isEmpty {
                                VStack(spacing: Theme.Spacing.md) {
                                    Text("No contacts matching \"\(searchText)\"")
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                                .padding(.top, Theme.Spacing.xxl)
                            }
                        }
                    }
                }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add (\(selectedPhones.count))") {
                        let selected = allContacts.filter { selectedPhones.contains(selectionKey(for: $0)) }
                        onSelect(selected)
                        dismiss()
                    }
                    .font(Theme.Typography.bodySemibold)
                    .foregroundColor(selectedPhones.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.primary)
                    .disabled(selectedPhones.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showDevicePicker) {
            ContactPickerSheet { deviceContacts in
                guard !deviceContacts.isEmpty else { return }
                // Refresh saved contacts from DB after bulk sync
                Task {
                    if let refreshed = try? await SupabaseService.shared.fetchSavedContacts() {
                        savedContacts = refreshed
                    }
                }
                // Pre-select imported contacts in the list — user confirms with "Add (N)"
                for contact in deviceContacts {
                    if !importedContacts.contains(where: { $0.phoneNumber == contact.phoneNumber }) {
                        importedContacts.append(contact)
                    }
                    selectedPhones.insert(selectionKey(for: contact))
                }
            }
        }
        .task {
            await loadContacts()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("No contacts yet")
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Import contacts from your phone to get started.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showDevicePicker = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("Import from Phone")
                }
                .font(Theme.Typography.bodyMedium)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.jumbo)
            Spacer()
        }
        .padding(Theme.Spacing.xl)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xs)
    }

    private func toggleSelection(_ contact: UserContact) {
        let key = selectionKey(for: contact)
        if selectedPhones.contains(key) {
            selectedPhones.remove(key)
        } else {
            selectedPhones.insert(key)
        }
    }

    private func selectionKey(for contact: UserContact) -> String {
        PhoneNumberFormatter.normalizedForComparison(contact.phoneNumber)
    }

    // MARK: - Data

    private func loadContacts() async {
        let supabase = SupabaseService.shared
        async let savedResult = supabase.fetchSavedContacts()
        async let frequentResult = supabase.fetchFrequentContacts()
        async let groupsResult: [GameGroup]? = try? supabase.fetchGroups()
        async let currentUserResult = try? supabase.fetchCurrentUser()

        savedContacts = (try? await savedResult) ?? []
        frequentContacts = (try? await frequentResult) ?? []

        let currentUser = await currentUserResult
        if let currentUser {
            currentUserId = currentUser.id
            currentUserPhone = ContactPickerService.normalizePhone(currentUser.phoneNumber)
        }

        // Extract group members as UserContacts
        let groups = await groupsResult ?? []
        var gmContacts: [UserContact] = []
        for group in groups {
            for member in group.members {
                if let currentUserId, member.userId == currentUserId { continue }
                gmContacts.append(UserContact(
                    id: UUID(),
                    name: member.displayName ?? member.phoneNumber,
                    phoneNumber: member.phoneNumber,
                    avatarUrl: nil,
                    isAppUser: member.userId != nil,
                    appUserId: member.userId,
                    source: .appConnection
                ))
            }
        }
        groupMemberContacts = gmContacts

        isLoading = false
    }
}
