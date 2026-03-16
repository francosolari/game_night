import XCTest
@testable import GameNight

@MainActor
final class CreateEventViewModelTests: XCTestCase {
    func testEventEditSuccessToastUsesUpdatedEventTitle() {
        let event = FixtureFactory.makeEvent(title: "Updated Dune Night")

        let toast = EventEditToastFactory.makeSuccessToast(for: event)

        XCTAssertEqual(toast.style.icon, ToastStyle.success.icon)
        XCTAssertEqual(toast.message, "Saved changes to Updated Dune Night")
    }

    func testPublishedEditPreloadsExistingInvitesIntoInvitees() {
        let event = FixtureFactory.makeEvent()
        let firstInvite = makeInvite(displayName: "Jordan", phoneNumber: "+15555550111", tier: 1, status: .pending)
        let benchInvite = makeInvite(displayName: "Casey", phoneNumber: "+15555550112", tier: 2, status: .waitlisted)

        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [firstInvite, benchInvite],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        XCTAssertEqual(sut.invitees.map(\.name), ["Jordan", "Casey"])
        XCTAssertEqual(sut.invitees.map(\.phoneNumber), ["+15555550111", "+15555550112"])
        XCTAssertEqual(sut.invitees.map(\.tier), [1, 2])
    }

    func testPublishedEditPrimaryActionIsSaveChangesOnEveryStep() {
        let event = FixtureFactory.makeEvent()
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        for step in CreateEventViewModel.CreateStep.allCases {
            sut.currentStep = step
            XCTAssertEqual(sut.primaryAction, .saveChanges)
            XCTAssertEqual(sut.nextButtonLabel, "Save Changes")
        }
    }

    func testPublishedEditSaveUsesUpdateFlowInsteadOfCreate() async {
        let event = FixtureFactory.makeEvent()
        let service = StubEventEditorService(currentUserId: event.hostId, fetchedEvent: event)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: service
        )
        sut.title = "Updated Title"

        await sut.saveChanges()

