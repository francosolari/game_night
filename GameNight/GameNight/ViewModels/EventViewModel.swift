import SwiftUI
import Combine

@MainActor
final class EventViewModel: ObservableObject {
    @Published var event: GameEvent?
    @Published var invites: [Invite] = []
    @Published var myInvite: Invite?
    @Published var isLoading = false
    @Published var error: String?
    @Published var isSending = false
    @Published var isDeleting = false

    // Activity feed
    @Published var activityFeed: [ActivityFeedItem] = []
    @Published var isPostingComment = false
    @Published var newCommentText = ""

    // Game voting
    @Published var gameVotes: [GameVote] = []
    @Published var myGameVotes: [UUID: GameVoteType] = [:]

    private let supabase = SupabaseService.shared
    private var realtimeChannel: RealtimeChannelV2?
    private var activityChannel: RealtimeChannelV2?
    private var subscribedEventId: UUID?
    private var subscribedActivityEventId: UUID?

    var hasRSVPd: Bool {
        guard let status = myInvite?.status else { return false }
        return status == .accepted || status == .maybe
    }

    var isOwner: Bool {
        guard let event else { return false }
        return event.hostId == SupabaseService.shared.client.auth.currentSession?.user.id
    }

    var canSeeActivityFeed: Bool {
        hasRSVPd || isOwner
    }

    var confirmedPlayerCount: Int {
        inviteSummary.accepted
    }

    var inviteSummary: InviteSummary {
        let accepted = invites.filter { $0.status == .accepted }
        let declined = invites.filter { $0.status == .declined }
        let pending = invites.filter { $0.status == .pending }
        let maybe = invites.filter { $0.status == .maybe }
        let waitlisted = invites.filter { $0.status == .waitlisted }

        func mapUsers(_ list: [Invite]) -> [InviteSummary.InviteUser] {
            list.map { .init(id: $0.id, name: $0.displayName ?? "Unknown", avatarUrl: nil, status: $0.status, tier: $0.tier) }
        }

        return InviteSummary(
            total: invites.count,
            accepted: accepted.count,
            declined: declined.count,
            pending: pending.count,
            maybe: maybe.count,
            waitlisted: waitlisted.count,
            acceptedUsers: mapUsers(accepted),
            pendingUsers: mapUsers(pending),
            maybeUsers: mapUsers(maybe),
            declinedUsers: mapUsers(declined),
            waitlistedUsers: mapUsers(waitlisted)
        )
    }

