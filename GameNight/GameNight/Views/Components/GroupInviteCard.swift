import SwiftUI

/// Card shown in the home screen "Awaiting Response" section for pending group invitations.
/// Styled to match VerticalEventCard with a rich visual treatment.
struct GroupInviteCard: View {
    let group: GameGroup
    let member: GroupMember
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var isResponding = false

    private var acceptedMembers: [GroupMember] {
        group.members.filter(\.isAccepted)
    }

    private var expiresText: String? {
        let expiryDate = member.addedAt.addingTimeInterval(7 * 24 * 60 * 60) // 1 week
        let remaining = expiryDate.timeIntervalSince(Date())
        if remaining <= 0 { return "Expired" }
        let days = Int(remaining / (24 * 60 * 60))
        if days > 1 { return "Expires in \(days) days" }
        if days == 1 { return "Expires tomorrow" }
        let hours = Int(remaining / 3600)
        if hours > 0 { return "Expires in \(hours)h" }
        return "Expires soon"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header banner with emoji + gradient
            ZStack(alignment: .bottomLeading) {
                // Gradient background
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Colors.primary.opacity(0.25),
                                Theme.Colors.accentWarm.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)
                    .overlay(
                        Text(group.emoji ?? "🎲")
                            .font(.system(size: 48))
                            .opacity(0.3),
                        alignment: .center
                    )

                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.Colors.highlight)
                        .frame(width: 6, height: 6)
                    Text("Group Invite")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Theme.Colors.cardBackground.opacity(0.9))
                )
                .padding(8)
            }
            .padding(Theme.Spacing.xs)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Group emoji + name
                HStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primarySubtle)
                            .frame(width: 32, height: 32)
                        Text(group.emoji ?? "🎲")
                            .font(.system(size: 16))
                    }

                    Text(group.name)
                        .font(Theme.Typography.calloutMedium.weight(.bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Member count
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 9))
                    Text("\(acceptedMembers.count) member\(acceptedMembers.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Theme.Colors.textTertiary)

                // Expiry
                if let expiresText {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(expiresText)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Theme.Colors.accentWarm)
                }

                Spacer(minLength: 4)

                Divider().opacity(0.4)

                // Accept / Decline
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
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.sm)
            .padding(.top, 2)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: Theme.Shadows.card(), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Theme.Colors.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}
