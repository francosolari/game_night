import SwiftUI

struct PlayDetailView: View {
    @StateObject private var viewModel: PlayDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var toast: ToastItem?

    init(play: Play, currentUserId: UUID?, onDelete: (() async -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: PlayDetailViewModel(
            play: play,
            currentUserId: currentUserId,
            onDelete: onDelete
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                // Game header
                gameHeader

                // Tab picker
                SegmentedTabPicker(selection: $viewModel.selectedTab)

                // Tab content
                switch viewModel.selectedTab {
                case .overview:
                    overviewTab
                case .placements:
                    placementsTab
                case .stats:
                    statsTab
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
                    await viewModel.onDelete?()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .toast($toast)
        .task {
            await viewModel.loadLinkedEvent()
        }
    }

    // MARK: - Game Header

    private var gameHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let url = viewModel.play.game?.imageUrl, let imageUrl = URL(string: url) {
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

            Text(viewModel.play.game?.name ?? "Unknown Game")
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

                if let duration = viewModel.play.durationMinutes {
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
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            // Co-op result
            if viewModel.play.isCooperative, let result = viewModel.play.cooperativeResult {
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

                let sorted = viewModel.play.participants.sorted { a, b in
                    if a.isWinner != b.isWinner { return a.isWinner }
                    if let ap = a.placement, let bp = b.placement { return ap < bp }
                    return false
                }

                ForEach(sorted) { participant in
                    participantRow(participant)
                }
            }
            .cardStyle()

            // Notes
            if let notes = viewModel.play.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    SectionHeader(title: "Notes")
                    Text(notes)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .cardStyle()
            }

            // Linked event
            if let event = viewModel.linkedEvent {
                linkedEventSection(event: event)
            }

            // Logged by
            HStack(spacing: Theme.Spacing.sm) {
                Text("Logged by")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                Text(viewModel.play.logger?.displayName ?? "Unknown")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Delete
            if viewModel.isLogger {
                Button("Delete Play", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.error)
            }
        }
    }

    // MARK: - Placements Tab

    private var placementsTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            let hasPlacementData = viewModel.play.participants.contains { $0.placement != nil || $0.score != nil }

            if !hasPlacementData {
                EmptyStateView(
                    icon: "list.number",
                    title: "No Placement Data",
                    message: "No placements or scores were recorded for this play."
                )
                .frame(minHeight: 200)
            } else {
                let ranked = viewModel.play.participants
                    .filter { $0.placement != nil || $0.score != nil }
                    .sorted { a, b in
                        if let ap = a.placement, let bp = b.placement { return ap < bp }
                        if let asc = a.score, let bsc = b.score { return asc > bsc }
                        return a.isWinner && !b.isWinner
                    }

                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, participant in
                    HStack(spacing: Theme.Spacing.md) {
                        // Medal / rank
                        ZStack {
                            Circle()
                                .fill(medalColor(for: participant.placement ?? (index + 1)).opacity(0.15))
                                .frame(width: 36, height: 36)

                            if let placement = participant.placement {
                                Text(medalEmoji(for: placement) ?? "#\(placement)")
                                    .font(placement <= 3 ? .system(size: 18) : Theme.Typography.calloutMedium)
                                    .foregroundColor(medalColor(for: placement))
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(participant.displayName)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)

                            if participant.isWinner {
                                Text("Winner")
                                    .font(Theme.Typography.caption2)
                                    .foregroundColor(Theme.Colors.accentWarm)
                            }
                        }

                        Spacer()

                        if let score = participant.score {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(score)")
                                    .font(Theme.Typography.headlineMedium)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text("pts")
                                    .font(Theme.Typography.caption2)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.cardBackground)
                    )
                }
            }
        }
    }

    // MARK: - Stats Tab

    private var statsTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            let participantUserIds = viewModel.play.participants.compactMap(\.userId)

            if participantUserIds.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    title: "No Stats Available",
                    message: "Stats require participants linked to app accounts."
                )
                .frame(minHeight: 200)
            } else if viewModel.isLoadingStats {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.cardBackground)
                            .frame(height: 64)
                            .shimmer()
                    }
                }
            } else if viewModel.perPlayerStats.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    title: "No History Yet",
                    message: "Play more games to build up stats."
                )
                .frame(minHeight: 200)
            } else {
                SectionHeader(title: "\(viewModel.play.game?.name ?? "Game") Stats")

                ForEach(viewModel.perPlayerStats) { stat in
                    VStack(spacing: Theme.Spacing.sm) {
                        HStack {
                            Text(stat.name)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Text("\(stat.wins)W / \(stat.playsThisGame) plays")
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                        HStack(spacing: Theme.Spacing.lg) {
                            statChip(label: "Win %", value: "\(Int(stat.winPercent * 100))%")

                            if let avgPlacement = stat.averagePlacement {
                                statChip(label: "Avg Place", value: String(format: "#%.1f", avgPlacement))
                            }

                            if let avgScore = stat.averageScore {
                                statChip(label: "Avg Score", value: String(format: "%.0f", avgScore))
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.cardBackground)
                    )
                }
            }
        }
        .task {
            if viewModel.gamePlayHistory.isEmpty {
                await viewModel.loadStats()
            }
        }
    }

    // MARK: - Helpers

    private func participantRow(_ participant: PlayParticipant) -> some View {
        HStack(spacing: Theme.Spacing.md) {
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

    private func statChip(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(label)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
        }
    }

    private func medalColor(for placement: Int) -> Color {
        switch placement {
        case 1: return Theme.Colors.accentWarm
        case 2: return Theme.Colors.textSecondary
        case 3: return Theme.Colors.accentWarm.opacity(0.7)
        default: return Theme.Colors.textTertiary
        }
    }

    private func medalEmoji(for placement: Int) -> String? {
        switch placement {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }

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

                let accepted = viewModel.linkedEventInvites.filter { $0.status == .accepted }
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

            if !viewModel.linkedEventPlays.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Also played")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textSecondary)

                    ForEach(viewModel.linkedEventPlays) { otherPlay in
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
        return formatter.string(from: viewModel.play.playedAt)
    }
}
