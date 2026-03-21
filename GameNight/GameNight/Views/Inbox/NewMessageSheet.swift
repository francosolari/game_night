import SwiftUI

struct NewMessageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var savedContacts: [SavedContact] = []
    @State private var frequentContacts: [FrequentContact] = []
    @State private var isLoading = true
    @State private var startingDMContactId: UUID?
    @State private var toast: ToastItem?

    /// Called when a DM conversation is successfully created or retrieved.
    /// Passes back the conversation ID and the other user's info.
    let onConversationReady: (UUID, ConversationViewModel.ConversationOtherUser) -> Void

    // MARK: - Computed Contact Lists

    private var allContacts: [UserContact] {
        var seen = Set<String>()
        var result: [UserContact] = []

        for fc in frequentContacts {
            let key = PhoneNumberFormatter.normalizedForComparison(fc.contactPhone)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(UserContact(
                id: fc.contactUserId ?? UUID(),
                name: fc.contactName,
                phoneNumber: fc.contactPhone,
                avatarUrl: fc.contactAvatarUrl,
                isAppUser: fc.isAppUser,
                appUserId: fc.contactUserId
            ))
        }

        for sc in savedContacts {
            let key = PhoneNumberFormatter.normalizedForComparison(sc.phoneNumber)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(sc.asUserContact)
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var appUserContacts: [UserContact] {
        filteredContacts.filter { $0.isAppUser }
    }

    private var otherContacts: [UserContact] {
        filteredContacts.filter { !$0.isAppUser }
    }

    private var filteredContacts: [UserContact] {
        guard !searchText.isEmpty else { return allContacts }
        return allContacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phoneNumber.contains(searchText)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBar(text: $searchText, placeholder: "Search contacts...")
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)

                Divider()
                    .background(Theme.Colors.divider)

                if isLoading {
                    loadingState
                } else if allContacts.isEmpty {
                    emptyState
                } else {
                    contactList
                }
            }
            .background(Theme.Colors.pageBackground.ignoresSafeArea())
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .toast($toast)
        }
        .task {
            await loadContacts()
        }
    }

    // MARK: - Contact List

    private var contactList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !appUserContacts.isEmpty {
                    sectionLabel("On CardboardWithMe")
                    ForEach(appUserContacts) { contact in
                        NewMessageContactRow(contact: contact, isLoading: startingDMContactId == contact.id, isDisabled: startingDMContactId != nil && startingDMContactId != contact.id) {
                            startDM(with: contact)
                        }
                        Divider()
                            .background(Theme.Colors.divider.opacity(0.5))
                            .padding(.leading, Theme.Spacing.xl + 44 + Theme.Spacing.md)
                    }
                }

                if !otherContacts.isEmpty {
                    sectionLabel(appUserContacts.isEmpty ? "Contacts" : "Not on the App")
                    ForEach(otherContacts) { contact in
                        NewMessageContactRow(contact: contact, isLoading: false, isDisabled: true) {
                            // Non-app users cannot receive DMs yet
                            toast = ToastItem(style: .info, message: "\(contact.name) hasn't joined the app yet.")
                        }
                        Divider()
                            .background(Theme.Colors.divider.opacity(0.5))
                            .padding(.leading, Theme.Spacing.xl + 44 + Theme.Spacing.md)
                    }
                }

                if filteredContacts.isEmpty && !searchText.isEmpty {
                    VStack(spacing: Theme.Spacing.sm) {
                        Text("No results for \"\(searchText)\"")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xxl)
                }
            }
        }
    }

    // MARK: - Loading / Empty

    private var loadingState: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    HStack(spacing: Theme.Spacing.md) {
                        Circle()
                            .fill(Theme.Colors.cardBackground)
                            .frame(width: 44, height: 44)
                            .shimmer()
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.cardBackground)
                                .frame(width: 130, height: 14)
                                .shimmer()
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.cardBackground)
                                .frame(width: 90, height: 12)
                                .shimmer()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 44))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("No contacts yet")
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Your saved contacts will appear here once they join the app.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xs)
    }

    private func startDM(with contact: UserContact) {
        guard startingDMContactId == nil else { return }
        guard let appUserId = contact.appUserId else {
            toast = ToastItem(style: .error, message: "\(contact.name) hasn't joined the app yet.")
            return
        }
        startingDMContactId = contact.id

        Task {
            do {
                print("[DM] Starting DM with contact: \(contact.name), appUserId: \(appUserId), isAppUser: \(contact.isAppUser)")
                let supabase = SupabaseService.shared
                let conversationId = try await supabase.getOrCreateDM(otherUserId: appUserId)
                print("[DM] Got conversationId: \(conversationId)")
                let otherUser = ConversationViewModel.ConversationOtherUser(
                    id: appUserId,
                    displayName: contact.name,
                    avatarUrl: contact.avatarUrl
                )
                onConversationReady(conversationId, otherUser)
            } catch {
                print("[DM] startDM failed: \(error)")
                toast = ToastItem(style: .error, message: "Couldn't start conversation. Try again.")
            }
            startingDMContactId = nil
        }
    }

    private func loadContacts() async {
        let supabase = SupabaseService.shared
        async let savedResult = supabase.fetchSavedContacts()
        async let frequentResult = supabase.fetchFrequentContacts()
        savedContacts = (try? await savedResult) ?? []
        frequentContacts = (try? await frequentResult) ?? []
        isLoading = false
    }
}

// MARK: - Contact Row

private struct NewMessageContactRow: View {
    let contact: UserContact
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                AvatarView(url: contact.avatarUrl, size: 44)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(contact.name)
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(isDisabled ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(contact.phoneNumber)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                Spacer()

                if isDisabled {
                    Text("Not on app")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.fieldBackground)
                        )
                } else if isLoading {
                    ProgressView()
                        .tint(Theme.Colors.primary)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}
