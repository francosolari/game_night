import SwiftUI

struct HostBadge: View {
    let host: User?
    let isCurrentUserHost: Bool
    var size: ComponentSize = .standard

    var body: some View {
        HStack(spacing: 4) {
            if let host {
                AvatarView(url: host.avatarUrl, size: size.avatarSize)
            }
            Text(displayText)
                .font(size.captionFont)
                .foregroundColor(Theme.Colors.textTertiary)
                .lineLimit(1)
        }
    }

    private var displayText: String {
        if isCurrentUserHost {
            return "You \u{00B7} Hosting"
        }
        if let host {
            return host.displayName
        }
        return "Unknown host"
    }
}
