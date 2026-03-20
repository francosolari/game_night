import SwiftUI

/// Compact card shown in the home screen "Awaiting Response" section for pending group invitations.
struct GroupInviteCard: View {
    let group: GameGroup
    let member: GroupMember
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var isResponding = false

    private var inviterText: String {
        // Show who invited you if available
        if let invitedBy = member.invitedBy {
            // Fallback to generic text — could be enriched with display name resolution
            return "You've been invited to join"
        }
        return "You've been invited to join"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header row
            HStack(spacing: Theme.Spacing.md) {
                // Group emoji avatar
                ZStack {
                    Circle()
                        .fill(Theme.Gradients.primary)
                        .frame(width: 44, height: 44)
                    Text(group.emoji ?? "🎲")
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Text("\(group.members.filter(\.isAccepted).count) members")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.Colors.highlight)
                        .frame(width: 7, height: 7)
                    Text("Invited")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.primary)
                }
            }

            Text(inviterText)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)

            // Accept / Decline buttons
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    guard !isResponding else { return }
                    isResponding = true
                    onDecline()
                } label: {
                    Text("Decline")
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.fieldBackground)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isResponding)

                Button {
                    guard !isResponding else { return }
                    isResponding = true
                    onAccept()
                } label: {
                    Text("Join Group")
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.primary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isResponding)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Theme.Colors.primary.opacity(0.25), lineWidth: 1)
        )
    }
}
