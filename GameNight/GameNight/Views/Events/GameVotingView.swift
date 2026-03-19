import SwiftUI

struct GameVotingView: View {
    let eventGames: [EventGame]
    let myVotes: [UUID: GameVoteType]
    let isHost: Bool
    let confirmedGameId: UUID?
    let onVote: (UUID, GameVoteType) async -> Void
    let onConfirm: ((UUID) async -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.md) {
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
            // Larger thumbnail
            NavigationLink(value: game) {
                VStack(spacing: Theme.Spacing.sm) {
                    if let url = game.thumbnailUrl, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .fill(Theme.Colors.backgroundElevated)
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
                    } else {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.backgroundElevated)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "dice.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.Colors.textTertiary)
                            )
                    }

                    VStack(spacing: 2) {
                        Text(game.name)
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text("\(game.playtimeDisplay) · \(String(format: "%.1f", game.complexity))⚖️")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Vote buttons
            HStack(spacing: 4) {
                TriStateVoteButton(
                    icon: "checkmark",
                    label: "Yes",
                    color: Theme.Colors.success,
                    isSelected: myVote == .yes,
                    size: 28
                ) { Task { await onVote(.yes) } }

                TriStateVoteButton(
                    icon: "questionmark",
                    label: "Maybe",
                    color: Theme.Colors.warning,
                    isSelected: myVote == .maybe,
                    size: 28
                ) { Task { await onVote(.maybe) } }

                TriStateVoteButton(
                    icon: "xmark",
                    label: "No",
                    color: Theme.Colors.error,
                    isSelected: myVote == .no,
                    size: 28
                ) { Task { await onVote(.no) } }
            }

            // Vote tally
            HStack(spacing: 6) {
                if eventGame.yesCount > 0 {
                    HStack(spacing: 2) {
                        StatusDot(color: Theme.Colors.success, size: 5)
                        Text("\(eventGame.yesCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.success)
                    }
                }
                if eventGame.maybeCount > 0 {
                    HStack(spacing: 2) {
                        StatusDot(color: Theme.Colors.warning, size: 5)
                        Text("\(eventGame.maybeCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.warning)
                    }
                }
                if eventGame.noCount > 0 {
                    HStack(spacing: 2) {
                        StatusDot(color: Theme.Colors.error, size: 5)
                        Text("\(eventGame.noCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.error)
                    }
                }
            }

            if isConfirmed {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                    Text("Confirmed")
                        .font(Theme.Typography.caption2)
                }
                .foregroundColor(Theme.Colors.success)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.Colors.success.opacity(0.15)))
            }
        }
        .frame(width: 160)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(isConfirmed ? Theme.Colors.success.opacity(0.05) : Theme.Colors.backgroundElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
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
