import SwiftUI

// MARK: - Theme
/// Design system inspired by Linear and Raycast.
/// Minimalist dark mode, high contrast, subtle borders, electric blue accents.
struct Theme {

    // MARK: - Colors
    struct Colors {
        // Backgrounds - deep, neutral grays/blacks
        static let background = Color(hex: "08090A")
        static let backgroundElevated = Color(hex: "121316")
        static let cardBackground = Color(hex: "1C1D21")
        static let cardBackgroundHover = Color(hex: "25262B")

        // Primary palette — electric blue (Interstellar)
        static let primary = Color(hex: "3B82F6") // Blue 500
        static let primaryLight = Color(hex: "60A5FA") // Blue 400
        static let primaryDark = Color(hex: "2563EB") // Blue 600

        // Secondary — neutral slate
        static let secondary = Color(hex: "64748B") // Slate 500
        static let secondaryLight = Color(hex: "94A3B8") // Slate 400

        // Accent — vibrant teal
        static let accent = Color(hex: "14B8A6") // Teal 500
        static let accentLight = Color(hex: "2DD4BF") // Teal 400

        // Success / Warning / Error
        static let success = Color(hex: "10B981") // Emerald 500
        static let warning = Color(hex: "F59E0B") // Amber 500
        static let error = Color(hex: "EF4444")   // Red 500

        // Text
        static let textPrimary = Color(hex: "F8FAFC") // Slate 50
        static let textSecondary = Color(hex: "94A3B8") // Slate 400
        static let textTertiary = Color(hex: "64748B")  // Slate 500

        // Divider & overlay
        static let divider = Color.white.opacity(0.08)
        static let overlay = Color.black.opacity(0.6)

        // Complexity level colors (keeping logic but refining palette)
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
        // Subtle, professional gradients
        static let primary = LinearGradient(
            colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let secondary = LinearGradient(
            colors: [Color(hex: "64748B"), Color(hex: "475569")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accent = LinearGradient(
            colors: [Color(hex: "14B8A6"), Color(hex: "0D9488")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let card = LinearGradient(
            colors: [
                Color.white.opacity(0.04),
                Color.white.opacity(0.01)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let eventCard = LinearGradient(
            colors: [
                Color(hex: "1C1D21"),
                Color(hex: "121316")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Typography
    // Using system fonts (SF Pro) with slightly tighter tracking for a technical feel
    struct Typography {
        static let displayLarge = Font.system(size: 32, weight: .bold, design: .default)
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .default)
        static let displaySmall = Font.system(size: 24, weight: .semibold, design: .default)

        static let headlineLarge = Font.system(size: 20, weight: .semibold, design: .default)
        static let headlineMedium = Font.system(size: 18, weight: .semibold, design: .default)

        static let titleLarge = Font.system(size: 16, weight: .medium)
        static let titleMedium = Font.system(size: 14, weight: .medium)

        static let body = Font.system(size: 15, weight: .regular)
        static let bodyMedium = Font.system(size: 15, weight: .medium)
        static let bodySemibold = Font.system(size: 15, weight: .semibold)

        static let callout = Font.system(size: 14, weight: .regular)
        static let calloutMedium = Font.system(size: 14, weight: .medium)

        static let caption = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .medium)

        static let label = Font.system(size: 13, weight: .semibold)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24  // Increased for more breathing room
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
        static let jumbo: CGFloat = 64
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 6   // Tighter corners (Linear style)
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 18
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows
    struct Shadows {
        static func card() -> some View {
            Color.black.opacity(0.4)
        }
    }

    // MARK: - Animation
    struct Animation {
        static let snappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7) // Slightly snappier
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
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
