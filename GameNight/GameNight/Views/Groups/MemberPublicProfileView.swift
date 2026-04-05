import SwiftUI

struct MemberPublicProfileView: View {
    let member: GroupMember
    @ObservedObject var viewModel: GroupDetailViewModel
    @EnvironmentObject var appState: AppState

    @State private var user: User?
    @State private var profileSummary: UserProfileSummary?
    @State private var gameLibrary: [GameLibraryEntry] = []
    @State private var wishlist: [GameWishlistEntry] = []
    @State private var publicPlays: [Play] = []
    @State private var isLoading = true
    @State private var playsExpanded = false

    private var currentUserId: UUID? { appState.currentUser?.id }
    private var targetUserId: UUID? { member.userId }
    private var isViewingSelf: Bool {
        guard let cuid = currentUserId, let tuid = targetUserId else { return false }
        return cuid == tuid
    }

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: Theme.Spacing.lg) {
                    ForEach(0..<4, id: \.self) { _ in
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
                    headToHeadSection
                    mostPlayedSection
                    eventsTogetherSection
                    gameCollectionSection
                    wishlistSection
                    playsSection
                }
                .padding(Theme.Spacing.xl)
                .padding(.bottom, 100)
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle(member.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfile() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            AvatarView(url: user?.avatarUrl, size: 80)

            Text(user?.displayName ?? member.displayName ?? "Unknown")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

            if let bio = user?.bio, !bio.isEmpty {
                Text(bio)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Text("Member since \(member.addedAt.formatted(.dateTime.month(.wide).year()))")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
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

    // MARK: - Head-to-Head

    @ViewBuilder
    private var headToHeadSection: some View {
        if let cuid = currentUserId, let tuid = targetUserId, !isViewingSelf {
            let h2h = viewModel.headToHead(currentUserId: cuid, targetUserId: tuid)
            if h2h.hasData {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader(title: "Head-to-Head")

                    HStack(spacing: 0) {
                        H2HColumn(value: h2h.wins, label: "Wins", color: Theme.Colors.success)
                        Rectangle().fill(Theme.Colors.divider).frame(width: 1, height: 48)
                        H2HColumn(value: h2h.losses, label: "Losses", color: Theme.Colors.accentWarm)
                        Rectangle().fill(Theme.Colors.divider).frame(width: 1, height: 48)
                        H2HColumn(value: h2h.ties, label: "Ties", color: Theme.Colors.textTertiary)
                    }
                    .cardStyle()
                }
            }
        }
    }

    // MARK: - Most Played

    @ViewBuilder
    private var mostPlayedSection: some View {
        if let tuid = targetUserId, let topGame = viewModel.mostPlayedGame(for: tuid) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Most Played in Group")

                HStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.accentWarm.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.accentWarm)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(topGame.gameName)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("Played \(topGame.count) time\(topGame.count == 1 ? "" : "s")")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    Spacer()
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Events Together

    @ViewBuilder
    private var eventsTogetherSection: some View {
        if let cuid = currentUserId, let tuid = targetUserId, !isViewingSelf {
            let events = viewModel.eventsTogether(currentUserId: cuid, targetUserId: tuid)
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader(title: "Events Together")
                    VStack(spacing: 0) {
                        ForEach(Array(events.prefix(5).enumerated()), id: \.element.id) { index, event in
                            NavigationLink(value: event) {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.Colors.primary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title)
                                            .font(Theme.Typography.bodyMedium)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Text(event.effectiveStartDate, style: .date)
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textTertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                                .padding(.vertical, Theme.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                            if index < min(events.count, 5) - 1 { Divider() }
                        }
                    }
                    .cardStyle()
                }
            }
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
            } else if !u.gameLibraryPublic, !isViewingSelf {
                profilePrivateBanner(label: "Game collection is private")
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
            } else if !u.wishlistPublic, !isViewingSelf {
                profilePrivateBanner(label: "Wishlist is private")
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
                            PlayLogRow(play: play, targetUserId: targetUserId)
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
            } else if !u.playsPublic, !isViewingSelf {
                profilePrivateBanner(label: "Play history is private")
            }
        }
    }

    // MARK: - Helpers

    private func profilePrivateBanner(label: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "lock.fill").font(.system(size: 13))
            Text(label).font(Theme.Typography.callout)
        }
        .foregroundColor(Theme.Colors.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private func loadProfile() async {
        guard let userId = member.userId else {
            isLoading = false
            return
        }
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
            wishlist = fetchedWishlist  // RPC handles privacy server-side
            publicPlays = fetchedPlays  // RPC handles privacy server-side
        } catch {
            user = try? await SupabaseService.shared.fetchUserById(userId)
            profileSummary = try? await SupabaseService.shared.fetchProfileSummaryForUser(userId: userId)
        }
        isLoading = false
    }
}

// MARK: - Play Log Row

private struct PlayLogRow: View {
    let play: Play
    let targetUserId: UUID?

    private var userParticipant: PlayParticipant? {
        guard let uid = targetUserId else { return nil }
        return play.participants.first(where: { $0.userId == uid })
    }

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
            resultBadge
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    @ViewBuilder
    private var resultBadge: some View {
        if play.isCooperative {
            if let result = play.cooperativeResult {
                resultPill(text: result == .won ? "Won" : "Lost",
                           color: result == .won ? Theme.Colors.success : Theme.Colors.error)
            }
        } else if let p = userParticipant {
            if p.isWinner {
                resultPill(text: "Won", color: Theme.Colors.success)
            } else if let placement = p.placement {
                resultPill(text: "#\(placement)", color: Theme.Colors.textTertiary)
            }
        }
    }

    private func resultPill(text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
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

// MARK: - H2H Column

private struct H2HColumn: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("\(value)")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(color)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
