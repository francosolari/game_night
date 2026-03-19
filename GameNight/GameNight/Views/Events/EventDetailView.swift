import SwiftUI

struct EventDetailView: View {
    let eventId: UUID
    @StateObject private var viewModel = EventViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeIds = Set<UUID>()
    @State private var pollVotes: [UUID: TimeOptionVoteType] = [:]
    @State private var showTimeSuggestion = false
    @State private var showInviteContacts = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showCreateGroupFromEvent = false
    @State private var showGuestListFullPage = false
    @State private var toast: ToastItem?
    @State private var editSavePresentation = EventEditSavePresentation()
    @State private var heroStretchOffset: CGFloat = 0
    @State private var showRSVPSheet = false

    private var deleteErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.error?.isEmpty == false },
            set: { isPresented in
                if !isPresented {
                    viewModel.error = nil
                }
            }
        )
    }

    var body: some View {
        ZStack {
            ScrollView {
                if viewModel.isLoading {
                    LoadingView()
                } else if let event = viewModel.event {
                    VStack(spacing: 0) {
                        // 1. Hero cover with overlay (title, RSVP, location, host, date badge)
                        EventHeroHeader(
                            event: event,
                            locationPresentation: locationPresentation(for: event),
                            calendarTimeOption: calendarTimeOption(for: event),
                            myInvite: viewModel.myInvite,
                            rsvpDeadline: event.rsvpDeadline,
                            onRSVPTap: { showRSVPSheet = true }
                        )

                        VStack(spacing: Theme.Spacing.xxl) {
                            // 2. Games Section ("What We're Playing") — first for visibility
                            gamesSection(event)

                            // 3. Description
                            if let desc = event.description, !desc.isEmpty {
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    Text(desc)
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }

                            // 4. Schedule Section
                            scheduleSection(event)

                            // 5. Guest List (inline preview)
                            GuestListTabsView(
                                summary: viewModel.inviteSummary,
                                visibilityMode: guestListVisibilityMode,
                                isHost: viewModel.isOwner,
                                actionTitle: viewModel.canInviteGuests ? "Invite" : nil,
                                onAction: viewModel.canInviteGuests ? {
                                    showInviteContacts = true
                                } : nil,
                                onViewAll: { showGuestListFullPage = true }
                            )

                            // 7. Activity Feed
                            ActivityFeedView(viewModel: viewModel, isHost: viewModel.isOwner)
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.top, Theme.Spacing.xl)
                    }
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .disabled(viewModel.isDeleting)

            // Delete overlay
            if viewModel.isDeleting {
                Theme.Colors.overlay
                    .ignoresSafeArea()

                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .tint(Theme.Colors.primary)
                    Text("Deleting event...")
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .padding(Theme.Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(Theme.Colors.cardBackground)
                )
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Button {
                            showEditSheet = true
                        } label: {
                            Text("Edit")
                                .font(Theme.Typography.calloutMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Theme.Colors.secondary.opacity(0.15)))
                        }

                        Menu {
                            Button {
                                showCreateGroupFromEvent = true
                            } label: {
                                Label("Create Group from Guests", systemImage: "person.3.fill")
                            }

                            Button("Delete Event", role: .destructive) {
                                showDeleteConfirmation = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showTimeSuggestion) {
            TimeSuggestionSheet { option in
                // Handle time suggestion
            }
        }
        .sheet(isPresented: $showInviteContacts) {
            ContactListSheet(
                excludedPhones: Set(viewModel.invites.map(\.phoneNumber)),
                onSelect: { contacts in
                    Task { await viewModel.inviteContacts(contacts) }
                }
            )
        }
        .sheet(isPresented: $showEditSheet) {
            if let event = viewModel.event {
                CreateEventView(eventToEdit: event, initialInvites: viewModel.invites) { savedEvent in
                    editSavePresentation.register(savedEvent)
                }
            }
        }
        .onChange(of: showEditSheet) { _, isPresented in
            guard let savedEvent = editSavePresentation.consumeIfSheetDismissed(isSheetPresented: isPresented) else {
                return
            }
            viewModel.applyEditedEvent(savedEvent)
            toast = EventEditToastFactory.makeSuccessToast(for: savedEvent)
            Task { await viewModel.loadEvent(id: eventId) }
        }
        .confirmationDialog(
            "Delete this event?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Event", role: .destructive) {
                Task {
                    if await viewModel.deleteEvent() {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .alert("Couldn't delete event", isPresented: deleteErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "Please try again.")
        }
        .sheet(isPresented: $showCreateGroupFromEvent) {
            CreateGroupFromAttendeesSheet(invites: viewModel.invites, onResult: { resultToast in
                toast = resultToast
            })
        }
        .sheet(isPresented: $showRSVPSheet) {
            if let event = viewModel.event {
                RSVPSheet(
                    event: event,
                    currentStatus: viewModel.myInvite?.status,
                    isSending: viewModel.isSending,
                    pollVotes: $pollVotes,
                    onSubmit: { status in
                        let votes = buildTimeVotes(for: event)
                        await viewModel.respondToInvite(
                            status: status,
                            timeVotes: status == .declined ? [] : votes,
                            suggestedTimes: nil
                        )
                    }
                )
            }
        }
        .sheet(isPresented: $showGuestListFullPage) {
            GuestListFullPageView(
                summary: viewModel.inviteSummary,
                isHost: viewModel.isOwner,
                visibilityMode: guestListVisibilityMode,
                canInvite: viewModel.canInviteGuests,
                onInvite: { showInviteContacts = true }
            )
        }
        .toast($toast)
        .task {
            await viewModel.loadEvent(id: eventId)
        }
    }

    // MARK: - Games Section

    @ViewBuilder
    private func gamesSection(_ event: GameEvent) -> some View {
        if event.allowGameVoting && event.games.count > 1 {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    SectionHeader(title: "What We're Playing")
                    Spacer()
                    if event.minPlayers > 0 {
                        PlayerCountIndicator(
                            confirmedCount: viewModel.inviteSummary.accepted,
                            minPlayers: event.minPlayers,
                            maxPlayers: event.maxPlayers
                        )
                    }
                }

                // Quorum warning banner
                if event.minPlayers > 0 && viewModel.inviteSummary.accepted < event.minPlayers {
                    let needed = event.minPlayers - viewModel.inviteSummary.accepted
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("\(needed) more player\(needed == 1 ? "" : "s") needed")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundColor(Theme.Colors.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.warning.opacity(0.1))
                    )
                }

                GameVotingView(
                    eventGames: event.games,
                    myVotes: viewModel.myGameVotes,
                    isHost: viewModel.isOwner,
                    confirmedGameId: event.confirmedGameId,
                    onVote: { gameId, voteType in
                        await viewModel.voteForGame(gameId: gameId, voteType: voteType)
                    },
                    onConfirm: viewModel.isOwner ? { gameId in
                        await viewModel.confirmGame(gameId: gameId)
                    } : nil
                )
            }
        } else if !event.games.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if event.minPlayers > 0 {
                    HStack {
                        Spacer()
                        PlayerCountIndicator(
                            confirmedCount: viewModel.inviteSummary.accepted,
                            minPlayers: event.minPlayers,
                            maxPlayers: event.maxPlayers
                        )
                    }
                }

                if let primaryGame = event.games.first(where: { $0.isPrimary }) ?? event.games.first,
                   let game = primaryGame.game {
                    let otherEventGames = event.games.filter { $0.id != primaryGame.id }
                    PrimaryGameCard(game: game, eventGame: primaryGame, otherGames: otherEventGames)
                }
            }
        }
    }

    // MARK: - Schedule Section

    @ViewBuilder
    private func scheduleSection(_ event: GameEvent) -> some View {
        if event.scheduleMode == .poll && event.timeOptions.count > 1 {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "When")

                if let myInvite = viewModel.myInvite, myInvite.status == .pending {
                    Text("Vote on the times that work for you:")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textSecondary)

                    PollVotingView(
                        timeOptions: event.timeOptions,
                        votes: $pollVotes
                    )

                    if event.allowTimeSuggestions {
                        Button {
                            showTimeSuggestion = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Suggest another time")
                            }
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(Theme.Colors.accent)
                        }
                    }
                } else {
                    TimeOptionPicker(
                        timeOptions: event.timeOptions,
                        selectedIds: $selectedTimeIds,
                        allowMultiple: false,
                        showVoteCounts: true
                    )
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Helpers

    private func buildTimeVotes(for event: GameEvent) -> [TimeOptionVote] {
        if event.scheduleMode == .poll && event.timeOptions.count > 1 {
            return pollVotes.map { TimeOptionVote(timeOptionId: $0.key, voteType: $0.value) }
        } else {
            return selectedTimeIds.map { TimeOptionVote(timeOptionId: $0, voteType: .yes) }
        }
    }

    private var guestListVisibilityMode: GuestListVisibilityMode {
        guard viewModel.accessPolicy?.canViewGuestList ?? true else {
            return .countsOnly(message: "RSVP to see who's going.")
        }
        if viewModel.isOwner || viewModel.hasRSVPd {
            return .fullList
        }
        return .countsOnly(message: "RSVP to see who's going.")
    }

    private func locationPresentation(for event: GameEvent) -> EventLocationPresentation? {
        guard event.location != nil || event.locationAddress != nil else { return nil }
        return EventLocationPresentation(
            locationName: event.location,
            locationAddress: event.locationAddress,
            canViewFullAddress: viewModel.accessPolicy?.canViewFullAddress ?? true
        )
    }

    private func calendarTimeOption(for event: GameEvent) -> TimeOption? {
        if let confirmedId = event.confirmedTimeOptionId,
           let confirmed = event.timeOptions.first(where: { $0.id == confirmedId }) {
            return confirmed
        }
        if event.scheduleMode == .fixed, let first = event.timeOptions.first {
            return first
        }
        return nil
    }

}

