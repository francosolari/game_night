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

    func respondToInvite(status: InviteStatus, selectedTimeIds: [UUID], suggestedTimes: [TimeOption]?) async {
        guard let invite = myInvite else { return }
        isSending = true
        do {
            try await supabase.respondToInvite(
                inviteId: invite.id,
                status: status,
                selectedTimeIds: selectedTimeIds,
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
    @Published var inviteStrategy = InviteStrategy(type: .tiered, tierSize: nil, autoPromote: true)
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
    @Published var manualGameName = ""

    // Contacts
    @Published var suggestedContacts: [FrequentContact] = []
    @Published var isLoadingSuggestions = true

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

    var nextButtonLabel: String {
        if currentStep == .review { return "Send Invites" }
        if currentStep == .games && selectedGames.isEmpty { return "Add Game Later" }
        return "Next"
    }

    var canProceed: Bool {
        switch currentStep {
        case .details: return !title.isEmpty
        case .games: return true
        case .schedule: return !timeOptions.isEmpty
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
            voteCount: 0
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
        }
    }

    func createEvent() async {
        isSaving = true
        error = nil

        do {
            let session = try await supabase.client.auth.session

            let event = GameEvent(
                id: UUID(),
                hostId: session.user.id,
                host: nil,
                title: title,
                description: description.isEmpty ? nil : description,
                location: location.isEmpty ? nil : location,
                locationAddress: locationAddress.isEmpty ? nil : locationAddress,
                status: .published,
                games: selectedGames,
                timeOptions: timeOptions,
                confirmedTimeOptionId: nil,
                allowTimeSuggestions: allowTimeSuggestions,
                inviteStrategy: inviteStrategy,
                minPlayers: minPlayers,
                maxPlayers: maxPlayers,
                coverImageUrl: nil,
                createdAt: Date(),
                updatedAt: Date()
            )

            let created = try await supabase.createEvent(event)

            // Create invites
            let sortedInvitees = invitees.sorted { $0.tier < $1.tier }
            let firstTierSize = inviteStrategy.tierSize ?? sortedInvitees.count

            let invites: [Invite] = sortedInvitees.enumerated().map { index, invitee in
                let isFirstTier = inviteStrategy.type == .allAtOnce || index < firstTierSize
                return Invite(
                    id: UUID(),
                    eventId: created.id,
                    hostUserId: created.hostId,
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
