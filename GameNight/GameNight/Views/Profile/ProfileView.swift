import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showEditProfile = false
    @State private var showBGGLink = false
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Profile header
                    VStack(spacing: Theme.Spacing.lg) {
                        AvatarView(url: appState.currentUser?.avatarUrl, size: 80)

                        VStack(spacing: Theme.Spacing.xs) {
                            Text(appState.currentUser?.displayName ?? "Player")
                                .font(Theme.Typography.displaySmall)
                                .foregroundColor(Theme.Colors.textPrimary)

                            // Show masked phone by default (privacy-first)
                            Text(appState.currentUser?.maskedPhone ?? "")
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.textSecondary)

                            if let bio = appState.currentUser?.bio {
                                Text(bio)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        Button("Edit Profile") {
                            showEditProfile = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(width: 160)
                    }
                    .padding(.top, Theme.Spacing.xl)

                    // Settings sections
                    VStack(spacing: Theme.Spacing.md) {
                        // Privacy & Safety (prominent position)
                        SettingsRow(
                            icon: "lock.shield.fill",
                            title: "Privacy & Safety",
                            subtitle: "Phone visibility, blocking, your data",
                            color: Theme.Colors.accentWarm
                        ) {
                            showPrivacy = true
                        }

                        // BGG Integration
                        SettingsRow(
                            icon: "dice.fill",
                            title: "BoardGameGeek",
                            subtitle: appState.currentUser?.bggUsername ?? "Link your account",
                            color: Theme.Colors.textSecondary
                        ) {
                            showBGGLink = true
                        }

                        // Notifications
                        SettingsRow(
                            icon: "bell.fill",
                            title: "Notifications",
                            subtitle: "Push & SMS preferences",
                            color: Theme.Colors.primaryAction
                        ) {
                            // TODO: Notification settings
                        }

                        // Appearance — theme toggle
                        ThemeToggleRow()
                    }
                    .padding(.horizontal, Theme.Spacing.xl)

                    // Sign out
                    VStack(spacing: Theme.Spacing.md) {
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
                                    .fill(Theme.Colors.error.opacity(0.1))
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)
                }
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
        }
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
            .cardStyle()
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
                AvatarView(url: appState.currentUser?.avatarUrl, size: 80)

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
        }
        .cardStyle()
    }
}

// MARK: - Link BGG Sheet
struct LinkBGGSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var username = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xxl) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.Gradients.secondary)

                Text("Link BoardGameGeek")
                    .font(Theme.Typography.displaySmall)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Connect your BGG account to import your game collection and get personalized recommendations.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                TextField("BGG Username", text: $username)
                    .font(Theme.Typography.body)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.fieldBackground)
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button("Link Account") {
                    Task {
                        guard var user = appState.currentUser else { return }
                        user.bggUsername = username
                        try? await SupabaseService.shared.updateUser(user)
                        appState.currentUser = user
                        dismiss()
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: !username.isEmpty))
                .disabled(username.isEmpty)

                Spacer()
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
    }
}
