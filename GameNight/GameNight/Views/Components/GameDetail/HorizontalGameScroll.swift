import SwiftUI

struct HorizontalGameScroll: View {
    let title: String
    let games: [Game]
    var contentPadding: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !title.isEmpty {
                Text(title)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .textCase(.uppercase)
                    .padding(.leading, contentPadding)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(games) { game in
                        NavigationLink(value: game) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                GameThumbnail(url: game.thumbnailUrl, size: 80)

                                Text(game.name)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(2)

                                if let year = game.yearPublished {
                                    Text(String(year))
                                        .font(Theme.Typography.caption2)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                            }
                            .frame(width: 100)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, contentPadding)
            }
        }
    }
}
