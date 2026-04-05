import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showBGGLink = false
    @State private var showPrivacy = false
    @State private var showContacts = false
    @State private var showNotificationSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // MARK: - Profile Header Card
                    profileHeaderCard

                    // MARK: - Stats Grid
                    statsGrid

                    // MARK: - Badges
                    badgesSection

                    // MARK: - Event History
                    eventHistorySection

                    // MARK: - My Contacts
                    contactsRow

                    // MARK: - Settings
                    settingsSection

                    // MARK: - Sign Out
                    signOutButton
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, 100)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
            }
            .sheet(isPresented: $showBGGLink) {
                LinkBGGSheet()
            }
            .navigationDestination(isPresented: $showPrivacy) {
                PrivacySettingsView()
            }
            .navigationDestination(isPresented: $showContacts) {
                MyContactsView()
            }
            .navigationDestination(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
            .navigationDestination(for: GameEvent.self) { event in
                EventDetailView(eventId: event.id)
            }
            .onAppear {
                viewModel.loadIfNeeded()
            }
        }
    }

    // MARK: - Profile Header Card

    private var profileHeaderCard: some View {
        VStack(spacing: Theme.Spacing.lg) {
            AvatarView(url: appState.currentUser?.avatarUrl, size: 80)

            VStack(spacing: Theme.Spacing.xs) {
                Text(appState.currentUser?.displayName ?? "Player")
                    .font(Theme.Typography.displaySmall)
                    .foregroundColor(Theme.Colors.textPrimary)

                HStack(spacing: 6) {
                    Text(appState.currentUser?.maskedPhone ?? "")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textSecondary)

                    if !viewModel.joinedDateString.isEmpty {
                        Text("·")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textTertiary)
                        Text(viewModel.joinedDateString)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                if let bio = appState.currentUser?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                showEditProfile = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                    Text("Edit Profile")
                }
                .font(Theme.Typography.bodySemibold)
                .foregroundColor(Theme.Colors.primary)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    Capsule()
                        .stroke(Theme.Colors.primary, lineWidth: 1.5)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.lg)
        .cardStyle()
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatCard(icon: "bolt.fill", value: viewModel.hostedCount, label: "HOSTED", color: Theme.Colors.dateAccent)
            StatCard(icon: "calendar.badge.checkmark", value: viewModel.attendedCount, label: "ATTENDED", color: Theme.Colors.primaryAction)
            StatCard(icon: "dice.fill", value: viewModel.gameLibraryCount, label: "GAMES", color: Theme.Colors.accentWarm)
            StatCard(icon: "person.2.fill", value: viewModel.groupCount, label: "GROUPS", color: Theme.Colors.textSecondary)
        }
    }

    // MARK: - Badges Section

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(Theme.Colors.dateAccent)
                Text("Badges")
                    .font(Theme.Typography.headlineMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            // Badge chips - flow layout
            let badges = ProfileBadge.allBadges(
                hostedCount: viewModel.hostedCount,
                attendedCount: viewModel.attendedCount,
                gameCount: viewModel.gameLibraryCount,
                groupCount: viewModel.groupCount
            )

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(badges) { badge in
                    BadgeChip(badge: badge)
                }
            }

            Text("More badges coming soon!")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.primaryAction)
        }
        .cardStyle()
    }

    // MARK: - Event History

    private var eventHistorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "calendar")
                        .foregroundColor(Theme.Colors.dateAccent)
                    Text("Event History")
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                }

                Spacer()

                Button("View All") {
                    appState.navigateToCalendar = true
                }
                .font(Theme.Typography.bodySemibold)
                .foregroundColor(Theme.Colors.primaryAction)
            }

            if viewModel.recentEvents.isEmpty && !viewModel.isLoading {
                Text("No past events yet")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.lg)
            } else {
                ForEach(viewModel.recentEvents) { event in
                    NavigationLink(value: event) {
                        ProfileEventRow(
                            event: event,
                            invite: viewModel.recentEventInvites[event.id],
                            confirmedCount: viewModel.recentEventCounts[event.id] ?? 0
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Contacts Row

    private var contactsRow: some View {
        Button {
            showContacts = true
        } label: {
            HStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.primaryAction.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.primaryAction)
                }

                Text("My Contacts")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("(\(viewModel.savedContactsCount))")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "lock.shield.fill",
                title: "Privacy & Safety",
                subtitle: "Phone visibility, blocking, your data",
                color: Theme.Colors.accentWarm
            ) {
                showPrivacy = true
            }
            .padding(.bottom, 1)

            Divider()
                .padding(.horizontal, Theme.Spacing.lg)

            SettingsRow(
                icon: "dice.fill",
                title: "BoardGameGeek",
                subtitle: appState.currentUser?.bggUsername ?? "Link your account",
                color: Theme.Colors.textSecondary
            ) {
                showBGGLink = true
            }
            .padding(.vertical, 1)

            Divider()
                .padding(.horizontal, Theme.Spacing.lg)

            SettingsRow(
                icon: "bell.fill",
                title: "Notifications",
                subtitle: "Push & SMS preferences",
                color: Theme.Colors.primaryAction
            ) {
                showNotificationSettings = true
            }
            .padding(.vertical, 1)

            Divider()
                .padding(.horizontal, Theme.Spacing.lg)

            ThemeToggleRow()
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: Color.black.opacity(ThemeManager.shared.isDark ? 0.3 : 0.06), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
        )
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            Task { await appState.signOut() }
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .font(Theme.Typography.bodyMedium)
            .foregroundColor(Theme.Colors.error)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Theme.Colors.error.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.top, Theme.Spacing.sm)
    }
}