    func loadEvent(id: UUID) async {
        isLoading = true
        do {
            async let eventResult = supabase.fetchEvent(id: id)
            async let invitesResult = supabase.fetchInvites(eventId: id)

            self.event = try await eventResult
            self.invites = try await invitesResult

            // Find my invite
            let session = try await supabase.client.auth.session
            self.myInvite = invites.first { $0.userId == session.user.id }

            // Load activity feed and game votes
            await loadActivityFeed(eventId: id)
            await loadGameVotes(eventId: id, currentUserId: session.user.id)

            // Subscribe to realtime updates
            if subscribedEventId != id {
                subscribeToUpdates(eventId: id)
                subscribedEventId = id
            }

            if subscribedActivityEventId != id {
                subscribeToActivityFeed(eventId: id)
                subscribedActivityEventId = id
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadActivityFeed(eventId: UUID) async {
        do {
            let items = try await supabase.fetchActivityFeed(eventId: eventId)
            // Group into threads: top-level items with replies attached
            var topLevel: [ActivityFeedItem] = []
            var repliesByParent: [UUID: [ActivityFeedItem]] = [:]

            for item in items {
                if let parentId = item.parentId {
                    repliesByParent[parentId, default: []].append(item)
                } else {
                    topLevel.append(item)
                }
            }

            // Attach replies and sort: pinned first, then chronological
            self.activityFeed = topLevel.map { item in
                var withReplies = item
                withReplies.replies = repliesByParent[item.id]?.sorted { $0.createdAt < $1.createdAt }
                return withReplies
            }.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.createdAt < rhs.createdAt
            }
        } catch {
            // Non-critical: activity feed may not be accessible if not RSVP'd
        }
    }

    func loadGameVotes(eventId: UUID, currentUserId: UUID) async {
        do {
            self.gameVotes = try await supabase.fetchGameVotes(eventId: eventId)
            self.myGameVotes = Dictionary(
                uniqueKeysWithValues: gameVotes
                    .filter { $0.userId == currentUserId }
                    .map { ($0.gameId, $0.voteType) }
            )
        } catch {
            // Non-critical
        }
    }

    func postComment(content: String, parentId: UUID? = nil) async {
        guard let eventId = event?.id else { return }
        isPostingComment = true
        do {
            try await supabase.postComment(eventId: eventId, content: content, parentId: parentId)
            await loadActivityFeed(eventId: eventId)
        } catch {
            self.error = error.localizedDescription
        }
        isPostingComment = false
    }

    func postAnnouncement(content: String) async {
        guard let eventId = event?.id else { return }
        isPostingComment = true
        do {
            try await supabase.postAnnouncement(eventId: eventId, content: content)
            await loadActivityFeed(eventId: eventId)
        } catch {
            self.error = error.localizedDescription
        }
        isPostingComment = false
    }

    func togglePin(itemId: UUID, isPinned: Bool) async {
        guard let eventId = event?.id else { return }
        do {
            try await supabase.togglePinComment(itemId: itemId, isPinned: isPinned)
            await loadActivityFeed(eventId: eventId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func voteForGame(gameId: UUID, voteType: GameVoteType) async {
        guard let eventId = event?.id else { return }
        do {
            // Toggle off if already selected
            if myGameVotes[gameId] == voteType {
                try await supabase.deleteGameVote(eventId: eventId, gameId: gameId)
                myGameVotes.removeValue(forKey: gameId)
            } else {
                try await supabase.upsertGameVote(eventId: eventId, gameId: gameId, voteType: voteType)
                myGameVotes[gameId] = voteType
            }
            // Reload event to get updated vote counts
            if let event = try? await supabase.fetchEvent(id: eventId) {
                self.event = event
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func confirmGame(gameId: UUID) async {
        guard let eventId = event?.id else { return }
        do {
            try await supabase.confirmGame(eventId: eventId, gameId: gameId)
            event?.confirmedGameId = gameId
        } catch {
            self.error = error.localizedDescription
        }
    }

    func respondToInvite(status: InviteStatus, timeVotes: [TimeOptionVote], suggestedTimes: [TimeOption]?) async {
        guard let invite = myInvite else { return }
        isSending = true
        do {
            try await supabase.respondToInvite(
                inviteId: invite.id,
                status: status,
                timeVotes: timeVotes,
                suggestedTimes: suggestedTimes
            )
            myInvite?.status = status
        } catch {
            self.error = error.localizedDescription
        }
        isSending = false
    }

    func deleteEvent() async -> Bool {
        guard let event else { return false }
        error = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await supabase.softDeleteEvent(id: event.id)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func subscribeToUpdates(eventId: UUID) {
        realtimeChannel = supabase.subscribeToEventUpdates(eventId: eventId) { [weak self] updatedEvent in
            Task { @MainActor in
                self?.event = updatedEvent
            }
        }
    }

    private func subscribeToActivityFeed(eventId: UUID) {
        activityChannel = supabase.subscribeToActivityFeed(eventId: eventId) { [weak self] in
            Task { @MainActor in
                await self?.loadActivityFeed(eventId: eventId)
            }
        }
    }

    deinit {
        Task { [realtimeChannel, activityChannel] in
            await realtimeChannel?.unsubscribe()
            await activityChannel?.unsubscribe()
        }
    }
}

// MARK: - Create Event ViewModel
@MainActor
final class CreateEventViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var location = ""
    @Published var locationAddress = ""
    @Published var selectedGames: [EventGame] = []
    @Published var timeOptions: [TimeOption] = []
    @Published var allowTimeSuggestions = true
    @Published var allowGameVoting = false
    @Published var scheduleMode: ScheduleMode = .fixed
    @Published var fixedDate: Date = Date()
    @Published var fixedStartTime: Date = Date()
    @Published var inviteStrategy = InviteStrategy(type: .allAtOnce, tierSize: nil, autoPromote: true)
    @Published var minPlayers = 3
    @Published var maxPlayers: Int? = nil
    @Published var selectedGroup: GameGroup?
    @Published var invitees: [InviteeEntry] = []
    @Published var isSaving = false
    @Published var error: String?
    @Published var createdEvent: GameEvent?
    let eventToEdit: GameEvent?

    // Game search
    @Published var gameSearchQuery = ""
    @Published var gameSearchResults: [BGGSearchResult] = []
    @Published var isSearchingGames = false
    @Published var manualGameName = ""

    // Contacts
    @Published var suggestedContacts: [FrequentContact] = []
    @Published var isLoadingSuggestions = true

    // Group collapse state
    @Published var collapsedGroups: Set<UUID> = []

    // Steps
    @Published var currentStep: CreateStep = .details
    @Published var completedSteps: Set<CreateStep> = []
    enum CreateStep: Int, CaseIterable, Hashable {
        case details = 0
        case games
        case schedule
        case invites
        case review
    }

    private let supabase = SupabaseService.shared
    private let bgg = BGGService.shared

    init(eventToEdit: GameEvent? = nil) {
        self.eventToEdit = eventToEdit

        if let eventToEdit {
            title = eventToEdit.title
            description = eventToEdit.description ?? ""
            location = eventToEdit.location ?? ""
            locationAddress = eventToEdit.locationAddress ?? ""
            selectedGames = eventToEdit.games
            timeOptions = eventToEdit.timeOptions
            allowTimeSuggestions = eventToEdit.allowTimeSuggestions
            allowGameVoting = eventToEdit.allowGameVoting
            inviteStrategy = eventToEdit.inviteStrategy
            minPlayers = eventToEdit.minPlayers
            maxPlayers = eventToEdit.maxPlayers

            if eventToEdit.status == .draft {
                // Resume draft: load draft invitees, start at first incomplete step
                if let draftInvitees = eventToEdit.draftInvitees {
                    invitees = draftInvitees.map { draft in
                        InviteeEntry(
                            id: draft.id,
                            name: draft.name,
                            phoneNumber: draft.phoneNumber,
                            userId: draft.userId,
                            tier: draft.tier,
                            groupId: draft.groupId,
                            groupEmoji: draft.groupEmoji
                        )
                    }
                }
                // Mark steps that have data as completed
                if !title.isEmpty { completedSteps.insert(.details) }
                if !selectedGames.isEmpty { completedSteps.insert(.games) }
                if !timeOptions.isEmpty { completedSteps.insert(.schedule) }
                if !invitees.isEmpty { completedSteps.insert(.invites) }
                // Start at first incomplete step
                currentStep = CreateStep.allCases.first { !completedSteps.contains($0) } ?? .review
            } else {
                // Editing published event: all steps completed, start at review
                completedSteps = Set(CreateStep.allCases)
                currentStep = .review
            }
        }
    }

    var isEditing: Bool { eventToEdit != nil }

    var isDraftEdit: Bool { eventToEdit?.status == .draft }

    var nextButtonLabel: String {
        if currentStep == .review {
            if isDraftEdit { return "Send Invites" }
            return isEditing ? "Save Changes" : "Send Invites"
        }
        if currentStep == .games && selectedGames.isEmpty { return "Add Game Later" }
        return "Next"
    }

    var canProceed: Bool {
        switch currentStep {
        case .details: return !title.isEmpty
        case .games: return !selectedGames.isEmpty
        case .schedule: return scheduleMode == .fixed || !timeOptions.isEmpty
        case .invites: return !invitees.isEmpty
        case .review: return true
        }
    }

    func navigateToStep(_ step: CreateStep) {
        // Can always go backward or to completed steps or to the next incomplete step
        if step.rawValue <= currentStep.rawValue
            || completedSteps.contains(step)
            || step.rawValue == (completedSteps.map(\.rawValue).max() ?? -1) + 1 {
            currentStep = step
        }
    }

    func canNavigateToStep(_ step: CreateStep) -> Bool {
        step.rawValue <= currentStep.rawValue
            || completedSteps.contains(step)
            || step.rawValue == (completedSteps.map(\.rawValue).max() ?? -1) + 1
    }

    func markCurrentStepCompleted() {
        completedSteps.insert(currentStep)
    }

    func searchGames() async {
        guard !gameSearchQuery.isEmpty else {
            gameSearchResults = []
            return
        }
        isSearchingGames = true
        do {
            gameSearchResults = try await bgg.searchGames(query: gameSearchQuery)
        } catch {
            self.error = error.localizedDescription
        }
        isSearchingGames = false
    }

    func addGame(bggId: Int, isPrimary: Bool = false) async {
        do {
            let game = try await bgg.fetchGameDetails(bggId: bggId)
            let saved = try await supabase.upsertGame(game)
            let eventGame = EventGame(
                id: UUID(),
                gameId: saved.id,
                game: saved,
                isPrimary: isPrimary && selectedGames.isEmpty,
                sortOrder: selectedGames.count
            )
            selectedGames.append(eventGame)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addManualGame(name: String) async {
        let game = Game(
            id: UUID(),
            bggId: nil,
            name: name,
            yearPublished: nil,
            thumbnailUrl: nil,
            imageUrl: nil,
            minPlayers: 1,
            maxPlayers: 10,
            recommendedPlayers: nil,
            minPlaytime: 30,
            maxPlaytime: 120,
            complexity: 0,
            bggRating: nil,
            description: nil,
            categories: [],
            mechanics: []
        )
        do {
            let saved = try await supabase.upsertGame(game)
            let eventGame = EventGame(
                id: UUID(),
                gameId: saved.id,
                game: saved,
                isPrimary: selectedGames.isEmpty,
                sortOrder: selectedGames.count
            )
            selectedGames.append(eventGame)
            manualGameName = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeGame(at index: Int) {
        selectedGames.remove(at: index)
    }

    func setPrimaryGame(id: UUID) {
        for i in selectedGames.indices {
            selectedGames[i].isPrimary = selectedGames[i].id == id
        }
    }

    func addTimeOption(date: Date, startTime: Date, endTime: Date?, label: String?) {
        let option = TimeOption(
            id: UUID(),
            eventId: nil,
            date: date,
            startTime: startTime,
            endTime: endTime,
            label: label,
            isSuggested: false,
            suggestedBy: nil,
            voteCount: 0,
            maybeCount: 0
        )
        timeOptions.append(option)
    }

    func removeTimeOption(at index: Int) {
        timeOptions.remove(at: index)
    }

    func loadGroupMembers(_ group: GameGroup) {
        selectedGroup = group
        let existingPhones = Set(invitees.map(\.phoneNumber))
        let newMembers = group.members
            .filter { !existingPhones.contains($0.phoneNumber) }
            .map { member in
                InviteeEntry(
                    id: UUID(),
                    name: member.displayName ?? member.phoneNumber,
                    phoneNumber: member.phoneNumber,
                    userId: member.userId,
                    tier: member.tier,
                    groupId: group.id,
                    groupEmoji: group.emoji
                )
            }
        invitees.append(contentsOf: newMembers)
    }

    func loadSuggestedContacts() async {
        isLoadingSuggestions = true
        do {
            suggestedContacts = try await supabase.fetchFrequentContacts(limit: 20)
        } catch {
            // Non-critical
        }
        isLoadingSuggestions = false
    }

    /// Top 3 suggested contacts not already in the invite list
    var topSuggestions: [FrequentContact] {
        suggestedContacts
            .filter { fc in !invitees.contains(where: { $0.phoneNumber == fc.contactPhone }) }
            .prefix(3)
            .map { $0 }
    }

    /// Phones already in the invite list
    var invitedPhones: Set<String> {
        Set(invitees.map(\.phoneNumber))
    }

    func addContact(_ contact: UserContact) {
        guard !invitees.contains(where: { $0.phoneNumber == contact.phoneNumber }) else { return }
        addInvitee(name: contact.name, phoneNumber: contact.phoneNumber, tier: 1)
    }

    func addFrequentContact(_ contact: FrequentContact) {
        guard !invitees.contains(where: { $0.phoneNumber == contact.contactPhone }) else { return }
        addInvitee(name: contact.contactName, phoneNumber: contact.contactPhone, tier: 1)
    }

    var tier1Invitees: [InviteeEntry] {
        invitees.filter { $0.tier == 1 }
    }

    var tier2Invitees: [InviteeEntry] {
        invitees.filter { $0.tier == 2 }
    }

    func toggleGroupCollapse(_ groupId: UUID) {
        if collapsedGroups.contains(groupId) {
            collapsedGroups.remove(groupId)
        } else {
            collapsedGroups.insert(groupId)
        }
    }

    /// Returns grouped and ungrouped invitees for a tier.
    /// Grouped: keyed by groupId with (emoji, name, entries).
    /// Ungrouped: entries with no groupId.
    func groupedInvitees(forTier tier: Int) -> (groups: [(id: UUID, emoji: String, entries: [InviteeEntry])], ungrouped: [InviteeEntry]) {
        let tierInvitees = invitees.filter { $0.tier == tier }
        let ungrouped = tierInvitees.filter { $0.groupId == nil }

        var groupDict: [UUID: (emoji: String, entries: [InviteeEntry])] = [:]
        for invitee in tierInvitees {
            guard let gid = invitee.groupId else { continue }
            if groupDict[gid] == nil {
                groupDict[gid] = (emoji: invitee.groupEmoji ?? "🎲", entries: [])
            }
            groupDict[gid]!.entries.append(invitee)
        }

        let groups = groupDict.map { (id: $0.key, emoji: $0.value.emoji, entries: $0.value.entries) }
            .sorted { $0.entries.first?.name ?? "" < $1.entries.first?.name ?? "" }

        return (groups: groups, ungrouped: ungrouped)
    }

    func moveInvitee(from source: IndexSet, to destination: Int, inTier tier: Int) {
        var tierItems = tier == 1 ? tier1Invitees : tier2Invitees
        tierItems.move(fromOffsets: source, toOffset: destination)

        // Rebuild invitees preserving order: tier 1 first, then tier 2
        let otherTier = invitees.filter { $0.tier != tier }
        if tier == 1 {
            invitees = tierItems + otherTier
        } else {
            invitees = otherTier + tierItems
        }
    }

    func addInvitee(name: String, phoneNumber: String, tier: Int = 1) {
        let entry = InviteeEntry(
            id: UUID(),
            name: name,
            phoneNumber: ContactPickerService.normalizePhone(phoneNumber),
            userId: nil,
            tier: tier
        )
        invitees.append(entry)
    }

    func removeInvitee(at index: Int) {
        invitees.remove(at: index)
    }

    func setInviteeTier(_ id: UUID, tier: Int) {
        if let idx = invitees.firstIndex(where: { $0.id == id }) {
            invitees[idx].tier = tier
            if let groupId = invitees[idx].groupId {
                collapsedGroups.remove(groupId)
            }
        }
    }

    private func buildEvent(status: EventStatus, session: Supabase.Session) -> GameEvent {
        let existingEvent = eventToEdit
        return GameEvent(
            id: existingEvent?.id ?? UUID(),
            hostId: existingEvent?.hostId ?? session.user.id,
            host: nil,
            title: title,
            description: description.isEmpty ? nil : description,
            location: location.isEmpty ? nil : location,
            locationAddress: locationAddress.isEmpty ? nil : locationAddress,
            status: status,
            games: selectedGames,
            timeOptions: timeOptions,
            confirmedTimeOptionId: nil,
            allowTimeSuggestions: scheduleMode == .poll ? allowTimeSuggestions : false,
            scheduleMode: scheduleMode,
            inviteStrategy: inviteStrategy,
            minPlayers: minPlayers,
            maxPlayers: maxPlayers,
            allowGameVoting: allowGameVoting,
            confirmedGameId: nil,
            coverImageUrl: existingEvent?.coverImageUrl,
            draftInvitees: status == .draft ? invitees.map { entry in
                DraftInvitee(
                    id: entry.id,
                    name: entry.name,
                    phoneNumber: entry.phoneNumber,
                    userId: entry.userId,
                    tier: entry.tier,
                    groupId: entry.groupId,
                    groupEmoji: entry.groupEmoji
                )
            } : nil,
            deletedAt: existingEvent?.deletedAt,
            createdAt: existingEvent?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }

    private func createInviteRecords(eventId: UUID, hostId: UUID) async throws {
        let sortedInvitees = invitees.sorted { $0.tier < $1.tier }
        let firstTierSize = inviteStrategy.tierSize ?? sortedInvitees.count

        let invites: [Invite] = sortedInvitees.enumerated().map { index, invitee in
            let isFirstTier = inviteStrategy.type == .allAtOnce || index < firstTierSize
            return Invite(
                id: UUID(),
                eventId: eventId,
                hostUserId: hostId,
                userId: invitee.userId,
                phoneNumber: invitee.phoneNumber,
                displayName: invitee.name,
                status: isFirstTier ? .pending : .waitlisted,
                tier: invitee.tier,
                tierPosition: index,
                isActive: isFirstTier,
                respondedAt: nil,
                selectedTimeOptionIds: [],
                suggestedTimes: nil,
                sentVia: .both,
                smsDeliveryStatus: nil,
                createdAt: Date()
            )
        }

        try await supabase.createInvites(invites)
    }

    func saveDraft() async {
        isSaving = true
        error = nil

        do {
            let session = try await supabase.client.auth.session
            let event = buildEvent(status: .draft, session: session)

            if isEditing {
                try await supabase.deleteEventGames(eventId: event.id)
                try await supabase.deleteTimeOptions(eventId: event.id)
                try await supabase.updateEvent(event)
            } else {
                let _ = try await supabase.createEvent(event)
            }

            // Persist games and time options separately
            try await supabase.createEventGames(eventId: event.id, games: selectedGames)

            let timeOptionsWithEventId = timeOptions.map { option in
                var o = option
                o.eventId = event.id
                return o
            }
            try await supabase.createTimeOptions(timeOptionsWithEventId)

            self.createdEvent = try await supabase.fetchEvent(id: event.id)
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    func createEvent() async {
        isSaving = true
        error = nil

        do {
            let session = try await supabase.client.auth.session

            // If fixed mode, create a single time option from the date pickers
            var finalTimeOptions = timeOptions
            if scheduleMode == .fixed {
                let option = TimeOption(
                    id: UUID(),
                    eventId: nil,
                    date: fixedDate,
                    startTime: fixedStartTime,
                    endTime: nil,
                    label: nil,
                    isSuggested: false,
                    suggestedBy: nil,
                    voteCount: 0,
                    maybeCount: 0
                )
                finalTimeOptions = [option]
            }

            let event = buildEvent(status: .published, session: session)
            let created = try await supabase.createEvent(event)

            // Persist event games separately
            try await supabase.createEventGames(eventId: created.id, games: selectedGames)

            // Persist time options separately with eventId set
            let timeOptionsWithEventId = finalTimeOptions.map { option in
                var o = option
                o.eventId = created.id
                return o
            }
            try await supabase.createTimeOptions(timeOptionsWithEventId)

            // Create invites
            try await createInviteRecords(eventId: created.id, hostId: session.user.id)

            self.createdEvent = created
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

struct InviteeEntry: Identifiable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var userId: UUID?
    var tier: Int
    var groupId: UUID?
    var groupEmoji: String?
}

import Supabase
