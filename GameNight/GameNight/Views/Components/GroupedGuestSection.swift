import SwiftUI

/// Status-grouped guest rows with accent bars and avatar rows.
/// Shared between inline guest list preview and full page view.
struct GroupedGuestSection: View {
    let title: String
    let count: Int
    let accentColor: Color
    let users: [InviteSummary.InviteUser]
    var maxVisible: Int? = nil
    var onSeeMore: (() -> Void)? = nil

    private var displayUsers: [InviteSummary.InviteUser] {
        if let maxVisible, users.count > maxVisible {
            return Array(users.prefix(maxVisible))
        }
        return users
    }

    private var hiddenCount: Int {
        guard let maxVisible, users.count > maxVisible else { return 0 }
        return users.count - maxVisible
    }

    var body: some View {
        if users.isEmpty { EmptyView() } else {
            AccentBorderCard(accentColor: accentColor) {
                VStack(alignment: .leading, spacing: 0) {
                    // Group header
                    HStack(spacing: Theme.Spacing.sm) {
                        StatusDot(color: accentColor)
                        Text("\(title) (\(count))")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.xs)

                    // Guest rows
                    ForEach(Array(displayUsers.enumerated()), id: \.element.id) { index, user in
                        GuestRow(user: user)

                        if index < displayUsers.count - 1 {
                            Divider()
                                .background(Theme.Colors.divider)
                                .padding(.leading, Theme.Spacing.md + 36 + Theme.Spacing.sm)
                        }
                    }

                    // "See X more..." link
                    if hiddenCount > 0 {
                        Button {
                            onSeeMore?()
                        } label: {
                            Text("See \(hiddenCount) more...")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.primary)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, Theme.Spacing.xs)
            }
        }
    }
}

/// A single guest row with avatar and name.
struct GuestRow: View {
    let user: InviteSummary.InviteUser

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            AvatarView(url: user.avatarUrl, size: 36)
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
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 6)
    }
}
