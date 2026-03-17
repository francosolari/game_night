import Foundation
import SwiftUI
import Supabase

// MARK: - Create Event ViewModel
@MainActor
final class CreateEventViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var visibility: EventVisibility = .private
    @Published var rsvpDeadline: Date?
    @Published var allowGuestInvites = false
    @Published var location = ""
    @Published var locationAddress = ""
    @Published var selectedGames: [EventGame] = []
    @Published var timeOptions: [TimeOption] = []
    @Published var allowTimeSuggestions = true
    @Published var allowGameVoting = false
    @Published var scheduleMode: ScheduleMode = .fixed
    @Published var fixedDate: Date = Date()
    @Published var fixedStartTime: Date = Date()
    @Published var fixedEndDate: Date = Date()
    @Published var fixedEndTime: Date = Calendar.current.date(byAdding: .hour, value: 3, to: Date())!
    @Published var hasEndTime: Bool = false
    @Published var hasDate: Bool = true
    @Published var selectedTimezone: TimeZone = .current
    @Published var inviteStrategy = InviteStrategy(type: .allAtOnce, tierSize: nil, autoPromote: true)
    @Published var minPlayers = 3
    @Published var maxPlayers: Int? = nil
    @Published var plusOneLimit: Int = 0
    @Published var allowMaybeRSVP: Bool = true
    @Published var requirePlusOneNames: Bool = false
    @Published var selectedGroup: GameGroup?
    @Published var invitees: [InviteeEntry] = []
    @Published var isSaving = false
    @Published var error: String?
    @Published var createdEvent: GameEvent?
    let eventToEdit: GameEvent?

    @Published var gameSearchQuery = ""
    @Published var gameSearchResults: [BGGSearchResult] = []
    @Published var isSearchingGames = false
    @Published var manualGameName = ""

    @Published var suggestedContacts: [FrequentContact] = []
    @Published var isLoadingSuggestions = true
    @Published var collapsedGroups: Set<UUID> = []
    @Published private(set) var currentUserId: UUID?
    @Published private(set) var currentUserPhone: String?

    @Published var currentStep: CreateStep = .details
    @Published var completedSteps: Set<CreateStep> = []

    enum CreateStep: Int, CaseIterable, Hashable {
        case details = 0
        case games
        case invites
        case review
    }

    enum PrimaryAction: Equatable {
        case next
        case submit
        case saveChanges
    }

    private let supabase: EventEditingProviding
    private let bgg: BGGService

    init(
        eventToEdit: GameEvent? = nil,
        initialInvites: [Invite] = [],
        supabase: EventEditingProviding? = nil,
        bgg: BGGService = .shared
    ) {
        self.eventToEdit = eventToEdit
        self.supabase = supabase ?? SupabaseService.shared
        self.bgg = bgg

        if let eventToEdit {
            title = eventToEdit.title
            description = eventToEdit.description ?? ""
            visibility = eventToEdit.visibility
            rsvpDeadline = eventToEdit.rsvpDeadline
            allowGuestInvites = eventToEdit.allowGuestInvites
            location = eventToEdit.location ?? ""
            locationAddress = eventToEdit.locationAddress ?? ""
            selectedGames = eventToEdit.games
            timeOptions = eventToEdit.timeOptions
            allowTimeSuggestions = eventToEdit.allowTimeSuggestions
            allowGameVoting = eventToEdit.allowGameVoting
            scheduleMode = eventToEdit.scheduleMode
            inviteStrategy = eventToEdit.inviteStrategy
            minPlayers = eventToEdit.minPlayers
            maxPlayers = eventToEdit.maxPlayers
            plusOneLimit = eventToEdit.plusOneLimit
            allowMaybeRSVP = eventToEdit.allowMaybeRSVP
            requirePlusOneNames = eventToEdit.requirePlusOneNames

            if eventToEdit.scheduleMode == .fixed {
                if let fixedOption = eventToEdit.timeOptions.first {
                    fixedDate = fixedOption.date
                    fixedStartTime = fixedOption.startTime
                    hasDate = true
                    if let end = fixedOption.endTime {
                        fixedEndDate = Calendar.current.startOfDay(for: end)
                        fixedEndTime = end
                        hasEndTime = true
                    }
                } else {
                    hasDate = false
                }
            }

            if eventToEdit.status == .draft {
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

                if !title.isEmpty && (scheduleMode == .fixed || !timeOptions.isEmpty) { completedSteps.insert(.details) }
                if !selectedGames.isEmpty { completedSteps.insert(.games) }
                if !invitees.isEmpty { completedSteps.insert(.invites) }
                currentStep = CreateStep.allCases.first { !completedSteps.contains($0) } ?? .review
            } else {
                invitees = Self.mapInvitesToEntries(initialInvites)
                completedSteps = Set(CreateStep.allCases)
                currentStep = .details
            }
        }
    }

    var isEditing: Bool { eventToEdit != nil }

    var isDraftEdit: Bool { eventToEdit?.status == .draft }

    var primaryAction: PrimaryAction {
        if isEditing && !isDraftEdit {
            return .saveChanges
        }
        if currentStep == .review {
            return .submit
        }
        return .next
    }

    var nextButtonLabel: String {
        switch primaryAction {
        case .saveChanges:
            return "Save Changes"
        case .submit:
            return "Send Invites"
        case .next:
            if currentStep == .games && selectedGames.isEmpty {
                return "Add Game Later"
            }
            return "Next"
        }
    }

    var canProceed: Bool {
        switch currentStep {
        case .details: return !title.isEmpty && (scheduleMode == .fixed || !timeOptions.isEmpty)
        case .games: return !selectedGames.isEmpty
        case .invites: return !invitees.isEmpty
        case .review: return true
        }
    }

    func navigateToStep(_ step: CreateStep) {
        if isEditing && !isDraftEdit {
            currentStep = step
            return
        }

        if step.rawValue <= currentStep.rawValue
            || completedSteps.contains(step)
            || step.rawValue == (completedSteps.map(\.rawValue).max() ?? -1) + 1 {
            currentStep = step
        }
    }

    func canNavigateToStep(_ step: CreateStep) -> Bool {
        if isEditing && !isDraftEdit {
            return true
        }

        return step.rawValue <= currentStep.rawValue
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
        sortTimeOptions()
    }

    func removeTimeOption(at index: Int) {
        guard index >= 0 && index < timeOptions.count else { return }
        removeTimeOption(id: timeOptions[index].id)
    }

    func removeTimeOption(id: UUID) {
        timeOptions.removeAll { $0.id == id }
    }

    func updateTimeOption(at index: Int, date: Date, startTime: Date, endTime: Date?, label: String?) {
        guard index >= 0 && index < timeOptions.count else { return }
        updateTimeOption(
            id: timeOptions[index].id,
            date: date,
            startTime: startTime,
            endTime: endTime,
            label: label
        )
    }

    func updateTimeOption(id: UUID, date: Date, startTime: Date, endTime: Date?, label: String?) {
        guard let index = timeOptions.firstIndex(where: { $0.id == id }) else { return }
        timeOptions[index].date = date
        timeOptions[index].startTime = startTime
        timeOptions[index].endTime = endTime
        timeOptions[index].label = label
        sortTimeOptions()
    }

    func loadGroupMembers(_ group: GameGroup) {
        selectedGroup = group
        let existingPhones = Set(invitees.map(\.phoneNumber))
        let newMembers = group.members
            .filter {
                !existingPhones.contains($0.phoneNumber)
                    && !isCurrentUser(phoneNumber: $0.phoneNumber, userId: $0.userId)
            }
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

    var topSuggestions: [FrequentContact] {
        suggestedContacts
            .filter { contact in
                !invitees.contains(where: { $0.phoneNumber == contact.contactPhone })
                    && !isCurrentUser(phoneNumber: contact.contactPhone, userId: contact.contactUserId)
            }
            .prefix(3)
            .map { $0 }
    }

    private func sortTimeOptions() {
        timeOptions.sort {
            if $0.date != $1.date {
                return $0.date < $1.date
            }
            return $0.startTime < $1.startTime
        }
    }

    var invitedPhones: Set<String> {
        Set(invitees.map(\.phoneNumber))
    }

    func configureCurrentUser(_ user: User?) {
        currentUserId = user?.id
        currentUserPhone = user.map { ContactPickerService.normalizePhone($0.phoneNumber) }
        removeSelfInvitees()
    }

    func addContact(_ contact: UserContact) {
        guard !isCurrentUser(phoneNumber: contact.phoneNumber, userId: nil) else { return }
        guard !invitees.contains(where: { $0.phoneNumber == contact.phoneNumber }) else { return }
        addInvitee(name: contact.name, phoneNumber: contact.phoneNumber, tier: 1)
    }

    func addFrequentContact(_ contact: FrequentContact) {
        guard !isCurrentUser(phoneNumber: contact.contactPhone, userId: contact.contactUserId) else { return }
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

    func groupedInvitees(forTier tier: Int) -> (groups: [(id: UUID, emoji: String, entries: [InviteeEntry])], ungrouped: [InviteeEntry]) {
        let tierInvitees = invitees.filter { $0.tier == tier }
        let ungrouped = tierInvitees.filter { $0.groupId == nil }

        var groupDict: [UUID: (emoji: String, entries: [InviteeEntry])] = [:]
        for invitee in tierInvitees {
            guard let groupId = invitee.groupId else { continue }
            if groupDict[groupId] == nil {
                groupDict[groupId] = (emoji: invitee.groupEmoji ?? "🎲", entries: [])
            }
            groupDict[groupId]?.entries.append(invitee)
        }

        let groups = groupDict.map { (id: $0.key, emoji: $0.value.emoji, entries: $0.value.entries) }
            .sorted { $0.entries.first?.name ?? "" < $1.entries.first?.name ?? "" }

        return (groups: groups, ungrouped: ungrouped)
    }

    func moveInvitee(from source: IndexSet, to destination: Int, inTier tier: Int) {
        var tierItems = tier == 1 ? tier1Invitees : tier2Invitees
        tierItems.move(fromOffsets: source, toOffset: destination)

        let otherTier = invitees.filter { $0.tier != tier }
        if tier == 1 {
            invitees = tierItems + otherTier
        } else {
            invitees = otherTier + tierItems
        }
    }

    func addInvitee(name: String, phoneNumber: String, tier: Int = 1) {
        let normalizedPhone = ContactPickerService.normalizePhone(phoneNumber)
        guard !isCurrentUser(phoneNumber: normalizedPhone, userId: nil) else { return }
        let entry = InviteeEntry(
            id: UUID(),
            name: name,
            phoneNumber: normalizedPhone,
            userId: nil,
            tier: tier
        )
        invitees.append(entry)
    }

    func removeInvitee(at index: Int) {
        invitees.remove(at: index)
    }

    func setInviteeTier(_ id: UUID, tier: Int) {
        if let index = invitees.firstIndex(where: { $0.id == id }) {
            invitees[index].tier = tier
            if let groupId = invitees[index].groupId {
                collapsedGroups.remove(groupId)
            }
        }
    }

    func saveDraft() async {
        isSaving = true
        error = nil

        do {
            let hostId = try await supabase.currentUserId()
            let event = buildEvent(status: .draft, hostId: hostId)

            if isEditing {
                try await supabase.updateEvent(event)
                try await syncEventGames(eventId: event.id)
                try await syncTimeOptions(eventId: event.id)
            } else {
                let _ = try await supabase.createEvent(event)
                try await supabase.createEventGames(eventId: event.id, games: selectedGames)
                try await supabase.createTimeOptions(resolvedTimeOptions(eventId: event.id))
            }

            createdEvent = try await supabase.fetchEvent(id: event.id)
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    func saveChanges() async {
        guard isEditing else {
            await createEvent()
            return
        }

        isSaving = true
        error = nil

        do {
            let hostId = try await supabase.currentUserId()
            let status = eventToEdit?.status ?? .published
            let event = buildEvent(status: status, hostId: hostId)

            try await supabase.updateEvent(event)
            try await syncEventGames(eventId: event.id)
            try await syncTimeOptions(eventId: event.id)
            try await syncInviteRecords(eventId: event.id, hostId: hostId)

            createdEvent = try await supabase.fetchEvent(id: event.id)
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    func createEvent() async {
        if isEditing {
            isSaving = true
            error = nil

            do {
                let hostId = try await supabase.currentUserId()
                let status: EventStatus = isDraftEdit ? .published : (eventToEdit?.status ?? .published)
                let event = buildEvent(status: status, hostId: hostId)

                try await supabase.updateEvent(event)
                try await syncEventGames(eventId: event.id)
                try await syncTimeOptions(eventId: event.id)
                try await syncInviteRecords(eventId: event.id, hostId: hostId)

                createdEvent = try await supabase.fetchEvent(id: event.id)
            } catch {
                self.error = error.localizedDescription
            }

            isSaving = false
            return
        }

        isSaving = true
        error = nil

        do {
            let hostId = try await supabase.currentUserId()
            let event = buildEvent(status: .published, hostId: hostId)
            let created = try await supabase.createEvent(event)

            try await supabase.createEventGames(eventId: created.id, games: selectedGames)
            try await supabase.createTimeOptions(resolvedTimeOptions(eventId: created.id))
            try await createInviteRecords(eventId: created.id, hostId: hostId)

            createdEvent = created
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    private func buildEvent(status: EventStatus, hostId: UUID) -> GameEvent {
        let existingEvent = eventToEdit
        return GameEvent(
            id: existingEvent?.id ?? UUID(),
            hostId: existingEvent?.hostId ?? hostId,
            host: nil,
            title: title,
            description: description.isEmpty ? nil : description,
            visibility: visibility,
            rsvpDeadline: rsvpDeadline,
            allowGuestInvites: allowGuestInvites,
            location: location.isEmpty ? nil : location,
            locationAddress: locationAddress.isEmpty ? nil : locationAddress,
            status: status,
            games: selectedGames,
            timeOptions: resolvedTimeOptions(),
            confirmedTimeOptionId: existingEvent?.confirmedTimeOptionId,
            allowTimeSuggestions: scheduleMode == .poll ? allowTimeSuggestions : false,
            scheduleMode: scheduleMode,
            inviteStrategy: inviteStrategy,
            minPlayers: minPlayers,
            maxPlayers: maxPlayers,
            allowGameVoting: allowGameVoting,
            confirmedGameId: existingEvent?.confirmedGameId,
            plusOneLimit: plusOneLimit,
            allowMaybeRSVP: allowMaybeRSVP,
            requirePlusOneNames: requirePlusOneNames,
            coverImageUrl: existingEvent?.coverImageUrl,
            draftInvitees: status == .draft ? orderedInvitees().map { entry in
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
        let sortedInvitees = orderedInvitees()
        let firstTierSize = inviteStrategy.tierSize ?? sortedInvitees.count

        let invites: [Invite] = sortedInvitees.enumerated().map { index, invitee in
            let isFirstTier = inviteStrategy.type == .allAtOnce || index < firstTierSize
            return Invite(
                id: invitee.id,
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

    private func syncInviteRecords(eventId: UUID, hostId: UUID) async throws {
        let existingInvites = try await supabase.fetchInvites(eventId: eventId)
        let existingById = Dictionary(uniqueKeysWithValues: existingInvites.map { ($0.id, $0) })
        let currentEntries = orderedInvitees()
        let currentIds = Set(currentEntries.map(\.id))

        let deletedIds = existingInvites
            .map(\.id)
            .filter { !currentIds.contains($0) }
        try await supabase.deleteInvites(ids: deletedIds)

        var newInvites: [Invite] = []
        for (index, entry) in currentEntries.enumerated() {
            let invite = buildInviteRecord(
                from: entry,
                existingInvite: existingById[entry.id],
                eventId: eventId,
                hostId: hostId,
                tierPosition: index
            )

            if existingById[entry.id] == nil {
                newInvites.append(invite)
            } else {
                try await supabase.updateInvite(invite)
            }
        }

        try await supabase.createInvites(newInvites)
    }

    private func syncEventGames(eventId: UUID) async throws {
        let existingIds = Set(eventToEdit?.games.map(\.id) ?? [])
        let currentGames = selectedGames.enumerated().map { index, game in
            var updated = game
            updated.sortOrder = index
            return updated
        }
        let currentIds = Set(currentGames.map(\.id))

        try await supabase.upsertEventGames(eventId: eventId, games: currentGames)
        try await supabase.deleteEventGames(ids: Array(existingIds.subtracting(currentIds)))
    }

    private func syncTimeOptions(eventId: UUID) async throws {
        let existingIds = Set(eventToEdit?.timeOptions.map(\.id) ?? [])
        let currentOptions = resolvedTimeOptions(eventId: eventId)
        let currentIds = Set(currentOptions.map(\.id))

        try await supabase.upsertTimeOptions(currentOptions)
        try await supabase.deleteTimeOptions(ids: Array(existingIds.subtracting(currentIds)))
    }

    private func resolvedTimeOptions(eventId: UUID? = nil) -> [TimeOption] {
        if scheduleMode == .fixed {
            // No date set — return empty (event saved without a date)
            guard hasDate else { return [] }

            let existingFixed = eventToEdit?.timeOptions.first ?? timeOptions.first
            let calendar = Calendar.current

            // Combine fixedDate's year/month/day + fixedStartTime's hour/minute
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: fixedDate)
            let startComponents = calendar.dateComponents([.hour, .minute], from: fixedStartTime)
            var combinedStart = DateComponents()
            combinedStart.year = dateComponents.year
            combinedStart.month = dateComponents.month
            combinedStart.day = dateComponents.day
            combinedStart.hour = startComponents.hour
            combinedStart.minute = startComponents.minute
            let resolvedStartTime = calendar.date(from: combinedStart) ?? fixedStartTime

            var resolvedEndTime: Date? = nil
            if hasEndTime {
                let endDateComponents = calendar.dateComponents([.year, .month, .day], from: fixedEndDate)
                let endTimeComponents = calendar.dateComponents([.hour, .minute], from: fixedEndTime)
                var combinedEnd = DateComponents()
                combinedEnd.year = endDateComponents.year
                combinedEnd.month = endDateComponents.month
                combinedEnd.day = endDateComponents.day
                combinedEnd.hour = endTimeComponents.hour
                combinedEnd.minute = endTimeComponents.minute
                resolvedEndTime = calendar.date(from: combinedEnd) ?? fixedEndTime
            }

            return [
                TimeOption(
                    id: existingFixed?.id ?? UUID(),
                    eventId: eventId,
                    date: fixedDate,
                    startTime: resolvedStartTime,
                    endTime: resolvedEndTime,
                    label: existingFixed?.label,
                    isSuggested: false,
                    suggestedBy: nil,
                    voteCount: existingFixed?.voteCount ?? 0,
                    maybeCount: existingFixed?.maybeCount ?? 0
                )
            ]
        }

        return timeOptions.map { option in
            var updated = option
            updated.eventId = eventId
            return updated
        }
    }

    private func orderedInvitees() -> [InviteeEntry] {
        invitees.enumerated()
            .map(\.element)
            .filter { !isCurrentUser(phoneNumber: $0.phoneNumber, userId: $0.userId) }
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.tier == rhs.element.tier {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.tier < rhs.element.tier
            }
            .map(\.element)
    }

    private func removeSelfInvitees() {
        invitees.removeAll { isCurrentUser(phoneNumber: $0.phoneNumber, userId: $0.userId) }
    }

    private func isCurrentUser(phoneNumber: String, userId: UUID?) -> Bool {
        if let currentUserId, let userId, currentUserId == userId {
            return true
        }

        guard let currentUserPhone else { return false }
        return ContactPickerService.normalizePhone(phoneNumber) == currentUserPhone
    }

    private func buildInviteRecord(
        from entry: InviteeEntry,
        existingInvite: Invite?,
        eventId: UUID,
        hostId: UUID,
        tierPosition: Int
    ) -> Invite {
        let normalizedPhone = ContactPickerService.normalizePhone(entry.phoneNumber)
        let isBenchInvite = entry.tier > 1

        if var existingInvite {
            existingInvite.eventId = eventId
            existingInvite.hostUserId = existingInvite.hostUserId ?? hostId
            existingInvite.userId = entry.userId
            existingInvite.phoneNumber = normalizedPhone
            existingInvite.displayName = entry.name
            existingInvite.tier = entry.tier
            existingInvite.tierPosition = tierPosition

            if isBenchInvite {
                existingInvite.status = .waitlisted
                existingInvite.isActive = false
                existingInvite.respondedAt = nil
                existingInvite.selectedTimeOptionIds = []
                existingInvite.suggestedTimes = nil
            } else if existingInvite.status == .waitlisted || !existingInvite.isActive {
                existingInvite.status = .pending
                existingInvite.isActive = true
                existingInvite.respondedAt = nil
                existingInvite.selectedTimeOptionIds = []
                existingInvite.suggestedTimes = nil
            } else {
                existingInvite.isActive = true
            }

            return existingInvite
        }

        return Invite(
            id: entry.id,
            eventId: eventId,
            hostUserId: hostId,
            userId: entry.userId,
            phoneNumber: normalizedPhone,
            displayName: entry.name,
            status: isBenchInvite ? .waitlisted : .pending,
            tier: entry.tier,
            tierPosition: tierPosition,
            isActive: !isBenchInvite,
            respondedAt: nil,
            selectedTimeOptionIds: [],
            suggestedTimes: nil,
            sentVia: .both,
            smsDeliveryStatus: nil,
            createdAt: Date()
        )
    }

    private static func mapInvitesToEntries(_ invites: [Invite]) -> [InviteeEntry] {
        invites
            .sorted {
                if $0.tier == $1.tier {
                    return $0.tierPosition < $1.tierPosition
                }
                return $0.tier < $1.tier
            }
            .map { invite in
                InviteeEntry(
                    id: invite.id,
                    name: invite.displayName ?? invite.phoneNumber,
                    phoneNumber: invite.phoneNumber,
                    userId: invite.userId,
                    tier: invite.tier
                )
            }
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
