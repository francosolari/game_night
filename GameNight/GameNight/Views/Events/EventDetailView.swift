import SwiftUI

struct EventDetailView: View {
    let eventId: UUID
    @StateObject private var viewModel = EventViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var pollVotes: [UUID: TimeOptionVoteType] = [:]
    @State private var showTimeSuggestion = false
    @State private var showInviteContacts = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showCreateGroupFromEvent = false
    @State private var showGuestListFullPage = false
    @State private var editSavePresentation = EventEditSavePresentation()
    @State private var heroStretchOffset: CGFloat = 0
    @State private var showRSVPSheet = false
    @State private var showInviteLinkSheet = false
    @State private var pendingLinkInvites: [Invite] = []
    @State private var showPlayLogging = false
    @State private var eventPlays: [Play] = []
    @State private var selectedPlay: Play?

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
                } else if viewModel.isNotFound {
                    EventNotFoundView()
                } else if let event = viewModel.event {
                    VStack(spacing: 0) {
                        // 1. Hero cover with overlay (title, RSVP, location, host, date badge)
                        EventHeroHeader(
                            event: event,
                            locationPresentation: locationPresentation(for: event),
                            calendarTimeOption: calendarTimeOption(for: event),
                            myInvite: viewModel.myInvite,
                            rsvpDeadline: event.rsvpDeadline,
                            confirmedCount: viewModel.inviteSummary.accepted,
                            minPlayers: event.minPlayers,
                            maxPlayers: event.maxPlayers,
                            hasPollsActive: viewModel.hasPollsActive,
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

                            // 4. Guest List / Poll Guest List
                            if viewModel.hasDatePollPending {
                                PollGuestListView(
                                    timeOptions: event.timeOptions,
                                    voters: viewModel.timeOptionVoters,
                                    isHost: viewModel.isOwner,
                                    pollVotes: pollVotes,
                                    canVoteDirectly: viewModel.canEditPollVotesDirectly,
                                    onVote: { optionId, voteType in
                                        pollVotes[optionId] = voteType
                                        await viewModel.voteOnTimeOption(optionId: optionId, voteType: voteType)
                                        await refreshSharedData()
                                    },
                                    onRequireRSVP: {
                                        showRSVPSheet = true
                                    },
                                    onConfirmTime: viewModel.isOwner ? { timeOptionId in
                                        await viewModel.confirmTimeOption(timeOptionId: timeOptionId)
                                        await refreshSharedData()
                                    } : nil
                                )
                            } else {
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
                            }

                            // 5. Play Logging (completed events)
                            if event.status == .completed {
                                playLoggingSection(event)
                            }

                            // 7. Activity Feed
                            ActivityFeedView(viewModel: viewModel, isHost: viewModel.isOwner)
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.top, Theme.Spacing.xl)
                    }
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await viewModel.refreshEventData(eventId: eventId)
                pollVotes = viewModel.myPollVotes
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
            // Share button — visible when user has invite permissions
            if let shareToken = viewModel.event?.shareToken,
               viewModel.isOwner || viewModel.canInviteGuests {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(
                        item: URL(string: "https://cardboardwithme.com/event/\(shareToken)")!,
                        message: Text("Join me for \(viewModel.event?.title ?? "Game Night")!")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }

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
                    Task { await handleInviteContacts(contacts) }
                }
            )
        }
        .sheet(isPresented: $showInviteLinkSheet) {
            InviteLinkSheet(invites: pendingLinkInvites)
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
            viewModel.toast = EventEditToastFactory.makeSuccessToast(for: savedEvent)
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
                        Task {
                            await refreshSharedData()
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .alert("Something went wrong", isPresented: deleteErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "Please try again.")
        }
        .sheet(isPresented: $showCreateGroupFromEvent) {
                CreateGroupFromAttendeesSheet(invites: viewModel.invites, onResult: { resultToast in
                    viewModel.toast = resultToast
                })
            }
        .sheet(isPresented: $showRSVPSheet) {
            if let event = viewModel.event {
                RSVPSheet(
                    event: event,
                    currentStatus: viewModel.myInvite?.status,
                    isSending: viewModel.isSending,
                    pollVotes: $pollVotes,
                    onSubmit: { status, votes in
                        await viewModel.respondToInvite(
                            status: status,
                            timeVotes: votes,
                            suggestedTimes: nil
                        )
                        await refreshSharedData()
                        let message = status == .accepted ? "You're going!" : status == .maybe ? "Maybe next time!" : "RSVP updated"
                        viewModel.toast = ToastItem(style: .success, message: message)
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
        .sheet(isPresented: $showPlayLogging) {
            if let event = viewModel.event {
                PlayLoggingSheet(event: event, invites: viewModel.invites)
            }
        }
        .onChange(of: showPlayLogging) { _, isPresented in
            if !isPresented {
                Task { await loadEventPlays() }
            }
        }
        .navigationDestination(item: $selectedPlay) { play in
            PlayDetailView(
                play: play,
                currentUserId: SupabaseService.shared.client.auth.currentSession?.user.id
            ) {
                try? await SupabaseService.shared.deletePlay(id: play.id)
                await loadEventPlays()
            }
        }
        .toast($viewModel.toast)
        .task {
            await viewModel.loadEvent(id: eventId)
            pollVotes = viewModel.myPollVotes
            await loadEventPlays()
        }
    }

    private func loadEventPlays() async {
        guard let event = viewModel.event, event.status == .completed else { return }
        eventPlays = (try? await SupabaseService.shared.fetchPlaysForEvent(eventId: eventId)) ?? []
    }

    // MARK: - Play Logging Section

    @ViewBuilder
    private func playLoggingSection(_ event: GameEvent) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "What did you play?")

            if !eventPlays.isEmpty {
                ForEach(eventPlays) { play in
                    PlayCard(play: play) {
                        selectedPlay = play
                    }
                }
            }

            Button {
                showPlayLogging = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: eventPlays.isEmpty ? "trophy" : "plus.circle")
                        .font(.system(size: 14))
                    Text(eventPlays.isEmpty ? "Log Plays" : "Log Another")
                        .font(Theme.Typography.calloutMedium)
                }
                .foregroundColor(Theme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.primary.opacity(0.1))
                )
            }
        }
        .cardStyle()
    }

    // MARK: - Games Section

    @ViewBuilder
    private func gamesSection(_ event: GameEvent) -> some View {
        if event.allowGameVoting && event.games.count > 1 {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "What We're Playing")

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
                    voterDetails: viewModel.gameVoterDetails,
                    onVote: { gameId, voteType in
                        await viewModel.voteForGame(gameId: gameId, voteType: voteType)
                        await refreshSharedData()
                    },
                    onConfirm: viewModel.isOwner ? { gameId in
                        await viewModel.confirmGame(gameId: gameId)
                        await refreshSharedData()
                    } : nil
                )
            }
        } else if !event.games.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let primaryGame = event.games.first(where: { $0.isPrimary }) ?? event.games.first,
                   let game = primaryGame.game {
                    let otherEventGames = event.games.filter { $0.id != primaryGame.id }
                    PrimaryGameCard(game: game, eventGame: primaryGame, otherGames: otherEventGames)
                }
            }
        }
    }

    // MARK: - Helpers

    private var guestListVisibilityMode: GuestListVisibilityMode {
        guard viewModel.accessPolicy?.canViewGuestList ?? true else {
            return .countsWithBlocker(message: "RSVP to see who's going.")
        }
        if viewModel.isOwner || viewModel.hasRSVPd {
            return .fullList
        }
        return .countsWithBlocker(message: "RSVP to see who's going.")
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

    private func handleInviteContacts(_ contacts: [UserContact]) async {
        await viewModel.inviteContacts(contacts)
        await refreshSharedData()
        // Check if any app-connection contacts were invited — show their links
        let appConnectionContacts = contacts.filter { $0.source == .appConnection && $0.isAppUser }
        if !appConnectionContacts.isEmpty {
            let appConnectionPhones = Set(appConnectionContacts.map { PhoneNumberFormatter.normalizedForComparison($0.phoneNumber) })
            pendingLinkInvites = viewModel.invites.filter { invite in
                let normalizedPhone = PhoneNumberFormatter.normalizedForComparison(invite.phoneNumber)
                return appConnectionPhones.contains(normalizedPhone) && invite.inviteToken != nil
            }
            if !pendingLinkInvites.isEmpty {
                showInviteLinkSheet = true
            }
        }
        let count = contacts.count
        viewModel.toast = ToastItem(style: .success, message: "\(count) invite\(count == 1 ? "" : "s") sent!")
    }

    private func refreshSharedData() async {
        await appState.refresh([.home, .groups])
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
    var confirmedCount: Int = 0
    var minPlayers: Int = 0
    var maxPlayers: Int? = nil
    var hasPollsActive: Bool = false
    var onRSVPTap: (() -> Void)? = nil
    private let heroHeight: CGFloat = 330

    @Environment(\.openURL) private var openURL
    @State private var showMapPicker = false

    private var coverImageURL: URL? {
        guard let urlString = event.preferredCoverImageURLString else { return nil }
        return URL(string: urlString)
    }

    private var firstTimeOption: TimeOption? {
        event.timeOptions.first
    }

    private var isEventPast: Bool {
        event.hasEnded()
    }

    private var relativeTimeLabel: String {
        guard let timeOption = firstTimeOption else { return "" }
        return timeOption.relativeTimeDisplay
    }

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let stretchHeight = minY > 0 ? heroHeight + minY : heroHeight

            ZStack(alignment: .bottom) {
                // Cover image — full bleed
                coverBackground
                    .frame(width: geo.size.width, height: stretchHeight)
                    .clipped()

                // Frosted material that fades in from mid → bottom
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.35),
                            .init(color: .black.opacity(0.6), location: 0.55),
                            .init(color: .black, location: 0.68),
                        ], startPoint: .top, endPoint: .bottom)
                    )

                // Subtle tint over the material area — warm cream in light, dark in dark
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.55),
                    .init(color: (ThemeManager.shared.isDark
                        ? Color(red: 0.08, green: 0.07, blue: 0.06).opacity(0.4)
                        : Color(red: 0.96, green: 0.94, blue: 0.90).opacity(0.25)
                    ), location: 0.72),
                    .init(color: (ThemeManager.shared.isDark
                        ? Color(red: 0.08, green: 0.07, blue: 0.06).opacity(0.55)
                        : Color(red: 0.96, green: 0.94, blue: 0.90).opacity(0.35)
                    ), location: 1.0),
                ], startPoint: .top, endPoint: .bottom)

                // Content — dense, no wasted vertical space
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(event.title)
                        .font(Theme.Typography.displayMedium.weight(.bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .shadow(color: ThemeManager.shared.isDark ? .black.opacity(0.6) : .white.opacity(0.5), radius: 8, y: 0)

                    // Date/time line
                    if let timeOption = firstTimeOption {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.dateAccent)

                            heroDateTimeText(for: timeOption)

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

                    // Location
                    if let locationPresentation {
                        heroLocationRow(locationPresentation)
                    }

                    // Host
                    if let host = event.host {
                        HStack(spacing: 6) {
                            AvatarView(url: host.avatarUrl, size: 18)
                            Text("Hosted by \(host.displayName)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    // RSVP + player count — immediately after details
                    if myInvite != nil || minPlayers > 0 {
                        Divider()
                            .background(Theme.Colors.divider)
                            .padding(.top, 2)

                        HStack(spacing: Theme.Spacing.md) {
                            if let myInvite {
                                heroRSVPRow(invite: myInvite, onTap: isEventPast ? nil : onRSVPTap)
                            }

                            Spacer()

                            if minPlayers > 0 {
                                PlayerCountIndicator(
                                    confirmedCount: confirmedCount,
                                    minPlayers: minPlayers,
                                    maxPlayers: maxPlayers
                                )
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .offset(y: minY > 0 ? -minY : 0)
        }
        .frame(height: heroHeight)
    }

    // MARK: - RSVP Row
    @ViewBuilder
    private func heroRSVPRow(invite: Invite, onTap: (() -> Void)?) -> some View {
        if let onTap {
            // Future event — tappable RSVP button
            let isPending = invite.status == .pending
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.sm) {
                        if isPending {
                            Image(systemName: "envelope.open.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.primary)
                            Text(hasPollsActive ? "RSVP & Vote" : "RSVP")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.primary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.Colors.textTertiary)
                        } else {
                            Image(systemName: invite.status.icon)
                                .font(.system(size: 14))
                                .foregroundColor(invite.status.color)
                            Text(invite.status.rsvpDisplayLabel)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }

                    if let rsvpDeadline {
                        Text(RSVPDeadlineDisplay.label(for: rsvpDeadline))
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(Theme.Colors.textTertiary)
                    } else if !isPending && hasPollsActive {
                        Text("View Polls")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            // Past event — static display, no edit affordance
            let wentIcon = invite.status == .accepted ? "checkmark.seal.fill" : invite.status.icon
            let wentLabel = invite.status == .accepted ? "Went" : invite.status.rsvpDisplayLabel
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: wentIcon)
                    .font(.system(size: 14))
                    .foregroundColor(invite.status.color)
                Text(wentLabel)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
        }
    }

    /// Renders "TODAY · 7:00 PM", "TOMORROW · 7:00 PM", or "Thursday, Mar 19 · 7:00 PM"
    @ViewBuilder
    private func heroDateTimeText(for timeOption: TimeOption) -> some View {
        let relative = timeOption.relativeTimeDisplay
        let isUrgent = relative == "Today" || relative == "Tomorrow"

        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f
        }()
        let timeStr = timeFormatter.string(from: timeOption.startTime)

        if isUrgent {
            HStack(spacing: 6) {
                Text(relative.uppercased())
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.dateAccent)
                    )

                Text("·")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Colors.textTertiary)

                Text(timeStr)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(Theme.Colors.dateAccent)
            }
        } else {
            let dateFormatter: DateFormatter = {
                let f = DateFormatter()
                f.dateFormat = "EEEE, MMM d"
                return f
            }()
            let dateStr = dateFormatter.string(from: timeOption.date)

            HStack(spacing: 0) {
                Text(dateStr)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("  ·  ")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textTertiary)

                Text(timeStr)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(Theme.Colors.dateAccent)
            }
        }
    }

    @ViewBuilder
    private func heroLocationRow(_ presentation: EventLocationPresentation) -> some View {
        let content = VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
                Text(presentation.title)
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                if presentation.mapsURL != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }

            if let subtitle = presentation.subtitle {
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .lineLimit(1)
                    .padding(.leading, 19)
            }
        }

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
                    if let url = game.imageUrl ?? game.thumbnailUrl, let imageUrl = URL(string: url) {
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
                                            if let url = oGame.imageUrl ?? oGame.thumbnailUrl, let imageUrl = URL(string: url) {
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
                    if !summary.votedUsers.isEmpty {
                        InviteSection(title: "Voted", users: summary.votedUsers, color: Theme.Colors.accent)
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
            .scrollIndicators(.hidden)
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
