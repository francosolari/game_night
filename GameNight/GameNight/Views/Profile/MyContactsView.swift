import SwiftUI

struct MyContactsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MyContactsViewModel()
    @State private var searchText = ""
    @State private var showDevicePicker = false
    @Environment(\.dismiss) private var dismiss

    var filteredContacts: [ContactWithStats] {
        if searchText.isEmpty {
            return viewModel.contacts
        }
        return viewModel.contacts.filter {
            $0.contact.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.contacts.isEmpty {
                emptyState
            } else {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.textTertiary)
                    TextField("Search contacts...", text: $searchText)
                        .font(Theme.Typography.body)
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .fill(Theme.Colors.fieldBackground)
                )
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.md)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Import from phone button
                        Button {
                            showDevicePicker = true
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 14))
                                Text("Sync Contacts from Phone")
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

                        ForEach(filteredContacts) { item in
                            SavedContactRow(
                                item: item,
                                onRename: { newName in
                                    Task {
                                        await viewModel.renameContact(item.contact, newName: newName)
                                    }
                                },
                                onDelete: {
                                    Task {
                                        await viewModel.deleteContact(item.contact)
                                    }
                                },
                                onBlock: {
                                    Task {
                                        await viewModel.blockContact(item.contact)
                                    }
                                }
                            )

                            if item.id != filteredContacts.last?.id {
                                Divider()
                                    .padding(.leading, 72)
                                    .padding(.horizontal, Theme.Spacing.xl)
                            }
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
            ContactPickerSheet { deviceContacts in
                guard !deviceContacts.isEmpty else { return }
                Task {
                    _ = try? await SupabaseService.shared.saveContacts(deviceContacts)
                    await viewModel.loadData()
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.textTertiary)

            Text("No contacts yet")
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Sync from your phone or invite people to events to build your contacts.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showDevicePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                    Text("Sync from Phone")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 220)
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Contact Row

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
            HStack(spacing: Theme.Spacing.md) {
                AvatarView(url: item.contact.avatarUrl, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.contact.name)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        if item.contact.isAppUser {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.primaryAction)
                        }
                    }

                    if item.mutualEventCount > 0 {
                        Text("\(item.mutualEventCount) event\(item.mutualEventCount == 1 ? "" : "s") together")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    } else {
                        Text(item.contact.phoneNumber)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
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

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

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

            // Build unified contact map keyed by normalized phone
            // Each entry: (name, phone, avatarUrl, isAppUser, mutualEventCount, savedContactId?)
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
                    savedContactId: sc.id
                )
            }

            // 2. Frequent contacts (co-attendees from events) — fills mutual counts + adds new people
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
                        savedContactId: nil
                    )
                }
            }

            // 3. Group members — anyone in your groups
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
                            savedContactId: nil
                        )
                    }
                }
            }

            // 4. Invites you've sent (from events you hosted) — people you've invited
            let hostedEventIds = Set(myEvents.map(\.id))
            for eventId in hostedEventIds {
                if let invites = try? await SupabaseService.shared.fetchInvites(eventId: eventId) {
                    for invite in invites where invite.userId != myUserId {
                        let key = invite.phoneNumber.filter(\.isNumber)
                        if contactMap[key] == nil {
                            contactMap[key] = MergedContact(
                                name: invite.displayName ?? invite.phoneNumber,
                                phoneNumber: invite.phoneNumber,
                                avatarUrl: nil,
                                isAppUser: invite.userId != nil,
                                mutualEventCount: 0,
                                savedContactId: nil
                            )
                        }
                    }
                }
            }

            // 5. Co-attendees from events I was invited to
            let attendedEventIds = Set(myInvites.filter { $0.status == .accepted }.map(\.eventId))
            for eventId in attendedEventIds where !hostedEventIds.contains(eventId) {
                if let invites = try? await SupabaseService.shared.fetchInvites(eventId: eventId) {
                    for invite in invites where invite.userId != myUserId && invite.status == .accepted {
                        let key = invite.phoneNumber.filter(\.isNumber)
                        if contactMap[key] == nil {
                            contactMap[key] = MergedContact(
                                name: invite.displayName ?? invite.phoneNumber,
                                phoneNumber: invite.phoneNumber,
                                avatarUrl: nil,
                                isAppUser: invite.userId != nil,
                                mutualEventCount: 0,
                                savedContactId: nil
                            )
                        }
                    }
                }
            }

            // Remove self
            let myPhone = session.user.phone ?? ""
            let myKey = myPhone.filter(\.isNumber)
            contactMap.removeValue(forKey: myKey)

            // Convert to ContactWithStats, sorted by mutual events then name
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
                        isSavedContact: mc.savedContactId != nil
                    )
                }
                .sorted { a, b in
                    if a.mutualEventCount != b.mutualEventCount {
                        return a.mutualEventCount > b.mutualEventCount
                    }
                    return a.contact.name.localizedCaseInsensitiveCompare(b.contact.name) == .orderedAscending
                }
        } catch {
            print("⚠️ [MyContactsVM] Failed to load contacts: \(error)")
        }
    }

    private struct MergedContact {
        var name: String
        var phoneNumber: String
        var avatarUrl: String?
        var isAppUser: Bool
        var mutualEventCount: Int
        var savedContactId: UUID?
    }

    func renameContact(_ contact: SavedContact, newName: String) async {
        do {
            try await SupabaseService.shared.updateSavedContactName(id: contact.id, name: newName)
            if let index = contacts.firstIndex(where: { $0.contact.id == contact.id }) {
                var updated = contacts[index].contact
                updated.name = newName
                contacts[index] = ContactWithStats(
                    contact: updated,
                    mutualEventCount: contacts[index].mutualEventCount
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
            // Block by phone number (userId may not be available for non-app users)
            try await SupabaseService.shared.blockUser(
                blockedId: nil,
                blockedPhone: contact.phoneNumber,
                reason: "Blocked from contacts"
            )
            // Also remove from saved contacts
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

    var id: UUID { contact.id }
}
