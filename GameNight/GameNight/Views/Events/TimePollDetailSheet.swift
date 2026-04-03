import SwiftUI

struct TimePollDetailSheet: View {
    let timeOptions: [TimeOption]
    let voters: [UUID: [TimeOptionVoter]]
    let isHost: Bool
    let pollVotes: [UUID: TimeOptionVoteType]
    let canVoteDirectly: Bool
    let initialOptionId: UUID
    let onVote: (UUID, TimeOptionVoteType) async -> Void
    let onRequireRSVP: () -> Void
    let onConfirmTime: ((UUID) async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var isConfirming = false

    private var currentOption: TimeOption {
        timeOptions[currentIndex]
    }

    private func optionVoters(_ option: TimeOption, isHost: Bool) -> [(id: UUID, name: String, avatarUrl: String?, voteType: String)] {
        let all = voters[option.id] ?? []
        let filtered = isHost ? all : all.filter { $0.voteType != "no" }
        return filtered.map { (id: $0.userId, name: $0.displayName, avatarUrl: $0.avatarUrl, voteType: $0.voteType) }
    }

    private func yesVoters(_ option: TimeOption) -> [(id: UUID, name: String, avatarUrl: String?)] {
        (voters[option.id] ?? []).filter { $0.voteType == "yes" }.map { (id: $0.userId, name: $0.displayName, avatarUrl: $0.avatarUrl) }
    }

    private func maybeVoters(_ option: TimeOption) -> [(id: UUID, name: String, avatarUrl: String?)] {
        (voters[option.id] ?? []).filter { $0.voteType == "maybe" }.map { (id: $0.userId, name: $0.displayName, avatarUrl: $0.avatarUrl) }
    }

    private func noVoters(_ option: TimeOption) -> [(id: UUID, name: String, avatarUrl: String?)] {
        (voters[option.id] ?? []).filter { $0.voteType == "no" }.map { (id: $0.userId, name: $0.displayName, avatarUrl: $0.avatarUrl) }
    }

    private func isMostPopular(_ option: TimeOption) -> Bool {
        let counts = timeOptions.map { (voters[$0.id] ?? []).filter { $0.voteType == "yes" }.count }
        let maxYes = counts.max() ?? 0
        let thisYes = (voters[option.id] ?? []).filter { $0.voteType == "yes" }.count
        return maxYes > 0 && thisYes == maxYes
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main scrollable content for current option
                ScrollView {
                    optionContent(currentOption)
                        .padding(Theme.Spacing.xl)
                }

                Divider().background(Theme.Colors.divider)

                // Bottom navigation pills
                if timeOptions.count > 1 {
                    optionNavigationBar
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.Colors.cardBackground)
                }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Responses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .onAppear {
            if let idx = timeOptions.firstIndex(where: { $0.id == initialOptionId }) {
                currentIndex = idx
            }
        }
    }

    // MARK: - Option Content

    @ViewBuilder
    private func optionContent(_ option: TimeOption) -> some View {
        let myVote = pollVotes[option.id]

        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            // Header
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(option.displayDate)
                        .font(Theme.Typography.titleLarge.weight(.bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    if isMostPopular(option) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.highlight)
                    }
                }
                Text(option.displayTime)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.dateAccent)
            }

            // Inline vote buttons
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Your vote")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)

                HStack(spacing: Theme.Spacing.sm) {
                    TimeVotePill(
                        label: "Yes",
                        icon: "checkmark",
                        color: Theme.Colors.success,
                        isSelected: myVote == .yes
                    ) {
                        if canVoteDirectly {
                            Task { await onVote(option.id, .yes) }
                        } else {
                            dismiss()
                            onRequireRSVP()
                        }
                    }
                    TimeVotePill(
                        label: "Maybe",
                        icon: "questionmark",
                        color: Theme.Colors.warning,
                        isSelected: myVote == .maybe
                    ) {
                        if canVoteDirectly {
                            Task { await onVote(option.id, .maybe) }
                        } else {
                            dismiss()
                            onRequireRSVP()
                        }
                    }
                    TimeVotePill(
                        label: "No",
                        icon: "xmark",
                        color: Theme.Colors.error,
                        isSelected: myVote == .no
                    ) {
                        if canVoteDirectly {
                            Task { await onVote(option.id, .no) }
                        } else {
                            dismiss()
                            onRequireRSVP()
                        }
                    }
                }
            }

            // Voter sections
            let yes = yesVoters(option)
            let maybe = maybeVoters(option)
            let no = noVoters(option)

            if !yes.isEmpty {
                voterSection(title: "Going", icon: "hand.thumbsup.fill", color: Theme.Colors.success, voters: yes)
            }
            if !maybe.isEmpty {
                voterSection(title: "Maybe", icon: "face.smiling", color: Theme.Colors.warning, voters: maybe)
            }
            if isHost && !no.isEmpty {
                voterSection(title: "Can't", icon: "hand.thumbsdown.fill", color: Theme.Colors.error, voters: no)
            }

            if yes.isEmpty && maybe.isEmpty && (isHost ? no.isEmpty : true) {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text("No votes yet")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)
            }

            // Host pick button
            if isHost, let onConfirmTime {
                Button {
                    isConfirming = true
                    Task {
                        await onConfirmTime(option.id)
                        isConfirming = false
                        dismiss()
                    }
                } label: {
                    HStack {
                        if isConfirming {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                            Text("PICK THIS")
                                .font(.system(size: 15, weight: .heavy))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.primary)
                    )
                }
                .disabled(isConfirming)
            }
        }
    }

    // MARK: - Voter Section

    @ViewBuilder
    private func voterSection(title: String, icon: String, color: Color, voters: [(id: UUID, name: String, avatarUrl: String?)]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text("\(title) (\(voters.count))")
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            ForEach(voters, id: \.id) { voter in
                HStack(spacing: Theme.Spacing.sm) {
                    AvatarView(url: voter.avatarUrl, size: 32)
                    Text(voter.name)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Bottom Navigation

    private var optionNavigationBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(timeOptions.enumerated()), id: \.element.id) { index, option in
                        let isCurrent = index == currentIndex
                        let yesCount = (voters[option.id] ?? []).filter { $0.voteType == "yes" }.count

                        Button {
                            withAnimation(Theme.Animation.snappy) {
                                currentIndex = index
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(option.displayDate)
                                    .font(.system(size: 11, weight: isCurrent ? .bold : .medium))
                                if yesCount > 0 {
                                    Text("·")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("\(yesCount)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.Colors.success)
                                }
                            }
                            .foregroundColor(isCurrent ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isCurrent
                                        ? Theme.Colors.primary.opacity(0.12)
                                        : Theme.Colors.fieldBackground
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .id(option.id)
                    }
                }
            }
            .onChange(of: currentIndex) { _, newIndex in
                withAnimation {
                    proxy.scrollTo(timeOptions[newIndex].id, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Vote Pill Button

private struct TimeVotePill: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}
