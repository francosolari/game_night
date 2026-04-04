import XCTest
@testable import GameNight

final class AppNotificationTests: XCTestCase {
    func testTimeConfirmedDisplayBodyUsesLocalTimezone() throws {
        let originalTimezone = NSTimeZone.default
        NSTimeZone.default = TimeZone(secondsFromGMT: -5 * 3600)!
        defer { NSTimeZone.default = originalTimezone }

        let notification = try makeNotification(
            body: "Game Night is locked in for Fri, Apr 3 at 8:00 PM UTC.",
            metadata: ["start_time_utc": "2026-04-03T20:00:00Z"]
        )

        let expected = "Game Night is locked in for \(expectedLocalizedTime(fromUTCISO8601: "2026-04-03T20:00:00Z"))."
        XCTAssertEqual(notification.displayBody, expected)
    }

    func testTimeConfirmedDisplayBodyFallsBackToParsingUtcBodyText() throws {
        let originalTimezone = NSTimeZone.default
        NSTimeZone.default = TimeZone(secondsFromGMT: -4 * 3600)!
        defer { NSTimeZone.default = originalTimezone }

        let notification = try makeNotification(
            body: "Game Night is locked in for Fri, Apr 3 at 11:00 PM UTC.",
            metadata: nil
        )

        let expected = "Game Night is locked in for \(expectedLocalizedTime(fromUTCBodyText: "Fri, Apr 3 at 11:00 PM UTC"))."
        XCTAssertEqual(notification.displayBody, expected)
    }

    private func makeNotification(body: String, metadata: [String: String]?) throws -> AppNotification {
        let payload: [String: Any?] = [
            "id": UUID().uuidString,
            "user_id": UUID().uuidString,
            "type": "time_confirmed",
            "title": "Date Confirmed",
            "body": body,
            "metadata": metadata,
            "event_id": nil,
            "invite_id": nil,
            "group_id": nil,
            "conversation_id": nil,
            "read_at": nil,
            "created_at": "2026-04-01T00:00:00Z"
        ]

        let data = try JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 })
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppNotification.self, from: data)
    }

    private func expectedLocalizedTime(fromUTCISO8601 isoString: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        let date = parser.date(from: isoString)!
        return makeDisplayFormatter().string(from: date)
    }

    private func expectedLocalizedTime(fromUTCBodyText utcBody: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "EEE, MMM d 'at' h:mm a zzz"
        let date = parser.date(from: utcBody)!
        return makeDisplayFormatter().string(from: date)
    }

    private func makeDisplayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter
    }
}