        XCTAssertEqual(service.createdEvents.count, 0)
        XCTAssertEqual(service.updatedEvents.map(\.title), ["Updated Title"])
    }

    func testPublishedEditSaveFromDetailsPersistsDetailChanges() async {
        let event = FixtureFactory.makeEvent(title: "Original Title")
        let service = StubEventEditorService(currentUserId: event.hostId, fetchedEvent: event)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: service
        )
        sut.currentStep = .details
        sut.title = "Updated Title"
        sut.location = "New Venue"

        await sut.saveChanges()

        XCTAssertEqual(service.updatedEvents.last?.title, "Updated Title")
        XCTAssertEqual(service.updatedEvents.last?.location, "New Venue")
        XCTAssertEqual(sut.createdEvent?.title, "Updated Title")
        XCTAssertEqual(sut.createdEvent?.location, "New Venue")
    }

    func testPublishedEditSaveFromGamesPersistsGameChanges() async {
        let primaryGame = FixtureFactory.makeEventGame(game: FixtureFactory.makeGame(name: "Dune"))
        let addedGame = FixtureFactory.makeEventGame(
            game: FixtureFactory.makeGame(name: "Brass"),
            isPrimary: false,
            sortOrder: 1
        )
        let event = FixtureFactory.makeEvent(games: [primaryGame])
        let service = StubEventEditorService(currentUserId: event.hostId, fetchedEvent: event)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: service
        )
        sut.currentStep = .games
        sut.selectedGames = [primaryGame, addedGame]

        await sut.saveChanges()

        XCTAssertEqual(service.upsertedEventGames.map(\.gameId), [primaryGame.gameId, addedGame.gameId])
        XCTAssertEqual(sut.createdEvent?.games.map(\.gameId), [primaryGame.gameId, addedGame.gameId])
    }

    func testPublishedEditSaveFromSchedulePersistsFixedDateChanges() async {
        let originalOption = FixtureFactory.makeTimeOption(id: UUID())
        let event = FixtureFactory.makeEvent(timeOptions: [originalOption])
        let service = StubEventEditorService(currentUserId: event.hostId, fetchedEvent: event)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: service
        )
        sut.currentStep = .schedule
        sut.fixedDate = Date(timeIntervalSince1970: 1_720_000_000)
        sut.fixedStartTime = Date(timeIntervalSince1970: 1_720_003_600)

        await sut.saveChanges()

        XCTAssertEqual(service.upsertedTimeOptions.count, 1)
        XCTAssertEqual(service.upsertedTimeOptions.first?.id, originalOption.id)
        XCTAssertEqual(service.upsertedTimeOptions.first?.date, sut.fixedDate)
        XCTAssertEqual(service.upsertedTimeOptions.first?.startTime, sut.fixedStartTime)
        XCTAssertEqual(sut.createdEvent?.timeOptions.first?.date, sut.fixedDate)
        XCTAssertEqual(sut.createdEvent?.timeOptions.first?.startTime, sut.fixedStartTime)
    }

    func testPublishedEditSaveDiffsInvites() async {
        let event = FixtureFactory.makeEvent()
        let existingTierOne = makeInvite(displayName: "Jordan", phoneNumber: "+15555550111", tier: 1, status: .pending)
        let existingBench = makeInvite(displayName: "Casey", phoneNumber: "+15555550112", tier: 2, status: .waitlisted)
        let service = StubEventEditorService(
            currentUserId: event.hostId,
            fetchedEvent: event,
            existingInvites: [existingTierOne, existingBench]
        )
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [existingTierOne, existingBench],
            supabase: service
        )
        sut.currentStep = .invites

        sut.invitees = [
            InviteeEntry(
                id: existingTierOne.id,
                name: "Jordan Updated",
                phoneNumber: existingTierOne.phoneNumber,
                userId: existingTierOne.userId,
                tier: 2
            ),
            InviteeEntry(
                id: UUID(),
                name: "Alex",
                phoneNumber: "+15555550113",
                userId: nil,
                tier: 1
            )
        ]

        await sut.saveChanges()

        XCTAssertEqual(service.deletedInviteIds, [existingBench.id])
        XCTAssertEqual(service.updatedInvites.count, 1)
        XCTAssertEqual(service.updatedInvites.first?.id, existingTierOne.id)
        XCTAssertEqual(service.updatedInvites.first?.displayName, "Jordan Updated")
        XCTAssertEqual(service.updatedInvites.first?.tier, 2)
        XCTAssertEqual(service.updatedInvites.first?.status, .waitlisted)
        XCTAssertEqual(service.createdInvites.count, 1)
        XCTAssertEqual(service.createdInvites.first?.displayName, "Alex")
        XCTAssertEqual(service.createdInvites.first?.tier, 1)
        XCTAssertEqual(service.createdInvites.first?.status, .pending)
    }

    func testPublishedEditSaveFromSchedulePersistsCombinationOfTabChanges() async {
        let primaryGame = FixtureFactory.makeEventGame(game: FixtureFactory.makeGame(name: "Dune"))
        let event = FixtureFactory.makeEvent(title: "Original Title", games: [primaryGame])
        let service = StubEventEditorService(
            currentUserId: event.hostId,
            fetchedEvent: event,
            existingInvites: [makeInvite(displayName: "Jordan", phoneNumber: "+15555550111", tier: 1, status: .pending)]
        )
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: service.existingInvites,
            supabase: service
        )
        sut.currentStep = .schedule
        sut.title = "Updated Title"
        sut.fixedDate = Date(timeIntervalSince1970: 1_730_000_000)
        sut.fixedStartTime = Date(timeIntervalSince1970: 1_730_003_600)
        let addedGame = FixtureFactory.makeEventGame(
            game: FixtureFactory.makeGame(name: "Brass"),
            isPrimary: false,
            sortOrder: 1
        )
        sut.selectedGames = [primaryGame, addedGame]
        sut.invitees.append(
            InviteeEntry(
                id: UUID(),
                name: "Casey",
                phoneNumber: "+15555550112",
                userId: nil,
                tier: 1
            )
        )

        await sut.saveChanges()

        XCTAssertEqual(sut.createdEvent?.title, "Updated Title")
        XCTAssertEqual(sut.createdEvent?.games.map(\.gameId), [primaryGame.gameId, addedGame.gameId])
        XCTAssertEqual(sut.createdEvent?.timeOptions.first?.date, sut.fixedDate)
        XCTAssertEqual(service.createdInvites.map(\.displayName), ["Casey"])
    }
}

