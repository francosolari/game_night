import SwiftUI

struct GroupPlayHistoryView: View {
    @ObservedObject var viewModel: GroupDetailViewModel
    @State private var selectedPlay: Play?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Filter bar
            Picker("Filter", selection: $viewModel.playFilter) {
                ForEach(PlayFilterMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Custom filter — member checkboxes
            if viewModel.playFilter == .custom {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.group.members) { member in
                            if let userId = member.userId {
                                let isSelected = viewModel.customFilterMembers.contains(userId)
                                Button {
                                    if isSelected {
                                        viewModel.customFilterMembers.remove(userId)
                                    } else {
                                        viewModel.customFilterMembers.insert(userId)
                                    }
                                } label: {
                                    Text(member.displayName ?? "Player")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(isSelected ? Theme.Colors.primaryActionText : Theme.Colors.textSecondary)
                                        .padding(.horizontal, Theme.Spacing.md)
                                        .padding(.vertical, Theme.Spacing.sm)
                                        .background(
                                            Capsule().fill(isSelected ? Theme.Colors.primary : Theme.Colors.cardBackground)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Play list
            if viewModel.isLoadingPlays {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.cardBackground)
                            .frame(height: 64)
                            .shimmer()
                    }
                }
            } else if viewModel.filteredPlays.isEmpty {
                EmptyStateView(
                    icon: "trophy",
                    title: "No Plays Yet",
                    message: "Log your first play to start building this group's history."
                )
                .frame(minHeight: 200)
            } else {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.filteredPlays) { play in
                        PlayCard(play: play) {
                            selectedPlay = play
                        }
                    }
                }
            }
        }
        .navigationDestination(item: $selectedPlay) { play in
            PlayDetailView(
                play: play,
                currentUserId: SupabaseService.shared.client.auth.currentSession?.user.id
            ) {
                await viewModel.deletePlay(id: play.id)
            }
        }
    }
}
