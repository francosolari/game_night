import XCTest
import SwiftUI
import UIKit
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

final class ThemePaletteTests: XCTestCase {
    func testLightPalettePreservesExistingSurfaceAndTextValues() {
        let palette = LightPalette()

        XCTAssertEqual(UIColor(palette.pageBackground).normalizedHex, BrandGuide.Warm.cream.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.elevatedBackground).normalizedHex, BrandGuide.Warm.sand.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.cardBackground).normalizedHex, BrandGuide.Warm.sand.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.fieldBackground).normalizedHex, BrandGuide.Warm.sand.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.textPrimary).normalizedHex, BrandGuide.Warm.espresso.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.primaryAction).normalizedHex, BrandGuide.Warm.sage.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.primaryActionPressed).normalizedHex, BrandGuide.Warm.sageDark.normalizedBrandHex)
    }

    func testDarkPaletteUsesUpdatedWarmSemanticRoles() {
        let palette = DarkPalette()

        XCTAssertEqual(UIColor(palette.pageBackground).normalizedHex, BrandGuide.Dark.background.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.elevatedBackground).normalizedHex, BrandGuide.Dark.backgroundElevated.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.cardBackground).normalizedHex, BrandGuide.Dark.cardBackground.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.fieldBackground).normalizedHex, BrandGuide.Dark.inputBackground.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.selectedSegmentBackground).normalizedHex, BrandGuide.Dark.chipBackground.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.border).normalizedHex, BrandGuide.Dark.border.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.textPrimary).normalizedHex, BrandGuide.Dark.textPrimary.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.textSecondary).normalizedHex, BrandGuide.Dark.textSecondary.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.textTertiary).normalizedHex, BrandGuide.Dark.textTertiary.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.textDisabled).normalizedHex, BrandGuide.Dark.textDisabled.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.primaryAction).normalizedHex, BrandGuide.Dark.primary.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.primaryActionPressed).normalizedHex, BrandGuide.Dark.primaryDark.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.accentWarm).normalizedHex, BrandGuide.Dark.secondaryAccent.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.tabBarBackground).normalizedHex, BrandGuide.Dark.tabBarBackground.normalizedBrandHex)
        XCTAssertEqual(UIColor(palette.tabInactive).normalizedHex, BrandGuide.Dark.tabIconInactive.normalizedBrandHex)
    }

    func testCompatibilityAliasesMatchSemanticRoles() {
        let palette = DarkPalette()

        XCTAssertEqual(UIColor(palette.background).normalizedHex, UIColor(palette.pageBackground).normalizedHex)
        XCTAssertEqual(UIColor(palette.backgroundElevated).normalizedHex, UIColor(palette.elevatedBackground).normalizedHex)
        XCTAssertEqual(UIColor(palette.primary).normalizedHex, UIColor(palette.primaryAction).normalizedHex)
        XCTAssertEqual(UIColor(palette.primaryDark).normalizedHex, UIColor(palette.primaryActionPressed).normalizedHex)
        XCTAssertEqual(UIColor(palette.accent).normalizedHex, UIColor(palette.accentWarm).normalizedHex)
        XCTAssertEqual(UIColor(palette.divider).normalizedHex, UIColor(palette.border).normalizedHex)
    }
}

private extension UIColor {
    var normalizedHex: String {
        guard let components = cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components else {
            return "000000"
        }

        let resolved: (CGFloat, CGFloat, CGFloat)
        switch components.count {
        case 2:
            resolved = (components[0], components[0], components[0])
        default:
            resolved = (components[0], components[1], components[2])
        }

        let red = Int(round(resolved.0 * 255))
        let green = Int(round(resolved.1 * 255))
        let blue = Int(round(resolved.2 * 255))

        return String(format: "%02X%02X%02X", red, green, blue)
    }
}

private extension String {
    var normalizedBrandHex: String {
        trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
    }
}
