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
                    HStack(spacing: 4) {
                        if eventGame.isPrimary {
                            Image(systemName: "star.fill")
                                .font(.system(size: size == .compact ? 8 : 10))
                                .foregroundColor(Theme.Colors.highlight)
                        }
                        Text(game.name)
                            .font(size.captionFont)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        ComplexityDot(weight: game.complexity)
                        Text(game.playtimeDisplay)
                            .font(size == .compact ? Theme.Typography.caption2 : Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }
        }
    }
}
