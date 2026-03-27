import SwiftUI

/// Compact group invite preview card rendered inside group_invite-type DM bubbles.
struct GroupInviteMessageCard: View {
    let metadata: MessageMetadata

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Group emoji avatar
            ZStack {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.primarySubtle)
                    .frame(width: 48, height: 48)
                Text(metadata.groupEmoji ?? "🎲")
                    .font(.system(size: 24))
            }

            // Info
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Group Invite")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.accentWarm)
                    .textCase(.uppercase)
                    .tracking(0.4)

                if let name = metadata.groupName {
                    Text(name)
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                }

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 10))
                    Text("You're invited to join")
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
        )
    }
}
