import SwiftUI

// MARK: - Brand Guide
/// Canonical color palette for Game Night.
/// Reference this file for cross-platform consistency (iOS, web, marketing).
///
/// Warm palette inspired by cardboard meeple logo + Claude brand guide.
/// Dark palette preserves the original Linear/Raycast-inspired design.
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
        static let background        = "#08090A"
        static let backgroundElevated = "#121316"
        static let cardBackground    = "#1C1D21"
        static let cardBackgroundHover = "#25262B"

        // Primary — electric blue
        static let primary      = "#3B82F6"
        static let primaryLight = "#60A5FA"
        static let primaryDark  = "#2563EB"

        // Secondary — slate
        static let secondary      = "#64748B"
        static let secondaryLight = "#94A3B8"

        // Accent — teal
        static let accent      = "#14B8A6"
        static let accentLight = "#2DD4BF"

        // Status
        static let success = "#10B981"
        static let warning = "#F59E0B"
        static let error   = "#EF4444"

        // Text
        static let textPrimary   = "#F8FAFC"
        static let textSecondary = "#94A3B8"
        static let textTertiary  = "#64748B"

        // Complexity scale
        static let complexityLight       = "#10B981"
        static let complexityMediumLight = "#84CC16"
        static let complexityMedium      = "#F59E0B"
        static let complexityMediumHeavy = "#F97316"
        static let complexityHeavy       = "#EF4444"
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
