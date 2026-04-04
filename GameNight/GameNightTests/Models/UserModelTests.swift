import XCTest
@testable import GameNight

/// Tests for User model — specifically the serialization contract required for upsert
/// and the maskedPhone display logic.
final class UserModelTests: XCTestCase {

    // MARK: - maskedPhone

    func testMaskedPhoneShowsLast4Digits() {
        let user = FixtureFactory.makeUser()
        // FixtureFactory phone: "19543482945", last 4 = "2945"
        XCTAssertEqual(user.maskedPhone, "***-***-2945")
    }

    func testMaskedPhoneWithExactly4Digits() {
        let user = FixtureFactory.makeUser()
        var u = user
        u.phoneNumber = "1234"
        XCTAssertEqual(u.maskedPhone, "***-***-1234")
    }

    func testMaskedPhoneWithFewerThan4Digits_returnsSafeDefault() {
        var user = FixtureFactory.makeUser()
        user.phoneNumber = "123"
        XCTAssertEqual(user.maskedPhone, "***")
    }

    func testMaskedPhoneWithEmptyString_returnsSafeDefault() {
        var user = FixtureFactory.makeUser()
        user.phoneNumber = ""
        XCTAssertEqual(user.maskedPhone, "***")
    }

    // MARK: - Codable round-trip (required for upsert serialization)

    func testUserEncodesWithCorrectSnakeCaseKeys() throws {
        let user = FixtureFactory.makeUser()
        let data = try JSONEncoder().encode(user)
        let dict = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        // These keys must match the Supabase column names for upsert to land correctly
        XCTAssertNotNil(dict["id"], "Missing 'id'")
        XCTAssertNotNil(dict["phone_number"], "Missing 'phone_number'")
        XCTAssertNotNil(dict["display_name"], "Missing 'display_name'")
        XCTAssertNotNil(dict["phone_visible"], "Missing 'phone_visible'")
        XCTAssertNotNil(dict["discoverable_by_phone"], "Missing 'discoverable_by_phone'")
        XCTAssertNotNil(dict["marketing_opt_in"], "Missing 'marketing_opt_in'")
        XCTAssertNotNil(dict["contacts_synced"], "Missing 'contacts_synced'")
        XCTAssertNotNil(dict["phone_verified"], "Missing 'phone_verified'")
        XCTAssertNotNil(dict["created_at"], "Missing 'created_at'")
        XCTAssertNotNil(dict["updated_at"], "Missing 'updated_at'")

        // Camel-case keys must NOT appear — would silently insert nulls on upsert
        XCTAssertNil(dict["phoneNumber"], "Camel-case key 'phoneNumber' must not be encoded")
        XCTAssertNil(dict["displayName"], "Camel-case key 'displayName' must not be encoded")
        XCTAssertNil(dict["phoneVisible"], "Camel-case key 'phoneVisible' must not be encoded")
    }

    func testUserDecodeFromSnakeCaseJSON() throws {
        let id = UUID()
        let json: [String: Any] = [
            "id": id.uuidString,
            "phone_number": "+15555550101",
            "display_name": "Taylor",
            "avatar_url": NSNull(),
            "bio": NSNull(),
            "bgg_username": NSNull(),
            "phone_visible": false,
            "discoverable_by_phone": true,
            "game_library_public": true,
            "marketing_opt_in": false,
            "contacts_synced": false,
            "phone_verified": true,
            "privacy_accepted_at": NSNull(),
            "created_at": "2026-03-16T12:00:00.000+00:00",
            "updated_at": "2026-03-16T12:00:00.000+00:00"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONTestHelpers.makeEventDecoder()
        let user = try decoder.decode(User.self, from: data)

        XCTAssertEqual(user.id, id)
        XCTAssertEqual(user.phoneNumber, "+15555550101")
        XCTAssertEqual(user.displayName, "Taylor")
        XCTAssertTrue(user.discoverableByPhone)
        XCTAssertFalse(user.phoneVisible)
        XCTAssertTrue(user.phoneVerified)
    }

    func testUserRoundTrip_preservesAllFields() throws {
        let original = FixtureFactory.makeUser()
        let data = try JSONEncoder().encode(original)
        let decoder = JSONTestHelpers.makeEventDecoder()
        let decoded = try decoder.decode(User.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.phoneNumber, original.phoneNumber)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.phoneVisible, original.phoneVisible)
        XCTAssertEqual(decoded.discoverableByPhone, original.discoverableByPhone)
        XCTAssertEqual(decoded.marketingOptIn, original.marketingOptIn)
        XCTAssertEqual(decoded.contactsSynced, original.contactsSynced)
        XCTAssertEqual(decoded.phoneVerified, original.phoneVerified)
    }
}
