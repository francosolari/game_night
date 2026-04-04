import SwiftUI

struct GroupStatsView: View {
    @ObservedObject var viewModel: GroupDetailViewModel
    @State private var showFilterSheet = false
    @State private var animateWinBars = false

    private var stats: GroupStatsData { viewModel.stats }

    // UUID → first known thumbnailUrl across all plays
    private var thumbnailLookup: [UUID: String] {
        var result: [UUID: String] = [:]
        for play in viewModel.plays {
            if result[play.gameId] == nil {
                if let url = play.game?.thumbnailUrl ?? play.game?.imageUrl {
                    result[play.gameId] = url
                }
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            if viewModel.filteredPlays.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    title: "No Stats Yet",
                    message: "Play some games to see stats!"
                )
                .frame(minHeight: 200)
            } else {
                // Filter
                PlayFilterButton(
                    filter: $viewModel.playFilter,
                    customMembers: $viewModel.customFilterMembers,
                    gameFilterId: .constant(nil),
                    groupMembers: viewModel.group.members,
                    plays: viewModel.plays,
                    showSheet: $showFilterSheet
                )

                // Summary card
                StatsSummaryCard(
                    totalPlays: stats.totalPlays,
                    uniqueGames: stats.uniqueGames
                )

                // Fun stats grid
                if !stats.funStats.isEmpty {
                    FunStatsGrid(stats: stats.funStats)
                }

                // Leaderboard
                if !stats.leaderboard.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        SectionHeader(title: "Leaderboard")

                        VStack(spacing: 0) {
                            PodiumSection(
                                top3: Array(stats.leaderboard.prefix(3)),
                                animateBars: animateWinBars
                            )

                            if stats.leaderboard.count > 3 {
                                Divider()
                                    .padding(.vertical, Theme.Spacing.sm)
                                CompactLeaderboardRows(
                                    players: Array(stats.leaderboard.dropFirst(3)),
                                    startIndex: 3,
                                    animateBars: animateWinBars
                                )
                            }
                        }
                        .padding(Theme.Spacing.md)
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

                // Most played
                if !stats.mostPlayedGames.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        SectionHeader(title: "Most Played")

                        let games = Array(stats.mostPlayedGames.prefix(10))
                        VStack(spacing: 0) {
                            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                                MostPlayedRow(
                                    index: index,
                                    game: game,
                                    thumbnail: thumbnailLookup[game.gameId]
                                )
                                if index < games.count - 1 {
                                    Divider().padding(.leading, 76)
                                }
                            }
                        }
                        .padding(Theme.Spacing.md)
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
            }
        }
        .onAppear {
            withAnimation(Theme.Animation.snappy.delay(0.15)) {
                animateWinBars = true
            }
        }
    }
}

// MARK: - StatsSummaryCard

private struct StatsSummaryCard: View {
    let totalPlays: Int
    let uniqueGames: Int

    var body: some View {
        HStack(spacing: 0) {
            StatNumber(value: totalPlays, label: "Total Plays")
            Rectangle()
                .fill(Theme.Colors.divider)
                .frame(width: 1, height: 40)
            StatNumber(value: uniqueGames, label: "Unique Games")
        }
        .cardStyle()
    }
}

private struct StatNumber: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("\(value)")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - FunStatsGrid

private struct FunStatsGrid: View {
    let stats: [FunStat]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Highlights")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.md
            ) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    FunStatCard(
                        stat: stat,
                        accentColor: index.isMultiple(of: 2)
                            ? Theme.Colors.accentWarm
                            : Theme.Colors.primary
                    )
                }
            }
        }
    }
}

private struct FunStatCard: View {
    let stat: FunStat
    let accentColor: Color

