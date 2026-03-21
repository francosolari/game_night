import SwiftUI

// MARK: - Notification Type Color

private extension AppNotification.NotificationType {
    var color: Color {
        switch self {
        case .inviteReceived:   return Theme.Colors.primary
        case .rsvpUpdate:       return Theme.Colors.success
        case .groupInvite:      return Theme.Colors.accentWarm
        case .timeConfirmed:    return Theme.Colors.primary
        case .benchPromoted:    return Theme.Colors.warning
        case .dmReceived:       return Theme.Colors.accent
        case .textBlast:        return Theme.Colors.accentWarm
        case .gameConfirmed:    return Theme.Colors.success
        case .eventCancelled:   return Theme.Colors.error
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            iconCircle
            contentStack
            Spacer(minLength: 0)
            trailingIndicator
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(rowBackground)
        .contentShape(Rectangle())
    }

    // MARK: - Subviews

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(notification.type.color.opacity(0.15))
                .frame(width: 40, height: 40)

            Image(systemName: notification.type.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(notification.type.color)
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(notification.title)
                .font(notification.isRead ? Theme.Typography.callout : Theme.Typography.calloutMedium)
                .foregroundColor(notification.isRead ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let body = notification.body {
                Text(body)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(notification.createdAt.relativeDisplay)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trailingIndicator: some View {
        Group {
            if !notification.isRead {
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, Theme.Spacing.xs)
            } else {
                Color.clear
                    .frame(width: 8, height: 8)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
    }

    private var rowBackground: some View {
        notification.isRead
            ? Color.clear
            : Theme.Colors.accent.opacity(0.04)
    }
}
