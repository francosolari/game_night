import SwiftUI

enum GuestListVisibilityMode: Equatable {
    case fullList
    case countsOnly(message: String)
}

struct GuestListTabsView: View {
    let summary: InviteSummary
    var visibilityMode: GuestListVisibilityMode = .fullList
    var isHost: Bool = false
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil
    var onViewAll: (() -> Void)? = nil
    @State private var selectedTab = 0

    private var allTabs: [(label: String, count: Int, color: Color, users: [InviteSummary.InviteUser])] {
        [
            ("Going", summary.accepted, InviteStatus.accepted.color, summary.acceptedUsers),
            ("Maybe", summary.maybe, InviteStatus.maybe.color, summary.maybeUsers),
            ("Pending", summary.pending, InviteStatus.pending.color, summary.pendingUsers),
            ("Can't", summary.declined, InviteStatus.declined.color, summary.declinedUsers)
        ]
    }

    private var tabs: [(label: String, count: Int, color: Color, users: [InviteSummary.InviteUser])] {
        isHost ? allTabs : Array(allTabs.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                SectionHeader(title: "Guest List")
                Spacer()
                HStack(spacing: Theme.Spacing.md) {
                    if let onViewAll {
                        Button("View all", action: onViewAll)
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    if let actionTitle, let onAction {
                        Button(actionTitle, action: onAction)
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
            }

            // Pill tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button {
                            withAnimation(Theme.Animation.snappy) {
                                selectedTab = index
                            }
                        } label: {
                            Text("\(tab.label) · \(tab.count)")
                                .font(Theme.Typography.caption2)
                                .foregroundColor(selectedTab == index ? .white : tab.color)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedTab == index ? tab.color : tab.color.opacity(0.15))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Swipeable content
            TabView(selection: $selectedTab) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    switch visibilityMode {
                    case .fullList:
                        GuestTabContent(users: tab.users, emptyLabel: "No one \(tab.label.lowercased()) yet")
                            .tag(index)
                    case .countsOnly(let message):
                        CountsOnlyGuestTabContent(message: message)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: guestListHeight)
            .animation(Theme.Animation.snappy, value: selectedTab)
        }
        .cardStyle()
    }

    private var guestListHeight: CGFloat {
        switch visibilityMode {
        case .fullList:
            guard selectedTab < tabs.count else { return 2 * 44 + Theme.Spacing.sm }
            let currentUsers = tabs[selectedTab].users
            let rowHeight: CGFloat = 44
            let minRows: CGFloat = 2
            return max(minRows, CGFloat(currentUsers.count)) * rowHeight + Theme.Spacing.sm
        case .countsOnly:
            return 96
        }
    }
}

private struct CountsOnlyGuestTabContent: View {
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.Colors.textTertiary)

            Text(message)
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct GuestTabContent: View {
    let users: [InviteSummary.InviteUser]
    let emptyLabel: String

    var body: some View {
        if users.isEmpty {
            VStack(spacing: Theme.Spacing.sm) {
                Text(emptyLabel)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(users) { user in
                        HStack(spacing: Theme.Spacing.md) {
                            AvatarView(url: user.avatarUrl, size: 32)
                            Text(user.name)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            if user.tier > 1 {
                                Text("Tier \(user.tier)")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct GuestListFullPageView: View {
    let summary: InviteSummary
    let isHost: Bool
    let visibilityMode: GuestListVisibilityMode
    let canInvite: Bool
    let onInvite: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    private var allTabs: [(label: String, count: Int, color: Color, users: [InviteSummary.InviteUser])] {
        [
            ("Going", summary.accepted, InviteStatus.accepted.color, summary.acceptedUsers),
            ("Maybe", summary.maybe, InviteStatus.maybe.color, summary.maybeUsers),
            ("Pending", summary.pending, InviteStatus.pending.color, summary.pendingUsers),
            ("Can't", summary.declined, InviteStatus.declined.color, summary.declinedUsers)
        ]
    }

    private var tabs: [(label: String, count: Int, color: Color, users: [InviteSummary.InviteUser])] {
        isHost ? allTabs : Array(allTabs.prefix(2))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                            Button {
                                withAnimation(Theme.Animation.snappy) {
                                    selectedTab = index
                                }
                            } label: {
                                Text("\(tab.label) · \(tab.count)")
                                    .font(Theme.Typography.caption2)
                                    .foregroundColor(selectedTab == index ? .white : tab.color)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selectedTab == index ? tab.color : tab.color.opacity(0.15))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                TabView(selection: $selectedTab) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        switch visibilityMode {
                        case .fullList:
                            GuestTabContent(users: tab.users, emptyLabel: "No one \(tab.label.lowercased()) yet")
                                .tag(index)
                        case .countsOnly(let message):
                            CountsOnlyGuestTabContent(message: message)
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(Theme.Animation.snappy, value: selectedTab)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Guest List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
                if canInvite {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Invite") {
                            onInvite()
                            dismiss()
                        }
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
        }
    }
}
