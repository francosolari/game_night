import SwiftUI

/// Partiful-inspired RSVP sheet with status selection, time poll voting, and submission.
struct RSVPSheet: View {
    let event: GameEvent
    let currentStatus: InviteStatus?
    let isSending: Bool
    @Binding var pollVotes: [UUID: TimeOptionVoteType]
    let onSubmit: (InviteStatus, [TimeOptionVote]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatus: InviteStatus?

    private var isPollMode: Bool {
        event.scheduleMode == .poll && event.timeOptions.count > 1
    }

    private var canSubmit: Bool {
        if isPollMode {
            return PollRSVP.submissionStatus(from: pollVotes) != nil && !isSending
        }
        return selectedStatus != nil && !isSending
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    if isPollMode {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Find a Time")
                                .font(Theme.Typography.displaySmall)
                                .foregroundColor(Theme.Colors.textPrimary)

                            Text("Vote on the times that work for you:")
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.textSecondary)

                            PollVotingView(
                                timeOptions: event.timeOptions,
                                votes: $pollVotes
                            )

                            if PollRSVP.submissionStatus(from: pollVotes) != nil {
                                Text("Votes saved as pending until the host confirms a time.")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            } else {
                                Text("Vote at least once to submit your RSVP.")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }
                    } else {
                        // Standard RSVP Selection (fixed date mode)
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Are you going?")
                                .font(Theme.Typography.displaySmall)
                                .foregroundColor(Theme.Colors.textPrimary)

                            VStack(spacing: Theme.Spacing.sm) {
                                RSVPOptionButton(
                                    title: "Going",
                                    icon: "checkmark.circle.fill",
                                    color: Theme.Colors.success,
                                    isSelected: selectedStatus == .accepted
                                ) {
                                    withAnimation(Theme.Animation.snappy) {
                                        selectedStatus = .accepted
                                    }
                                }

                                RSVPOptionButton(
                                    title: "Maybe",
                                    icon: "questionmark.circle.fill",
                                    color: Theme.Colors.warning,
                                    isSelected: selectedStatus == .maybe
                                ) {
                                    withAnimation(Theme.Animation.snappy) {
                                        selectedStatus = .maybe
                                    }
                                }

                                RSVPOptionButton(
                                    title: "Can't Go",
                                    icon: "xmark.circle.fill",
                                    color: Theme.Colors.error,
                                    isSelected: selectedStatus == .declined
                                ) {
                                    withAnimation(Theme.Animation.snappy) {
                                        selectedStatus = .declined
                                    }
                                }
                            }

                            Text("When the host picks a time, your RSVP will auto-update.")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
                .padding(.bottom, 80)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.Colors.divider)
                        .frame(height: 0.5)

                    Button {
                        let status: InviteStatus
                        let votes: [TimeOptionVote]
                        if isPollMode {
                            guard let submissionStatus = PollRSVP.submissionStatus(from: pollVotes) else { return }
                            status = submissionStatus
                            votes = pollVotes.map { TimeOptionVote(timeOptionId: $0.key, voteType: $0.value) }
                        } else {
                            guard let selectedStatus else { return }
                            status = selectedStatus
                            votes = status == .declined ? [] : pollVotes.map { TimeOptionVote(timeOptionId: $0.key, voteType: $0.value) }
                        }
                        Task {
                            await onSubmit(status, votes)
                            dismiss()
                        }
                    } label: {
                        Group {
                            if isSending {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(currentStatus == nil || currentStatus == .pending ? "Confirm RSVP" : "Update RSVP")
                                    .font(Theme.Typography.bodyMedium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                .fill(canSubmit ? Theme.Colors.primary : Theme.Colors.textTertiary)
                        )
                    }
                    .disabled(!canSubmit)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)
                }
                .background(Theme.Colors.cardBackground)
            }
        }
        .onAppear {
            if let currentStatus, currentStatus != .pending {
                selectedStatus = currentStatus
            }
        }
    }
}

// MARK: - RSVP Option Button

private struct RSVPOptionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .white : color)

                Text(title)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(isSelected ? color : Theme.Colors.fieldBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                            .stroke(isSelected ? color : Theme.Colors.divider, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
