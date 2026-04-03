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

    func testPollRSVPDerivesAcceptedWhenAnyYesVoteExists() {
        let votes: [UUID: TimeOptionVoteType] = [
            UUID(): .no,
            UUID(): .yes
        ]

        XCTAssertEqual(PollRSVP.derivedStatus(from: votes), .accepted)
    }

    func testPollRSVPDerivesMaybeWhenNoYesButAtLeastOneMaybeExists() {
        let votes: [UUID: TimeOptionVoteType] = [
            UUID(): .no,
            UUID(): .maybe
        ]

        XCTAssertEqual(PollRSVP.derivedStatus(from: votes), .maybe)
    }

    func testPollRSVPDerivesDeclinedWhenVotesAreOnlyNo() {
        let votes: [UUID: TimeOptionVoteType] = [
            UUID(): .no,
            UUID(): .no
        ]

        XCTAssertEqual(PollRSVP.derivedStatus(from: votes), .declined)
    }

    func testPollRSVPReturnsNilWhenNoVotesSelected() {
        XCTAssertNil(PollRSVP.derivedStatus(from: [:]))
    }

    func testPollRSVPSubmissionStatusIsPendingWhenVotesExist() {
        let votes: [UUID: TimeOptionVoteType] = [
            UUID(): .yes
        ]
        XCTAssertEqual(PollRSVP.submissionStatus(from: votes), .pending)
    }

    func testPollRSVPSubmissionStatusIsNilWhenNoVotesExist() {
        XCTAssertNil(PollRSVP.submissionStatus(from: [:]))
    }

    func testGroupEmojiSanitizerFallsBackForInvalidValues() {
        XCTAssertEqual(GroupEmojiSanitizer.sanitized(nil), "🎲")
        XCTAssertEqual(GroupEmojiSanitizer.sanitized(""), "🎲")
        XCTAssertEqual(GroupEmojiSanitizer.sanitized("   "), "🎲")
        XCTAssertEqual(GroupEmojiSanitizer.sanitized("?"), "🎲")
        XCTAssertEqual(GroupEmojiSanitizer.sanitized("�"), "🎲")
    }

    func testGroupEmojiSanitizerPreservesValidEmoji() {
        XCTAssertEqual(GroupEmojiSanitizer.sanitized("🏜️"), "🏜️")
    }

    @MainActor
    func testThemeManagerSystemModeFollowsUpdatedSystemColorScheme() {
        let sut = ThemeManager.shared
        let originalMode = sut.mode
        let originalSystem = sut.systemColorScheme
        defer {
            sut.mode = originalMode
            sut.updateSystemColorScheme(originalSystem)
        }

        sut.mode = .system
        sut.updateSystemColorScheme(.dark)
        XCTAssertTrue(sut.isDark)

        sut.updateSystemColorScheme(.light)
        XCTAssertFalse(sut.isDark)
    }

    @MainActor
    func testThemeManagerSwitchingToSystemUsesLatestCapturedScheme() {
        let sut = ThemeManager.shared
        let originalMode = sut.mode
        let originalSystem = sut.systemColorScheme
        defer {
            sut.mode = originalMode
            sut.updateSystemColorScheme(originalSystem)
        }

        sut.mode = .light
        sut.updateSystemColorScheme(.dark)
        sut.mode = .system

        XCTAssertTrue(sut.isDark)
    }
}
