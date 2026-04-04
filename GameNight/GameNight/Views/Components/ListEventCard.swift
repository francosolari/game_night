import SwiftUI

struct ListEventCard: View {
    let event: GameEvent
    var myInvite: Invite?
    var confirmedCount: Int = 0
    var onTap: (() -> Void)?

    private var isCurrentUserHost: Bool {
        event.hostId == SupabaseService.shared.client.auth.currentSession?.user.id
    }

    private var viewerRole: EventViewerRole {
        if isCurrentUserHost { return .host }
        if let status = myInvite?.status, status == .accepted || status == .maybe || status == .voted {
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
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                // Left: Cover image
                ZStack(alignment: .topTrailing) {
                    coverImage
                        .frame(width: 80, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))

                    if let invite = myInvite {
                        InviteStatusBadge(status: invite.status, isPast: eventIsPast)
                            .scaleEffect(0.65)
                            .padding(2)
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                    }
                }

                // Right: Info stack
                VStack(alignment: .leading, spacing: 6) {
                    // Date + Title
                    VStack(alignment: .leading, spacing: 3) {
                        EventDateLabel(event: event, size: .standard)

                        Text(event.title)
                            .font(Theme.Typography.headlineMedium.weight(.bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                    }

                    // Location
                    EventLocationLabel(event: event, viewerRole: viewerRole, size: .compact)

                    // Game info (with complexity in standard mode)
                    if !event.games.isEmpty {
                        GameInfoCompact(games: event.games, size: .compact)
                    }

                    // Footer: Host + Player count
                    HStack(alignment: .center) {
                        HostBadge(host: event.host, isCurrentUserHost: isCurrentUserHost, size: .compact)
                        Spacer()
                        PlayerCountIndicator(
                            confirmedCount: confirmedCount,
                            minPlayers: event.minPlayers,
                            maxPlayers: event.maxPlayers,
                            size: .compact
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.cardBackground)
                    .shadow(color: Theme.Shadows.card(), radius: 4, x: 0, y: 2)
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
