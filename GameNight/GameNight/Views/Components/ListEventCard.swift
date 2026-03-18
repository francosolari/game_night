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
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                // Cover Image
                ZStack(alignment: .topTrailing) {
                    coverImage
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))

                    if let invite = myInvite {
                        InviteStatusBadge(status: invite.status, isPast: eventIsPast)
                            .scaleEffect(0.7)
                            .padding(2)
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                    }
                }

                // Info Content
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            EventDateLabel(event: event, size: .compact)
                            
                            Text(event.title)
                                .font(Theme.Typography.headlineMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }

                    EventLocationLabel(event: event, viewerRole: viewerRole, size: .compact)

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            if !event.games.isEmpty {
                                GameInfoCompact(games: event.games, size: .compact)
                            }
                            
                            HostBadge(host: event.host, isCurrentUserHost: isCurrentUserHost, size: .compact)
                        }

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
                gradientPlaceholder
            }
        } else {
            gradientPlaceholder
        }
    }

    private var gradientPlaceholder: some View {
        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
            .fill(Theme.Gradients.eventCard)
            .overlay {
                if let game = event.games.first?.game {
                    GameThumbnail(url: game.thumbnailUrl, size: 32)
                } else {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.textTertiary.opacity(0.5))
                }
            }
    }
}
