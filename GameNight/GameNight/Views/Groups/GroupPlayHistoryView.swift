import SwiftUI

struct GroupPlayHistoryView: View {
    @ObservedObject var viewModel: GroupDetailViewModel
    @State private var selectedPlay: Play?
    @State private var showFilterSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Filter button
            PlayFilterButton(
                filter: $viewModel.playFilter,
                customMembers: $viewModel.customFilterMembers,
                groupMembers: viewModel.group.members,
                showSheet: $showFilterSheet
            )

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

// MARK: - Play Filter Button + Sheet

struct PlayFilterButton: View {
    @Binding var filter: PlayFilterMode
    @Binding var customMembers: Set<UUID>
    let groupMembers: [GroupMember]
    @Binding var showSheet: Bool

    private var filterLabel: String {
        switch filter {
        case .all: return "All Plays"
        case .groupNights: return "Group Nights"
        case .custom:
            let count = customMembers.count
            return count == 0 ? "Custom" : "\(count) Player\(count == 1 ? "" : "s")"
        }
    }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14))
                Text(filterLabel)
                    .font(Theme.Typography.calloutMedium)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Capsule().fill(Theme.Colors.primary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            PlayFilterSheet(
                filter: $filter,
                customMembers: $customMembers,
                groupMembers: groupMembers
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Play Filter Sheet

private struct PlayFilterSheet: View {
    @Binding var filter: PlayFilterMode
    @Binding var customMembers: Set<UUID>
    let groupMembers: [GroupMember]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Preset filters
                    VStack(spacing: 0) {
                        filterRow("All Plays", icon: "list.bullet", isSelected: filter == .all) {
                            filter = .all
                        }
                        Divider().padding(.leading, 44)
                        filterRow("Group Nights", icon: "person.3.fill", isSelected: filter == .groupNights) {
                            filter = .groupNights
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.cardBackground)
                    )

                    // By players
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("By Players")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.textSecondary)

                        let membersWithUserId = groupMembers.filter { $0.userId != nil }
                        ForEach(membersWithUserId) { member in
                            if let userId = member.userId {
                                let isSelected = customMembers.contains(userId)
                                Button {
                                    if isSelected {
                                        customMembers.remove(userId)
                                        if customMembers.isEmpty { filter = .all }
                                    } else {
                                        customMembers.insert(userId)
                                        filter = .custom
                                    }
                                } label: {
                                    HStack(spacing: Theme.Spacing.md) {
                                        AvatarView(url: nil, size: 32)

                                        Text(member.displayName ?? "Player")
                                            .font(Theme.Typography.bodyMedium)
                                            .foregroundColor(Theme.Colors.textPrimary)

                                        Spacer()

                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(isSelected ? Theme.Colors.primary : Theme.Colors.textTertiary)
                                    }
                                    .padding(.vertical, Theme.Spacing.xs)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Filter Plays")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }

    private func filterRow(_ title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.primary)
                    .frame(width: 24)

                Text(title)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .buttonStyle(.plain)
    }
}
