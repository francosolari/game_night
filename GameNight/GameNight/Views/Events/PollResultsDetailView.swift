import SwiftUI

struct PollResultsDetailView: View {
    let title: String
    let subtitle: String?
    let voters: [(id: UUID, name: String, avatarUrl: String?, voteType: String)]
    let isMostPopular: Bool
    let isHost: Bool
    let onPickThis: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirming = false

    private var yesVoters: [(id: UUID, name: String, avatarUrl: String?, voteType: String)] {
        voters.filter { $0.voteType == "yes" }
    }

    private var maybeVoters: [(id: UUID, name: String, avatarUrl: String?, voteType: String)] {
        voters.filter { $0.voteType == "maybe" }
    }

    private var noVoters: [(id: UUID, name: String, avatarUrl: String?, voteType: String)] {
        voters.filter { $0.voteType == "no" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text(title)
                                .font(Theme.Typography.titleLarge.weight(.bold))
                                .foregroundColor(Theme.Colors.textPrimary)

                            if isMostPopular {
                                Text("Most Popular")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(Theme.Colors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(Theme.Colors.primary.opacity(0.12))
                                    )
                            }
                        }

                        if let subtitle {
                            Text(subtitle)
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    // Voter sections
                    if !yesVoters.isEmpty {
                        voterSection(title: "Going", icon: "hand.thumbsup.fill", color: Theme.Colors.success, voters: yesVoters)
                    }

                    if !maybeVoters.isEmpty {
                        voterSection(title: "Maybe", icon: "face.smiling", color: Theme.Colors.warning, voters: maybeVoters)
                    }

                    if !noVoters.isEmpty {
                        voterSection(title: "Can't", icon: "hand.thumbsdown.fill", color: Theme.Colors.error, voters: noVoters)
                    }

                    // Host pick button
                    if isHost, let onPickThis {
                        Button {
                            isConfirming = true
                            Task {
                                await onPickThis()
                                isConfirming = false
                                dismiss()
                            }
                        } label: {
                            HStack {
                                if isConfirming {
                                    ProgressView()
                                        .tint(.white)
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
                        .padding(.top, Theme.Spacing.md)
                    }
                }
                .padding(Theme.Spacing.xl)
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
    }

    @ViewBuilder
    private func voterSection(title: String, icon: String, color: Color, voters: [(id: UUID, name: String, avatarUrl: String?, voteType: String)]) -> some View {
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
}
