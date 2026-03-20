import SwiftUI

struct PlayDetailView: View {
    let play: Play
    let currentUserId: UUID?
    var onDelete: (() async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var toast: ToastItem?

    private var isLogger: Bool {
        currentUserId == play.loggedBy
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                // Game header
                VStack(spacing: Theme.Spacing.md) {
                    if let url = play.game?.imageUrl, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                .fill(Theme.Colors.primary.opacity(0.1))
                                .frame(height: 120)
                        }
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
                    }

                    Text(play.game?.name ?? "Unknown Game")
                        .font(Theme.Typography.displaySmall)
                        .foregroundColor(Theme.Colors.textPrimary)

                    HStack(spacing: Theme.Spacing.md) {
                        Label {
                            Text(playDateDisplay)
                                .font(Theme.Typography.callout)
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Theme.Colors.textSecondary)

                        if let duration = play.durationMinutes {
                            Label {
                                Text("\(duration) min")
                                    .font(Theme.Typography.callout)
                            } icon: {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }

                // Co-op result
                if play.isCooperative, let result = play.cooperativeResult {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: result == .won ? "trophy.fill" : "xmark.circle.fill")
                            .font(.system(size: 20))
                        Text(result == .won ? "Victory!" : "Defeated")
                            .font(Theme.Typography.headlineMedium)
                    }
                    .foregroundColor(result == .won ? Theme.Colors.success : Theme.Colors.error)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill((result == .won ? Theme.Colors.success : Theme.Colors.error).opacity(0.1))
                    )
                }

                // Participants
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    SectionHeader(title: "Players")

                    let sorted = play.participants.sorted { a, b in
                        if a.isWinner != b.isWinner { return a.isWinner }
                        if let ap = a.placement, let bp = b.placement { return ap < bp }
                        return false
                    }

                    ForEach(sorted) { participant in
                        HStack(spacing: Theme.Spacing.md) {
                            // Placement badge
                            if let placement = participant.placement {
                                Text("#\(placement)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(placement == 1 ? Theme.Colors.accentWarm : Theme.Colors.textTertiary)
                                    .frame(width: 28)
                            } else {
                                Spacer().frame(width: 28)
                            }

                            AvatarView(url: nil, size: 32)

                            Text(participant.displayName)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)

                            if participant.isWinner {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.accentWarm)
                            }

                            Spacer()

                            if let score = participant.score {
                                Text("\(score) pts")
                                    .font(Theme.Typography.calloutMedium)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }

                            if let team = participant.team {
                                Text(team)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.Colors.primary.opacity(0.1)))
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                }
                .cardStyle()

                // Notes
                if let notes = play.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        SectionHeader(title: "Notes")
                        Text(notes)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .cardStyle()
                }

                // Logged by
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Logged by")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text(play.logger?.displayName ?? "Unknown")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                // Delete (logger only)
                if isLogger {
                    Button("Delete Play", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.error)
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Play Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this play?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await onDelete?()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .toast($toast)
    }

    private var playDateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: play.playedAt)
    }
}
