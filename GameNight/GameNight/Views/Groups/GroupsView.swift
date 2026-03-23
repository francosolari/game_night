import SwiftUI

struct GroupsView: View {
    @StateObject private var viewModel = GroupsViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showCreateGroup = false
    @State private var toast: ToastItem?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Header
                    HStack {
                        Text("Groups")
                            .font(Theme.Typography.displayLarge)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Spacer()

                        Button {
                            showCreateGroup = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.Gradients.primary)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.lg)

                    if viewModel.isLoading {
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                    .fill(Theme.Colors.cardBackground)
                                    .frame(height: 100)
                                    .shimmer()
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    } else if viewModel.groups.isEmpty {
                        EmptyStateView(
                            icon: "person.3.fill",
                            title: "No Groups Yet",
                            message: "Create groups of friends to quickly invite them to game nights.",
                            actionLabel: "Create a Group"
                        ) {
                            showCreateGroup = true
                        }
                        .frame(minHeight: 400)
                    } else {
                        // My Groups — horizontal scroll bubbles
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            SectionHeader(title: "My Groups")
                                .padding(.horizontal, Theme.Spacing.xl)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.md) {
                                    ForEach(viewModel.groups) { group in
                                        NavigationLink {
                                            GroupDetailView(group: group)
                                        } label: {
                                            GroupBubble(group: group)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    // New Group button
                                    Button {
                                        showCreateGroup = true
                                    } label: {
                                        VStack(spacing: Theme.Spacing.sm) {
                                            ZStack {
                                                Circle()
                                                    .strokeBorder(Theme.Colors.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                                    .frame(width: 56, height: 56)

                                                Image(systemName: "plus")
                                                    .font(.system(size: 20, weight: .medium))
                                                    .foregroundColor(Theme.Colors.primary)
                                            }

                                            Text("New")
                                                .font(Theme.Typography.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                        }
                                        .frame(width: 72)
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.xl)
                            }
                        }

                        // Upcoming Events
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            SectionHeader(title: "Upcoming Events")
                                .padding(.horizontal, Theme.Spacing.xl)

                            if viewModel.upcomingEvents.isEmpty {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 20))
                                        .foregroundColor(Theme.Colors.textTertiary)
                                    Text("No upcoming events across your groups")
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.xxl)
                                .padding(.horizontal, Theme.Spacing.xl)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Spacing.md) {
                                        ForEach(viewModel.upcomingEvents) { event in
                                            VerticalEventCard(
                                                event: event,
                                                confirmedCount: viewModel.confirmedCount(for: event.id)
                                            ) {
                                                navigationPath.append(event)
                                            }
                                            .frame(width: 200)
                                        }
                                    }
                                    .padding(.horizontal, Theme.Spacing.xl)
                                }
                            }
                        }

                        // Recent Plays
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            SectionHeader(title: "Recent Plays")
                                .padding(.horizontal, Theme.Spacing.xl)

                            if viewModel.recentPlays.isEmpty {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: "trophy")
                                        .font(.system(size: 20))
                                        .foregroundColor(Theme.Colors.textTertiary)
                                    Text("No plays logged yet")
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.xxl)
                                .padding(.horizontal, Theme.Spacing.xl)
                            } else {
                                LazyVStack(spacing: Theme.Spacing.sm) {
                                    ForEach(viewModel.recentPlays) { play in
                                        RecentPlayRow(play: play, groups: viewModel.groups) {
                                            navigationPath.append(play)
                                        }
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.xl)
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationDestination(for: GameEvent.self) { event in
                EventDetailView(eventId: event.id)
            }
            .navigationDestination(for: Game.self) { game in
                GameDetailView(game: game)
            }
            .navigationDestination(for: Play.self) { play in
                PlayDetailView(
                    play: play,
                    currentUserId: SupabaseService.shared.client.auth.currentSession?.user.id
                )
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupSheet(viewModel: viewModel, onResult: { resultToast in
                    toast = resultToast
                })
            }
            .toast($toast)
        }
        .task {
            await viewModel.loadGroups()
            await viewModel.loadDashboardData()
        }
    }
}

// MARK: - Group Bubble
struct GroupBubble: View {
    let group: GameGroup

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Theme.Gradients.primary)
                    .frame(width: 56, height: 56)

                Text(group.emoji ?? "🎲")
                    .font(.system(size: 26))
            }

            Text(group.name)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)

            Text("\(group.memberCount)")
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(width: 72)
    }
}

// MARK: - Recent Play Row
struct RecentPlayRow: View {
    let play: Play
    let groups: [GameGroup]
    var onTap: (() -> Void)? = nil

    private var groupForPlay: GameGroup? {
        guard let groupId = play.groupId else { return nil }
        return groups.first { $0.id == groupId }
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                // Game cover art
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.primary.opacity(0.1))
                        .frame(width: 44, height: 44)

