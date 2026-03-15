import SwiftUI

// MARK: - Theme
/// Design system inspired by Partiful and DICE.
/// Dark-first, vibrant accents, generous spacing, bold typography.
struct Theme {

    // MARK: - Colors
    struct Colors {
        // Backgrounds
        static let background = Color(hex: "0A0A0F")
        static let backgroundElevated = Color(hex: "14141F")
        static let cardBackground = Color(hex: "1A1A2E")
        static let cardBackgroundHover = Color(hex: "22223A")

        // Primary palette — electric violet / magenta
        static let primary = Color(hex: "8B5CF6")
        static let primaryLight = Color(hex: "A78BFA")
        static let primaryDark = Color(hex: "6D28D9")

        // Secondary — warm coral / orange
        static let secondary = Color(hex: "F97316")
        static let secondaryLight = Color(hex: "FB923C")

        // Accent — electric cyan
        static let accent = Color(hex: "06B6D4")
        static let accentLight = Color(hex: "22D3EE")

        // Success / Warning / Error
        static let success = Color(hex: "10B981")
        static let warning = Color(hex: "F59E0B")
        static let error = Color(hex: "EF4444")

        // Text
        static let textPrimary = Color(hex: "F8FAFC")
        static let textSecondary = Color(hex: "94A3B8")
        static let textTertiary = Color(hex: "64748B")

        // Divider & overlay
        static let divider = Color.white.opacity(0.08)
        static let overlay = Color.black.opacity(0.5)

        // Complexity level colors
        static let complexityLight = Color(hex: "10B981")
        static let complexityMediumLight = Color(hex: "84CC16")
        static let complexityMedium = Color(hex: "F59E0B")
        static let complexityMediumHeavy = Color(hex: "F97316")
        static let complexityHeavy = Color(hex: "EF4444")

        static func complexity(_ weight: Double) -> Color {
            switch weight {
            case 0..<1.5: return complexityLight
            case 1.5..<2.5: return complexityMediumLight
            case 2.5..<3.5: return complexityMedium
            case 3.5..<4.5: return complexityMediumHeavy
            default: return complexityHeavy
            }
        }

        static func complexityLabel(_ weight: Double) -> String {
            switch weight {
            case 0..<1.5: return "Light"
            case 1.5..<2.5: return "Medium Light"
            case 2.5..<3.5: return "Medium"
            case 3.5..<4.5: return "Medium Heavy"
            default: return "Heavy"
            }
        }
    }

    // MARK: - Gradients
    struct Gradients {
        static let primary = LinearGradient(
            colors: [Color(hex: "8B5CF6"), Color(hex: "EC4899")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let secondary = LinearGradient(
            colors: [Color(hex: "F97316"), Color(hex: "F43F5E")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accent = LinearGradient(
            colors: [Color(hex: "06B6D4"), Color(hex: "8B5CF6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let card = LinearGradient(
            colors: [
                Color.white.opacity(0.06),
                Color.white.opacity(0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let eventCard = LinearGradient(
            colors: [
                Color(hex: "1E1B4B").opacity(0.8),
                Color(hex: "1A1A2E").opacity(0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography
    struct Typography {
        static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
        static let displaySmall = Font.system(size: 24, weight: .bold, design: .rounded)

        static let headlineLarge = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headlineMedium = Font.system(size: 18, weight: .semibold, design: .rounded)

        static let titleLarge = Font.system(size: 17, weight: .semibold)
        static let titleMedium = Font.system(size: 15, weight: .semibold)

        static let body = Font.system(size: 15, weight: .regular)
        static let bodyMedium = Font.system(size: 15, weight: .medium)
        static let bodySemibold = Font.system(size: 15, weight: .semibold)

        static let callout = Font.system(size: 14, weight: .regular)
        static let calloutMedium = Font.system(size: 14, weight: .medium)

        static let caption = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .medium)

        static let label = Font.system(size: 13, weight: .semibold, design: .rounded)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let jumbo: CGFloat = 48
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows
    struct Shadows {
        static func card() -> some View {
            Color.black.opacity(0.2)
        }
    }

    // MARK: - Animation
    struct Animation {
        static let snappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let bouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
}

// MARK: - ThemeManager
@MainActor
final class ThemeManager: ObservableObject {
    @Published var accentColor: Color = Theme.Colors.primary
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
