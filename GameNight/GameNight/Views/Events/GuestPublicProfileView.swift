import SwiftUI

/// Lightweight public profile for viewing a user from an event guest list.
/// Unlike MemberPublicProfileView, this has no group context (no h2h or events-together).
struct GuestPublicProfileView: View {
    let userId: UUID
    let name: String
    let avatarUrl: String?

    @State private var user: User?
    @State private var profileSummary: UserProfileSummary?
    @State private var gameLibrary: [GameLibraryEntry] = []
    @State private var wishlist: [GameWishlistEntry] = []
    @State private var publicPlays: [Play] = []
    @State private var isLoading = true
    @State private var playsExpanded = false

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
                    headerSection
                    statsGrid
                    gameCollectionSection
                    wishlistSection
                    playsSection
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

    // MARK: - Header

    private var headerSection: some View {
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
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatCard(
                icon: "bolt.fill",
                value: profileSummary?.hostedEventCount ?? 0,
                label: "HOSTED",
                color: Theme.Colors.dateAccent
            )
            StatCard(
                icon: "calendar.badge.checkmark",
                value: profileSummary?.attendedEventCount ?? 0,
                label: "ATTENDED",
                color: Theme.Colors.primaryAction
            )
            if user?.gameLibraryPublic == true {
                StatCard(
                    icon: "dice.fill",
                    value: gameLibrary.count,
                    label: "GAMES",
                    color: Theme.Colors.accentWarm
                )
            }
            StatCard(
                icon: "person.2.fill",
                value: profileSummary?.groupCount ?? 0,
                label: "GROUPS",
                color: Theme.Colors.textSecondary
            )
        }
    }

    // MARK: - Game Collection

    @ViewBuilder
    private var gameCollectionSection: some View {
        if let u = user {
            if u.gameLibraryPublic, !gameLibrary.isEmpty {
                HorizontalGameScrollSection(
                    title: "Game Collection",
                    entries: gameLibrary.compactMap { entry in
                        guard let game = entry.game else { return nil }
                        return (game: game, rating: entry.rating)
                    }
                )
            } else if !u.gameLibraryPublic {
                privacyBanner(label: "Game collection is private")
            }
        }
    }

    // MARK: - Wishlist

    @ViewBuilder
    private var wishlistSection: some View {
        if let u = user {
            if u.wishlistPublic, !wishlist.isEmpty {
                HorizontalGameScrollSection(
                    title: "Wishlist",
                    entries: wishlist.compactMap { entry in
                        guard let game = entry.game else { return nil }
                        return (game: game, rating: nil)
                    }
                )
            } else if !u.wishlistPublic {
                privacyBanner(label: "Wishlist is private")
            }
        }
    }

    // MARK: - Plays

    @ViewBuilder
    private var playsSection: some View {
        if let u = user {
            if u.playsPublic, !publicPlays.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader(title: "Play History (\(publicPlays.count))")

                    let visiblePlays = playsExpanded ? publicPlays : Array(publicPlays.prefix(3))
                    VStack(spacing: 0) {
                        ForEach(Array(visiblePlays.enumerated()), id: \.element.id) { index, play in
                            GuestPlayLogRow(play: play)
                            if index < visiblePlays.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }

                        if publicPlays.count > 3 {
                            Divider()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    playsExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Text(playsExpanded ? "Show less" : "Show \(publicPlays.count - 3) more")
                                        .font(Theme.Typography.calloutMedium)
                                        .foregroundColor(Theme.Colors.primary)
                                    Image(systemName: playsExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.Colors.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cardStyle()
                }
            } else if !u.playsPublic {
                privacyBanner(label: "Play history is private")
            }
        }
    }

    private func privacyBanner(label: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "lock.fill").font(.system(size: 13))
            Text(label).font(Theme.Typography.callout)
        }
        .foregroundColor(Theme.Colors.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private func loadProfile() async {
        do {
            async let userFetch = SupabaseService.shared.fetchUserById(userId)
            async let summaryFetch = SupabaseService.shared.fetchProfileSummaryForUser(userId: userId)
            async let libraryFetch = SupabaseService.shared.fetchGameLibraryForUser(userId: userId)
            async let wishlistFetch = SupabaseService.shared.fetchPublicWishlistForUser(userId: userId)
            async let playsFetch = SupabaseService.shared.fetchPublicPlaysForUser(userId: userId)
            let (fetchedUser, fetchedSummary, fetchedLibrary, fetchedWishlist, fetchedPlays) = try await (
                userFetch, summaryFetch, libraryFetch, wishlistFetch, playsFetch
            )
            user = fetchedUser
            profileSummary = fetchedSummary
            if fetchedUser.gameLibraryPublic { gameLibrary = fetchedLibrary }
            wishlist = fetchedWishlist
            publicPlays = fetchedPlays
        } catch {
            user = try? await SupabaseService.shared.fetchUserById(userId)
            profileSummary = try? await SupabaseService.shared.fetchProfileSummaryForUser(userId: userId)
        }
        isLoading = false
    }
}

// MARK: - Guest Play Log Row

private struct GuestPlayLogRow: View {
    let play: Play

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Group {
                if let urlStr = play.game?.thumbnailUrl ?? play.game?.imageUrl,
                   let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { playPlaceholder }
                } else { playPlaceholder }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(play.game?.name ?? "Unknown Game")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(play.playedAt, style: .date)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

            Spacer()

            if play.isCooperative, let result = play.cooperativeResult {
                let isWon = result == .won
                Text(isWon ? "Won" : "Lost")
                    .font(Theme.Typography.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isWon ? Theme.Colors.success : Theme.Colors.error)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill((isWon ? Theme.Colors.success : Theme.Colors.error).opacity(0.12)))
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var playPlaceholder: some View {
        ZStack {
            Theme.Colors.primary.opacity(0.08)
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.primary.opacity(0.4))
        }
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
