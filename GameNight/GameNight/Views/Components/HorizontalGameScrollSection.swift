import SwiftUI

/// Reusable horizontal scrolling section for game cards on public profiles.
/// Shows ~4 cards in the viewport; swipe to see more.
struct HorizontalGameScrollSection: View {
    let title: String
    let entries: [(game: Game, rating: Int?)]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "\(title) (\(entries.count))")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(entries, id: \.game.id) { entry in
                        NavigationLink {
                            GameDetailView(game: entry.game)
                        } label: {
                            HorizontalGameCard(game: entry.game, rating: entry.rating)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding(.horizontal, -Theme.Spacing.xl)
        }
    }
}

private struct HorizontalGameCard: View {
    let game: Game
    let rating: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
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
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))

            Text(game.name)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .frame(width: 88, alignment: .leading)

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
