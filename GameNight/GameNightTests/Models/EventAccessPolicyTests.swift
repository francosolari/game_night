import XCTest
@testable import GameNight

final class EventAccessPolicyTests: XCTestCase {
    func testPrivateEventNonRSVPViewerCannotSeeFullAddress() {
        let policy = EventAccessPolicy(
            visibility: .private,
            viewerRole: .publicViewer,
            rsvpDeadline: nil,
            allowGuestInvites: false,
            now: Date(timeIntervalSince1970: 1_720_000_000)
        )

        XCTAssertFalse(policy.canViewFullAddress)
        XCTAssertFalse(policy.canViewGuestList)
        XCTAssertTrue(policy.canViewGuestCounts)
    }

    func testPrivateEventNonRSVPViewerSeesCustomLocationNameAndCityState() {
        let presentation = EventLocationPresentation(
            locationName: "Alex's House",
            locationAddress: "123 Main St Unit 4, Washington, DC",
            canViewFullAddress: false
        )

        XCTAssertEqual(presentation.title, "Alex's House")
        XCTAssertEqual(presentation.subtitle, "Washington, DC")
    }

    func testPublicEventNonRSVPViewerCanSeeFullAddressButNotGuestList() {
        let policy = EventAccessPolicy(
            visibility: .public,
            viewerRole: .publicViewer,
            rsvpDeadline: nil,
            allowGuestInvites: false,
            now: Date(timeIntervalSince1970: 1_720_000_000)
        )

        XCTAssertTrue(policy.canViewFullAddress)
        XCTAssertFalse(policy.canViewGuestList)
        XCTAssertTrue(policy.canViewGuestCounts)
    }

    func testHostAlwaysSeesFullAddress() {
        let policy = EventAccessPolicy(
            visibility: .private,
            viewerRole: .host,
            rsvpDeadline: Date(timeIntervalSince1970: 1_710_000_000),
            allowGuestInvites: false,
            now: Date(timeIntervalSince1970: 1_720_000_000)
        )

        XCTAssertTrue(policy.canViewFullAddress)
        XCTAssertTrue(policy.canViewGuestList)
        XCTAssertTrue(policy.isRSVPClosed)
    }

    func testMaskedLocationNeverLeaksStreetLineForPrivateHiddenMode() {
        let presentation = EventLocationPresentation(
            locationName: nil,
            locationAddress: "1545 18th St NW Unit 703, Washington, DC",
            canViewFullAddress: false
        )

        XCTAssertEqual(presentation.title, "Washington, DC")
        XCTAssertNil(presentation.subtitle)
        XCTAssertFalse(presentation.title.contains("1545"))
    }

    func testVisibleLocationBuildsMapsURLFromFullAddress() {
        let presentation = EventLocationPresentation(
            locationName: "Alex's House",
            locationAddress: "123 Main St Unit 4, Washington, DC",
            canViewFullAddress: true
        )

        XCTAssertEqual(
            presentation.mapsURL?.absoluteString,
            "http://maps.apple.com/?q=123%20Main%20St%20Unit%204,%20Washington,%20DC"
        )
    }

    func testHostCanAlwaysInviteGuests() {
        let policy = EventAccessPolicy(
            visibility: .private,
            viewerRole: .host,
            rsvpDeadline: nil,
            allowGuestInvites: false,
            now: Date(timeIntervalSince1970: 1_720_000_000)
        )

        XCTAssertTrue(policy.canInviteGuests)
    }

    func testRSVPdGuestCanInviteOnlyWhenAllowed() {
        let allowed = EventAccessPolicy(
            visibility: .private,
            viewerRole: .rsvpd,
            rsvpDeadline: nil,
            allowGuestInvites: true,
            now: Date(timeIntervalSince1970: 1_720_000_000)
        )
        let blocked = EventAccessPolicy(
            visibility: .private,
            viewerRole: .rsvpd,
            rsvpDeadline: nil,
            allowGuestInvites: false,
            now: Date(timeIntervalSince1970: 1_720_000_000)
        )

        XCTAssertTrue(allowed.canInviteGuests)
        XCTAssertFalse(blocked.canInviteGuests)
    }
}
