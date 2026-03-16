import SwiftUI

struct GuestListTabsView: View {
    let summary: InviteSummary
    @State private var selectedTab = 0

    private var tabs: [(label: String, count: Int, color: Color, users: [InviteSummary.InviteUser])] {
        [
            ("Going", summary.accepted, Theme.Colors.success, summary.acceptedUsers),
            ("Maybe", summary.maybe, Theme.Colors.warning, summary.maybeUsers),
            ("Pending", summary.pending, Theme.Colors.textTertiary, summary.pendingUsers),
            ("Can't", summary.declined, Theme.Colors.error, summary.declinedUsers)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Guest List")

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
                    GuestTabContent(users: tab.users, emptyLabel: "No one \(tab.label.lowercased()) yet")
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: guestListHeight)
            .animation(Theme.Animation.snappy, value: selectedTab)
        }
        .cardStyle()
    }

    private var guestListHeight: CGFloat {
        let currentUsers = tabs[selectedTab].users
        let rowHeight: CGFloat = 44
        let minRows: CGFloat = 2
        return max(minRows, CGFloat(currentUsers.count)) * rowHeight + Theme.Spacing.sm
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
