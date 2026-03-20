import SwiftUI

struct PollGuestListView: View {
    let timeOptions: [TimeOption]
    let voters: [UUID: [TimeOptionVoter]]
    let isHost: Bool
    let onConfirmTime: ((UUID) async -> Void)?

    @State private var selectedOption: TimeOption?

    private func yesCount(for option: TimeOption) -> Int {
        voters[option.id]?.filter { $0.voteType == "yes" }.count ?? 0
    }

    private func maybeCount(for option: TimeOption) -> Int {
        voters[option.id]?.filter { $0.voteType == "maybe" }.count ?? 0
    }

    private func isMostPopular(_ option: TimeOption) -> Bool {
        let maxYes = timeOptions.map { yesCount(for: $0) }.max() ?? 0
        return maxYes > 0 && yesCount(for: option) == maxYes
    }

    private func voterTuples(for option: TimeOption) -> [(id: UUID, name: String, avatarUrl: String?)] {
        (voters[option.id] ?? [])
            .filter { $0.voteType == "yes" || $0.voteType == "maybe" }
            .map { (id: $0.userId, name: $0.displayName, avatarUrl: $0.avatarUrl) }
    }

    private func detailVoters(for option: TimeOption) -> [(id: UUID, name: String, avatarUrl: String?, voteType: String)] {
        let all = voters[option.id] ?? []
        let filtered = isHost ? all : all.filter { $0.voteType != "no" }
        return filtered.map { (id: $0.userId, name: $0.displayName, avatarUrl: $0.avatarUrl, voteType: $0.voteType) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                SectionHeader(title: "Finding a Time...")
                Text("The host will pick one when they're ready!")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

            // Horizontal scroll of time option cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(timeOptions) { option in
                        timeOptionCard(option)
                    }
                }
            }
        }
        .cardStyle()
        .sheet(item: $selectedOption) { option in
            PollResultsDetailView(
                title: option.displayDate,
                subtitle: option.displayTime,
                voters: detailVoters(for: option),
                isMostPopular: isMostPopular(option),
                isHost: isHost,
                onPickThis: isHost ? {
                    await onConfirmTime?(option.id)
                } : nil
            )
        }
    }

    @ViewBuilder
    private func timeOptionCard(_ option: TimeOption) -> some View {
        let yes = yesCount(for: option)
        let maybe = maybeCount(for: option)
        let popular = isMostPopular(option)

        Button {
            selectedOption = option
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // Date — with subtle star if popular
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.displayDate)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(option.displayTime)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.dateAccent)
                    }
                    Spacer()
                    if popular {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.highlight)
                    }
                }

                // Vote counts
                HStack(spacing: Theme.Spacing.sm) {
                    if yes > 0 {
                        HStack(spacing: 2) {
                            StatusDot(color: Theme.Colors.success, size: 5)
                            Text("\(yes) Yes")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.success)
                        }
                    }
                    if maybe > 0 {
                        HStack(spacing: 2) {
                            StatusDot(color: Theme.Colors.warning, size: 5)
                            Text("\(maybe) Maybe")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.warning)
                        }
                    }
                }

                // Voter avatars
                VoterAvatarStack(
                    voters: voterTuples(for: option),
                    maxVisible: 3,
                    avatarSize: 20
                )
            }
            .frame(width: 140, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(popular ? Theme.Colors.primary.opacity(0.05) : Theme.Colors.backgroundElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                            .stroke(
                                popular ? Theme.Colors.primary.opacity(0.25) : Theme.Colors.divider,
                                lineWidth: popular ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
