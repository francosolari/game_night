import SwiftUI

// MARK: - Game Card (used in library, event creation, search results)
struct GameCard: View {
    let game: Game
    var isPrimary: Bool = false
    var showAddButton: Bool = false
    var onAdd: (() -> Void)?

    var body: some View {
        content
            .cardStyle()
    }

    private var content: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Thumbnail
            GameThumbnail(url: game.thumbnailUrl, size: 72)

            // Info
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    if isPrimary {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.warning)
                    }

                    Text(game.name)
                        .font(Theme.Typography.titleMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                }

                if let year = game.yearPublished {
                    Text("(\(String(year)))")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                HStack(spacing: Theme.Spacing.md) {
                    Label(game.playerCountDisplay, systemImage: "person.2.fill")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)

                    Label(game.playtimeDisplay, systemImage: "clock.fill")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                ComplexityBadge(weight: game.complexity)
            }

            Spacer()

            if showAddButton {
                Button(action: { onAdd?() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.Gradients.primary)
                }
                .buttonStyle(.plain)
            }

            if let rating = game.bggRating {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", rating))
                        .font(Theme.Typography.titleMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("BGG")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
    }
}

// MARK: - Compact Game Card (for event invites)
struct CompactGameCard: View {
    let game: Game
    var isPrimary: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            GameThumbnail(url: game.thumbnailUrl, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if isPrimary {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.accent)
                    }
                    Text(game.name)
                        .font(Theme.Typography.calloutMedium.weight(.bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.gameHighlight)
                        )
                }

                HStack(spacing: Theme.Spacing.sm) {
                    ComplexityDot(weight: game.complexity)
                    Text(game.playtimeDisplay)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text("·")
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text(game.playerCountDisplay)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Game Thumbnail
struct GameThumbnail: View {
    let url: String?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let url, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        gamePlaceholder
                    case .empty:
                        ProgressView()
                            .tint(Theme.Colors.textTertiary)
                    @unknown default:
                        gamePlaceholder
                    }
                }
            } else {
                gamePlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
    }

    private var gamePlaceholder: some View {
        ZStack {
            Theme.Colors.backgroundElevated
            Image(systemName: "dice.fill")
                .font(.system(size: size * 0.3))
                .foregroundColor(Theme.Colors.textTertiary)
        }
    }
}

// MARK: - Complexity Badge
struct ComplexityBadge: View {
    let weight: Double

    var body: some View {
        HStack(spacing: 4) {
            ComplexityDot(weight: weight)
            Text(Theme.Colors.complexityLabel(weight))
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.complexity(weight))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Theme.Colors.complexity(weight).opacity(0.15))
        )
    }
}

// MARK: - Complexity Dot
struct ComplexityDot: View {
    let weight: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                Circle()
                    .fill(Double(i) < weight
                        ? Theme.Colors.complexity(weight)
                        : Theme.Colors.complexity(weight).opacity(0.2))
                    .frame(width: 5, height: 5)
            }
        }
    }
}
