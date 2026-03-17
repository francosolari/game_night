import XCTest
import SwiftUI
@testable import GameNight

final class InviteStatusTests: XCTestCase {
    func testAcceptedColorIsSuccess() {
        XCTAssertEqual(InviteStatus.accepted.color, Theme.Colors.success)
    }

    func testDeclinedColorIsError() {
        XCTAssertEqual(InviteStatus.declined.color, Theme.Colors.error)
    }

    func testMaybeColorIsWarning() {
        XCTAssertEqual(InviteStatus.maybe.color, Theme.Colors.warning)
    }

    func testPendingColorIsTextTertiary() {
        XCTAssertEqual(InviteStatus.pending.color, Theme.Colors.textTertiary)
    }

    func testExpiredColorIsTextTertiary() {
        XCTAssertEqual(InviteStatus.expired.color, Theme.Colors.textTertiary)
    }

    func testWaitlistedColorIsAccent() {
        XCTAssertEqual(InviteStatus.waitlisted.color, Theme.Colors.accent)
    }

    func testDisplayLabelCoversAllCases() {
        for status in InviteStatus.allCases {
            XCTAssertFalse(status.displayLabel.isEmpty, "\(status) has empty displayLabel")
        }
    }

    func testIconCoversAllCases() {
        for status in InviteStatus.allCases {
            XCTAssertFalse(status.icon.isEmpty, "\(status) has empty icon")
        }
    }
}
