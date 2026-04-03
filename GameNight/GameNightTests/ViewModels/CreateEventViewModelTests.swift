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

    func testNewEventsDefaultToPrivateVisibility() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )

        XCTAssertEqual(sut.visibility, .private)
        XCTAssertNil(sut.rsvpDeadline)
        XCTAssertFalse(sut.allowGuestInvites)
    }

    func testEditModePreloadsVisibilityAndRSVPDeadline() {
        let deadline = Date(timeIntervalSince1970: 1_730_000_000)
        let event = FixtureFactory.makeEvent(
            visibility: .public,
            rsvpDeadline: deadline,
            allowGuestInvites: true
        )
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        XCTAssertEqual(sut.visibility, .public)
        XCTAssertEqual(sut.rsvpDeadline, deadline)
        XCTAssertTrue(sut.allowGuestInvites)
    }

    func testSaveChangesPersistsVisibilityAndRSVPDeadline() async {
        let deadline = Date(timeIntervalSince1970: 1_740_000_000)
        let event = FixtureFactory.makeEvent()
        let service = StubEventEditorService(currentUserId: event.hostId, fetchedEvent: event)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: service
        )
        sut.visibility = .public
        sut.rsvpDeadline = deadline
        sut.allowGuestInvites = true

        await sut.saveChanges()

        XCTAssertEqual(service.updatedEvents.last?.visibility, .public)
        XCTAssertEqual(service.updatedEvents.last?.rsvpDeadline, deadline)
        XCTAssertEqual(service.updatedEvents.last?.allowGuestInvites, true)
        XCTAssertEqual(sut.createdEvent?.visibility, .public)
        XCTAssertEqual(sut.createdEvent?.rsvpDeadline, deadline)
        XCTAssertEqual(sut.createdEvent?.allowGuestInvites, true)
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
        sut.currentStep = .details
        // resolvedTimeOptions recombines date (year/month/day) + time (hour/minute),
        // so the test dates must have zero seconds to survive the round-trip.
        let cal = Calendar.current
        let fixedDate = cal.date(from: DateComponents(year: 2024, month: 7, day: 3))!
        let fixedStart = cal.date(from: DateComponents(year: 2024, month: 7, day: 3, hour: 14, minute: 0))!
        sut.fixedDate = fixedDate
        sut.fixedStartTime = fixedStart

        await sut.saveChanges()

        XCTAssertEqual(service.upsertedTimeOptions.count, 1)
        XCTAssertEqual(service.upsertedTimeOptions.first?.id, originalOption.id)
        XCTAssertEqual(service.upsertedTimeOptions.first?.date, sut.fixedDate)
        XCTAssertEqual(service.upsertedTimeOptions.first?.startTime, sut.fixedStartTime)
        XCTAssertEqual(sut.createdEvent?.timeOptions.first?.date, sut.fixedDate)
        XCTAssertEqual(sut.createdEvent?.timeOptions.first?.startTime, sut.fixedStartTime)
    }

    func testPublishedEditSaveResetsPollStateWhenChangingFromFixedToPoll() async {
        let event = FixtureFactory.makeEvent()
        let service = StubEventEditorService(currentUserId: event.hostId, fetchedEvent: event)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: service
        )
        sut.scheduleMode = .poll

        await sut.saveChanges()

        XCTAssertEqual(service.resetEventPollStateEventIds, [event.id])
    }

    func testPublishedEditSaveDoesNotResetPollStateWhenStayingFixed() async {
        let event = FixtureFactory.makeEvent()
        let service = StubEventEditorService(currentUserId: event.hostId, fetchedEvent: event)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: service
        )
        sut.scheduleMode = .fixed

        await sut.saveChanges()

        XCTAssertTrue(service.resetEventPollStateEventIds.isEmpty)
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
        sut.currentStep = .details
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

    func testUpdateTimeOptionByIdUpdatesMatchingOptionAndResortsByDate() {
        let original = FixtureFactory.makeTimeOption(id: UUID())
        var later = FixtureFactory.makeTimeOption(id: UUID())
        later.date = Date(timeIntervalSince1970: 1_720_000_000)
        later.startTime = Date(timeIntervalSince1970: 1_720_003_600)
        later.label = "Later"

        var event = FixtureFactory.makeEvent(timeOptions: [later, original])
        event.scheduleMode = .poll
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        let updatedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedStart = Date(timeIntervalSince1970: 1_700_003_600)
        let updatedEnd = Date(timeIntervalSince1970: 1_700_007_200)

        sut.updateTimeOption(
            id: later.id,
            date: updatedDate,
            startTime: updatedStart,
            endTime: updatedEnd,
            label: "Earlier"
        )

        XCTAssertEqual(sut.timeOptions.map(\.id), [later.id, original.id])
        XCTAssertEqual(sut.timeOptions.first?.date, updatedDate)
        XCTAssertEqual(sut.timeOptions.first?.startTime, updatedStart)
        XCTAssertEqual(sut.timeOptions.first?.endTime, updatedEnd)
        XCTAssertEqual(sut.timeOptions.first?.label, "Earlier")
    }

    func testRemoveTimeOptionByIdRemovesOnlyMatchingOption() {
        let first = FixtureFactory.makeTimeOption(id: UUID())
        let second = FixtureFactory.makeTimeOption(id: UUID())
        var event = FixtureFactory.makeEvent(timeOptions: [first, second])
        event.scheduleMode = .poll
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        sut.removeTimeOption(id: first.id)

        XCTAssertEqual(sut.timeOptions.map(\.id), [second.id])
    }

    func testConfigureCurrentUserRemovesExistingSelfInviteesByPhoneAndUserId() {
        let hostId = UUID()
        let hostPhone = "+15555550199"
        let event = FixtureFactory.makeEvent()
        let service = StubEventEditorService(currentUserId: hostId)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: service
        )
        sut.invitees = [
            InviteeEntry(
                id: UUID(),
                name: "Me By User",
                phoneNumber: "+15555550001",
                userId: hostId,
                tier: 1
            ),
            InviteeEntry(
                id: UUID(),
                name: "Me By Phone",
                phoneNumber: hostPhone,
                userId: nil,
                tier: 1
            ),
            InviteeEntry(
                id: UUID(),
                name: "Jordan",
                phoneNumber: "+15555550111",
                userId: UUID(),
                tier: 1
            )
        ]

        sut.configureCurrentUser(
            User(
                id: hostId,
                phoneNumber: hostPhone,
                displayName: "Franco",
                avatarUrl: nil,
                bio: nil,
                bggUsername: nil,
                phoneVisible: false,
                discoverableByPhone: true,
                marketingOptIn: false,
                contactsSynced: false,
                phoneVerified: true,
                privacyAcceptedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        )

        XCTAssertEqual(sut.invitees.map(\.name), ["Jordan"])
    }

    func testAddInviteeIgnoresCurrentUserPhone() {
        let hostId = UUID()
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: hostId)
        )

        sut.configureCurrentUser(
            User(
                id: hostId,
                phoneNumber: "+15555550199",
                displayName: "Franco",
                avatarUrl: nil,
                bio: nil,
                bggUsername: nil,
                phoneVisible: false,
                discoverableByPhone: true,
                marketingOptIn: false,
                contactsSynced: false,
                phoneVerified: true,
                privacyAcceptedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        )

        sut.addInvitee(name: "Franco", phoneNumber: "(555) 555-0199", tier: 1)

        XCTAssertTrue(sut.invitees.isEmpty)
    }

    // MARK: - canProceed navigation logic

    func testCanProceedRequiresTitleForDetails() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )
        sut.currentStep = .details
        sut.title = ""

        XCTAssertFalse(sut.canProceed)

        sut.title = "Board Game Night"

        XCTAssertTrue(sut.canProceed)
    }

    func testCanProceedAlwaysTrueForReview() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )
        sut.currentStep = .review

        XCTAssertTrue(sut.canProceed)
    }

    func testCanProceedGamesStepRequiresSelectedGames() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )
        sut.currentStep = .games
        sut.selectedGames = []

        XCTAssertFalse(sut.canProceed)

        sut.selectedGames = [FixtureFactory.makeEventGame()]

        XCTAssertTrue(sut.canProceed)
    }

    func testCanProceedInvitesStepRequiresInvitees() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )
        sut.currentStep = .invites
        sut.invitees = []

        XCTAssertFalse(sut.canProceed)

        sut.invitees = [
            InviteeEntry(id: UUID(), name: "Jordan", phoneNumber: "+15555550111", userId: nil, tier: 1)
        ]

        XCTAssertTrue(sut.canProceed)
    }

    func testAddGamePersistsBGGRelationsAndHydratedGame() async {
        let primaryId = UUID()
        let hydratedGame = Game(
            id: primaryId,
            bggId: 123,
            name: "Dune: Imperium",
            yearPublished: 2020,
            thumbnailUrl: nil,
            imageUrl: "https://example.com/dune.png",
            minPlayers: 1,
            maxPlayers: 4,
            recommendedPlayers: [3, 4],
            minPlaytime: 60,
            maxPlaytime: 120,
            complexity: 3.08,
            bggRating: 8.4,
            description: "Deck building on Arrakis.",
            categories: ["Sci-Fi"],
            mechanics: ["Deck Building"],
            designers: ["Paul Dennen"],
            publishers: ["Dire Wolf"],
            artists: [],
            minAge: 14,
            bggRank: 6
        )
        let expansionGame = Game(
            id: UUID(),
            bggId: 456,
            name: "Rise of Ix",
            yearPublished: 2022,
            thumbnailUrl: nil,
            imageUrl: nil,
            minPlayers: 1,
            maxPlayers: 4,
            recommendedPlayers: nil,
            minPlaytime: 60,
            maxPlaytime: 120,
            complexity: 3.2,
            bggRating: 8.0,
            description: nil,
            categories: [],
            mechanics: [],
            designers: [],
            publishers: [],
            artists: [],
            minAge: nil,
            bggRank: nil
        )

        let service = StubEventEditorService(currentUserId: UUID())
        service.upsertGameResults = [
            123: hydratedGame,
            456: expansionGame
        ]
        let bgg = StubEventGameBGGProvider(
            parseResult: BGGGameParseResult(
                game: hydratedGame,
                expansionLinks: [(bggId: 456, name: "Rise of Ix", isInbound: false)],
                familyLinks: [(bggFamilyId: 999, name: "Dune")]
            )
        )
        let sut = CreateEventViewModel(supabase: service, bgg: bgg)

        await sut.addGame(bggId: 123, isPrimary: true)

        XCTAssertEqual(bgg.requestedBGGIds, [123])
        XCTAssertEqual(service.expansionLinkCalls.count, 1)
        XCTAssertEqual(service.expansionLinkCalls.first?.baseGameId, hydratedGame.id)
        XCTAssertEqual(service.expansionLinkCalls.first?.expansionGameIds, [expansionGame.id])
        XCTAssertEqual(service.familyLinkCalls.count, 1)
        XCTAssertEqual(service.familyLinkCalls.first?.gameId, hydratedGame.id)
        XCTAssertEqual(sut.selectedGames.first?.game?.designers, ["Paul Dennen"])
        XCTAssertEqual(sut.selectedGames.first?.game?.publishers, ["Dire Wolf"])
    }

    func testNavigateToStepAllowsBackwardNavigation() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )
        sut.currentStep = .games
        sut.completedSteps = [.details]

        sut.navigateToStep(.details)

        XCTAssertEqual(sut.currentStep, .details)
    }

    func testNavigateToStepBlocksSkippingAhead() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )
        sut.currentStep = .details
        sut.completedSteps = []

        sut.navigateToStep(.review)

        XCTAssertEqual(sut.currentStep, .details)
    }

    func testCanNavigateToStepAllowsAllStepsInEditMode() {
        let event = FixtureFactory.makeEvent()
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        for step in CreateEventViewModel.CreateStep.allCases {
            XCTAssertTrue(sut.canNavigateToStep(step), "Should allow navigating to \(step) in published edit mode")
        }
    }

    func testMarkCurrentStepCompletedAddsToSet() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )
        sut.currentStep = .details

        XCTAssertFalse(sut.completedSteps.contains(.details))

        sut.markCurrentStepCompleted()

        XCTAssertTrue(sut.completedSteps.contains(.details))
    }

    func testNewEventCoverPreviewPersistsAcrossViewModelRecreation() {
        let suiteName = "CreateEventViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = StubEventEditorService(currentUserId: UUID())
        let first = CreateEventViewModel(supabase: service, userDefaults: defaults)
        first.coverVariant = 4

        let second = CreateEventViewModel(supabase: service, userDefaults: defaults)

        XCTAssertEqual(second.previewEventId, first.previewEventId)
        XCTAssertEqual(second.coverVariant, 4)
    }

    func testDiscardingNewEventClearsPersistedCoverPreview() {
        let suiteName = "CreateEventViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = StubEventEditorService(currentUserId: UUID())
        let first = CreateEventViewModel(supabase: service, userDefaults: defaults)
        first.coverVariant = 4

        first.discardCreateSession()

        let second = CreateEventViewModel(supabase: service, userDefaults: defaults)

        XCTAssertNotEqual(second.previewEventId, first.previewEventId)
        XCTAssertEqual(second.coverVariant, 0)
    }

    // MARK: - Draft initialization

    func testDraftEditPreloadsCompletedStepsAndNavigatesToFirstIncomplete() {
        let game = FixtureFactory.makeEventGame(game: FixtureFactory.makeGame(name: "Dune"))
        let event = FixtureFactory.makeEvent(
            title: "Draft Night",
            status: .draft,
            games: [game]
        )
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        XCTAssertTrue(sut.completedSteps.contains(.details))
        XCTAssertTrue(sut.completedSteps.contains(.games))
        XCTAssertFalse(sut.completedSteps.contains(.invites))
        XCTAssertEqual(sut.currentStep, .invites)
    }

    // MARK: - RSVP Options (plus-one, maybe, require names)

    func testDefaultPlusOneLimitIsZero() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )

        XCTAssertEqual(sut.plusOneLimit, 0)
    }

    func testDefaultAllowMaybeRSVPIsTrue() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )

        XCTAssertTrue(sut.allowMaybeRSVP)
    }

    func testDefaultRequirePlusOneNamesIsFalse() {
        let sut = CreateEventViewModel(
            supabase: StubEventEditorService(currentUserId: UUID())
        )

        XCTAssertFalse(sut.requirePlusOneNames)
    }

    func testEditModePreloadsPlusOneLimitFromEvent() {
        let event = FixtureFactory.makeEvent(plusOneLimit: 2)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        XCTAssertEqual(sut.plusOneLimit, 2)
    }

    func testEditModePreloadsAllowMaybeRSVPFromEvent() {
        let event = FixtureFactory.makeEvent(allowMaybeRSVP: false)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        XCTAssertFalse(sut.allowMaybeRSVP)
    }

    func testEditModePreloadsRequirePlusOneNamesFromEvent() {
        let event = FixtureFactory.makeEvent(requirePlusOneNames: true)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        XCTAssertTrue(sut.requirePlusOneNames)
    }

    func testSaveChangesPersistsRSVPOptions() async {
        let event = FixtureFactory.makeEvent()
        let service = StubEventEditorService(currentUserId: event.hostId, fetchedEvent: event)
        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: service
        )
        sut.plusOneLimit = 3
        sut.allowMaybeRSVP = false
        sut.requirePlusOneNames = true

        await sut.saveChanges()

        XCTAssertEqual(service.updatedEvents.last?.plusOneLimit, 3)
        XCTAssertEqual(service.updatedEvents.last?.allowMaybeRSVP, false)
        XCTAssertEqual(service.updatedEvents.last?.requirePlusOneNames, true)
    }

    func testDraftEditWithDraftInviteesPreloadsInviteeEntries() {
        let inviteeId = UUID()
        let draftInvitees = [
            DraftInvitee(
                id: inviteeId,
                name: "Jordan",
                phoneNumber: "+15555550111",
                userId: nil,
                tier: 1,
                groupId: nil,
                groupEmoji: nil
            )
        ]
        var event = FixtureFactory.makeEvent(status: .draft)
        event.draftInvitees = draftInvitees

        let sut = CreateEventViewModel(
            eventToEdit: event,
            initialInvites: [],
            supabase: StubEventEditorService(currentUserId: event.hostId)
        )

        XCTAssertEqual(sut.invitees.count, 1)
        XCTAssertEqual(sut.invitees.first?.name, "Jordan")
        XCTAssertEqual(sut.invitees.first?.phoneNumber, "+15555550111")
        XCTAssertEqual(sut.invitees.first?.id, inviteeId)
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

    func testInviteSummaryIncludesHostAsGoingWithoutInviteRow() {
        let hostId = UUID()
        let host = FixtureFactory.makeUser(id: hostId, displayName: "Franco")
        let event = FixtureFactory.makeEvent(host: host)
        let sut = EventViewModel()
        sut.event = event
        sut.invites = []

        XCTAssertEqual(sut.inviteSummary.accepted, 1)
        XCTAssertEqual(sut.inviteSummary.acceptedUsers.first?.id, hostId)
        XCTAssertEqual(sut.inviteSummary.acceptedUsers.first?.name, "Franco")
    }

    func testInviteSummaryGroupsByStatusCorrectly() {
        let hostId = UUID()
        let host = FixtureFactory.makeUser(id: hostId, displayName: "Franco")
        let event = FixtureFactory.makeEvent(host: host)
        let sut = EventViewModel()
        sut.event = event
        sut.invites = [
            makeInvite(displayName: "Jordan", phoneNumber: "+15555550111", tier: 1, status: .accepted),
            makeInvite(displayName: "Casey", phoneNumber: "+15555550112", tier: 1, status: .declined),
            makeInvite(displayName: "Alex", phoneNumber: "+15555550113", tier: 1, status: .maybe),
            makeInvite(displayName: "Sam", phoneNumber: "+15555550114", tier: 1, status: .pending),
            makeInvite(displayName: "Riley", phoneNumber: "+15555550115", tier: 2, status: .waitlisted),
        ]

        let summary = sut.inviteSummary

        XCTAssertEqual(summary.accepted, 2) // Jordan + host
        XCTAssertEqual(summary.declined, 1)
        XCTAssertEqual(summary.maybe, 1)
        XCTAssertEqual(summary.pending, 1)
        XCTAssertEqual(summary.waitlisted, 1)
        XCTAssertTrue(summary.acceptedUsers.contains { $0.name == "Jordan" })
        XCTAssertTrue(summary.acceptedUsers.contains { $0.name == "Franco" })
        XCTAssertEqual(summary.declinedUsers.first?.name, "Casey")
    }

    func testInviteSummaryExcludesHostByUserId() {
        let hostId = UUID()
        let host = FixtureFactory.makeUser(id: hostId, displayName: "Franco")
        let event = FixtureFactory.makeEvent(host: host)
        let sut = EventViewModel()
        sut.event = event

        let hostInvite = Invite(
            id: UUID(),
            eventId: event.id,
            hostUserId: hostId,
            userId: hostId,
            phoneNumber: "+15555550199",
            displayName: "Franco",
            status: .accepted,
            tier: 1,
            tierPosition: 0,
            isActive: true,
            respondedAt: nil,
            selectedTimeOptionIds: [],
            suggestedTimes: nil,
            sentVia: .both,
            smsDeliveryStatus: .delivered,
            createdAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
        sut.invites = [hostInvite]

        let summary = sut.inviteSummary

        // Host invite should be excluded, but host is still counted via the host user logic
        XCTAssertEqual(summary.accepted, 1)
        XCTAssertEqual(summary.acceptedUsers.count, 1)
        XCTAssertEqual(summary.acceptedUsers.first?.name, "Franco")
    }

    func testInviteSummaryExcludesHostByPhoneNumber() {
        let hostId = UUID()
        let hostPhone = "19543482945"
        let host = FixtureFactory.makeUser(id: hostId, displayName: "Franco")
        let event = FixtureFactory.makeEvent(host: host)
        let sut = EventViewModel()
        sut.event = event

        let hostInviteByPhone = Invite(
            id: UUID(),
            eventId: event.id,
            hostUserId: hostId,
            userId: nil,
            phoneNumber: hostPhone,
            displayName: "Franco",
            status: .accepted,
            tier: 1,
            tierPosition: 0,
            isActive: true,
            respondedAt: nil,
            selectedTimeOptionIds: [],
            suggestedTimes: nil,
            sentVia: .both,
            smsDeliveryStatus: .delivered,
            createdAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
        sut.invites = [hostInviteByPhone]

        let summary = sut.inviteSummary

        // Host invite matched by phone should be excluded
        XCTAssertEqual(summary.accepted, 1)
        XCTAssertEqual(summary.acceptedUsers.count, 1)
        XCTAssertEqual(summary.acceptedUsers.first?.name, "Franco")
    }

    func testInviteSummaryWithNoInvitesShowsOnlyHost() {
        let host = FixtureFactory.makeUser(displayName: "Franco")
        let event = FixtureFactory.makeEvent(host: host)
        let sut = EventViewModel()
        sut.event = event
        sut.invites = []

        let summary = sut.inviteSummary

        XCTAssertEqual(summary.total, 1)
        XCTAssertEqual(summary.accepted, 1)
        XCTAssertEqual(summary.declined, 0)
        XCTAssertEqual(summary.pending, 0)
        XCTAssertEqual(summary.maybe, 0)
        XCTAssertEqual(summary.waitlisted, 0)
        XCTAssertEqual(summary.acceptedUsers.first?.name, "Franco")
    }
}

final class EventEditSavePresentationTests: XCTestCase {
    func testRegisteredSaveIsNotConsumedWhileSheetIsPresented() {
        var sut = EventEditSavePresentation()
        let event = FixtureFactory.makeEvent(title: "Updated")

        sut.register(event)

        XCTAssertNil(sut.consumeIfSheetDismissed(isSheetPresented: true))
    }

    func testRegisteredSaveIsConsumedAfterSheetDismisses() {
        var sut = EventEditSavePresentation()
        let event = FixtureFactory.makeEvent(title: "Updated")

        sut.register(event)

        let consumed = sut.consumeIfSheetDismissed(isSheetPresented: false)

        XCTAssertEqual(consumed?.id, event.id)
        XCTAssertNil(sut.consumeIfSheetDismissed(isSheetPresented: false))
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
    var upsertGameResults: [Int: Game] = [:]
    var createdEvents: [GameEvent] = []
    var updatedEvents: [GameEvent] = []
    var upsertedTimeOptions: [TimeOption] = []
    var upsertedEventGames: [EventGame] = []
    var resetEventPollStateEventIds: [UUID] = []
    var createdInvites: [Invite] = []
    var updatedInvites: [Invite] = []
    var deletedInviteIds: [UUID] = []
    var expansionLinkCalls: [(baseGameId: UUID, expansionGameIds: [UUID])] = []
    var familyLinkCalls: [(gameId: UUID, families: [(bggFamilyId: Int, name: String)])] = []

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

    func resetEventPollState(eventId: UUID) async throws {
        resetEventPollStateEventIds.append(eventId)
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
        if let bggId = game.bggId, let result = upsertGameResults[bggId] {
            return result
        }
        return game
    }

    func updateGame(_ game: Game) async throws {}

    func updateGameImageUrl(gameId: UUID, imageUrl: String) async throws {}

    func updateEventCoverImageUrl(eventId: UUID, coverImageUrl: String) async throws {
        storedEvent?.coverImageUrl = coverImageUrl
    }

    func addGameToLibrary(gameId: UUID, categoryId: UUID?) async throws {}

    func fetchGameLibrary() async throws -> [GameLibraryEntry] {
        []
    }

    func upsertExpansionLinks(baseGameId: UUID, expansionGameIds: [UUID]) async throws {
        expansionLinkCalls.append((baseGameId: baseGameId, expansionGameIds: expansionGameIds))
    }

    func upsertFamilyLinks(gameId: UUID, families: [(bggFamilyId: Int, name: String)]) async throws {
        familyLinkCalls.append((gameId: gameId, families: families))
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

private final class StubEventGameBGGProvider: EventGameBGGProviding {
    let parseResult: BGGGameParseResult
    private(set) var requestedBGGIds: [Int] = []

    init(parseResult: BGGGameParseResult) {
        self.parseResult = parseResult
    }

    func searchGames(query: String) async throws -> [BGGSearchResult] {
        []
    }

    func fetchGameDetailsWithRelations(bggId: Int) async throws -> BGGGameParseResult {
        requestedBGGIds.append(bggId)
        return parseResult
    }
}

@MainActor
final class GameDetailViewModelTests: XCTestCase {
    func testLoadRelatedDataHydratesBGGGameAndPersistsRelationLinks() async {
        let originalGame = Game(
            id: UUID(),
            bggId: 123,
            name: "Dune: Imperium",
            yearPublished: 2020,
            thumbnailUrl: nil,
            imageUrl: nil,
            minPlayers: 1,
            maxPlayers: 4,
            recommendedPlayers: nil,
            minPlaytime: 60,
            maxPlaytime: 120,
            complexity: 3.0,
            bggRating: 8.4,
            description: nil,
            categories: [],
            mechanics: [],
            designers: [],
            publishers: [],
            artists: [],
            minAge: nil,
            bggRank: nil
        )

        let hydratedGame = Game(
            id: originalGame.id,
            bggId: 123,
            name: "Dune: Imperium",
            yearPublished: 2020,
            thumbnailUrl: nil,
            imageUrl: "https://example.com/dune.png",
            minPlayers: 1,
            maxPlayers: 4,
            recommendedPlayers: [3, 4],
            minPlaytime: 60,
            maxPlaytime: 120,
            complexity: 3.08,
            bggRating: 8.4,
            description: "Deck building on Arrakis.",
            categories: ["Sci-Fi"],
            mechanics: ["Deck Building"],
            designers: ["Paul Dennen"],
            publishers: ["Dire Wolf"],
            artists: ["Clay Brooks"],
            minAge: 14,
            bggRank: 6
        )

        let expansionGame = Game(
            id: UUID(),
            bggId: 456,
            name: "Rise of Ix",
            yearPublished: 2022,
            thumbnailUrl: nil,
            imageUrl: nil,
            minPlayers: 1,
            maxPlayers: 4,
            recommendedPlayers: nil,
            minPlaytime: 60,
            maxPlaytime: 120,
            complexity: 3.2,
            bggRating: 8.0,
            description: nil,
            categories: [],
            mechanics: [],
            designers: [],
            publishers: [],
            artists: [],
            minAge: nil,
            bggRank: nil
        )

        let service = StubGameDetailDataProvider(
            upsertResults: [
                123: hydratedGame,
                456: expansionGame
            ],
            expansions: [expansionGame]
        )
        let bgg = StubGameDetailBGGProvider(
            result: BGGGameParseResult(
                game: hydratedGame,
                expansionLinks: [(bggId: 456, name: "Rise of Ix", isInbound: false)],
                familyLinks: [(bggFamilyId: 999, name: "Dune")]
            )
        )

        let sut = GameDetailViewModel(game: originalGame, supabase: service, bgg: bgg)

        await sut.loadRelatedData()

        XCTAssertEqual(bgg.requestedBGGIds, [123])
        XCTAssertEqual(service.upsertedGames.map(\.bggId).compactMap { $0 }, [123, 456])
        XCTAssertEqual(service.expansionLinkCalls.count, 1)
        XCTAssertEqual(service.expansionLinkCalls.first?.baseGameId, originalGame.id)
        XCTAssertEqual(service.expansionLinkCalls.first?.expansionGameIds, [expansionGame.id])
        XCTAssertEqual(service.familyLinkCalls.count, 1)
        XCTAssertEqual(service.familyLinkCalls.first?.gameId, originalGame.id)
        XCTAssertEqual(service.familyLinkCalls.first?.families.first?.name, "Dune")
        XCTAssertEqual(sut.game.designers, ["Paul Dennen"])
    }
}

private final class StubGameDetailDataProvider: GameDetailDataProviding {
    var upsertResults: [Int: Game]
    var expansions: [Game]
    var upsertedGames: [Game] = []
    var expansionLinkCalls: [(baseGameId: UUID, expansionGameIds: [UUID])] = []
    var familyLinkCalls: [(gameId: UUID, families: [(bggFamilyId: Int, name: String)])] = []

    init(upsertResults: [Int: Game], expansions: [Game] = []) {
        self.upsertResults = upsertResults
        self.expansions = expansions
    }

    func fetchGame(id: UUID) async throws -> Game? {
        nil
    }

    func upsertGame(_ game: Game) async throws -> Game {
        upsertedGames.append(game)
        if let bggId = game.bggId, let result = upsertResults[bggId] {
            return result
        }
        return game
    }

    func fetchExpansions(gameId: UUID) async throws -> [Game] {
        expansions
    }

    func fetchBaseGame(expansionGameId: UUID) async throws -> Game? {
        nil
    }

    func fetchFamilyMembers(gameId: UUID) async throws -> [(family: GameFamily, games: [Game])] {
        []
    }

    func upsertExpansionLinks(baseGameId: UUID, expansionGameIds: [UUID]) async throws {
        expansionLinkCalls.append((baseGameId: baseGameId, expansionGameIds: expansionGameIds))
    }

    func upsertFamilyLinks(gameId: UUID, families: [(bggFamilyId: Int, name: String)]) async throws {
        familyLinkCalls.append((gameId: gameId, families: families))
    }
}

private final class StubGameDetailBGGProvider: GameDetailBGGProviding {
    let result: BGGGameParseResult
    private(set) var requestedBGGIds: [Int] = []

    init(result: BGGGameParseResult) {
        self.result = result
    }

    func fetchGameDetailsWithRelations(bggId: Int) async throws -> BGGGameParseResult {
        requestedBGGIds.append(bggId)
        return result
    }
}
