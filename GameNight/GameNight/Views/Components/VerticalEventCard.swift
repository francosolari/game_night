import SwiftUI

struct VerticalEventCard: View {
    let event: GameEvent
    var myInvite: Invite?
    var confirmedCount: Int = 0
    var size: ComponentSize = .standard
    var onTap: (() -> Void)?

    private var isCurrentUserHost: Bool {
        event.hostId == SupabaseService.shared.client.auth.currentSession?.user.id
    }

    private var viewerRole: EventViewerRole {
        if isCurrentUserHost { return .host }
        if let status = myInvite?.status, status == .accepted || status == .maybe {
            return .rsvpd
        }
        if myInvite != nil { return .invitedNotRSVPd }
        return .publicViewer
    }

    private var eventIsPast: Bool {
        let eventDate = event.timeOptions.first?.date ?? event.createdAt
        return eventDate < Date()
    }

    private var coverImageUrl: String? {
        event.coverImageUrl ?? event.games.first(where: { $0.isPrimary })?.game?.imageUrl ?? event.games.first?.game?.imageUrl
    }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {
                // Cover image with optional invite status overlay
                ZStack(alignment: .topTrailing) {
                    coverImage
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))

                    if let invite = myInvite {
                        InviteStatusBadge(status: invite.status, isPast: eventIsPast)
                            .scaleEffect(0.8)
                            .padding(6)
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                    }
                }
                .padding(Theme.Spacing.xs)

                // Content section
                VStack(alignment: .leading, spacing: 6) {
                    // Date badge (two-line compact format)
                    EventDateLabel(event: event, size: .compact)

                    // Title
                    Text(event.title)
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Location
                    EventLocationLabel(event: event, viewerRole: viewerRole, size: .compact)

                    // Game info (name + playtime, no complexity in compact)
                    if !event.games.isEmpty {
                        GameInfoCompact(games: event.games, size: .compact)
                    }

                    Spacer(minLength: 4)

                    // Footer: Host avatar + Player count
                    Divider().opacity(0.4)

                    HStack(alignment: .center) {
                        HostBadge(host: event.host, isCurrentUserHost: isCurrentUserHost, size: .compact)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        PlayerCountIndicator(
                            confirmedCount: confirmedCount,
                            minPlayers: event.minPlayers,
                            maxPlayers: event.maxPlayers,
                            size: .compact
                        )
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
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let urlString = coverImageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                GenerativeEventCover(title: event.title, eventId: event.id, variant: event.coverVariant)
            }
        } else {
            GenerativeEventCover(title: event.title, eventId: event.id, variant: event.coverVariant)
        }
    }
}