// MARK: - Profile Event Row

private struct ProfileEventRow: View {
    let event: GameEvent
    var invite: Invite?
    var confirmedCount: Int

    private var coverImageUrl: String? {
        event.coverImageUrl ?? event.games.first(where: { $0.isPrimary })?.game?.imageUrl ?? event.games.first?.game?.imageUrl
    }

    private var isCurrentUserHost: Bool {
        event.hostId == SupabaseService.shared.client.auth.currentSession?.user.id
    }

    private var hostName: String {
        if isCurrentUserHost { return "You" }
        return event.host?.displayName ?? "Unknown"
    }

    private var eventDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: event.effectiveStartDate)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Cover image
            Group {
                if let urlString = coverImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        GenerativeEventCover(title: event.title, eventId: event.id, variant: event.coverVariant)
                    }
                } else {
                    GenerativeEventCover(title: event.title, eventId: event.id, variant: event.coverVariant)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Text("\(eventDate) · Hosted by \(hostName)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Badge Model & Chip

struct ProfileBadge: Identifiable {
    let id: String
    let icon: String
    let name: String
    let isUnlocked: Bool

    static func allBadges(hostedCount: Int, attendedCount: Int, gameCount: Int, groupCount: Int) -> [ProfileBadge] {
        [
            ProfileBadge(id: "first_game_night", icon: "calendar.badge.checkmark", name: "First Game Night", isUnlocked: attendedCount >= 1 || hostedCount >= 1),
            ProfileBadge(id: "host_hero", icon: "crown.fill", name: "Host Hero", isUnlocked: hostedCount >= 3),
            ProfileBadge(id: "regular", icon: "flame.fill", name: "Regular", isUnlocked: attendedCount >= 5),
            ProfileBadge(id: "collector", icon: "dice.fill", name: "Collector", isUnlocked: gameCount >= 10),
            ProfileBadge(id: "social_butterfly", icon: "person.3.fill", name: "Social Butterfly", isUnlocked: groupCount >= 3),
            ProfileBadge(id: "champion", icon: "trophy.fill", name: "Champion", isUnlocked: attendedCount >= 20),
        ]
    }
}

private struct BadgeChip: View {
    let badge: ProfileBadge

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: badge.isUnlocked ? badge.icon : "lock.fill")
                .font(.system(size: 12))
            Text(badge.name)
                .font(Theme.Typography.caption)
        }
        .foregroundColor(badge.isUnlocked ? Theme.Colors.primaryAction : Theme.Colors.textTertiary)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Capsule()
                .fill(badge.isUnlocked ? Theme.Colors.primaryAction.opacity(0.12) : Theme.Colors.backgroundElevated)
                .overlay(
                    Capsule()
                        .stroke(badge.isUnlocked ? Theme.Colors.primaryAction.opacity(0.3) : Theme.Colors.divider, lineWidth: 1)
                )
        )
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.lg)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Profile Sheet
struct EditProfileSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var displayName = ""
    @State private var bio = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xxl) {
                AvatarUploadView(
                    currentAvatarUrl: appState.currentUser?.avatarUrl,
                    userId: appState.currentUser?.id,
                    onAvatarUpdated: { newUrl in
                        var user = appState.currentUser
                        user?.avatarUrl = newUrl
                        appState.currentUser = user
                    },
                    onAvatarDeleted: {
                        var user = appState.currentUser
                        user?.avatarUrl = nil
                        appState.currentUser = user
                    }
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("Display Name")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text("No real name required")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    TextField("Any name, nickname, or alias", text: $displayName)
                        .font(Theme.Typography.body)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.fieldBackground)
                        )
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Bio (optional)")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textSecondary)
                    TextField("Tell us about your gaming style", text: $bio, axis: .vertical)
                        .lineLimit(2...4)
                        .font(Theme.Typography.body)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.fieldBackground)
                        )
                }

                Button("Save") {
                    Task {
                        guard var user = appState.currentUser else { return }
                        isSaving = true
                        user.displayName = displayName
                        user.bio = bio.isEmpty ? nil : bio
                        try? await SupabaseService.shared.updateUser(user)
                        appState.currentUser = user
                        isSaving = false
                        dismiss()
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: !displayName.isEmpty))
                .disabled(displayName.isEmpty || isSaving)

                Spacer()
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .onAppear {
            displayName = appState.currentUser?.displayName ?? ""
            bio = appState.currentUser?.bio ?? ""
        }
    }
}

