import SwiftUI

struct GroupDetailView: View {
    @StateObject private var viewModel: GroupDetailViewModel
    @StateObject private var groupsViewModel = GroupsViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showAddMembers = false
    @State private var showPlayLogging = false
    @State private var toast: ToastItem?

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
                        appState.showCreateEvent = true
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
                Picker("Tab", selection: $viewModel.selectedTab) {
                    ForEach(GroupDetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

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
                        await groupsViewModel.addMembers(to: viewModel.group.id, contacts: contacts)
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
                Task { await viewModel.loadPlays() }
            }
        }
        .toast($toast)
        .task {
            await viewModel.loadAllData()
            viewModel.subscribeToChatUpdates()
        }
        .onDisappear {
            viewModel.unsubscribeFromChat()
        }
    }

    // MARK: - Members Tab

    private var membersTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
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

            let tier1 = viewModel.group.members.filter { $0.tier == 1 }
            if !tier1.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Tier 1 — First Invite")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.primary)

                    ForEach(tier1) { member in
                        MemberRow(member: member, groupId: viewModel.group.id, viewModel: groupsViewModel)
                    }
                }
            }

            let tier2 = viewModel.group.members.filter { $0.tier == 2 }
            if !tier2.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Tier 2 — Waitlist")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.accent)

                    ForEach(tier2) { member in
                        MemberRow(member: member, groupId: viewModel.group.id, viewModel: groupsViewModel)
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
}
