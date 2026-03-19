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

    private var tabs: [(title: String, color: Color, users: [InviteSummary.InviteUser])] {
        var result: [(String, Color, [InviteSummary.InviteUser])] = [
            ("Going", Theme.Colors.success, summary.acceptedUsers),
            ("Maybe", Theme.Colors.warning, summary.maybeUsers),
        ]
        if isHost {
            result.append(("Pending", Theme.Colors.textTertiary, summary.pendingUsers))
            result.append(("Can't Go", Theme.Colors.error, summary.declinedUsers))
        }
        return result.filter { !$0.2.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header with actions
            HStack {
                SectionHeader(title: "Guest List")
                Spacer()
                HStack(spacing: Theme.Spacing.md) {
                    if let onViewAll {
                        Button("See all", action: onViewAll)
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

            switch visibilityMode {
            case .fullList:
                if !tabs.isEmpty {
                    // Pill tab bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                                GuestTabPill(
                                    title: tab.title,
                                    count: tab.users.count,
                                    color: tab.color,
                                    isSelected: selectedTab == index
                                ) {
                                    withAnimation(Theme.Animation.snappy) {
                                        selectedTab = index
                                    }
                                }
                            }
                        }
                    }

                    Divider()
                        .background(Theme.Colors.divider)

                    // Swipeable tab content
                    TabView(selection: $selectedTab) {
                        ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                            GuestTabContent(
                                users: tab.users,
                                accentColor: tab.color,
                                maxVisible: 4,
                                onSeeMore: onViewAll
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: guestTabContentHeight)
                    .animation(Theme.Animation.snappy, value: selectedTab)
                }

            case .countsOnly(let message):
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.textTertiary)

                    Text(message)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.xl)
            }
        }
        .cardStyle()
        .onChange(of: tabs.count) { _, _ in
            if selectedTab >= tabs.count {
                selectedTab = max(0, tabs.count - 1)
            }
        }
    }

    private var guestTabContentHeight: CGFloat {
        guard selectedTab < tabs.count else { return 200 }
        let count = min(tabs[selectedTab].users.count, 4)
        let rowHeight: CGFloat = 48
        let seeMoreHeight: CGFloat = tabs[selectedTab].users.count > 4 ? 36 : 0
        return CGFloat(max(count, 1)) * rowHeight + seeMoreHeight + Theme.Spacing.sm
    }

}

// MARK: - Pill Tab Button

private struct GuestTabPill: View {
    let title: String
    let count: Int
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                StatusDot(color: color, size: 6)
                Text("\(title) · \(count)")
                    .font(Theme.Typography.caption.weight(isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.12) : Theme.Colors.fieldBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab Content (list of guests)

private struct GuestTabContent: View {
    let users: [InviteSummary.InviteUser]
    let accentColor: Color
    var maxVisible: Int = 4
    var onSeeMore: (() -> Void)? = nil

    private var displayUsers: [InviteSummary.InviteUser] {
        Array(users.prefix(maxVisible))
    }

    private var hiddenCount: Int {
        max(0, users.count - maxVisible)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(displayUsers.enumerated()), id: \.element.id) { index, user in
                HStack(spacing: Theme.Spacing.sm) {
                    StatusDot(color: accentColor, size: 6)
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
                .padding(.vertical, 8)
                .padding(.horizontal, Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.cardBackground)
                )

                if index < displayUsers.count - 1 {
                    Divider()
                        .background(Theme.Colors.divider)
                }
            }

            if hiddenCount > 0, let onSeeMore {
                Button {
                    onSeeMore()
                } label: {
                    Text("See \(hiddenCount) more...")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Full Page Guest List

struct GuestListFullPageView: View {
    let summary: InviteSummary
    let isHost: Bool
    let visibilityMode: GuestListVisibilityMode
    let canInvite: Bool
    let onInvite: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedTab = 0

    private var tabs: [(title: String, color: Color, users: [InviteSummary.InviteUser])] {
        var result: [(String, Color, [InviteSummary.InviteUser])] = [
            ("Going", Theme.Colors.success, summary.acceptedUsers),
            ("Maybe", Theme.Colors.warning, summary.maybeUsers),
        ]
        if isHost {
            result.append(("Pending", Theme.Colors.textTertiary, summary.pendingUsers))
            result.append(("Can't Go", Theme.Colors.error, summary.declinedUsers))
        }
        return result.filter { !$0.2.isEmpty }
    }

    private var totalGuests: Int {
        tabs.reduce(0) { $0 + $1.users.count }
    }

    private func filteredUsers(_ users: [InviteSummary.InviteUser]) -> [InviteSummary.InviteUser] {
        guard !searchText.isEmpty else { return users }
        return users.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if totalGuests > 10 {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.textTertiary)
                        TextField("Search guests...", text: $searchText)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.fieldBackground)
                    )
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.md)
                }

                switch visibilityMode {
                case .fullList:
                    if !tabs.isEmpty {
                        // Pill tabs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                                    let filtered = filteredUsers(tab.users)
                                    GuestTabPill(
                                        title: tab.title,
                                        count: filtered.count,
                                        color: tab.color,
                                        isSelected: selectedTab == index
                                    ) {
                                        withAnimation(Theme.Animation.snappy) {
                                            selectedTab = index
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.xl)
                        }
                        .padding(.top, Theme.Spacing.md)

                        // Full list content
                        TabView(selection: $selectedTab) {
                            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                                ScrollView {
                                    GuestTabContent(
                                        users: filteredUsers(tab.users),
                                        accentColor: tab.color,
                                        maxVisible: .max
                                    )
                                    .padding(.horizontal, Theme.Spacing.xl)
                                    .padding(.top, Theme.Spacing.md)
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }

                case .countsOnly(let message):
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
                    .padding(Theme.Spacing.xxl)
                }
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
