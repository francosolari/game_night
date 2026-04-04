import SwiftUI

struct MyContactsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MyContactsViewModel()
    @State private var searchText = ""
    @State private var showDevicePicker = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private var filteredContacts: [ContactWithStats] {
        if searchText.isEmpty {
            return viewModel.contacts
        }
        return viewModel.contacts.filter {
            $0.contact.name.localizedCaseInsensitiveContains(searchText) ||
            $0.contact.phoneNumber.contains(searchText)
        }
    }

    private var appUserContacts: [ContactWithStats] {
        filteredContacts.filter { $0.contact.isAppUser }
    }

    private var phoneContacts: [ContactWithStats] {
        filteredContacts.filter { !$0.contact.isAppUser }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.contacts.isEmpty {
                LoadingView(message: "Loading contacts...")
            } else if viewModel.contacts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Stats summary
                        statsHeader
                            .padding(.horizontal, Theme.Spacing.xl)
                            .padding(.top, Theme.Spacing.md)
                            .padding(.bottom, Theme.Spacing.sm)

                        // Search bar
                        SearchBar(text: $searchText, placeholder: "Search by name or number...")
                            .padding(.horizontal, Theme.Spacing.xl)
                            .padding(.bottom, Theme.Spacing.md)

                        // Sync button
                        Button {
                            showDevicePicker = true
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.Colors.primary.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Theme.Colors.primary)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Sync Contacts from Phone")
                                        .font(Theme.Typography.calloutMedium)
                                        .foregroundColor(Theme.Colors.primary)
                                    Text("Import new contacts or update existing ones")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                            .padding(.horizontal, Theme.Spacing.xl)
                            .padding(.vertical, Theme.Spacing.md)
                        }

                        Divider().padding(.horizontal, Theme.Spacing.xl)

                        // On cardboardwithme section
                        if !appUserContacts.isEmpty {
                            SectionHeader(title: "On cardboardwithme")
                                .padding(.horizontal, Theme.Spacing.xl)
                                .padding(.top, Theme.Spacing.lg)
                                .padding(.bottom, Theme.Spacing.xs)

                            ForEach(appUserContacts) { item in
                                if let appUserId = item.contact.appUserId {
                                    NavigationLink {
                                        GuestPublicProfileView(
                                            userId: appUserId,
                                            name: item.contact.name,
                                            avatarUrl: item.contact.avatarUrl
                                        )
                                    } label: {
                                        SavedContactRowContent(item: item)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        contactContextMenu(item: item)
                                    }
                                } else {
                                    SavedContactRow(
                                        item: item,
                                        onRename: { newName in
                                            Task { await viewModel.renameContact(item.contact, newName: newName) }
                                        },
                                        onDelete: {
                                            Task { await viewModel.deleteContact(item.contact) }
                                        },
                                        onBlock: {
                                            Task { await viewModel.blockContact(item.contact) }
                                        }
                                    )
                                }
                            }
                        }

                        // Phone contacts section
                        if !phoneContacts.isEmpty {
                            SectionHeader(title: "Phone Contacts")
                                .padding(.horizontal, Theme.Spacing.xl)
                                .padding(.top, Theme.Spacing.lg)
                                .padding(.bottom, Theme.Spacing.xs)

                            ForEach(phoneContacts) { item in
                                SavedContactRow(
                                    item: item,
                                    onRename: { newName in
                                        Task { await viewModel.renameContact(item.contact, newName: newName) }
                                    },
                                    onDelete: {
                                        Task { await viewModel.deleteContact(item.contact) }
                                    },
                                    onBlock: {
                                        Task { await viewModel.blockContact(item.contact) }
                                    }
                                )
                            }
                        }

                        // No results for search
                        if filteredContacts.isEmpty && !searchText.isEmpty {
                            VStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 28))
                                    .foregroundColor(Theme.Colors.textTertiary)
                                Text("No contacts matching \"\(searchText)\"")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xxl)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("My Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDevicePicker) {
            ContactPickerSheet { _ in
                Task { await viewModel.loadData() }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !viewModel.isLoading {
                Task { await viewModel.refreshIfNeeded() }
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            statPill(
                icon: "person.2.fill",
                value: "\(viewModel.contacts.count)",
                label: "Total"
            )
            statPill(
                icon: "gamecontroller.fill",
                value: "\(viewModel.contacts.filter { $0.contact.isAppUser }.count)",
                label: "On App"
            )
            statPill(
                icon: "calendar.badge.clock",
                value: "\(viewModel.contacts.filter { $0.mutualEventCount > 0 }.count)",
                label: "Played With"
            )
        }
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.primary)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            Text(label)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: .black.opacity(ThemeManager.shared.isDark ? 0.2 : 0.04), radius: 3, x: 0, y: 1)
        )
    }

    // MARK: - Context Menu (for NavigationLink rows)

    @ViewBuilder
    private func contactContextMenu(item: ContactWithStats) -> some View {
        if item.isSavedContact {
            Button {
                Task { await viewModel.deleteContact(item.contact) }
            } label: {
                Label("Delete Contact", systemImage: "trash")
            }
        }
        Button(role: .destructive) {
            Task { await viewModel.blockContact(item.contact) }
        } label: {
            Label("Block Contact", systemImage: "hand.raised")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "person.crop.rectangle.stack",
            title: "No contacts yet",
            message: "Sync from your phone or invite people to events to build your contacts.",
            actionLabel: "Sync from Phone"
        ) {
            showDevicePicker = true
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Contact Row Content (shared between NavigationLink and Button rows)

struct SavedContactRowContent: View {
    let item: ContactWithStats

    /// Resolves avatar: prefers stored URL, falls back to local contact cache.
    private var resolvedAvatarUrl: String? {
        if let url = item.contact.avatarUrl, !url.isEmpty { return url }
        return ContactPickerService.cachedAvatarUrl(for: item.contact.phoneNumber)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            AvatarView(url: resolvedAvatarUrl, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.contact.name)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    if item.contact.isAppUser {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.primaryAction)
                    }
                }

                HStack(spacing: 6) {
                    if item.mutualEventCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "dice.fill")
                                .font(.system(size: 9))
                            Text("\(item.mutualEventCount) game\(item.mutualEventCount == 1 ? "" : "s")")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                    }

                    if !item.isSavedContact {
                        Text(item.sourceLabel)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Theme.Colors.textTertiary.opacity(0.08))
                            )
                    } else if item.mutualEventCount == 0 {
                        Text(PhoneNumberFormatter.formatForDisplay(item.contact.phoneNumber))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            if item.contact.isAppUser {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            } else {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textTertiary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm + 2)
    }
}

