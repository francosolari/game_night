import XCTest
@testable import GameNight

/// Tests for AppState — verifies initial state and the sign-out reset behaviour.
@MainActor
final class AppStateTests: XCTestCase {

    // MARK: - Initial state

    func testInitialState_isNotAuthenticated() {
        let sut = AppState()
        XCTAssertFalse(sut.isAuthenticated)
    }

    func testInitialState_hasNoCurrentUser() {
        let sut = AppState()
        XCTAssertNil(sut.currentUser)
    }

    func testInitialState_isLoading() {
        // App starts in loading state until checkAuthState() completes
        let sut = AppState()
        XCTAssertTrue(sut.isLoading)
    }

    func testInitialState_unreadCountsAreZero() {
        let sut = AppState()
        XCTAssertEqual(sut.unreadNotificationCount, 0)
        XCTAssertEqual(sut.unreadMessageCount, 0)
    }

    func testInitialState_defaultTabIsHome() {
        let sut = AppState()
        XCTAssertEqual(sut.selectedTab, .home)
    }

    // MARK: - Refresh Handlers

    func testRefresh_whenMultipleHandlersRegisteredForSameArea_invokesAllHandlers() async {
        let sut = AppState()
        var callCount = 0

        sut.registerRefreshHandler(for: .groups) {
            callCount += 1
        }
        sut.registerRefreshHandler(for: .groups) {
            callCount += 1
        }

        await sut.refresh([.groups])

        XCTAssertEqual(callCount, 2)
    }
}
