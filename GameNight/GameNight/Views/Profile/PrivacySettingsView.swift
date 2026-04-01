import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var phoneVisible: Bool = false
    @State private var discoverableByPhone: Bool = true
    @State private var gameLibraryPublic: Bool = true
    @State private var marketingOptIn: Bool = false
    @State private var showBlockedUsers = false
    @State private var showDeleteConfirm = false
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                // Header
                VStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.accent.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.Colors.accent)
                    }

                    Text("Privacy & Safety")
                        .font(Theme.Typography.displaySmall)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("You're in control of your data")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.top, Theme.Spacing.lg)

                // Phone privacy
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader(title: "Phone Number")

                    PrivacyToggle(
                        icon: "eye.slash.fill",
                        title: "Hide phone from other users",
                        description: "Other users will see your display name, not your phone number",
                        isOn: Binding(
                            get: { !phoneVisible },
                            set: { phoneVisible = !$0 }
                        )
                    )

                    PrivacyToggle(
                        icon: "magnifyingglass",
                        title: "Discoverable by phone number",
                        description: "Friends who have your number can find you on Game Night",
                        isOn: $discoverableByPhone
                    )
                }
                .cardStyle()

                // Game Library
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader(title: "Game Library")

                    PrivacyToggle(
                        icon: "books.vertical.fill",
                        title: "Game library visible to others",
                        description: "Group members can see your game collection on your profile",
                        isOn: $gameLibraryPublic
                    )
                }
                .cardStyle()

                // Contacts
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader(title: "Contacts")

                    HStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.success.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 18))
                                .foregroundColor(Theme.Colors.success)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy-first contacts")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("We only store contacts you choose to invite, never your whole address book")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                }
                .cardStyle()

                // Communication
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader(title: "Communication")

                    PrivacyToggle(
                        icon: "megaphone.fill",
                        title: "Marketing emails & notifications",
                        description: "We don't subscribe you by default — opt in only if you want product updates",
                        isOn: $marketingOptIn
                    )
                }
                .cardStyle()

                // Blocking
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader(title: "Safety")

                    Button {
                        showBlockedUsers = true
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.error.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.Colors.error)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Blocked Users")
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text("Blocked users can't invite you or see your profile")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .cardStyle()

                // Data
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader(title: "Your Data")

                    HStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.primary.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                                .foregroundColor(Theme.Colors.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("We never sell your data")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Your personal information is never shared for advertising or sold to third parties")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }

                    Divider().background(Theme.Colors.divider)

                    Button {
                        Task { await exportData() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .foregroundColor(Theme.Colors.primary)
                            Text("Export My Data")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(Theme.Colors.error)
                            Text("Delete My Account")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.error)
                        }
                    }
                }
                .cardStyle()

                // Save
                Button("Save Privacy Settings") {
                    Task { await saveSettings() }
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: !isSaving))
                .disabled(isSaving)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, 100)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBlockedUsers) {
            BlockedUsersView()
        }
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This permanently deletes your account, game library, groups, and all event history. This cannot be undone.")
        }
        .onAppear {
            phoneVisible = appState.currentUser?.phoneVisible ?? false
            discoverableByPhone = appState.currentUser?.discoverableByPhone ?? true
            gameLibraryPublic = appState.currentUser?.gameLibraryPublic ?? true
            marketingOptIn = appState.currentUser?.marketingOptIn ?? false
        }
    }

    private func saveSettings() async {
        guard var user = appState.currentUser else { return }
        isSaving = true
        user.phoneVisible = phoneVisible
        user.discoverableByPhone = discoverableByPhone
        user.gameLibraryPublic = gameLibraryPublic
        user.marketingOptIn = marketingOptIn
        try? await SupabaseService.shared.updateUser(user)
        appState.currentUser = user
        isSaving = false
    }

    private func exportData() async {
        // Trigger data export via Edge Function
        try? await SupabaseService.shared.invokeAuthenticatedFunction(
            "export-user-data",
            body: [:] as [String: String]
        )
    }

    private func deleteAccount() async {
        try? await SupabaseService.shared.invokeAuthenticatedFunction(
            "delete-user-account",
            body: [:] as [String: String]
        )
        await appState.signOut()
    }
}

// MARK: - Privacy Toggle
struct PrivacyToggle: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
        .tint(Theme.Colors.primary)
    }
}

// MARK: - Blocked Users View
struct BlockedUsersView: View {
    @Environment(\.dismiss) var dismiss
    @State private var blockedUsers: [BlockedUser] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if blockedUsers.isEmpty {
                    VStack(spacing: Theme.Spacing.lg) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.Colors.success)

                        Text("No blocked users")
                            .font(Theme.Typography.headlineLarge)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("Anyone you block won't be able to invite you or see your profile.")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xxxl)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(blockedUsers) { blocked in
                            HStack {
                                AvatarView(url: nil, size: 36)

                                VStack(alignment: .leading) {
                                    Text(blocked.blockedPhone ?? "User")
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    if let reason = blocked.reason {
                                        Text(reason)
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textTertiary)
                                    }
                                }

                                Spacer()

                                Button("Unblock") {
                                    Task { await unblock(id: blocked.id) }
                                }
                                .font(Theme.Typography.calloutMedium)
                                .foregroundColor(Theme.Colors.error)
                            }
                            .listRowBackground(Theme.Colors.cardBackground)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Blocked Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .task {
            await loadBlocked()
        }
    }

    private func loadBlocked() async {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            blockedUsers = try await SupabaseService.shared.client
                .from("blocked_users")
                .select()
                .eq("blocker_id", value: session.user.id.uuidString)
                .execute()
                .value
        } catch {
            // Ignore
        }
        isLoading = false
    }

    private func unblock(id: UUID) async {
        _ = try? await SupabaseService.shared.client
            .from("blocked_users")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        blockedUsers.removeAll { $0.id == id }
    }
}
