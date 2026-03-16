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
            draftsResult: .success([])
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
}

private final class StubHomeDataProvider: HomeDataProviding {
    var upcomingEventsResult: Result<[GameEvent], Error>
    var invitesResult: Result<[Invite], Error>
    var draftsResult: Result<[GameEvent], Error>

    init(
        upcomingEventsResult: Result<[GameEvent], Error>,
        invitesResult: Result<[Invite], Error>,
        draftsResult: Result<[GameEvent], Error>
    ) {
        self.upcomingEventsResult = upcomingEventsResult
        self.invitesResult = invitesResult
        self.draftsResult = draftsResult
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
}
