import XCTest
@testable import GameNight

/// Tests for the session validation logic introduced to prevent bad_jwt cascades
/// on app launch when a stale keychain token is present.
final class SessionValidationTests: XCTestCase {

    // MARK: - isDefinitiveAuthRejection

    func testAuthRejection_401_isDefinitive() {
        XCTAssertTrue(SupabaseService.isDefinitiveAuthRejection(401))
    }

    func testAuthRejection_403_isDefinitive() {
        XCTAssertTrue(SupabaseService.isDefinitiveAuthRejection(403))
    }

    func testAuthRejection_200_isNotDefinitive() {
        XCTAssertFalse(SupabaseService.isDefinitiveAuthRejection(200))
    }

    func testAuthRejection_500_isNotDefinitive() {
        // Server errors are transient — don't sign the user out
        XCTAssertFalse(SupabaseService.isDefinitiveAuthRejection(500))
    }

    func testAuthRejection_503_isNotDefinitive() {
        XCTAssertFalse(SupabaseService.isDefinitiveAuthRejection(503))
    }

    func testAuthRejection_404_isNotDefinitive() {
        // 404 is not an auth failure — resource just doesn't exist
        XCTAssertFalse(SupabaseService.isDefinitiveAuthRejection(404))
    }

    func testAuthRejection_422_isNotDefinitive() {
        XCTAssertFalse(SupabaseService.isDefinitiveAuthRejection(422))
    }

    func testAuthRejection_400_isNotDefinitive() {
        // 400 Bad Request is not an auth rejection
        XCTAssertFalse(SupabaseService.isDefinitiveAuthRejection(400))
    }
}