// MARK: - Theme Toggle Row
struct ThemeToggleRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.dateAccent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.dateAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Appearance")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(themeManager.mode == .light ? "Light" : themeManager.mode == .dark ? "Dark" : "System")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                Spacer()
            }

            Picker("Theme", selection: $themeManager.mode) {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .sageSegmented()
            .id(themeManager.isDark)
        }
        .padding(Theme.Spacing.lg)
    }
}

// MARK: - Link BGG Sheet
struct LinkBGGSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var username: String
    @State private var isSavingUsername = false
    @State private var isSyncingCollection = false
    @State private var isSyncingPlays = false
    @State private var toast: ToastItem?

    init() {
        // Will be set in onAppear from appState
        _username = State(initialValue: "")
    }

    private var isLinked: Bool { !(appState.currentUser?.bggUsername ?? "").isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Header
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.Gradients.secondary)

                        Text("BoardGameGeek")
                            .font(Theme.Typography.displaySmall)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("Enter your BGG username to sync your collection and play history.")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Username field
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("BGG Username")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.textSecondary)

                        HStack(spacing: Theme.Spacing.sm) {
                            TextField("username", text: $username)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                        .fill(Theme.Colors.fieldBackground)
                                )

                            Button {
                                Task { await saveUsername() }
                            } label: {
                                if isSavingUsername {
                                    ProgressView().tint(.white).frame(width: 44, height: 44)
                                } else {
                                    Text("Save")
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 44)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(username.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.primary)
                            )
                            .disabled(username.isEmpty || isSavingUsername)
                        }

                        if isLinked {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.Colors.success)
                                    .font(.system(size: 12))
                                Text("Linked as \(appState.currentUser?.bggUsername ?? "")")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.success)
                            }
                        }
                    }

                    // Sync options — only shown when username is linked
                    if isLinked {
                        VStack(spacing: Theme.Spacing.md) {
                            BGGSyncCard(
                                icon: "square.and.arrow.down",
                                title: "Sync Collection",
                                description: "Import games you own on BGG into your library.",
                                isLoading: isSyncingCollection
                            ) {
                                Task { await syncCollection() }
                            }

                            BGGSyncCard(
                                icon: "clock.arrow.2.circlepath",
                                title: "Import Play History",
                                description: "Import your BGG play log into the app.",
                                isLoading: isSyncingPlays
                            ) {
                                Task { await syncPlays() }
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .toast($toast)
            .onAppear {
                username = appState.currentUser?.bggUsername ?? ""
            }
        }
    }

    private func saveUsername() async {
        guard !username.isEmpty, var user = appState.currentUser else { return }
        isSavingUsername = true
        user.bggUsername = username
        do {
            try await SupabaseService.shared.updateUser(user)
            appState.currentUser = user
            toast = ToastItem(style: .success, message: "BGG account linked!")
        } catch {
            toast = ToastItem(style: .error, message: "Failed to save: \(error.localizedDescription)")
        }
        isSavingUsername = false
    }

    private func syncCollection() async {
        guard let bggUsername = appState.currentUser?.bggUsername, !bggUsername.isEmpty else { return }
        isSyncingCollection = true
        do {
            let response = try await BGGService.shared.fetchUserCollection(username: bggUsername)
            toast = ToastItem(style: .success, message: "Synced \(response.count) game\(response.count == 1 ? "" : "s") from your collection!")
        } catch {
            toast = ToastItem(style: .error, message: error.localizedDescription)
        }
        isSyncingCollection = false
    }

    private func syncPlays() async {
        guard let bggUsername = appState.currentUser?.bggUsername, !bggUsername.isEmpty else { return }
        isSyncingPlays = true
        do {
            let response = try await BGGService.shared.syncPlaysFromBGG(username: bggUsername)
            let count = response.imported ?? 0
            toast = ToastItem(style: .success, message: "Imported \(count) play\(count == 1 ? "" : "s") from BGG!")
        } catch {
            toast = ToastItem(style: .error, message: error.localizedDescription)
        }
        isSyncingPlays = false
    }
}

// MARK: - BGG Sync Card

private struct BGGSyncCard: View {
    let icon: String
    let title: String
    let description: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Theme.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: action) {
                if isLoading {
                    ProgressView()
                        .tint(Theme.Colors.primary)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .disabled(isLoading)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
        )
    }
}