@MainActor
final class EventViewModelTests: XCTestCase {
    func testApplyEditedEventUpdatesCurrentEventImmediately() {
        let original = FixtureFactory.makeEvent(title: "Original")
        var updated = FixtureFactory.makeEvent(id: original.id, title: "Updated")
        updated.timeOptions = [
            TimeOption(
                id: UUID(),
                eventId: original.id,
                date: Date(timeIntervalSince1970: 1_730_000_000),
                startTime: Date(timeIntervalSince1970: 1_730_003_600),
                endTime: nil,
                label: "Updated Slot",
                isSuggested: false,
                suggestedBy: nil,
                voteCount: 0,
                maybeCount: 0
            )
        ]

        let sut = EventViewModel()
        sut.event = original

        sut.applyEditedEvent(updated)

        XCTAssertEqual(sut.event?.title, "Updated")
        XCTAssertEqual(sut.event?.timeOptions.first?.date, updated.timeOptions.first?.date)
    }
}

private func makeInvite(
    id: UUID = UUID(),
    displayName: String,
    phoneNumber: String,
    tier: Int,
    status: InviteStatus
) -> Invite {
    Invite(
        id: id,
        eventId: UUID(),
        hostUserId: UUID(),
        userId: UUID(),
        phoneNumber: phoneNumber,
        displayName: displayName,
        status: status,
        tier: tier,
        tierPosition: tier == 1 ? 0 : 1,
        isActive: tier == 1,
        respondedAt: nil,
        selectedTimeOptionIds: [],
        suggestedTimes: nil,
        sentVia: .both,
        smsDeliveryStatus: .delivered,
        createdAt: Date(timeIntervalSince1970: 1_710_000_000)
    )
}

private final class StubEventEditorService: EventEditingProviding {
    let currentUserIdValue: UUID
    var storedEvent: GameEvent?
    var existingInvites: [Invite]
    var createdEvents: [GameEvent] = []
    var updatedEvents: [GameEvent] = []
    var upsertedTimeOptions: [TimeOption] = []
    var upsertedEventGames: [EventGame] = []
    var createdInvites: [Invite] = []
    var updatedInvites: [Invite] = []
    var deletedInviteIds: [UUID] = []

    init(
        currentUserId: UUID,
        fetchedEvent: GameEvent? = nil,
        existingInvites: [Invite] = []
    ) {
        self.currentUserIdValue = currentUserId
        self.storedEvent = fetchedEvent
        self.existingInvites = existingInvites
    }

    func currentUserId() async throws -> UUID {
        currentUserIdValue
    }

    func createEvent(_ event: GameEvent) async throws -> GameEvent {
        createdEvents.append(event)
        storedEvent = event
        return event
    }

    func updateEvent(_ event: GameEvent) async throws {
        updatedEvents.append(event)
        storedEvent = event
    }

    func fetchEvent(id: UUID) async throws -> GameEvent {
        guard let storedEvent else {
            throw TestError.message("missing fetched event")
        }
        return storedEvent
    }

    func createTimeOptions(_ timeOptions: [TimeOption]) async throws {}

    func upsertTimeOptions(_ timeOptions: [TimeOption]) async throws {
        upsertedTimeOptions = timeOptions
        storedEvent?.timeOptions = timeOptions
    }

    func createEventGames(eventId: UUID, games: [EventGame]) async throws {}

    func upsertEventGames(eventId: UUID, games: [EventGame]) async throws {
        upsertedEventGames = games
        storedEvent?.games = games
    }

    func deleteTimeOptions(eventId: UUID) async throws {}

    func deleteTimeOptions(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        storedEvent?.timeOptions.removeAll { ids.contains($0.id) }
    }

    func deleteEventGames(eventId: UUID) async throws {}

    func deleteEventGames(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        storedEvent?.games.removeAll { ids.contains($0.id) }
    }

    func fetchFrequentContacts(limit: Int) async throws -> [FrequentContact] {
        []
    }

    func upsertGame(_ game: Game) async throws -> Game {
        game
    }

    func fetchInvites(eventId: UUID) async throws -> [Invite] {
        existingInvites
    }

    func createInvites(_ invites: [Invite]) async throws {
        createdInvites.append(contentsOf: invites)
        existingInvites.append(contentsOf: invites)
    }

    func updateInvite(_ invite: Invite) async throws {
        updatedInvites.append(invite)
        if let index = existingInvites.firstIndex(where: { $0.id == invite.id }) {
            existingInvites[index] = invite
        }
    }

    func deleteInvites(ids: [UUID]) async throws {
        deletedInviteIds.append(contentsOf: ids)
        existingInvites.removeAll { ids.contains($0.id) }
    }
}