// MARK: - Supporting Types

enum EventEditToastFactory {
    static func makeSuccessToast(for event: GameEvent) -> ToastItem {
        ToastItem(style: .success, message: "Saved changes to \(event.title)")
    }
}

struct EventEditSavePresentation {
    private var pendingSavedEvent: GameEvent?

    mutating func register(_ event: GameEvent) {
        pendingSavedEvent = event
    }

    mutating func consumeIfSheetDismissed(isSheetPresented: Bool) -> GameEvent? {
        guard !isSheetPresented else {
            return nil
        }

        let event = pendingSavedEvent
        pendingSavedEvent = nil
        return event
    }
}

// MARK: - Event Hero Header (overlay layout with gradient scrim)

struct EventHeroHeader: View {
    let event: GameEvent
    var locationPresentation: EventLocationPresentation? = nil
    var calendarTimeOption: TimeOption? = nil
    var myInvite: Invite? = nil
    var rsvpDeadline: Date? = nil
    var onRSVPTap: (() -> Void)? = nil
    private let heroHeight: CGFloat = 340

    @Environment(\.openURL) private var openURL
    @State private var showMapPicker = false

    private var coverImageURL: URL? {
        guard let urlString = event.preferredCoverImageURLString else { return nil }
        return URL(string: urlString)
    }

