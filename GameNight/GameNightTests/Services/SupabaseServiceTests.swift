import XCTest
@testable import GameNight

final class SupabaseServiceTests: XCTestCase {
    @MainActor
    func testEventSelectContainsRequiredRelations() {
        let select = SupabaseService.eventSelect

        XCTAssertTrue(select.contains("host:users(*)"), "eventSelect must include host relation")
        XCTAssertTrue(select.contains("games:event_games(*, game:games(*))"), "eventSelect must include nested games relation")
        XCTAssertTrue(select.contains("time_options!event_id(*)"), "eventSelect must include time_options relation")
    }
}
