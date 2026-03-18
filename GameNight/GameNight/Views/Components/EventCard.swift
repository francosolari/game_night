import SwiftUI

struct EventCard: View {
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

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {
                // 1. Top Section: Game Collage & Status
                ZStack(alignment: .bottomLeading) {
                    gameCollage
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
                    
                    // Status Badge (Top Right)
                    if let invite = myInvite {
                        VStack {
                            HStack {
                                Spacer()
                                InviteStatusBadge(status: invite.status, isPast: eventIsPast)
                                    .padding(Theme.Spacing.md)
                                    .shadow(color: Color.black.opacity(0.15), radius: 4)
                            }
                            Spacer()
                        }
                    }

                    // Floating Date Badge (Bottom Left)
                    EventDateLabel(event: event, size: .standard)
                        .padding(Theme.Spacing.md)
                        .shadow(color: Color.black.opacity(0.1), radius: 3)
                }
                .padding(Theme.Spacing.xs)

                // 2. Info Section
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    // Title & Location
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(event.title)
                            .font(Theme.Typography.displaySmall)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                        
                        EventLocationLabel(event: event, viewerRole: viewerRole, size: .standard)
                    }

                    // Games Detail Section
                    if !event.games.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("PLANNED GAMES")
                                .font(Theme.Typography.caption2)
                                .foregroundColor(Theme.Colors.textTertiary)
                                .tracking(1)

                            GameInfoCompact(games: event.games, size: .expanded)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .fill(Theme.Colors.backgroundElevated.opacity(0.5))
                        )
                    }

                    // Footer: Host & Players
                    HStack(alignment: .center) {
                        HostBadge(host: event.host, isCurrentUserHost: isCurrentUserHost, size: .standard)
                        
                        Spacer()
                        
                        PlayerCountIndicator(
                            confirmedCount: confirmedCount,
                            minPlayers: event.minPlayers,
                            maxPlayers: event.maxPlayers,
                            size: .standard
                        )
                    }
                    .padding(.top, Theme.Spacing.xs)
                }
                .padding(Theme.Spacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.cardBackground)
                    .shadow(color: Theme.Shadows.card(), radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .stroke(Theme.Colors.border.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var gameCollage: some View {
        let games = event.games.prefix(3)
        if games.isEmpty {
            GenerativeEventCover(title: event.title, eventId: event.id, variant: event.coverVariant)
        } else {
            HStack(spacing: 1) {
                ForEach(Array(games.enumerated()), id: \.offset) { index, eventGame in
                    if let game = eventGame.game, let url = URL(string: game.imageUrl ?? "") {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Theme.Colors.backgroundElevated
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                    } else {
                        Theme.Gradients.eventCard
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}
