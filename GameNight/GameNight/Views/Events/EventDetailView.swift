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
    @State private var toast: ToastItem?
    @State private var editSavePresentation = EventEditSavePresentation()

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
                        // Hero Header with date badge
                        EventHeroHeader(
                            event: event,
                            locationPresentation: locationPresentation(for: event)
                        )

                        VStack(spacing: Theme.Spacing.xxl) {
                            // RSVP Section (prominent, right after hero)
                            if let myInvite = viewModel.myInvite, myInvite.status == .pending {
                                RSVPSection(
                                    deadlineText: rsvpDeadlineText(for: event),
                                    onAccept: {
                                        let votes = buildTimeVotes(for: event)
                                        await viewModel.respondToInvite(
                                            status: .accepted,
                                            timeVotes: votes,
                                            suggestedTimes: nil
                                        )
                                    },
                                    onDecline: {
                                        await viewModel.respondToInvite(
                                            status: .declined,
                                            timeVotes: [],
                                            suggestedTimes: nil
                                        )
                                    },
                                    onMaybe: {
                                        let votes = buildTimeVotes(for: event)
                                        await viewModel.respondToInvite(
                                            status: .maybe,
                                            timeVotes: votes,
                                            suggestedTimes: nil
                                        )
                                    },
                                    isSending: viewModel.isSending
                                )
                            } else if let myInvite = viewModel.myInvite {
                                VStack(spacing: Theme.Spacing.xs) {
                                    HStack {
                                        Image(systemName: myInvite.status.icon)
                                        Text("You're \(myInvite.status.displayLabel.lowercased())")
                                            .font(Theme.Typography.bodyMedium)
                                    }
                                    .foregroundColor(myInvite.status.color)

                                    if let deadlineText = rsvpDeadlineText(for: event) {
                                        Text(deadlineText)
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textTertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(Theme.Spacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                        .fill(myInvite.status.color.opacity(0.1))
                                )
                            }

                            // Unified Games Section
                            if event.allowGameVoting && event.games.count > 1 {
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
                            } else if !event.games.isEmpty {
                                if let primaryGame = event.games.first(where: { $0.isPrimary }) ?? event.games.first,
                                   let game = primaryGame.game {
                                    let otherEventGames = event.games.filter { $0.id != primaryGame.id }
                                    PrimaryGameCard(game: game, eventGame: primaryGame, otherGames: otherEventGames)
                                }
                            }

                            // Player Count Indicator
                            if event.minPlayers > 0 {
                                PlayerCountIndicator(
                                    confirmedCount: viewModel.inviteSummary.accepted,
                                    minPlayers: event.minPlayers,
                                    maxPlayers: event.maxPlayers
                                )
                            }

                            // Schedule Section (poll mode or add-to-calendar)
                            if event.scheduleMode == .poll && event.timeOptions.count > 1 {
                                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                    SectionHeader(title: "Schedule Poll")

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

                            // Add to Calendar
                            if let timeOption = calendarTimeOption(for: event) {
                                AddToCalendarButton(
                                    title: event.title,
                                    startDate: timeOption.startTime,
                                    endDate: timeOption.endTime,
                                    location: event.locationAddress ?? event.location,
                                    notes: event.description,
                                    games: event.games,
                                    hostName: event.host?.displayName
                                )
                            }

                            // Guest List Tabs (inline, swipeable)
                            GuestListTabsView(
                                summary: viewModel.inviteSummary,
                                visibilityMode: guestListVisibilityMode,
                                actionTitle: viewModel.canInviteGuests ? "Invite" : nil,
                                onAction: viewModel.canInviteGuests ? {
                                    showInviteContacts = true
                                } : nil
                            )

                            // Activity Feed
                            ActivityFeedView(viewModel: viewModel, isHost: viewModel.isOwner)

                            // Description
                            if let desc = event.description, !desc.isEmpty {
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    SectionHeader(title: "Details")
                                    Text(desc)
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                                .cardStyle()
                            }
                        }
                        .padding(Theme.Spacing.xl)
                    }
                    .padding(.bottom, 100)
                }
            }
            .disabled(viewModel.isDeleting)

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
        .toast($toast)
        .task {
            await viewModel.loadEvent(id: eventId)
        }
    }

    private func buildTimeVotes(for event: GameEvent) -> [TimeOptionVote] {
        if event.scheduleMode == .poll && event.timeOptions.count > 1 {
            return pollVotes.map { TimeOptionVote(timeOptionId: $0.key, voteType: $0.value) }
        } else {
            return selectedTimeIds.map { TimeOptionVote(timeOptionId: $0, voteType: .yes) }
        }
    }


    private var guestListVisibilityMode: GuestListVisibilityMode {
        if viewModel.accessPolicy?.canViewGuestList ?? true {
            return .fullList
        }

        return .countsOnly(message: "Guest names unlock after you RSVP.")
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

    private func rsvpDeadlineText(for event: GameEvent) -> String? {
        guard let deadline = event.rsvpDeadline else { return nil }
        return RSVPDeadlineDisplay.label(for: deadline)
    }
}

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

