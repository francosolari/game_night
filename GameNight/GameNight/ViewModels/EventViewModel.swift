import SwiftUI
import Combine
import Supabase

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

    // Poll voting
    @Published var myPollVotes: [UUID: TimeOptionVoteType] = [:]

    // Game voting
    @Published var gameVotes: [GameVote] = []
    @Published var myGameVotes: [UUID: GameVoteType] = [:]

    // Poll voter details
    @Published var timeOptionVoters: [UUID: [TimeOptionVoter]] = [:]
    @Published var gameVoterDetails: [UUID: [GameVoterInfo]] = [:]

    // Toast notifications
    @Published var toast: ToastItem?

    private let supabase = SupabaseService.shared
    private var realtimeChannel: RealtimeChannelV2?
    private var activityChannel: RealtimeChannelV2?
    private var subscribedEventId: UUID?
    private var subscribedActivityEventId: UUID?

    var hasRSVPd: Bool {
        guard let status = myInvite?.status else { return false }
        return status == .accepted || status == .maybe
    }

    var viewerRole: EventViewerRole {
        if isOwner {
            return .host
        }

        if hasRSVPd {
            return .rsvpd
        }

        if myInvite != nil {
            return .invitedNotRSVPd
        }

        return .publicViewer
    }

    var isOwner: Bool {
        guard let event else { return false }
        return event.hostId == supabase.client.auth.currentSession?.user.id
    }

    var accessPolicy: EventAccessPolicy? {
        guard let event else { return nil }
        return EventAccessPolicy(
            visibility: event.visibility,
            viewerRole: viewerRole,
            rsvpDeadline: event.rsvpDeadline,
            allowGuestInvites: event.allowGuestInvites,
            now: Date()
        )
    }

    var hasPollsActive: Bool {
        guard let event else { return false }
        let hasUnconfirmedTimePoll = event.scheduleMode == .poll
            && event.timeOptions.count > 1
            && event.confirmedTimeOptionId == nil
        let hasUnconfirmedGamePoll = event.allowGameVoting
            && event.games.count > 1
            && event.confirmedGameId == nil
        return hasUnconfirmedTimePoll || hasUnconfirmedGamePoll
    }

    var hasDatePollPending: Bool {
        guard let event else { return false }
        return event.scheduleMode == .poll
            && event.timeOptions.count > 1
            && event.confirmedTimeOptionId == nil
    }

    var canSeeActivityFeed: Bool {
        hasRSVPd || isOwner
    }

    var canInviteGuests: Bool {
        accessPolicy?.canInviteGuests ?? false
    }

    var confirmedPlayerCount: Int {
        inviteSummary.accepted
    }

    var inviteSummary: InviteSummary {
        let hostPhone = event.map { ContactPickerService.normalizePhone($0.host?.phoneNumber ?? "") }
        let nonHostInvites = invites.filter { invite in
            if let hostId = event?.hostId, invite.userId == hostId {
                return false
            }
            if let hostPhone, !hostPhone.isEmpty {
                return ContactPickerService.normalizePhone(invite.phoneNumber) != hostPhone
            }
            return true
        }

        let accepted = nonHostInvites.filter { $0.status == .accepted }
        let declined = nonHostInvites.filter { $0.status == .declined }
        let pending = nonHostInvites.filter { $0.status == .pending }
        let maybe = nonHostInvites.filter { $0.status == .maybe }
        let waitlisted = nonHostInvites.filter { $0.status == .waitlisted }

        func mapUsers(_ list: [Invite]) -> [InviteSummary.InviteUser] {
            list.map { .init(id: $0.id, name: $0.displayName ?? "Unknown", phoneNumber: $0.phoneNumber, avatarUrl: nil, status: $0.status, tier: $0.tier, inviteToken: $0.inviteToken, promotedAt: $0.promotedAt) }
        }

        let hostUser: InviteSummary.InviteUser? = {
            guard let event else { return nil }
            let name = event.host?.displayName ?? "Host"
            let avatarUrl = event.host?.avatarUrl
            return .init(id: event.hostId, name: name, avatarUrl: avatarUrl, status: .accepted, tier: 1)
        }()

        let acceptedUsers = mapUsers(accepted) + (hostUser.map { [$0] } ?? [])

        return InviteSummary(
            total: nonHostInvites.count + (hostUser == nil ? 0 : 1),
            accepted: accepted.count + (hostUser == nil ? 0 : 1),
            declined: declined.count,
            pending: pending.count,
            maybe: maybe.count,
            waitlisted: waitlisted.count,
            acceptedUsers: acceptedUsers,
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

            // Load poll votes for current user
            if let invite = myInvite {
                self.myPollVotes = (try? await supabase.fetchMyPollVotes(inviteId: invite.id)) ?? [:]
            }

            // Load activity feed, game votes, and poll voter details
            await loadActivityFeed(eventId: id)
            await loadGameVotes(eventId: id, currentUserId: session.user.id)
            await loadPollVoterDetails(eventId: id)

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

    /// Silently refresh event, invites, and poll voter details without flashing loading state.
    func refreshEventData(eventId: UUID) async {
        do {
            async let eventResult = supabase.fetchEvent(id: eventId)
            async let invitesResult = supabase.fetchInvites(eventId: eventId)

            self.event = try await eventResult
            self.invites = try await invitesResult

            let session = try await supabase.client.auth.session
            self.myInvite = invites.first { $0.userId == session.user.id }

            if let invite = myInvite {
                self.myPollVotes = (try? await supabase.fetchMyPollVotes(inviteId: invite.id)) ?? [:]
            }

            await loadPollVoterDetails(eventId: eventId)
            await loadGameVotes(eventId: eventId, currentUserId: session.user.id)
        } catch {
            // Non-critical for background refresh
        }
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
        await postToFeed { eventId in
            try await self.supabase.postComment(eventId: eventId, content: content, parentId: parentId)
        }
    }

    func postAnnouncement(content: String) async {
        await postToFeed { eventId in
            try await self.supabase.postAnnouncement(eventId: eventId, content: content)
        }
    }

    private func postToFeed(_ action: (UUID) async throws -> Void) async {
        guard let eventId = event?.id else { return }
        isPostingComment = true
        do {
            try await action(eventId)
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

    func loadPollVoterDetails(eventId: UUID) async {
        do {
            // Time poll voters
            let timeVoters = try await supabase.fetchTimeOptionVoters(eventId: eventId)
            var grouped: [UUID: [TimeOptionVoter]] = [:]
            for voter in timeVoters {
                grouped[voter.timeOptionId, default: []].append(voter)
            }
            self.timeOptionVoters = grouped

            // Game poll voters
            let gameVoters = try await supabase.fetchGameVoterDetails(eventId: eventId)
            var byGame: [UUID: [GameVoterInfo]] = [:]
            for voter in gameVoters {
                byGame[voter.gameId, default: []].append(voter)
            }
            self.gameVoterDetails = byGame
        } catch {
            // Non-critical
        }
    }

    func voteOnTimeOption(optionId: UUID, voteType: TimeOptionVoteType) async {
        guard let eventId = event?.id, let invite = myInvite else { return }
        do {
            // Re-submit all current votes with this one updated
            myPollVotes[optionId] = voteType
            let allVotes = myPollVotes.map { TimeOptionVote(timeOptionId: $0.key, voteType: $0.value) }
            try await supabase.respondToInvite(
                inviteId: invite.id,
                status: invite.status,
                timeVotes: allVotes,
                suggestedTimes: nil
            )
            await refreshEventData(eventId: eventId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func confirmTimeOption(timeOptionId: UUID) async {
        guard let eventId = event?.id else { return }
        do {
            try await supabase.confirmTimeOption(eventId: eventId, timeOptionId: timeOptionId)
            event?.confirmedTimeOptionId = timeOptionId
            // Notify invitees (fire-and-forget)
            Task {
                try? await supabase.invokeAuthenticatedFunction(
                    "notify-poll-confirmed",
                    body: ["event_id": eventId.uuidString, "type": "time"]
                )
            }
            // Refresh to show final state (poll ended, guest list restored)
            await refreshEventData(eventId: eventId)
            toast = ToastItem(style: .success, message: "Time confirmed!")
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
            // Refresh event + voter details without loading flash
            await refreshEventData(eventId: eventId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func confirmGame(gameId: UUID) async {
        guard let eventId = event?.id else { return }
        let gameName = event?.games.first(where: { $0.gameId == gameId })?.game?.name ?? "a game"
        do {
            try await supabase.confirmGame(eventId: eventId, gameId: gameId, gameName: gameName)
            event?.confirmedGameId = gameId
            event?.allowGameVoting = false
            // Notify invitees (fire-and-forget)
            Task {
                try? await supabase.invokeAuthenticatedFunction(
                    "notify-poll-confirmed",
                    body: ["event_id": eventId.uuidString, "type": "game"]
                )
            }
            // Refresh to show final state
            await refreshEventData(eventId: eventId)
            toast = ToastItem(style: .success, message: "Game locked in!")
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
            // Keep local poll votes in sync
            myPollVotes = Dictionary(uniqueKeysWithValues: timeVotes.map { ($0.timeOptionId, $0.voteType) })
            // Refresh event data without flashing loading state
            if let eventId = event?.id {
                await refreshEventData(eventId: eventId)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isSending = false
    }

    func inviteContacts(_ contacts: [UserContact]) async {
        guard canInviteGuests, let event else { return }

        do {
            let existingPhones = Set(invites.map(\.phoneNumber))
            let newContacts = contacts.filter { !existingPhones.contains($0.phoneNumber) }
            guard !newContacts.isEmpty else { return }

            let nextTierPosition = (invites.map(\.tierPosition).max() ?? -1) + 1
            let newInvites = newContacts.enumerated().map { index, contact in
                // App connections with known userId get push only (no SMS — host doesn't own their number)
                let deliveryMethod: DeliveryMethod = (contact.source == .appConnection && contact.appUserId != nil) ? .push : .both
                return Invite(
                    id: UUID(),
                    eventId: event.id,
                    hostUserId: event.hostId,
                    userId: contact.appUserId,
                    phoneNumber: contact.phoneNumber,
                    displayName: contact.name,
                    status: .pending,
                    tier: 1,
                    tierPosition: nextTierPosition + index,
                    isActive: true,
                    respondedAt: nil,
                    selectedTimeOptionIds: [],
                    suggestedTimes: nil,
                    sentVia: deliveryMethod,
                    smsDeliveryStatus: nil,
                    createdAt: Date()
                )
            }

            try await supabase.createInvites(newInvites)
            invites.append(contentsOf: newInvites)
        } catch {
            self.error = error.localizedDescription
        }
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

    func applyEditedEvent(_ updatedEvent: GameEvent) {
        event = updatedEvent
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
