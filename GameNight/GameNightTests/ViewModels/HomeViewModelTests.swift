import XCTest
@testable import GameNight

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testLoadDataKeepsSuccessfulResultsWhenOneSourceFails() async {
        let event = FixtureFactory.makeEvent()
        let draft = FixtureFactory.makeEvent(status: .draft)
        let provider = StubHomeDataProvider(
            upcomingEventsResult: .success([event]),
            invitesResult: .failure(TestError.message("invite query failed")),
            draftsResult: .success([draft])
        )
        let sut = HomeViewModel(supabase: provider)

        await sut.loadData()

        XCTAssertEqual(sut.upcomingEvents.map(\.id), [event.id])
        XCTAssertEqual(sut.drafts.map(\.id), [draft.id])
        XCTAssertEqual(sut.myInvites.count, 0)
        XCTAssertEqual(sut.error, "Invites: invite query failed")
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadDataClearsPreviousErrorAfterSuccessfulReload() async {
        let event = FixtureFactory.makeEvent()
        let provider = StubHomeDataProvider(
            upcomingEventsResult: .failure(TestError.message("events failed")),
            invitesResult: .success([]),
            draftsResult: .success([]),
            fetchedEventsResult: .success([])
        )
        let sut = HomeViewModel(supabase: provider)

        await sut.loadData()
        XCTAssertEqual(sut.error, "Upcoming Events: events failed")

        provider.upcomingEventsResult = .success([event])

        await sut.loadData()

        XCTAssertEqual(sut.upcomingEvents.map(\.id), [event.id])
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadDataMergesAcceptedPrivateInviteEventsIntoUpcoming() async {
        let publicEvent = FixtureFactory.makeEvent(visibility: .public)
        let privateInviteEvent = FixtureFactory.makeEvent(visibility: .private)
        let provider = StubHomeDataProvider(
            upcomingEventsResult: .success([publicEvent]),
            invitesResult: .success([
                FixtureFactory.makeInvite(
                    eventId: privateInviteEvent.id,
                    status: .accepted
                )
            ]),
            draftsResult: .success([]),
            fetchedEventsResult: .success([privateInviteEvent])
        )
        let sut = HomeViewModel(supabase: provider)

        await sut.loadData()

        XCTAssertEqual(Set(sut.upcomingEvents.map(\.id)), Set([publicEvent.id, privateInviteEvent.id]))
        XCTAssertEqual(provider.fetchedEventIds, [privateInviteEvent.id])
    }

    func testLoadDataDoesNotSurfacePendingPrivateInvitesInUpcoming() async {
        let publicEvent = FixtureFactory.makeEvent(visibility: .public)
        let privateInviteEvent = FixtureFactory.makeEvent(visibility: .private)
        let pendingInvite = FixtureFactory.makeInvite(
            eventId: privateInviteEvent.id,
            status: .pending
        )
        let provider = StubHomeDataProvider(
            upcomingEventsResult: .success([publicEvent]),
            invitesResult: .success([pendingInvite]),
            draftsResult: .success([]),
            fetchedEventsResult: .success([privateInviteEvent])
        )
        let sut = HomeViewModel(supabase: provider)

        await sut.loadData()

        XCTAssertEqual(sut.upcomingEvents.map(\.id), [publicEvent.id])
        XCTAssertEqual(provider.fetchedEventIds, [privateInviteEvent.id])
        XCTAssertEqual(sut.awaitingResponseEvents.map(\.event.id), [privateInviteEvent.id])
        XCTAssertEqual(sut.awaitingResponseEvents.first?.invite.id, pendingInvite.id)
    }
}

private final class StubHomeDataProvider: HomeDataProviding {
    var upcomingEventsResult: Result<[GameEvent], Error>
    var invitesResult: Result<[Invite], Error>
    var draftsResult: Result<[GameEvent], Error>
    var fetchedEventsResult: Result<[GameEvent], Error>
    var fetchedEventIds: [UUID] = []

    init(
        upcomingEventsResult: Result<[GameEvent], Error>,
        invitesResult: Result<[Invite], Error>,
        draftsResult: Result<[GameEvent], Error>,
        fetchedEventsResult: Result<[GameEvent], Error> = .success([])
    ) {
        self.upcomingEventsResult = upcomingEventsResult
        self.invitesResult = invitesResult
        self.draftsResult = draftsResult
        self.fetchedEventsResult = fetchedEventsResult
    }

    func fetchUpcomingEvents() async throws -> [GameEvent] {
        try upcomingEventsResult.get()
    }

    func fetchMyInvites() async throws -> [Invite] {
        try invitesResult.get()
    }

    func fetchDrafts() async throws -> [GameEvent] {
        try draftsResult.get()
    }

    func fetchEvents(ids: [UUID]) async throws -> [GameEvent] {
        fetchedEventIds = ids
        return try fetchedEventsResult.get()
    }

    func fetchAcceptedInviteCounts(eventIds: [UUID]) async throws -> [UUID: Int] {
        [:]
    }
}
