import SwiftUI

struct EventDetailView: View {
    let eventId: UUID
    @StateObject private var viewModel = EventViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeIds = Set<UUID>()
    @State private var pollVotes: [UUID: TimeOptionVoteType] = [:]
    @State private var showTimeSuggestion = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showCreateGroupFromEvent = false
    @State private var toast: ToastItem?
    @State private var editSavePresentation = EventEditSavePresentation()

    private var isOwner: Bool {
        guard let event = viewModel.event else { return false }
        return appState.currentUser?.id == event.hostId
    }

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
                        EventHeroHeader(event: event)

                        VStack(spacing: Theme.Spacing.xxl) {
                            // RSVP Section (prominent, right after hero)
                            if let myInvite = viewModel.myInvite, myInvite.status == .pending {
                                RSVPSection(
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
                                HStack {
                                    Image(systemName: myInvite.status.icon)
                                    Text("You're \(myInvite.status.displayLabel.lowercased())")
                                        .font(Theme.Typography.bodyMedium)
                                }
                                .foregroundColor(statusColor(myInvite.status))
                                .frame(maxWidth: .infinity)
                                .padding(Theme.Spacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                        .fill(statusColor(myInvite.status).opacity(0.1))
                                )
                            }

                            // Primary Game Card with pills
                            if let primaryGame = event.games.first(where: { $0.isPrimary }),
                               let game = primaryGame.game {
                                PrimaryGameCard(game: game, eventGame: primaryGame)
                            }

                            // Player Count Indicator
                            if event.minPlayers > 0 {
                                PlayerCountIndicator(
                                    confirmedCount: viewModel.inviteSummary.accepted,
                                    minPlayers: event.minPlayers,
                                    maxPlayers: event.maxPlayers
                                )
                            }

                            // Game Voting (if enabled)
                            if event.allowGameVoting && !event.games.isEmpty {
                                GameVotingView(
                                    eventGames: event.games,
                                    myVotes: viewModel.myGameVotes,
                                    isHost: isOwner,
                                    confirmedGameId: event.confirmedGameId,
                                    onVote: { gameId, voteType in
                                        await viewModel.voteForGame(gameId: gameId, voteType: voteType)
                                    },
                                    onConfirm: isOwner ? { gameId in
                                        await viewModel.confirmGame(gameId: gameId)
                                    } : nil
                                )
                            }

                            // Other games (non-primary)
                            let otherGames = event.games.filter { !$0.isPrimary }
                            if !otherGames.isEmpty {
                                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                    SectionHeader(title: "Other Games")
                                    ForEach(otherGames) { eventGame in
                                        if let game = eventGame.game {
                                            CompactGameCard(game: game, isPrimary: false)
                                        }
                                    }
                                }
                                .cardStyle()
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

                            // Guest List Tabs (inline, swipeable)
                            GuestListTabsView(summary: viewModel.inviteSummary)

                            // Activity Feed
                            ActivityFeedView(viewModel: viewModel, isHost: isOwner)

                            // Location
                            if let location = event.location {
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    SectionHeader(title: "Location")

                                    HStack(spacing: Theme.Spacing.md) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                                .fill(Theme.Colors.secondary.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Theme.Colors.secondary)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(location)
                                                .font(Theme.Typography.bodyMedium)
                                                .foregroundColor(Theme.Colors.textPrimary)
                                            if let address = event.locationAddress {
                                                Text(address)
                                                    .font(Theme.Typography.caption)
                                                    .foregroundColor(Theme.Colors.textTertiary)
                                            }
                                        }
                                    }
                                }
                                .cardStyle()
                            }

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
                Color.black.opacity(0.2)
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
            if isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit Event") {
                            showEditSheet = true
                        }

                        Button {
                            showCreateGroupFromEvent = true
                        } label: {
                            Label("Create Group from Guests", systemImage: "person.3.fill")
                        }

                        Button("Delete Event", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showTimeSuggestion) {
            TimeSuggestionSheet { option in
                // Handle time suggestion
            }
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

    private func statusColor(_ status: InviteStatus) -> Color {
        switch status {
        case .accepted: return Theme.Colors.success
        case .declined: return Theme.Colors.error
        case .maybe: return Theme.Colors.warning
        case .pending: return Theme.Colors.textTertiary
        case .expired: return Theme.Colors.textTertiary
        case .waitlisted: return Theme.Colors.accent
        }
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

    private var firstTimeOption: TimeOption? {
        event.timeOptions.first
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                colors: [
                    Theme.Colors.cardBackgroundHover,
                    Theme.Colors.cardBackground,
                    Theme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 240)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    // Title + Date/Time Row
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Text(event.title)
                            .font(Theme.Typography.displayMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        if let timeOption = firstTimeOption {
                            Text("•")
                                .foregroundColor(Theme.Colors.textTertiary)
                            Text("\(timeOption.displayDate) • \(timeOption.startTime, style: .time)")
                                .font(Theme.Typography.headlineMedium)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    // Relative Time + Status Pill Row
                    HStack(spacing: Theme.Spacing.md) {
                        if let timeOption = firstTimeOption {
                            Text(timeOption.relativeTimeDisplay)
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.accent)
                        }
                        
                        Text(event.status.rawValue.capitalized)
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.primaryLight)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.Colors.primary.opacity(0.2)))
                    }

                    // Location line (simplified)
                    if let location = event.location {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.textTertiary)
                            Text(location)
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
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

                // Date badge (top-right) - Hidden for A/B testing
                /*
                if let timeOption = firstTimeOption {
                    DateBadge(date: timeOption.date)
                }
                */
            }
            .padding(Theme.Spacing.xl)
        }
    }
}

// MARK: - Date Badge
struct DateBadge: View {
    let date: Date

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
        VStack(spacing: 1) {
            Text(dayOfWeek)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.Colors.error)
            Text(dayNumber)
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(month)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(width: 52)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
        )
    }
}

// MARK: - Primary Game Card with Pills
struct PrimaryGameCard: View {
    let game: Game
    let eventGame: EventGame

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Thumbnail
            if let url = game.thumbnailUrl, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .fill(Theme.Colors.backgroundElevated)
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
            } else {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Theme.Colors.backgroundElevated)
                    .frame(width: 52, height: 52)
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
                    GamePill(icon: "star.fill", text: "Primary", color: Theme.Colors.warning)
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
        }
        .cardStyle()
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
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    let onMaybe: () async -> Void
    var isSending: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
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
