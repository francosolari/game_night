import SwiftUI

struct GameVotingView: View {
    let eventGames: [EventGame]
    let myVotes: [UUID: GameVoteType]
    let isHost: Bool
    let confirmedGameId: UUID?
    let onVote: (UUID, GameVoteType) async -> Void
    let onConfirm: ((UUID) async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                SectionHeader(title: "Games")
                Spacer()
                Text("Tap to vote")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(eventGames) { eventGame in
                        if let game = eventGame.game {
                            GameVoteCard(
                                game: game,
                                eventGame: eventGame,
                                myVote: myVotes[game.id],
                                isConfirmed: confirmedGameId == game.id,
                                isHost: isHost,
                                onVote: { voteType in
                                    await onVote(game.id, voteType)
                                },
                                onConfirm: isHost ? {
                                    await onConfirm?(game.id)
                                } : nil
                            )
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
}

private struct GameVoteCard: View {
    let game: Game
    let eventGame: EventGame
    let myVote: GameVoteType?
    let isConfirmed: Bool
    let isHost: Bool
    let onVote: (GameVoteType) async -> Void
    let onConfirm: (() async -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Game info row — tappable to view game detail
            NavigationLink(value: game) {
                HStack(spacing: Theme.Spacing.sm) {
                    if let url = game.thumbnailUrl, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.backgroundElevated)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                    } else {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.backgroundElevated)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "dice.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Colors.textTertiary)
                            )
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(game.name)
                            .font(Theme.Typography.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                        Text("\(game.playtimeDisplay) · \(String(format: "%.1f", game.complexity))⚖️")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Vote buttons
            HStack(spacing: 4) {
                TriStateVoteButton(
                    icon: "checkmark",
                    label: "Yes",
                    color: Theme.Colors.success,
                    isSelected: myVote == .yes,
                    size: 26
                ) { Task { await onVote(.yes) } }

                TriStateVoteButton(
                    icon: "questionmark",
                    label: "Maybe",
                    color: Theme.Colors.warning,
                    isSelected: myVote == .maybe,
                    size: 26
                ) { Task { await onVote(.maybe) } }

                TriStateVoteButton(
                    icon: "xmark",
                    label: "No",
                    color: Theme.Colors.error,
                    isSelected: myVote == .no,
                    size: 26
                ) { Task { await onVote(.no) } }
            }

            // Vote tally
            HStack(spacing: 4) {
                if eventGame.yesCount > 0 {
                    Text("\(eventGame.yesCount) yes")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.Colors.success)
                }
                if eventGame.maybeCount > 0 {
                    Text("\(eventGame.maybeCount) meh")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.Colors.warning)
                }
                if eventGame.noCount > 0 {
                    Text("\(eventGame.noCount) no")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.Colors.error)
                }
            }

            if isConfirmed {
                Text("Confirmed")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.Colors.success.opacity(0.15)))
            }
        }
        .frame(width: 130)
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(isConfirmed ? Theme.Colors.success.opacity(0.05) : Theme.Colors.backgroundElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(
                            isConfirmed ? Theme.Colors.success.opacity(0.2) : Theme.Colors.divider,
                            lineWidth: 1
                        )
                )
        )
        .contextMenu {
            if isHost, let onConfirm {
                Button {
                    Task { await onConfirm() }
                } label: {
                    Label("Confirm This Game", systemImage: "checkmark.seal.fill")
                }
            }
        }
    }
}