    var body: some View {
        HStack(spacing: 0) {
            // Colored left accent bar
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)
                .clipShape(
                    .rect(
                        topLeadingRadius: Theme.CornerRadius.md,
                        bottomLeadingRadius: Theme.CornerRadius.md,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(stat.emoji)
                    .font(.system(size: 20))
                Text(stat.title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                Text(stat.value)
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 110)
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

// MARK: - WinRateBar

private struct WinRateBar: View {
    let rate: Double
    let animate: Bool
    var height: CGFloat = 8
    var color: Color = Theme.Colors.primary

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color.opacity(0.12))
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: animate ? geo.size.width * min(rate, 1.0) : 0, height: height)
                    .animation(Theme.Animation.snappy, value: animate)
            }
        }
        .frame(height: height)
    }
}

// MARK: - StreakBadge

private struct StreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 9))
            Text("\(streak)")
                .font(Theme.Typography.caption2)
        }
        .foregroundColor(Theme.Colors.accentWarm)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Theme.Colors.accentWarm.opacity(0.12))
        )
    }
}

// MARK: - PodiumSection

private struct PodiumSection: View {
    let top3: [PlayerStats]
    let animateBars: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(top3.enumerated()), id: \.element.id) { index, player in
                PodiumPlayerCard(player: player, rank: index + 1, animateBar: animateBars)
            }
        }
    }
}

private struct PodiumPlayerCard: View {
    let player: PlayerStats
    let rank: Int
    let animateBar: Bool

    private var accentColor: Color {
        switch rank {
        case 1: return Theme.Colors.accentWarm
        case 2: return Theme.Colors.primary
        default: return Theme.Colors.textTertiary
        }
    }

    private var rankLabel: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        default: return "🥉"
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                // Rank badge
                Text(rankLabel)
                    .font(.system(size: rank == 1 ? 28 : 22))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(player.name)
                            .font(rank == 1 ? Theme.Typography.headlineMedium : Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        if player.longestWinStreak >= 2 {
                            StreakBadge(streak: player.longestWinStreak)
                        }
                    }
                    Text("\(player.wins)W / \(player.totalPlays) plays")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(player.winRate * 100))%")
                        .font(rank == 1 ? Theme.Typography.headlineMedium : Theme.Typography.bodyMedium)
                        .foregroundColor(accentColor)
                    if let avg = player.averagePlacement {
                        Text("avg #\(String(format: "%.1f", avg))")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }

            WinRateBar(rate: player.winRate, animate: animateBar, height: 8, color: accentColor)
        }
        .padding(rank == 1 ? Theme.Spacing.md : Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(rank == 1 ? accentColor.opacity(0.08) : Color.clear)
        )
    }
}

// MARK: - CompactLeaderboardRows

private struct CompactLeaderboardRows: View {
    let players: [PlayerStats]
    let startIndex: Int
    let animateBars: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(players.enumerated()), id: \.element.id) { offset, player in
                VStack(spacing: Theme.Spacing.xs) {
                    HStack(spacing: Theme.Spacing.md) {
                        Text("#\(startIndex + offset + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.Colors.textTertiary)
                            .frame(width: 28)

                        Text(player.name)
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        if player.longestWinStreak >= 3 {
                            StreakBadge(streak: player.longestWinStreak)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(player.wins)W / \(player.totalPlays)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("\(Int(player.winRate * 100))%")
                                .font(Theme.Typography.caption2)
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }

                    WinRateBar(rate: player.winRate, animate: animateBars, height: 6)
                }
                .padding(.vertical, Theme.Spacing.sm)

                if offset < players.count - 1 {
                    Divider()
                }
            }
        }
    }
}

// MARK: - MostPlayedRow

private struct MostPlayedRow: View {
    let index: Int
    let game: GamePlayCount
    let thumbnail: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(index + 1).")
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textTertiary)
                .frame(width: 24, alignment: .trailing)

            // Thumbnail
            Group {
                if let urlStr = thumbnail, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        gameThumbnailPlaceholder
                    }
                } else {
                    gameThumbnailPlaceholder
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))

            Text(game.gameName)
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            Text("\(game.count) play\(game.count == 1 ? "" : "s")")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .padding(.vertical, Theme.Spacing.xs + 2)
    }

    private var gameThumbnailPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(Theme.Colors.primary.opacity(0.1))
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.primary)
        }
    }
}
