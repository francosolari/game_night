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
                // Top Cover Section
                ZStack(alignment: .topTrailing) {
                    coverImage
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))

                    if let invite = myInvite {
                        InviteStatusBadge(status: invite.status, isPast: eventIsPast)
                            .scaleEffect(0.85)
                            .padding(Theme.Spacing.sm)
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                    }
                }
                .padding(Theme.Spacing.xs)

                // Info Section
                VStack(alignment: .leading, spacing: size.spacing) {
                    EventDateLabel(event: event, size: .compact)

                    Text(event.title)
                        .font(size.titleFont)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .frame(height: size.titleFont == Theme.Typography.calloutMedium ? 36 : 44, alignment: .topLeading)

                    EventLocationLabel(event: event, viewerRole: viewerRole, size: .compact)

                    if !event.games.isEmpty {
                        GameInfoCompact(games: event.games, size: .compact)
                            .padding(.top, 2)
                    }

                    Spacer(minLength: Theme.Spacing.sm)

                    Divider()
                        .opacity(0.5)
                        .padding(.vertical, 2)

                    HStack {
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
                .padding([.horizontal, .bottom], Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
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
                    GameThumbnail(url: game.thumbnailUrl, size: 40)
                } else {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.Colors.textTertiary.opacity(0.5))
                }
            }
    }
}
