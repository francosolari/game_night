import SwiftUI

struct ExpandableGameGrid: View {
    let games: [Game]
    var initialCount: Int = 5
    let sortMode: SortOption
    @State private var isExpanded = false

    private var sortedGames: [Game] {
        switch sortMode {
        case .topRated:
            return games.sorted { ($0.bggRating ?? 0) > ($1.bggRating ?? 0) }
        case .alphabetical:
            return games.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .byYear:
            return games.sorted { ($0.yearPublished ?? 0) > ($1.yearPublished ?? 0) }
        case .byWeight:
            return games.sorted { $0.complexity > $1.complexity }
        case .recentlyAdded:
            return games
        }
    }

    private var displayedGames: [Game] {
        isExpanded ? sortedGames : Array(sortedGames.prefix(initialCount))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(displayedGames) { game in
                NavigationLink {
                    GameDetailView(game: game)
                } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        GameThumbnail(url: game.thumbnailUrl, size: 48)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.name)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)

                            HStack(spacing: Theme.Spacing.sm) {
                                if let year = game.yearPublished {
                                    Text(String(year))
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                                if game.complexity > 0 {
                                    WeightDisplay(weight: game.complexity)
                                }
                            }
                        }

                        Spacer()

                        if let rating = game.bggRating {
                            RatingBadge(rating: rating, size: .small)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.backgroundElevated)
                    )
                }
                .buttonStyle(.plain)
            }

            if !isExpanded && sortedGames.count > initialCount {
                Button {
                    withAnimation { isExpanded = true }
                } label: {
                    Text("Show All \(sortedGames.count) Games")
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.primary.opacity(0.1))
                        )
                }
            }
        }
    }
}
