import SwiftUI

// MARK: - Brand Guide
/// Canonical color palette for Game Night.
/// Reference this file for cross-platform consistency (iOS, web, marketing).
///
/// Warm palette inspired by cardboard meeple logo + Claude brand guide.
/// Dark palette
struct BrandGuide {

    // MARK: - Warm Palette (Light Mode)
    struct Warm {
        // Backgrounds
        static let cream       = "#FAF7F2"  // Page background
        static let sand        = "#EDE6DA"  // Card / elevated surface
        static let deepSand    = "#E3DACB"  // Chips, tags, input fields
        static let borderSand  = "#DDD3C3"  // Borders, dividers

        // Text hierarchy
        static let espresso    = "#2C1F14"  // Primary text, headings
        static let mediumBrown = "#5C4433"  // Secondary text, subtitles
        static let cardboard   = "#8B6F4E"  // Tertiary text, metadata
        static let tan         = "#C4A882"  // Muted text, placeholders
        static let mutedTan    = "#B09A7D"  // Disabled, inactive tabs

        // Accents
        static let sage        = "#7E9163"  // Primary CTA, links, active states
        static let sageDark    = "#6A7D50"  // Pressed / dark variant
        static let sageLight   = "#95A87A"  // Light variant
        static let terracotta  = "#C4704B"  // Dates, times, urgency, ratings
        static let terracottaLight = "#D4886A"  // Light variant
        static let yellow      = "#F8E945"  // Highlight only: dots, stars, text emphasis

        // Status
        static let success     = "#7E9163"  // Same as sage
        static let warning     = "#C4704B"  // Same as terracotta
        static let error       = "#B5433A"  // Warm red

        // Complexity scale
        static let complexityLight       = "#7E9163"  // Sage
        static let complexityMediumLight = "#A3B048"  // Olive-lime
        static let complexityMedium      = "#D4A843"  // Warm amber
        static let complexityMediumHeavy = "#C4704B"  // Terracotta
        static let complexityHeavy       = "#B5433A"  // Warm red

        // Special surfaces
        static let headerBackground = "#2C1F14"  // Dark espresso header
        static let headerText       = "#FAF7F2"  // Cream text on dark header
    }

    // MARK: - Dark Palette (Original)
    struct Dark {
        // Backgrounds
        static let background         = "#14110F"  // warm near-black
        static let backgroundElevated = "#1B1714"  // slightly lifted base
        static let cardBackground     = "#231E1A"  // primary card surface
        static let cardBackgroundHover = "#2A241F" // pressed/hover surface

        // Surface details
        static let inputBackground    = "#2B2520"
        static let chipBackground     = "#312A24"
        static let border             = "#3A312B"
        static let divider            = "#332B25"

        // Brand accents
        static let primary      = "#8FA576"  // luminous sage
        static let primaryLight = "#A5BA8D"
        static let primaryDark  = "#73885E"

        static let secondaryAccent      = "#D08A68" // softened terracotta
        static let secondaryAccentLight = "#DEA081"
        static let secondaryAccentDark  = "#B87454"

        static let highlight    = "#D7C86A" // antique brass, use sparingly

        // Text
        static let textPrimary   = "#F3EDE3" // warm ivory
        static let textSecondary = "#C7B8A6" // muted warm beige
        static let textTertiary  = "#9F8D7A" // metadata
        static let textDisabled  = "#766759"

        // Status
        static let success = "#8FA576"
        static let warning = "#D08A68"
        static let error   = "#C56B5C"

        // Complexity scale
        static let complexityLight       = "#8FA576"
        static let complexityMediumLight = "#A7B56A"
        static let complexityMedium      = "#C9A35B"
        static let complexityMediumHeavy = "#D08A68"
        static let complexityHeavy       = "#C56B5C"

        // Special surfaces
        static let headerBackground = "#181310"
        static let headerText       = "#F3EDE3"
        static let tabBarBackground = "#1A1512"
        static let tabIconInactive  = "#A28F7A"
        static let tabIconActive    = "#8FA576"
    }

    // MARK: - Color Roles
    /// How each color should be used:
    ///
    /// | Role              | Light (Warm)     | Dark             |
    /// |-------------------|------------------|------------------|
    /// | Page background   | Cream            | Deep black       |
    /// | Card surface      | Sand             | Dark gray        |
    /// | Primary CTA       | Sage green       | Electric blue    |
    /// | Date/time accent  | Terracotta       | Electric blue    |
    /// | Highlight         | Yellow (dots only)| Yellow (dots only)|
    /// | Success           | Sage             | Emerald          |
    /// | Warning           | Terracotta       | Amber            |
    /// | Error             | Warm red         | Red              |
    /// | Header bar        | Dark espresso    | Card background  |
    /// | Active tab        | Sage             | Blue             |
    /// | Inactive tab      | Muted tan        | Slate 500        |
}
