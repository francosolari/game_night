import SwiftUI

/// Reusable contact list that combines saved contacts, frequent contacts, and device import.
/// Uses multi-select with shared ContactRow component (checkboxes + "Add (N)" button).
struct ContactListSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var savedContacts: [SavedContact] = []
    @State private var frequentContacts: [FrequentContact] = []
    @State private var currentUserId: UUID?
    @State private var currentUserPhone: String?
    @State private var isLoading = true
    @State private var showDevicePicker = false
    @State private var selectedIds = Set<UUID>()
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
        var result: [UserContact] = []

        for fc in frequentContacts {
            if let currentUserId, fc.contactUserId == currentUserId {
                continue
            }
            let normalizedPhone = PhoneNumberFormatter.normalizedForComparison(fc.contactPhone)
            guard !seen.contains(normalizedPhone) else { continue }
            seen.insert(normalizedPhone)
            result.append(UserContact(
                id: UUID(),
                name: fc.contactName,
                phoneNumber: fc.contactPhone,
                avatarUrl: fc.contactAvatarUrl,
                isAppUser: fc.isAppUser
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

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
                                sectionHeader("on cardboardwithme")
                                ForEach(appUserContacts) { contact in
                                    ContactRow(
                                        contact: contact,
                                        isSelected: selectedIds.contains(contact.id)
                                    ) {
                                        toggleSelection(contact.id)
                                    }
                                }
                            }

                            if !otherContacts.isEmpty {
                                sectionHeader(appUserContacts.isEmpty ? "Contacts" : "Others")
                                ForEach(otherContacts) { contact in
                                    ContactRow(
                                        contact: contact,
                                        isSelected: selectedIds.contains(contact.id)
                                    ) {
                                        toggleSelection(contact.id)
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
                    Button("Add (\(selectedIds.count))") {
                        let selected = allContacts.filter { selectedIds.contains($0.id) }
                        onSelect(selected)
                        dismiss()
                    }
                    .font(Theme.Typography.bodySemibold)
                    .foregroundColor(selectedIds.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.primary)
                    .disabled(selectedIds.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showDevicePicker) {
            ContactPickerSheet { deviceContacts in
                guard !deviceContacts.isEmpty else { return }
                // Save to Supabase in background
                Task {
                    let supabase = SupabaseService.shared
                    let saved = (try? await supabase.saveContacts(deviceContacts)) ?? []
                    for s in saved {
                        if !savedContacts.contains(where: { $0.phoneNumber == s.phoneNumber }) {
                            savedContacts.append(s)
                        }
                    }
                }
                // Pre-select imported contacts in the list — user confirms with "Add (N)"
                for contact in deviceContacts {
                    if !importedContacts.contains(where: { $0.phoneNumber == contact.phoneNumber }) {
                        importedContacts.append(contact)
                    }
                    selectedIds.insert(contact.id)
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

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    // MARK: - Data

    private func loadContacts() async {
        let supabase = SupabaseService.shared
        async let savedResult = supabase.fetchSavedContacts()
        async let frequentResult = supabase.fetchFrequentContacts()
        async let currentUserResult = try? supabase.fetchCurrentUser()

        savedContacts = (try? await savedResult) ?? []
        frequentContacts = (try? await frequentResult) ?? []
        if let currentUser = await currentUserResult {
            currentUserId = currentUser.id
            currentUserPhone = ContactPickerService.normalizePhone(currentUser.phoneNumber)
        }
        isLoading = false
    }
}
