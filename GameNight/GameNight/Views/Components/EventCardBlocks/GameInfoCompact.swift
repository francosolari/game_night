import SwiftUI

struct GameInfoCompact: View {
    let games: [EventGame]
    var size: ComponentSize = .standard

    private var displayCount: Int {
        switch size {
        case .compact: return 1
        case .standard, .expanded: return 2
        }
    }

    private var primaryGames: [EventGame] {
        let sorted = games.sorted { ($0.isPrimary ? 0 : 1) < ($1.isPrimary ? 0 : 1) }
        return Array(sorted.prefix(displayCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 1 : Theme.Spacing.xs) {
            ForEach(primaryGames) { eventGame in
                if let game = eventGame.game {
                    if size == .compact {
                        compactGameRow(game: game, isPrimary: eventGame.isPrimary)
                    } else {
                        standardGameRow(game: game, isPrimary: eventGame.isPrimary)
                    }
                }
            }
        }
    }

    // Compact: game name + playtime only, no complexity dots
    private func compactGameRow(game: Game, isPrimary: Bool) -> some View {
        HStack(spacing: 3) {
            if isPrimary {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Theme.Colors.accent)
            }
            Text(game.name)
                .font(Theme.Typography.caption2.weight(.bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.textPrimary.opacity(0.08))
                )

            Text("\u{00B7}")
                .foregroundColor(Theme.Colors.textTertiary)

            Text(game.playtimeDisplay)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
                .lineLimit(1)
                .layoutPriority(-1)
        }
    }

    // Standard/Expanded: full row with complexity dots
    private func standardGameRow(game: Game, isPrimary: Bool) -> some View {
        HStack(spacing: 4) {
            if isPrimary {
                Image(systemName: "star.fill")
                    .font(.system(size: size == .expanded ? 10 : 10))
                    .foregroundColor(Theme.Colors.accent)
            }
            Text(game.name)
                .font(size.captionFont.weight(.bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.textPrimary.opacity(0.08))
                )
            ComplexityDot(weight: game.complexity)
            Text(game.playtimeDisplay)
                .font(size == .expanded ? Theme.Typography.caption : Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
        }
    }
}
