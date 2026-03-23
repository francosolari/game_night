import SwiftUI

struct PlayCard: View {
    let play: Play
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                // Game cover art
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.primary.opacity(0.1))
                        .frame(width: 48, height: 48)

                    if let url = play.game?.imageUrl ?? play.game?.thumbnailUrl, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Theme.Colors.primary)
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                    } else {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(play.game?.name ?? "Unknown Game")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: Theme.Spacing.sm) {
                        Text(play.playedAt.relativeDisplay)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)

                        Text(playerSummary)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Winner display
                if play.isCooperative {
                    if let result = play.cooperativeResult {
                        HStack(spacing: 4) {
                            Image(systemName: result == .won ? "trophy.fill" : "xmark.circle")
                                .font(.system(size: 12))
                            Text(result == .won ? "Won" : "Lost")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundColor(result == .won ? Theme.Colors.success : Theme.Colors.error)
                    }
                } else {
                    let winners = play.participants.filter(\.isWinner)
                    if !winners.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.accentWarm)
                            Text(winners.map(\.displayName).joined(separator: ", "))
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var playerSummary: String {
        let names = play.participants.prefix(2).map(\.displayName)
        let extra = play.participants.count - 2
        if names.isEmpty { return "" }
        var summary = names.joined(separator: ", ")
        if extra > 0 { summary += " +\(extra)" }
        return summary
    }
}