// MARK: - Event Hero Header (redesigned with date badge)
struct EventHeroHeader: View {
    let event: GameEvent
    let locationPresentation: EventLocationPresentation?
    @Environment(\.openURL) private var openURL
    @State private var showMapPicker = false

    private var firstTimeOption: TimeOption? {
        event.timeOptions.first
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Clean background — flows naturally from page
            Theme.Colors.background
                .frame(height: 240)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    // Title
                    Text(event.title)
                        .font(Theme.Typography.displayMedium)
                        .foregroundColor(Theme.Colors.textPrimary)

                    // Status Pill
                    HStack(spacing: Theme.Spacing.md) {
                        Text(event.status.rawValue.capitalized)
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.primaryLight)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.Colors.primary.opacity(0.2)))
                    }

                    // Location line (simplified)
                    if let locationPresentation {
                        locationRow(locationPresentation)
                        .padding(.top, 4)
                    }

                    if let host = event.host {
                        HStack(spacing: 8) {
                            AvatarView(url: host.avatarUrl, size: 24)
                            Text("Hosted by \(host.displayName)")
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                }

                Spacer()

                if let timeOption = firstTimeOption {
                    DateBadge(
                        date: timeOption.date,
                        timeString: timeOption.displayTime,
                        relativeTime: timeOption.relativeTimeDisplay
                    )
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }

    @ViewBuilder
    private func locationRow(_ locationPresentation: EventLocationPresentation) -> some View {
        let content = HStack(alignment: .top, spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.textTertiary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(locationPresentation.title)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(1)
                if let subtitle = locationPresentation.subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            if locationPresentation.mapsURL != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
                    .padding(.top, 3)
            }
        }

        if locationPresentation.mapsURL != nil {
            Button {
                showMapPicker = true
            } label: {
                content
            }
            .buttonStyle(.plain)
            .confirmationDialog("Open in", isPresented: $showMapPicker, titleVisibility: .visible) {
                if let url = locationPresentation.mapsURL {
                    Button("Apple Maps") { openURL(url) }
                }
                if let url = locationPresentation.googleMapsURL {
                    Button("Google Maps") { openURL(url) }
                }
                if let url = locationPresentation.wazeURL {
                    Button("Waze") { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            }
        } else {
            content
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
                .foregroundColor(Theme.Colors.textPrimary)
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
                            .font(Theme.Typography.titleLarge)
                            .foregroundColor(Theme.Colors.textPrimary)

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
                                                .font(Theme.Typography.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
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

// MARK: - RSVP Section
struct RSVPSection: View {
    var deadlineText: String? = nil
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    let onMaybe: () async -> Void
    var isSending: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let deadlineText {
                Text(deadlineText)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

            Text("Are you in?")
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)

            if isSending {
                ProgressView()
                    .tint(Theme.Colors.primary)
            } else {
                Button("I'm Going!") {
                    Task { await onAccept() }
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack(spacing: Theme.Spacing.md) {
                    Button("Maybe") {
                        Task { await onMaybe() }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Can't Go") {
                        Task { await onDecline() }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .cardStyle()
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
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
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
