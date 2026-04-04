import SwiftUI

/// Lightweight public profile for viewing a user from an event guest list.
/// Unlike MemberPublicProfileView, this has no group context (no h2h or events-together).
struct GuestPublicProfileView: View {
    let userId: UUID
    let name: String
    let avatarUrl: String?

    @State private var user: User?
    @State private var gameLibrary: [GameLibraryEntry] = []
    @State private var wishlist: [GameWishlistEntry] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: Theme.Spacing.lg) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.cardBackground)
                            .frame(height: 64)
                            .shimmer()
                    }
                }
                .padding(Theme.Spacing.xl)
            } else {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Header
                    VStack(spacing: Theme.Spacing.md) {
                        AvatarView(url: user?.avatarUrl ?? avatarUrl, size: 80)

                        Text(user?.displayName ?? name)
                            .font(Theme.Typography.displaySmall)
                            .foregroundColor(Theme.Colors.textPrimary)

                        if let bio = user?.bio, !bio.isEmpty {
                            Text(bio)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        if let joinDate = user?.createdAt {
                            Text("On Game Night since \(joinDate.formatted(.dateTime.month(.wide).year()))")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }

                    // Stats
                    if user?.gameLibraryPublic == true {
                        HStack(spacing: Theme.Spacing.md) {
                            GuestStatCapsule(
                                value: "\(gameLibrary.count)",
                                label: "Games",
                                icon: "gamecontroller.fill",
                                color: Theme.Colors.primary
                            )
                        }
                    }

                    // Game Collection
                    if let u = user {
                        if u.gameLibraryPublic && !gameLibrary.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                SectionHeader(title: "Game Collection (\(gameLibrary.count))")

                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: Theme.Spacing.md
                                ) {
                                    ForEach(gameLibrary.prefix(20)) { entry in
                                        if let game = entry.game {
                                            NavigationLink {
                                                GameDetailView(game: game)
                                            } label: {
                                                GuestGameCell(game: game, rating: entry.rating)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                if gameLibrary.count > 20 {
                                    Text("\(gameLibrary.count - 20) more games")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }

                        // Wishlist
                        if u.gameLibraryPublic && !wishlist.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                SectionHeader(title: "Wishlist (\(wishlist.count))")

                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: Theme.Spacing.md
                                ) {
                                    ForEach(wishlist.prefix(20)) { entry in
                                        if let game = entry.game {
                                            NavigationLink {
                                                GameDetailView(game: game)
                                            } label: {
                                                GuestGameCell(game: game, rating: nil)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                if wishlist.count > 20 {
                                    Text("\(wishlist.count - 20) more games")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }

                        if !u.gameLibraryPublic {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 13))
                                Text("Game library is private")
                                    .font(Theme.Typography.callout)
                            }
                            .foregroundColor(Theme.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xxl)
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
                .padding(.bottom, 100)
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfile() }
    }

    private func loadProfile() async {
        do {
            async let userFetch = SupabaseService.shared.fetchUserById(userId)
            async let libraryFetch = SupabaseService.shared.fetchGameLibraryForUser(userId: userId)
            async let wishlistFetch = SupabaseService.shared.fetchWishlistForUser(userId: userId)
            let (fetchedUser, fetchedLibrary, fetchedWishlist) = try await (userFetch, libraryFetch, wishlistFetch)
            user = fetchedUser
            if fetchedUser.gameLibraryPublic {
                gameLibrary = fetchedLibrary
                wishlist = fetchedWishlist
            }
        } catch {
            user = try? await SupabaseService.shared.fetchUserById(userId)
        }
        isLoading = false
    }
}

// MARK: - Private Helpers

private struct GuestStatCapsule: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
    }
}

private struct GuestGameCell: View {
    let game: Game
    let rating: Int?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Group {
                if let urlStr = game.imageUrl ?? game.thumbnailUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        gamePlaceholder
                    }
                } else {
                    gamePlaceholder
                }
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))

            Text(game.name)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if let r = rating {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.accentWarm)
                    Text("\(r)/10")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
    }

    private var gamePlaceholder: some View {
        ZStack {
            Theme.Colors.primary.opacity(0.08)
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 24))
                .foregroundColor(Theme.Colors.primary.opacity(0.4))
        }
    }
}
