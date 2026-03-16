import XCTest
@testable import GameNight

final class TimeOptionTests: XCTestCase {
    func testRelativeTimeDisplay() {
        let calendar = Calendar.current
        let now = Date()
        
        // Test: Today
        let today = TimeOption(id: UUID(), date: now, startTime: now, isSuggested: false, voteCount: 0, maybeCount: 0)
        XCTAssertEqual(today.relativeTimeDisplay, "Today")
        
        // Test: Tomorrow
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now)!
        let tomorrow = TimeOption(id: UUID(), date: tomorrowDate, startTime: tomorrowDate, isSuggested: false, voteCount: 0, maybeCount: 0)
        XCTAssertEqual(tomorrow.relativeTimeDisplay, "Tomorrow")
        
        // Test: 3 days away
        let threeDaysDate = calendar.date(byAdding: .day, value: 3, to: now)!
        let threeDays = TimeOption(id: UUID(), date: threeDaysDate, startTime: threeDaysDate, isSuggested: false, voteCount: 0, maybeCount: 0)
        XCTAssertEqual(threeDays.relativeTimeDisplay, "3 days away")
        
        // Test: 1 month away
        let oneMonthDate = calendar.date(byAdding: .day, value: 31, to: now)!
        let oneMonth = TimeOption(id: UUID(), date: oneMonthDate, startTime: oneMonthDate, isSuggested: false, voteCount: 0, maybeCount: 0)
        XCTAssertEqual(oneMonth.relativeTimeDisplay, "1 month away")
        
        // Test: 2 months away
        let twoMonthsDate = calendar.date(byAdding: .month, value: 2, to: now)!
        let twoMonths = TimeOption(id: UUID(), date: twoMonthsDate, startTime: twoMonthsDate, isSuggested: false, voteCount: 0, maybeCount: 0)
        XCTAssertEqual(twoMonths.relativeTimeDisplay, "2 months away")
    }
}
