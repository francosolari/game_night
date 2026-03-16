import XCTest
@testable import GameNight

final class HomeDataLoaderTests: XCTestCase {
    func testLoadReturnsPartialSnapshotWhenInvitesFail() async {
        let event = FixtureFactory.makeEvent()
        let draft = FixtureFactory.makeEvent(status: .draft)

        let snapshot = await HomeDataLoader.load(
            fetchUpcomingEvents: { [event] in [event] },
            fetchMyInvites: { throw TestError.message("invite query failed") },
            fetchDrafts: { [draft] in [draft] }
        )

        XCTAssertEqual(snapshot.upcomingEvents.map(\.id), [event.id])
        XCTAssertEqual(snapshot.myInvites.count, 0)
        XCTAssertEqual(snapshot.drafts.map(\.id), [draft.id])
        XCTAssertEqual(snapshot.errorMessage, "Invites: invite query failed")
    }

    func testLoadAggregatesFailuresInStableOrder() async {
        let snapshot = await HomeDataLoader.load(
            fetchUpcomingEvents: { throw TestError.message("events failed") },
            fetchMyInvites: { throw TestError.message("invites failed") },
            fetchDrafts: { throw TestError.message("drafts failed") }
        )

        XCTAssertEqual(
            snapshot.errorMessage,
            """
            Upcoming Events: events failed
            Invites: invites failed
            Drafts: drafts failed
            """
        )
    }
}
