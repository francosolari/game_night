import SwiftUI

struct GroupDetailView: View {
    @StateObject private var viewModel: GroupDetailViewModel
    @EnvironmentObject var appState: AppState
    @State private var showAddMembers = false
    @State private var showPlayLogging = false
    @State private var showDeleteConfirmation = false
    @State private var toast: ToastItem?
    @State private var hasLoadedData = false
    @State private var hasRegisteredRefreshHandler = false
    @Environment(\.dismiss) private var dismiss

    init(group: GameGroup) {
        _viewModel = StateObject(wrappedValue: GroupDetailViewModel(group: group))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                // Header
                VStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Theme.Gradients.primary)
                            .frame(width: 80, height: 80)
                        Text(viewModel.group.emoji ?? "🎲")
                            .font(.system(size: 40))
                    }

                    Text(viewModel.group.name)
                        .font(Theme.Typography.displaySmall)
                        .foregroundColor(Theme.Colors.textPrimary)

                    if let desc = viewModel.group.description {
                        Text(desc)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }

                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                        Text("\(viewModel.group.memberCount) members")
                            .font(Theme.Typography.callout)
                    }
                    .foregroundColor(Theme.Colors.textTertiary)
                }

                // Quick actions
                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        appState.scheduleNightGroup = viewModel.group
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 14))
                            Text("Schedule Night")
                                .font(Theme.Typography.calloutMedium)
                        }
                        .foregroundColor(Theme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.primary.opacity(0.1))
                        )
                    }

                    Button {
                        showPlayLogging = true
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "trophy")
                                .font(.system(size: 14))
                            Text("Log a Play")
                                .font(Theme.Typography.calloutMedium)
                        }
                        .foregroundColor(Theme.Colors.accentWarm)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.accentWarm.opacity(0.1))
                        )
                    }
                }

                // Tab picker
                SegmentedTabPicker(selection: $viewModel.selectedTab)

                // Tab content
                switch viewModel.selectedTab {
                case .members:
                    membersTab
                case .history:
                    GroupPlayHistoryView(viewModel: viewModel)
                case .stats:
                    GroupStatsView(viewModel: viewModel)
                case .chat:
                    GroupChatView(viewModel: viewModel)
                }
            }
            .padding(Theme.Spacing.xl)
            .padding(.bottom, 100)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddMembers) {
            ContactListSheet(
                excludedPhones: Set(viewModel.group.members.map(\.phoneNumber)),
                onSelect: { contacts in
                    Task {
                        await viewModel.addMembers(contacts: contacts)
                        await appState.refresh([.home, .groups])
                        toast = ToastItem(style: .success, message: "Added \(contacts.count) member\(contacts.count == 1 ? "" : "s")")
                    }
                }
            )
        }
        .sheet(isPresented: $showPlayLogging) {
            PlayLoggingSheet(group: viewModel.group)
        }
        .onChange(of: showPlayLogging) { _, isPresented in
            if !isPresented {
                Task {
                    await viewModel.loadPlays()
                    await appState.refresh([.home, .groups])
                }
            }
        }
        .toast($toast)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Group", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete \(viewModel.group.name)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Group", role: .destructive) {
                Task {
                    do {
                        try await SupabaseService.shared.deleteGroup(id: viewModel.group.id)
                        await appState.refresh([.home, .groups])
                        dismiss()
                    } catch {
                        toast = ToastItem(style: .error, message: "Failed to delete group")
                    }
                }
            }
        } message: {
            Text("This will permanently delete the group, all members, and chat history. This can't be undone.")
        }
        .task {
            if !hasRegisteredRefreshHandler {
                hasRegisteredRefreshHandler = true
                appState.registerRefreshHandler(for: .groups) { [weak viewModel] in
                    await viewModel?.loadLinkedEvents()
                }
            }
            guard !hasLoadedData else { return }
            hasLoadedData = true
            await viewModel.loadAllData()
            viewModel.subscribeToChatUpdates()
        }
        .onDisappear {
            viewModel.unsubscribeFromChat()
        }
    }

    private var isOwner: Bool {
        viewModel.group.ownerId == appState.currentUser?.id
    }

    private var currentUserCanManage: Bool {
        guard let userId = appState.currentUser?.id else { return false }
        if viewModel.group.ownerId == userId { return true }
        return viewModel.group.members.first(where: { $0.userId == userId })?.role == .coOwner
    }

    // MARK: - Members Tab

    private var membersTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if currentUserCanManage {
                Button {
                    showAddMembers = true
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14))
                        Text("Add Members")
                            .font(Theme.Typography.calloutMedium)
                    }
                    .foregroundColor(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.primary.opacity(0.1))
                    )
                }
            }

            // Confirmed members
            let confirmedMembers = viewModel.group.members.filter(\.isAccepted)
            if !confirmedMembers.isEmpty {
                ForEach(confirmedMembers) { member in
                    memberRow(for: member)
                }
            }

            // Pending invites
            let pendingMembers = viewModel.group.members.filter(\.isPending)
            if !pendingMembers.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Invited — Awaiting Response")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .padding(.top, Theme.Spacing.xs)

                    ForEach(pendingMembers) { member in
                        memberRow(for: member)
                            .opacity(0.65)
                    }
                }
            }

            // Linked events section
            if !viewModel.upcomingLinkedEvents.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    SectionHeader(title: "Upcoming Events")
                    ForEach(viewModel.upcomingLinkedEvents) { event in
                        NavigationLink(value: event) {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Colors.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Text(event.effectiveStartDate, style: .date)
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.cardBackground)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func memberRow(for member: GroupMember) -> some View {
        let row = MemberRow(
            member: member,
            resolvedName: appState.resolveDisplayName(phone: member.phoneNumber, fallback: member.displayName),
            avatarUrl: member.userId.flatMap { viewModel.memberUsers[$0]?.avatarUrl },
            isGroupOwner: member.userId == viewModel.group.ownerId,
            isCurrentUserOwnerOrCoOwner: currentUserCanManage,
            onRoleChange: { role in
                Task { await viewModel.updateMemberRole(memberId: member.id, role: role) }
            },
            onRemove: { await viewModel.removeMember(id: member.id) }
        )

        if member.userId != nil {
            NavigationLink {
                MemberPublicProfileView(member: member, viewModel: viewModel)
            } label: {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }
}
