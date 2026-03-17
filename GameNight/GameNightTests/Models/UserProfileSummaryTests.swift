import XCTest
@testable import GameNight

final class UserProfileSummaryTests: XCTestCase {
    func testDecodesProfileSummaryFromSnakeCasePayload() throws {
        let json = """
        {
          "user_id": "11111111-1111-1111-1111-111111111111",
          "joined_at": "2026-03-01T12:00:00Z",
          "hosted_event_count": 4,
          "attended_event_count": 11,
          "group_count": 3
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let summary = try decoder.decode(UserProfileSummary.self, from: json)

        XCTAssertEqual(summary.userId.uuidString, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(summary.hostedEventCount, 4)
        XCTAssertEqual(summary.attendedEventCount, 11)
        XCTAssertEqual(summary.groupCount, 3)
    }
}
