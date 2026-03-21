import SwiftUI

struct PlayDetailView: View {
    let play: Play
    let currentUserId: UUID?
    var onDelete: (() async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var toast: ToastItem?
    @State private var linkedEvent: GameEvent?
    @State private var linkedEventPlays: [Play] = []
    @State private var linkedEventInvites: [Invite] = []

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

                // Linked event info
                if let event = linkedEvent {
                    linkedEventSection(event: event)
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
        .task {
            if let eventId = play.eventId {
                linkedEvent = try? await SupabaseService.shared.fetchEvent(id: eventId)
                linkedEventPlays = (try? await SupabaseService.shared.fetchPlaysForEvent(eventId: eventId))?.filter { $0.id != play.id } ?? []
                linkedEventInvites = (try? await SupabaseService.shared.fetchInvites(eventId: eventId)) ?? []
            }
        }
    }

    // MARK: - Linked Event

    private func linkedEventSection(event: GameEvent) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Game Night")

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.primary)
                    Text(event.title)
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                }

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(eventDateDisplay(event.effectiveStartDate))
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Colors.textSecondary)

                // Attendees
                let accepted = linkedEventInvites.filter { $0.status == .accepted }
                if !accepted.isEmpty {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                        Text(accepted.compactMap(\.displayName).joined(separator: ", "))
                            .font(Theme.Typography.caption)
                            .lineLimit(2)
                    }
                    .foregroundColor(Theme.Colors.textTertiary)
                }
            }

            // Also played
            if !linkedEventPlays.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Also played")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textSecondary)

                    ForEach(linkedEventPlays) { otherPlay in
                        PlayCard(play: otherPlay)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func eventDateDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var playDateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: play.playedAt)
    }
}
