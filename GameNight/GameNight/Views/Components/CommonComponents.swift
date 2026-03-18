import SwiftUI

// MARK: - Avatar View
struct AvatarView: View {
    let url: String?
    var size: CGFloat = 40
    var placeholder: String = "person.fill"

    var body: some View {
        Group {
            if let url, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(Theme.Colors.backgroundElevated)
            Image(systemName: placeholder)
                .font(.system(size: size * 0.4))
                .foregroundColor(Theme.Colors.textTertiary)
        }
    }
}

// MARK: - Avatar Stack
struct AvatarStack: View {
    let urls: [String?]
    var size: CGFloat = 32
    var maxDisplay: Int = 4

    var body: some View {
        HStack(spacing: -(size * 0.3)) {
            ForEach(Array(urls.prefix(maxDisplay).enumerated()), id: \.offset) { index, url in
                AvatarView(url: url, size: size)
                    .overlay(Circle().stroke(Theme.Colors.cardBackground, lineWidth: 2))
                    .zIndex(Double(maxDisplay - index))
            }
            if urls.count > maxDisplay {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.backgroundElevated)
                        .frame(width: size, height: size)
                    Text("+\(urls.count - maxDisplay)")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .overlay(Circle().stroke(Theme.Colors.cardBackground, lineWidth: 2))
            }
        }
    }
}

// MARK: - Invite Status Badge
struct InviteStatusBadge: View {
    let status: InviteStatus
    var isPast: Bool = false

    private var displayLabel: String {
        if isPast && status == .accepted { return "Went" }
        return status.displayLabel
    }

    private var displayIcon: String {
        if isPast && status == .accepted { return "checkmark.seal.fill" }
        return status.icon
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: displayIcon)
                .font(.system(size: 10))
            Text(displayLabel)
                .font(Theme.Typography.caption2)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(status.color.opacity(0.15))
        )
    }
}
