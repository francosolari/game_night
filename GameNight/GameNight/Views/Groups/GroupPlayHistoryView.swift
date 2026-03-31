import SwiftUI

// MARK: - Sort Order

enum PlaySortOrder: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case byGame = "By Game"

    var icon: String {
        switch self {
        case .newest: return "arrow.down.circle"
        case .oldest: return "arrow.up.circle"
        case .byGame: return "gamecontroller"
        }
    }
}

// MARK: - GroupPlayHistoryView

struct GroupPlayHistoryView: View {
    @ObservedObject var viewModel: GroupDetailViewModel
    @State private var selectedPlay: Play?
    @State private var showFilterSheet = false
    @State private var searchText: String = ""
    @State private var sortOrder: PlaySortOrder = .newest
    @State private var gameFilterId: UUID? = nil

    // MARK: Computed

    private var displayedPlays: [Play] {
        var result = viewModel.filteredPlays
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            result = result.filter { ($0.game?.name ?? "").localizedCaseInsensitiveContains(trimmed) }
        }
        if let gid = gameFilterId {
            result = result.filter { $0.gameId == gid }
        }
        switch sortOrder {
        case .newest: return result.sorted { $0.playedAt > $1.playedAt }
        case .oldest: return result.sorted { $0.playedAt < $1.playedAt }
        case .byGame:
            return result.sorted {
                ($0.game?.name ?? "").localizedCompare($1.game?.name ?? "") == .orderedAscending
            }
        }
    }

    private var groupedPlays: [(key: String, plays: [Play])] {
        if sortOrder == .byGame {
            let dict = Dictionary(grouping: displayedPlays) { $0.game?.name ?? "Unknown" }
            return dict.map { (key: $0.key, plays: $0.value) }
                       .sorted { $0.key.localizedCompare($1.key) == .orderedAscending }
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let dict = Dictionary(grouping: displayedPlays) { formatter.string(from: $0.playedAt) }
            return dict.map { (key: $0.key, plays: $0.value) }
                       .sorted {
                           let df = DateFormatter()
                           df.dateFormat = "MMMM yyyy"
                           let d0 = df.date(from: $0.key) ?? .distantPast
                           let d1 = df.date(from: $1.key) ?? .distantPast
                           return sortOrder == .newest ? d0 > d1 : d0 < d1
                       }
        }
    }

    private var summaryText: String {
        let plays = viewModel.filteredPlays
        let total = plays.count
        let unique = Set(plays.map(\.gameId)).count
        return "\(total) play\(total == 1 ? "" : "s") · \(unique) game\(unique == 1 ? "" : "s")"
    }

    private var activeCustomMembers: [GroupMember] {
        guard viewModel.playFilter == .custom else { return [] }
        return viewModel.group.members.filter {
            guard let uid = $0.userId else { return false }
            return viewModel.customFilterMembers.contains(uid)
        }
    }

    private var activeGameFilterName: String? {
        guard let gid = gameFilterId else { return nil }
        return viewModel.plays.first(where: { $0.gameId == gid })?.game?.name
    }

    private var availableGames: [(id: UUID, name: String)] {
        var seen = Set<UUID>()
        return viewModel.plays.compactMap { play -> (UUID, String)? in
            guard !seen.contains(play.gameId) else { return nil }
            seen.insert(play.gameId)
            return (play.gameId, play.game?.name ?? "Unknown")
        }.sorted { $0.1.localizedCompare($1.1) == .orderedAscending }
    }

    private var hasActiveFilters: Bool {
        !activeCustomMembers.isEmpty || gameFilterId != nil
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SearchBar(text: $searchText, placeholder: "Search games…")

            // Filter + Sort row
            HStack(spacing: Theme.Spacing.sm) {
                PlayFilterButton(
                    filter: $viewModel.playFilter,
                    customMembers: $viewModel.customFilterMembers,
                    gameFilterId: $gameFilterId,
                    groupMembers: viewModel.group.members,
                    plays: viewModel.plays,
                    showSheet: $showFilterSheet
                )
                Spacer()
                PlaySortMenu(sortOrder: $sortOrder)
            }

            // Active filter chips
            if hasActiveFilters {
                ActiveFilterChipsRow(
                    members: activeCustomMembers,
                    gameFilterName: activeGameFilterName,
                    onRemoveMember: { uid in
                        viewModel.customFilterMembers.remove(uid)
                        if viewModel.customFilterMembers.isEmpty {
                            viewModel.playFilter = .all
                        }
                    },
                    onRemoveGame: { gameFilterId = nil }
                )
            }

            // Summary
            if !viewModel.plays.isEmpty {
                Text(summaryText)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
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
            } else if displayedPlays.isEmpty {
                EmptyStateView(
                    icon: "trophy",
                    title: viewModel.plays.isEmpty ? "No Plays Yet" : "No Results",
                    message: viewModel.plays.isEmpty
                        ? "Log your first play to start building this group's history."
                        : "Try adjusting your search or filters."
                )
                .frame(minHeight: 200)
            } else {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedPlays, id: \.key) { section in
                        Section {
                            ForEach(section.plays) { play in
                                PlayCard(play: play) {
                                    selectedPlay = play
                                }
                                .padding(.bottom, Theme.Spacing.sm)
                            }
                        } header: {
                            PlaySectionHeader(title: section.key, count: section.plays.count)
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

// MARK: - PlaySortMenu

private struct PlaySortMenu: View {
    @Binding var sortOrder: PlaySortOrder

    var body: some View {
        Menu {
            ForEach(PlaySortOrder.allCases, id: \.self) { mode in
                Button {
                    sortOrder = mode
                } label: {
                    HStack {
                        Text(mode.rawValue)
                        if sortOrder == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: sortOrder.icon)
                    .font(.system(size: 13))
                Text(sortOrder.rawValue)
                    .font(Theme.Typography.calloutMedium)
            }
            .foregroundColor(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Capsule().fill(Theme.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ActiveFilterChipsRow

private struct ActiveFilterChipsRow: View {
    let members: [GroupMember]
    let gameFilterName: String?
    let onRemoveMember: (UUID) -> Void
    let onRemoveGame: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(members) { member in
                    if let uid = member.userId {
                        FilterChip(
                            label: member.displayName ?? "Player",
                            color: Theme.Colors.primary,
                            onRemove: { onRemoveMember(uid) }
                        )
                    }
                }
                if let name = gameFilterName {
                    FilterChip(
                        label: name,
                        icon: "gamecontroller.fill",
                        color: Theme.Colors.accentWarm,
                        onRemove: onRemoveGame
                    )
                }
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(Theme.Typography.caption)
                    .lineLimit(1)
                Text("×")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(
                Capsule().fill(color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PlaySectionHeader

private struct PlaySectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textSecondary)
            Spacer()
            Text("\(count)")
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, 2)
        .background(Theme.Colors.background)
    }
}

// MARK: - Play Filter Button + Sheet

struct PlayFilterButton: View {
    @Binding var filter: PlayFilterMode
    @Binding var customMembers: Set<UUID>
    @Binding var gameFilterId: UUID?
    let groupMembers: [GroupMember]
    let plays: [Play]
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
                gameFilterId: $gameFilterId,
                groupMembers: groupMembers,
                plays: plays
            )
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Play Filter Sheet

private struct PlayFilterSheet: View {
    @Binding var filter: PlayFilterMode
    @Binding var customMembers: Set<UUID>
    @Binding var gameFilterId: UUID?
    let groupMembers: [GroupMember]
    let plays: [Play]
    @Environment(\.dismiss) private var dismiss

    private var availableGames: [(id: UUID, name: String)] {
        var seen = Set<UUID>()
        return plays.compactMap { play -> (UUID, String)? in
            guard !seen.contains(play.gameId) else { return nil }
            seen.insert(play.gameId)
            return (play.gameId, play.game?.name ?? "Unknown")
        }.sorted { $0.1.localizedCompare($1.1) == .orderedAscending }
    }

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
                    let membersWithUserId = groupMembers.filter { $0.userId != nil }
                    if !membersWithUserId.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("By Players")
                                .font(Theme.Typography.label)
                                .foregroundColor(Theme.Colors.textSecondary)

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

                    // By game
                    if !availableGames.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            HStack {
                                Text("By Game")
                                    .font(Theme.Typography.label)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                if gameFilterId != nil {
                                    Spacer()
                                    Button("Clear") { gameFilterId = nil }
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.primary)
                                }
                            }

                            ForEach(availableGames, id: \.id) { game in
                                let isSelected = gameFilterId == game.id
                                Button {
                                    gameFilterId = isSelected ? nil : game.id
                                } label: {
                                    HStack(spacing: Theme.Spacing.md) {
                                        Image(systemName: "gamecontroller")
                                            .font(.system(size: 13))
                                            .foregroundColor(Theme.Colors.accentWarm)
                                            .frame(width: 24)
                                        Text(game.name)
                                            .font(Theme.Typography.bodyMedium)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Spacer()
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(isSelected ? Theme.Colors.accentWarm : Theme.Colors.textTertiary)
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
