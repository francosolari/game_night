import XCTest
@testable import GameNight

final class EventVisibilityTests: XCTestCase {
    func testGameEventDecodesMissingVisibilityAsPrivate() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "host_id": "00000000-0000-0000-0000-000000000002",
          "title": "Game Night",
          "description": "Bring snacks",
          "location": "Alex's House",
          "location_address": "123 Main St, Washington, DC",
          "status": "published",
          "games": [],
          "time_options": [],
          "allow_time_suggestions": true,
          "schedule_mode": "fixed",
          "invite_strategy": {
            "type": "all_at_once",
            "tierSize": null,
            "autoPromote": true
          },
          "min_players": 3,
          "max_players": 6,
          "allow_game_voting": false,
          "created_at": 1710000000,
          "updated_at": 1710000100
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let event = try decoder.decode(GameEvent.self, from: json)

        XCTAssertEqual(event.visibility, .private)
        XCTAssertNil(event.rsvpDeadline)
    }

    func testGameEventRoundTripsVisibilityAndRSVPDeadline() throws {
        let deadline = Date(timeIntervalSince1970: 1_720_500_000)
        let event = FixtureFactory.makeEvent(
            visibility: .public,
            rsvpDeadline: deadline,
            allowGuestInvites: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(GameEvent.self, from: data)

        XCTAssertEqual(decoded.visibility, .public)
        XCTAssertEqual(decoded.rsvpDeadline, deadline)
        XCTAssertTrue(decoded.allowGuestInvites)
    }
}