// MARK: - Contact Row (for non-navigable contacts)

private struct SavedContactRow: View {
    let item: ContactWithStats
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onBlock: () -> Void

    @State private var showRename = false
    @State private var showActions = false
    @State private var editedName = ""

    var body: some View {
        Button {
            showActions = true
        } label: {
            SavedContactRowContent(item: item)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Contact Options", isPresented: $showActions) {
            if item.isSavedContact {
                Button("Rename Display Name") {
                    editedName = item.contact.name
                    showRename = true
                }
                Button("Delete Contact", role: .destructive) {
                    onDelete()
                }
            }
            Button("Block Contact", role: .destructive) {
                onBlock()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Contact", isPresented: $showRename) {
            TextField("Display name", text: $editedName)
            Button("Save") {
                guard !editedName.isEmpty else { return }
                onRename(editedName)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This name is only visible to you.")
        }
    }
}

// MARK: - View Model

@MainActor
class MyContactsViewModel: ObservableObject {
    @Published var contacts: [ContactWithStats] = []
    @Published var isLoading = false

    private var loadTask: Task<Void, Never>?
    private var lastLoadTime: Date?

    func loadData() async {
        // Cancel any in-flight load to prevent request cancellation errors
        loadTask?.cancel()

        let task = Task {
            isLoading = contacts.isEmpty // Only show full loading on first load
            defer {
                isLoading = false
                lastLoadTime = Date()
            }

            do {
                let session = try await SupabaseService.shared.client.auth.session
                let myUserId = session.user.id

                // Fetch all sources in parallel
                async let savedTask = SupabaseService.shared.fetchSavedContacts()
                async let frequentTask: [FrequentContact]? = try? SupabaseService.shared.fetchFrequentContacts(limit: 200)
                async let groupsTask: [GameGroup]? = try? SupabaseService.shared.fetchGroups()
                async let myInvitesTask: [Invite]? = try? SupabaseService.shared.fetchMyInvites()
                async let myEventsTask: [GameEvent]? = try? SupabaseService.shared.fetchMyEvents()

                let savedContacts = try await savedTask
                let frequentContacts = await frequentTask ?? []
                let groups = await groupsTask ?? []
                let myInvites = await myInvitesTask ?? []
                let myEvents = await myEventsTask ?? []

                guard !Task.isCancelled else { return }

                // Build unified contact map keyed by normalized phone
                var contactMap: [String: MergedContact] = [:]

                // 1. Saved contacts (highest priority for name)
                for sc in savedContacts {
                    let key = sc.phoneNumber.filter(\.isNumber)
                    contactMap[key] = MergedContact(
                        name: sc.name,
                        phoneNumber: sc.phoneNumber,
                        avatarUrl: sc.avatarUrl,
                        isAppUser: sc.isAppUser,
                        mutualEventCount: 0,
                        savedContactId: sc.id,
                        source: .saved
                    )
                }

                // 2. Frequent contacts (co-attendees from events)
                for fc in frequentContacts {
                    let key = fc.contactPhone.filter(\.isNumber)
                    if var existing = contactMap[key] {
                        existing.mutualEventCount = max(existing.mutualEventCount, fc.mutualEventCount)
                        if fc.isAppUser { existing.isAppUser = true }
                        if existing.avatarUrl == nil { existing.avatarUrl = fc.contactAvatarUrl }
                        contactMap[key] = existing
                    } else {
                        contactMap[key] = MergedContact(
                            name: fc.contactName,
                            phoneNumber: fc.contactPhone,
                            avatarUrl: fc.contactAvatarUrl,
                            isAppUser: fc.isAppUser,
                            mutualEventCount: fc.mutualEventCount,
                            savedContactId: nil,
                            source: .frequent
                        )
                    }
                }

                // 3. Group members
                for group in groups {
                    for member in group.members where member.userId != myUserId {
                        let key = member.phoneNumber.filter(\.isNumber)
                        if contactMap[key] == nil {
                            contactMap[key] = MergedContact(
                                name: member.displayName ?? member.phoneNumber,
                                phoneNumber: member.phoneNumber,
                                avatarUrl: nil,
                                isAppUser: member.userId != nil,
                                mutualEventCount: 0,
                                savedContactId: nil,
                                source: .group
                            )
                        }
                    }
                }

                guard !Task.isCancelled else { return }

                // 4. People you've invited (from hosted events)
                let hostedEventIds = Set(myEvents.map(\.id))
                for eventId in hostedEventIds {
                    if let invites = try? await SupabaseService.shared.fetchInvites(eventId: eventId) {
                        guard !Task.isCancelled else { return }
                        for invite in invites where invite.userId != myUserId {
                            let key = invite.phoneNumber.filter(\.isNumber)
                            if contactMap[key] == nil {
                                contactMap[key] = MergedContact(
                                    name: invite.displayName ?? invite.phoneNumber,
                                    phoneNumber: invite.phoneNumber,
                                    avatarUrl: nil,
                                    isAppUser: invite.userId != nil,
                                    mutualEventCount: 0,
                                    savedContactId: nil,
                                    source: .invited
                                )
                            }
                        }
                    }
                }

                // 5. Co-attendees from attended events
                let attendedEventIds = Set(myInvites.filter { $0.status == .accepted }.map(\.eventId))
                for eventId in attendedEventIds where !hostedEventIds.contains(eventId) {
                    if let invites = try? await SupabaseService.shared.fetchInvites(eventId: eventId) {
                        guard !Task.isCancelled else { return }
                        for invite in invites where invite.userId != myUserId && invite.status == .accepted {
                            let key = invite.phoneNumber.filter(\.isNumber)
                            if contactMap[key] == nil {
                                contactMap[key] = MergedContact(
                                    name: invite.displayName ?? invite.phoneNumber,
                                    phoneNumber: invite.phoneNumber,
                                    avatarUrl: nil,
                                    isAppUser: invite.userId != nil,
                                    mutualEventCount: 0,
                                    savedContactId: nil,
                                    source: .coAttendee
                                )
                            }
                        }
                    }
                }

                // Remove self
                let myPhone = session.user.phone ?? ""
                let myKey = myPhone.filter(\.isNumber)
                contactMap.removeValue(forKey: myKey)

                guard !Task.isCancelled else { return }

                contacts = contactMap.values
                    .map { mc in
                        let saved = SavedContact(
                            id: mc.savedContactId ?? UUID(),
                            userId: UUID(),
                            name: mc.name,
                            phoneNumber: mc.phoneNumber,
                            avatarUrl: mc.avatarUrl,
                            isAppUser: mc.isAppUser,
                            createdAt: nil
                        )
                        return ContactWithStats(
                            contact: saved,
                            mutualEventCount: mc.mutualEventCount,
                            isSavedContact: mc.savedContactId != nil,
                            contactSource: mc.source
                        )
                    }
                    .sorted { a, b in
                        if a.mutualEventCount != b.mutualEventCount {
                            return a.mutualEventCount > b.mutualEventCount
                        }
                        if a.contact.isAppUser != b.contact.isAppUser {
                            return a.contact.isAppUser
                        }
                        return a.contact.name.localizedCaseInsensitiveCompare(b.contact.name) == .orderedAscending
                    }
            } catch {
                guard !Task.isCancelled else { return }
                print("⚠️ [MyContactsVM] Failed to load contacts: \(error)")
            }
        }
        loadTask = task
        await task.value
    }

    /// Light refresh that skips if loaded recently (within 5 seconds).
    /// Prevents scenePhase spam from cancelling in-flight requests.
    func refreshIfNeeded() async {
        if let lastLoadTime, Date().timeIntervalSince(lastLoadTime) < 5 {
            return
        }
        await loadData()
    }

    enum ContactMergeSource {
        case saved, frequent, group, invited, coAttendee
    }

    private struct MergedContact {
        var name: String
        var phoneNumber: String
        var avatarUrl: String?
        var isAppUser: Bool
        var mutualEventCount: Int
        var savedContactId: UUID?
        var source: ContactMergeSource
    }

    func renameContact(_ contact: SavedContact, newName: String) async {
        do {
            try await SupabaseService.shared.updateSavedContactName(id: contact.id, name: newName)
            if let index = contacts.firstIndex(where: { $0.contact.id == contact.id }) {
                var updated = contacts[index].contact
                updated.name = newName
                contacts[index] = ContactWithStats(
                    contact: updated,
                    mutualEventCount: contacts[index].mutualEventCount,
                    contactSource: contacts[index].contactSource
                )
            }
        } catch {
            print("⚠️ [MyContactsVM] Failed to rename contact: \(error)")
        }
    }

    func deleteContact(_ contact: SavedContact) async {
        do {
            try await SupabaseService.shared.deleteSavedContact(id: contact.id)
            contacts.removeAll { $0.contact.id == contact.id }
        } catch {
            print("⚠️ [MyContactsVM] Failed to delete contact: \(error)")
        }
    }

    func blockContact(_ contact: SavedContact) async {
        do {
            try await SupabaseService.shared.blockUser(
                blockedId: nil,
                blockedPhone: contact.phoneNumber,
                reason: "Blocked from contacts"
            )
            try await SupabaseService.shared.deleteSavedContact(id: contact.id)
            contacts.removeAll { $0.contact.id == contact.id }
        } catch {
            print("⚠️ [MyContactsVM] Failed to block contact: \(error)")
        }
    }
}

// MARK: - Contact with Stats

struct ContactWithStats: Identifiable {
    let contact: SavedContact
    let mutualEventCount: Int
    var isSavedContact: Bool = true
    var contactSource: MyContactsViewModel.ContactMergeSource = .saved

    var id: UUID { contact.id }

    var sourceLabel: String {
        switch contactSource {
        case .saved: return "Saved"
        case .frequent: return "Co-player"
        case .group: return "Group"
        case .invited: return "Invited"
        case .coAttendee: return "Co-attendee"
        }
    }
}
