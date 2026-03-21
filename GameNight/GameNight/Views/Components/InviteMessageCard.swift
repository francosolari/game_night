import SwiftUI

/// Compact event preview card rendered inside invite-type DM bubbles.
struct InviteMessageCard: View {
    let metadata: MessageMetadata
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                coverThumbnail
                eventInfo
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
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
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    private var coverThumbnail: some View {
        Group {
            if let urlString = metadata.coverImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    thumbnailPlaceholder
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
            .fill(Theme.Colors.primarySubtle)
            .overlay(
                Image(systemName: "dice.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.Colors.primary.opacity(0.5))
            )
    }

    private var eventInfo: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Game Night Invite")
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.primary)
                .textCase(.uppercase)
                .tracking(0.4)

            if let title = metadata.eventTitle {
                Text(title)
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
            }

            if let timeLabel = metadata.timeLabel {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(timeLabel)
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Colors.textSecondary)
            }

            if let hostName = metadata.hostName {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                    Text("Hosted by \(hostName)")
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Colors.textTertiary)
            }
        }
    }
}
