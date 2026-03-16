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

    private let supabase = SupabaseService.shared
    private var realtimeChannel: RealtimeChannelV2?

    var inviteSummary: InviteSummary {
        let accepted = invites.filter { $0.status == .accepted }
        let declined = invites.filter { $0.status == .declined }
        let pending = invites.filter { $0.status == .pending }
        let maybe = invites.filter { $0.status == .maybe }
        let waitlisted = invites.filter { $0.status == .waitlisted }

        return InviteSummary(
            total: invites.count,
            accepted: accepted.count,
            declined: declined.count,
            pending: pending.count,
            maybe: maybe.count,
            waitlisted: waitlisted.count,
            acceptedUsers: accepted.map { .init(id: $0.id, name: $0.displayName ?? "Unknown", avatarUrl: nil, status: $0.status, tier: $0.tier) },
            pendingUsers: pending.map { .init(id: $0.id, name: $0.displayName ?? "Unknown", avatarUrl: nil, status: $0.status, tier: $0.tier) },
            declinedUsers: declined.map { .init(id: $0.id, name: $0.displayName ?? "Unknown", avatarUrl: nil, status: $0.status, tier: $0.tier) },
            waitlistedUsers: waitlisted.map { .init(id: $0.id, name: $0.displayName ?? "Unknown", avatarUrl: nil, status: $0.status, tier: $0.tier) }
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

            // Subscribe to realtime updates
            subscribeToUpdates(eventId: id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
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

    private func subscribeToUpdates(eventId: UUID) {
        realtimeChannel = supabase.subscribeToEventUpdates(eventId: eventId) { [weak self] updatedEvent in
            Task { @MainActor in
                self?.event = updatedEvent
            }
        }
    }

    deinit {
        Task { [realtimeChannel] in
            await realtimeChannel?.unsubscribe()
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

    // Game search
    @Published var gameSearchQuery = ""
    @Published var gameSearchResults: [BGGSearchResult] = []
    @Published var isSearchingGames = false

    // Steps
    @Published var currentStep: CreateStep = .details
    enum CreateStep: Int, CaseIterable {
        case details = 0
        case games
        case schedule
        case invites
        case review
    }

    private let supabase = SupabaseService.shared
    private let bgg = BGGService.shared

    var canProceed: Bool {
        switch currentStep {
        case .details: return !title.isEmpty
        case .games: return !selectedGames.isEmpty
        case .schedule: return scheduleMode == .fixed || !timeOptions.isEmpty
        case .invites: return !invitees.isEmpty
        case .review: return true
        }
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
        invitees = group.members.map { member in
            InviteeEntry(
                id: member.id,
                name: member.displayName ?? member.phoneNumber,
                phoneNumber: member.phoneNumber,
                userId: member.userId,
                tier: member.tier
            )
        }
    }

    func addInvitee(name: String, phoneNumber: String, tier: Int = 1) {
        let entry = InviteeEntry(
            id: UUID(),
            name: name,
            phoneNumber: phoneNumber,
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
        }
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

            let event = GameEvent(
                id: UUID(),
                hostId: session.user.id,
                host: nil,
                title: title,
                description: description.isEmpty ? nil : description,
                location: location.isEmpty ? nil : location,
                locationAddress: locationAddress.isEmpty ? nil : locationAddress,
                status: .published,
                games: [],
                timeOptions: [],
                confirmedTimeOptionId: nil,
                allowTimeSuggestions: scheduleMode == .poll ? allowTimeSuggestions : false,
                scheduleMode: scheduleMode,
                inviteStrategy: inviteStrategy,
                minPlayers: minPlayers,
                maxPlayers: maxPlayers,
                coverImageUrl: nil,
                createdAt: Date(),
                updatedAt: Date()
            )

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
            let sortedInvitees = invitees.sorted { $0.tier < $1.tier }
            let firstTierSize = inviteStrategy.tierSize ?? sortedInvitees.count

            let invites: [Invite] = sortedInvitees.enumerated().map { index, invitee in
                let isFirstTier = inviteStrategy.type == .allAtOnce || index < firstTierSize
                return Invite(
                    id: UUID(),
                    eventId: created.id,
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
}

import Supabase