                    if let url = play.game?.imageUrl ?? play.game?.thumbnailUrl, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.Colors.primary)
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                    } else {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.Colors.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(play.game?.name ?? "Unknown Game")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: Theme.Spacing.sm) {
                        // Group badge
                        if let group = groupForPlay {
                            HStack(spacing: 2) {
                                Text(group.emoji ?? "🎲")
                                    .font(.system(size: 10))
                                Text(group.name)
                                    .font(Theme.Typography.caption2)
                            }
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.Colors.primary.opacity(0.1)))
                        }

                        Text(play.playedAt.relativeDisplay)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }

                Spacer()

                // Winner
                if play.isCooperative {
                    if let result = play.cooperativeResult {
                        HStack(spacing: 4) {
                            Image(systemName: result == .won ? "trophy.fill" : "xmark.circle")
                                .font(.system(size: 12))
                            Text(result == .won ? "Won" : "Lost")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundColor(result == .won ? Theme.Colors.success : Theme.Colors.error)
                    }
                } else {
                    let winners = play.participants.filter(\.isWinner)
                    if !winners.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.accentWarm)
                            Text(winners.map(\.displayName).joined(separator: ", "))
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Theme.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Group Sheet
struct CreateGroupSheet: View {
    @ObservedObject var viewModel: GroupsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var emoji = "🎲"
    @State private var description = ""
    @State private var step = 1
    @State private var createdGroup: GameGroup?
    @State private var isCreating = false
    var onResult: ((ToastItem) -> Void)?

    private let emojiOptions = ["🎲", "🏜️", "🐉", "🧙", "⚔️", "🎯", "🃏", "♟️", "🎮", "🌌", "🏰", "🚀"]

    var body: some View {
        NavigationStack {
            if step == 1 {
                ScrollView {
                    VStack(spacing: Theme.Spacing.xxl) {
                        // Emoji picker
                        VStack(spacing: Theme.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Gradients.primary)
                                    .frame(width: 80, height: 80)
                                Text(emoji)
                                    .font(.system(size: 40))
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    ForEach(emojiOptions, id: \.self) { e in
                                        Button { emoji = e } label: {
                                            Text(e)
                                                .font(.system(size: 28))
                                                .padding(Theme.Spacing.sm)
                                                .background(
                                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                                        .fill(emoji == e ? Theme.Colors.primary.opacity(0.2) : .clear)
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Group Name")
                                .font(Theme.Typography.label)
                                .foregroundColor(Theme.Colors.textSecondary)
                            TextField("e.g. Dune Crew", text: $name)
                                .font(Theme.Typography.body)
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                        .fill(Theme.Colors.fieldBackground)
                                )
                        }

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Description (optional)")
                                .font(Theme.Typography.label)
                                .foregroundColor(Theme.Colors.textSecondary)
                            TextField("What does this group play?", text: $description)
                                .font(Theme.Typography.body)
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                        .fill(Theme.Colors.fieldBackground)
                                )
                        }

                        if let errorMsg = viewModel.error {
                            Text(errorMsg)
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.error)
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                        .fill(Theme.Colors.error.opacity(0.1))
                                )
                        }

                        Button(isCreating ? "Creating..." : "Create Group") {
                            guard !isCreating else { return }
                            isCreating = true
                            viewModel.error = nil
                            Task {
                                if let group = await viewModel.createGroup(
                                    name: name,
                                    emoji: emoji,
                                    description: description.isEmpty ? nil : description
                                ) {
                                    createdGroup = group
                                    withAnimation { step = 2 }
                                } else {
                                    onResult?(ToastItem(style: .error, message: viewModel.error ?? "Couldn't create group"))
                                    dismiss()
                                }
                                isCreating = false
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: !name.isEmpty && !isCreating))
                        .disabled(name.isEmpty || isCreating)
                    }
                    .padding(Theme.Spacing.xl)
                }
                .background(Theme.Colors.background.ignoresSafeArea())
                .navigationTitle("New Group")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            } else if let group = createdGroup {
                ContactListSheet(
                    excludedPhones: Set<String>(),
                    onSelect: { contacts in
                        Task {
                            await viewModel.addMembers(to: group.id, contacts: contacts)
                            onResult?(ToastItem(style: .success, message: "\(group.emoji ?? "🎲") \(group.name) created with \(contacts.count) members"))
                        }
                        dismiss()
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Skip") {
                            onResult?(ToastItem(style: .success, message: "\(group.emoji ?? "🎲") \(group.name) created"))
                            dismiss()
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    let member: GroupMember
    var resolvedName: String? = nil
    let onRemove: () async -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            AvatarView(url: nil, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(resolvedName ?? member.displayName ?? "Unknown")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(member.phoneNumber)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

            Spacer()

            Menu {
                Button("Remove", role: .destructive) {
                    Task { await onRemove() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(Theme.Spacing.sm)
    }
}
