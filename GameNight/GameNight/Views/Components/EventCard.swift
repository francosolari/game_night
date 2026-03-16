import SwiftUI

struct EventCard: View {
    let event: GameEvent
    var myInvite: Invite?
    var onTap: (() -> Void)?

    private var viewerRole: EventViewerRole {
        let currentUserId = SupabaseService.shared.client.auth.currentSession?.user.id
        if event.hostId == currentUserId {
            return .host
        }

        if let status = myInvite?.status, status == .accepted || status == .maybe {
            return .rsvpd
        }

        if myInvite != nil {
            return .invitedNotRSVPd
        }

        return .publicViewer
    }

    private var accessPolicy: EventAccessPolicy {
        EventAccessPolicy(
            visibility: event.visibility,
            viewerRole: viewerRole,
            rsvpDeadline: event.rsvpDeadline,
            now: Date()
        )
    }

    private var locationPresentation: EventLocationPresentation? {
        guard event.location != nil || event.locationAddress != nil else { return nil }
        return EventLocationPresentation(
            locationName: event.location,
            locationAddress: event.locationAddress,
            canViewFullAddress: accessPolicy.canViewFullAddress
        )
    }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {
                // Cover / Header
                ZStack(alignment: .bottomLeading) {
                    // Gradient background
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(Theme.Gradients.eventCard)
                        .frame(height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )

                    // Game thumbnails collage
                    HStack(spacing: -8) {
                        ForEach(event.games.prefix(3)) { eventGame in
                            if let game = eventGame.game {
                                GameThumbnail(url: game.thumbnailUrl, size: 48)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                            .stroke(Theme.Colors.cardBackground, lineWidth: 2)
                                    )
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)

                    // Status badge
                    if let invite = myInvite {
                        HStack {
                            Spacer()
                            InviteStatusBadge(status: invite.status)
                                .padding(Theme.Spacing.md)
                        }
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(event.title)
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    // Time display
                    if let firstTime = event.timeOptions.first {
                        HStack(spacing: Theme.Spacing.sm) {
                            if event.scheduleMode == .fixed || event.timeOptions.count <= 1 {
                                // Fixed: show date + time directly
                                Image(systemName: "calendar")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.primary)

                                Text("\(firstTime.displayDate) \u{00B7} \(firstTime.displayTime)")
                                    .font(Theme.Typography.calloutMedium)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            } else {
                                // Poll: show option count
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.accent)

                                Text("\(event.timeOptions.count) time options")
                                    .font(Theme.Typography.calloutMedium)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }

                    // Location
                    if let locationPresentation {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "mappin")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.Colors.secondary)

                            Text(locationPresentation.title)
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    // Games list
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        ForEach(event.games.prefix(2)) { eventGame in
                            if let game = eventGame.game {
                                HStack(spacing: 6) {
                                    if eventGame.isPrimary {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.Colors.warning)
                                    }
                                    Text(game.name)
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    ComplexityDot(weight: game.complexity)
                                    Text(game.playtimeDisplay)
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                            }
                        }
                    }

                    // Host & player count
                    HStack {
                        if let host = event.host {
                            HStack(spacing: 6) {
                                AvatarView(url: host.avatarUrl, size: 20)
                                Text("Hosted by \(host.displayName)")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11))
                            Text("\(event.minPlayers)\(event.maxPlayers.map { "-\($0)" } ?? "+") players")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Invite Status Badge
struct InviteStatusBadge: View {
    let status: InviteStatus

    private var color: Color {
        switch status {
        case .accepted: return Theme.Colors.success
        case .declined: return Theme.Colors.error
        case .maybe: return Theme.Colors.warning
        case .pending: return Theme.Colors.textTertiary
        case .expired: return Theme.Colors.textTertiary
        case .waitlisted: return Theme.Colors.accent
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10))
            Text(status.displayLabel)
                .font(Theme.Typography.caption2)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

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
