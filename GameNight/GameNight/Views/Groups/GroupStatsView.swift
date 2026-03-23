import SwiftUI

struct GroupStatsView: View {
    @ObservedObject var viewModel: GroupDetailViewModel
    @State private var showFilterSheet = false

    private var stats: GroupStatsData { viewModel.stats }

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
                    groupMembers: viewModel.group.members,
                    showSheet: $showFilterSheet
                )

                // Fun stats row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.md) {
                        ForEach(stats.funStats) { stat in
                            VStack(spacing: Theme.Spacing.xs) {
                                Text(stat.emoji)
                                    .font(.system(size: 24))
                                Text(stat.title)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textTertiary)
                                Text(stat.value)
                                    .font(Theme.Typography.calloutMedium)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                            }
                            .frame(width: 100)
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .fill(Theme.Colors.cardBackground)
                            )
                        }
                    }
                }

                // Leaderboard
                if !stats.leaderboard.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        SectionHeader(title: "Leaderboard")

                        ForEach(Array(stats.leaderboard.enumerated()), id: \.element.id) { index, player in
                            VStack(spacing: Theme.Spacing.sm) {
                                HStack(spacing: Theme.Spacing.md) {
                                    Text("#\(index + 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(index == 0 ? Theme.Colors.accentWarm : Theme.Colors.textTertiary)
                                        .frame(width: 28)

                                    Text(player.name)
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(player.wins)W / \(player.totalPlays) plays")
                                            .font(Theme.Typography.calloutMedium)
                                            .foregroundColor(Theme.Colors.textPrimary)

                                        HStack(spacing: Theme.Spacing.sm) {
                                            Text("\(Int(player.winRate * 100))%")
                                                .font(Theme.Typography.caption2)
                                                .foregroundColor(Theme.Colors.primary)

                                            if let avgP = player.averagePlacement {
                                                Text("avg #\(String(format: "%.1f", avgP))")
                                                    .font(Theme.Typography.caption2)
                                                    .foregroundColor(Theme.Colors.textTertiary)
                                            }
                                        }
                                    }
                                }

                                // Win rate bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Theme.Colors.primary.opacity(0.1))
                                            .frame(height: 4)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Theme.Colors.primary)
                                            .frame(width: geo.size.width * player.winRate, height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                    }
                    .cardStyle()
                }

                // Most played games
                if !stats.mostPlayedGames.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        SectionHeader(title: "Most Played")

                        ForEach(Array(stats.mostPlayedGames.prefix(10).enumerated()), id: \.element.id) { index, game in
                            HStack(spacing: Theme.Spacing.md) {
                                Text("\(index + 1).")
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Theme.Colors.textTertiary)
                                    .frame(width: 24)

                                Text(game.gameName)
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundColor(Theme.Colors.textPrimary)

                                Spacer()

                                Text("\(game.count) play\(game.count == 1 ? "" : "s")")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                    }
                    .cardStyle()
                }
            }
        }
    }
}
