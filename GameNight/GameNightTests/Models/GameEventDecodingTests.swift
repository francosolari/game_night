import XCTest
@testable import GameNight

final class GameEventDecodingTests: XCTestCase {
    func testDecodesMissingVotingFieldsWithSafeDefaults() throws {
        let decoder = JSONTestHelpers.makeEventDecoder()
        let payload: [String: Any] = [
            "id": "a2abf3e8-91bf-4560-9d37-b0170b2967a6",
            "host_id": "1652326c-1d56-4d1e-8453-354e55262c5f",
            "title": "Game Night",
            "description": NSNull(),
            "location": "Alex's House",
            "location_address": NSNull(),
            "status": "published",
            "games": [],
            "time_options": [],
            "confirmed_time_option_id": NSNull(),
            "allow_time_suggestions": true,
            "schedule_mode": "fixed",
            "invite_strategy": [
                "type": "all_at_once",
                "autoPromote": true
            ],
            "min_players": 3,
            "max_players": 6,
            "cover_image_url": NSNull(),
            "draft_invitees": NSNull(),
            "deleted_at": NSNull(),
            "created_at": "2026-03-16T12:09:11.226+00:00",
            "updated_at": "2026-03-16T12:09:11.226+00:00"
        ]

        let event = try decoder.decode(GameEvent.self, from: try JSONTestHelpers.makeJSONData(payload))

        XCTAssertFalse(event.allowGameVoting)
        XCTAssertNil(event.confirmedGameId)
    }

    func testDropsMalformedNestedRelationsButKeepsBaseEvent() throws {
        let decoder = JSONTestHelpers.makeEventDecoder()
        let payload: [String: Any] = [
            "id": "a2abf3e8-91bf-4560-9d37-b0170b2967a6",
            "host_id": "1652326c-1d56-4d1e-8453-354e55262c5f",
            "host": [
                "id": "1652326c-1d56-4d1e-8453-354e55262c5f",
                "phone_number": NSNull(),
                "display_name": "Franco",
                "avatar_url": NSNull(),
                "bio": NSNull(),
                "bgg_username": "francosolari",
                "phone_visible": false,
                "discoverable_by_phone": true,
                "marketing_opt_in": false,
                "contacts_synced": false,
                "phone_verified": true,
                "privacy_accepted_at": NSNull(),
                "created_at": "2026-03-15T17:45:50.881+00:00",
                "updated_at": "2026-03-16T12:01:16.581333+00:00"
            ],
            "title": "Game Night",
            "description": NSNull(),
            "location": "Alex's House",
            "location_address": NSNull(),
            "status": "published",
            "games": [[
                "id": "e138db1b-29c0-4db7-ab7e-9e986211a177",
                "game_id": "5a9e109f-f00e-45b2-8204-db097517ebb4",
                "game": [
                    "id": "5a9e109f-f00e-45b2-8204-db097517ebb4",
                    "bgg_id": NSNull(),
                    "name": "Dune",
                    "year_published": NSNull(),
                    "thumbnail_url": NSNull(),
                    "image_url": NSNull(),
                    "min_players": 1,
                    "max_players": 6,
                    "recommended_players": NSNull(),
                    "min_playtime": 30,
                    "max_playtime": 120,
                    "complexity": 3.0,
                    "bgg_rating": NSNull(),
                    "description": NSNull(),
                    "categories": [],
                    "mechanics": []
                ],
                "is_primary": true,
                "sort_order": 0,
                "yes_count": 0,
                "maybe_count": 0,
                "no_count": 0
            ]],
            "time_options": [[
                "id": "0c883a99-59c0-4cdc-8ebc-1eaec3e9e67e",
                "event_id": "a2abf3e8-91bf-4560-9d37-b0170b2967a6",
                "date": "2026-03-16",
                "start_time": "2026-03-16T12:08:55.705+00:00",
                "end_time": NSNull(),
                "label": NSNull(),
                "is_suggested": false,
                "suggested_by": NSNull(),
                "vote_count": "bad",
                "maybe_count": 0
            ]],
            "confirmed_time_option_id": NSNull(),
            "allow_time_suggestions": true,
            "schedule_mode": "fixed",
            "invite_strategy": [
                "type": "all_at_once",
                "autoPromote": true
            ],
            "min_players": 3,
            "max_players": 6,
            "allow_game_voting": false,
            "confirmed_game_id": NSNull(),
            "cover_image_url": NSNull(),
            "draft_invitees": NSNull(),
            "deleted_at": NSNull(),
            "created_at": "2026-03-16T12:09:11.226+00:00",
            "updated_at": "2026-03-16T12:09:11.226+00:00"
        ]

        let event = try decoder.decode(GameEvent.self, from: try JSONTestHelpers.makeJSONData(payload))

        XCTAssertNil(event.host)
        XCTAssertEqual(event.games.count, 1)
        XCTAssertTrue(event.timeOptions.isEmpty)
    }
}