    private var firstTimeOption: TimeOption? {
        event.timeOptions.first
    }

    private var relativeTimeLabel: String {
        guard let timeOption = firstTimeOption else { return "" }
        return timeOption.relativeTimeDisplay
    }

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let stretchHeight = minY > 0 ? heroHeight + minY : heroHeight

            ZStack(alignment: .bottomLeading) {
                // Cover image
                coverBackground
                    .frame(width: geo.size.width, height: stretchHeight)
                    .clipped()

                // Subtle base tint for light covers
                Color.black.opacity(0.08)

                // Multi-stop gradient scrim (lighter than before)
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.0), location: 0.0),
                    .init(color: .black.opacity(0.10), location: 0.35),
                    .init(color: .black.opacity(0.42), location: 0.7),
                    .init(color: .black.opacity(0.62), location: 1.0),
                ], startPoint: .top, endPoint: .bottom)

                // Content overlay
                VStack(spacing: Theme.Spacing.md) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(event.title)
                                .font(Theme.Typography.displayMedium.weight(.bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                            // Location row with full address
                            if let locationPresentation {
                                heroLocationRow(locationPresentation)
                            }

                            // Host row
                            if let host = event.host {
                                HStack(spacing: Theme.Spacing.sm) {
                                    AvatarView(url: host.avatarUrl, size: 20)
                                    Text("Hosted by \(host.displayName)")
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(.white.opacity(0.88))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(Color.black.opacity(0.22))
                                )
                            }
                        }

                        Spacer()

                        // Date badge + calendar button
                        if let timeOption = firstTimeOption {
                            VStack(spacing: Theme.Spacing.xs) {
                                DateBadge(
                                    date: timeOption.date,
                                    timeString: timeOption.displayTime,
                                    relativeTime: relativeTimeLabel
                                )

                                if let calendarTimeOption {
                                    CompactCalendarButton(
                                        title: event.title,
                                        startDate: calendarTimeOption.startTime,
                                        endDate: calendarTimeOption.endTime,
                                        location: event.locationAddress ?? event.location,
                                        notes: event.description,
                                        games: event.games,
                                        hostName: event.host?.displayName
                                    )
                                }
                            }
                        }
                    }

                    // RSVP row in overlay
                    if let myInvite, let onRSVPTap {
                        heroRSVPRow(invite: myInvite, onTap: onRSVPTap)
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .offset(y: minY > 0 ? -minY : 0)
        }
        .frame(height: heroHeight)
    }

    // MARK: - RSVP Row (in overlay)
    @ViewBuilder
    private func heroRSVPRow(invite: Invite, onTap: @escaping () -> Void) -> some View {
        let isPending = invite.status == .pending
        Button(action: onTap) {
            VStack(spacing: 2) {
                HStack(spacing: Theme.Spacing.sm) {
                    if isPending {
                        Image(systemName: "envelope.open.fill")
                            .font(.system(size: 14))
                        Text("RSVP")
                            .font(Theme.Typography.bodyMedium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    } else {
                        Image(systemName: invite.status.icon)
                            .font(.system(size: 14))
                        Text(invite.status.rsvpDisplayLabel)
                            .font(Theme.Typography.bodyMedium)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .foregroundColor(.white)

                if let rsvpDeadline {
                    Text(RSVPDeadlineDisplay.label(for: rsvpDeadline))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Color.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func heroLocationRow(_ presentation: EventLocationPresentation) -> some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                Text(presentation.title)
                    .font(Theme.Typography.callout)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                if presentation.mapsURL != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Full address underneath
            if let subtitle = presentation.subtitle {
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .padding(.leading, 21) // align with text after pin icon
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.22))
        )

        if presentation.mapsURL != nil {
            Button {
                showMapPicker = true
            } label: {
                content
            }
            .buttonStyle(.plain)
            .confirmationDialog("Open in", isPresented: $showMapPicker, titleVisibility: .visible) {
                if let url = presentation.mapsURL {
                    Button("Apple Maps") { openURL(url) }
                }
                if let url = presentation.googleMapsURL {
                    Button("Google Maps") { openURL(url) }
                }
                if let url = presentation.wazeURL {
                    Button("Waze") { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            }
        } else {
            content
        }
    }

    @ViewBuilder
    private var coverBackground: some View {
        if let coverImageURL {
            AsyncImage(url: coverImageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                GenerativeEventCover(title: event.title, eventId: event.id, variant: event.coverVariant)
            }
        } else {
            GenerativeEventCover(title: event.title, eventId: event.id, variant: event.coverVariant)
        }
    }
}

// MARK: - Date Badge

struct DateBadge: View {
    let date: Date
    var timeString: String? = nil
    var relativeTime: String? = nil

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var month: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            VStack(spacing: 1) {
                Text(dayOfWeek)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.dateAccent)
                Text(dayNumber)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(month)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(width: 58)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(ThemeManager.shared.isDark ? 0.1 : 0.05), radius: 4, y: 2)
            )

            if let timeString {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(timeString)
                        .font(.system(size: 14, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .padding(.top, 2)
            }

            if let relativeTime, !relativeTime.isEmpty {
                Text(relativeTime.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.Colors.dateAccent))
            }
        }
    }
}

// MARK: - Primary Game Card with Pills

struct PrimaryGameCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let game: Game
    let eventGame: EventGame
    var otherGames: [EventGame] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "dice.fill")
                Text("We are playing")
            }
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(Theme.Colors.accent)
            .textCase(.uppercase)

            NavigationLink(value: game) {
                HStack(spacing: Theme.Spacing.md) {
                    // Thumbnail
                    if let url = game.thumbnailUrl, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .fill(Theme.Colors.backgroundElevated)
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
                    } else {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.backgroundElevated)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "dice.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Theme.Colors.textTertiary)
                            )
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(game.name)
                            .font(Theme.Typography.titleLarge.weight(.bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.Colors.gameHighlight)
                            )

                        // Pills
                        HStack(spacing: 6) {
                            GamePill(icon: "clock", text: game.playtimeDisplay, color: Theme.Colors.textSecondary)
                            if game.complexity > 0 {
                                GamePill(
                                    icon: "brain",
                                    text: String(format: "%.1f/5", game.complexity),
                                    color: Theme.Colors.complexity(game.complexity)
                                )
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if !otherGames.isEmpty {
                Divider().background(Theme.Colors.divider)
                HStack {
                    Text("Also playing")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .padding(.trailing, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.md) {
                            ForEach(otherGames) { eGame in
                                if let oGame = eGame.game {
                                    NavigationLink(value: oGame) {
                                        HStack(spacing: 4) {
                                            if let url = oGame.thumbnailUrl, let imageUrl = URL(string: url) {
                                                AsyncImage(url: imageUrl) { image in
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Color.clear
                                                }
                                                .frame(width: 20, height: 20)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                            } else {
                                                Image(systemName: "dice")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Theme.Colors.textTertiary)
                                            }
                                            Text(oGame.name)
                                                .font(Theme.Typography.caption.weight(.bold))
                                                .foregroundColor(Theme.Colors.textSecondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(Theme.Colors.gameHighlight)
                                                )
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Theme.Colors.accent.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Game Info Pill

struct GamePill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(color.opacity(0.12))
        )
    }
}

// MARK: - Guest Count Badge

struct GuestCountBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(Theme.Typography.headlineLarge)
                .foregroundColor(color)
            Text(label)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Invite List Sheet (kept for backward compatibility)

struct InviteListSheet: View {
    let invites: [Invite]
    let summary: InviteSummary
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    if !summary.acceptedUsers.isEmpty {
                        InviteSection(title: "Going", users: summary.acceptedUsers, color: Theme.Colors.success)
                    }
                    if !summary.pendingUsers.isEmpty {
                        InviteSection(title: "Pending", users: summary.pendingUsers, color: Theme.Colors.warning)
                    }
                    if !summary.waitlistedUsers.isEmpty {
                        InviteSection(title: "Waitlist", users: summary.waitlistedUsers, color: Theme.Colors.accent)
                    }
                    if !summary.declinedUsers.isEmpty {
                        InviteSection(title: "Can't Go", users: summary.declinedUsers, color: Theme.Colors.error)
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Guest List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }
}

struct InviteSection: View {
    let title: String
    let users: [InviteSummary.InviteUser]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                StatusDot(color: color)
                Text("\(title) (\(users.count))")
                    .font(Theme.Typography.headlineMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            ForEach(users) { user in
                HStack(spacing: Theme.Spacing.md) {
                    AvatarView(url: user.avatarUrl, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        if user.tier > 1 {
                            Text("Tier \(user.tier)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    Spacer()
                    InviteStatusBadge(status: user.status)
                }
            }
        }
    }
}
