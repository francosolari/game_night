import XCTest
@testable import GameNight

final class AppNotificationTests: XCTestCase {
    func testTimeConfirmedDisplayBodyUsesLocalTimezone() {
        let originalTimezone = TimeZone.default
        TimeZone.default = TimeZone(secondsFromGMT: -5 * 3600)!
        defer { TimeZone.default = originalTimezone }

        let notification = AppNotification(
            id: UUID(),
            userId: UUID(),
            type: .timeConfirmed,
            title: "Date Confirmed",
            body: "Game Night is locked in for Fri, Apr 3 at 8:00 PM UTC.",
            metadata: ["start_time_utc": "2026-04-03T20:00:00Z"],
            eventId: nil,
            inviteId: nil,
            groupId: nil,
            conversationId: nil,
            readAt: nil,
            createdAt: Date()
        )

        XCTAssertEqual(notification.displayBody, "Game Night is locked in for Fri, Apr 3 at 3:00 PM.")
    }
}
