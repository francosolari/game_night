import SwiftUI

// MARK: - Theme Mode
enum ThemeMode: String, CaseIterable {
    case light
    case dark
    case system
}

// MARK: - Palette Protocol
/// Defines all semantic colors that both light and dark themes must provide.
protocol Palette {
    // Backgrounds
    var background: Color { get }
    var backgroundElevated: Color { get }
    var cardBackground: Color { get }
    var cardBackgroundHover: Color { get }

    // Primary accent (CTA, links, active states)
    var primary: Color { get }
    var primaryLight: Color { get }
    var primaryDark: Color { get }

    // Secondary
    var secondary: Color { get }
    var secondaryLight: Color { get }

    // Accent (secondary interactive)
    var accent: Color { get }
    var accentLight: Color { get }

    // Status
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }

    // Text
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }

    // Divider & overlay
    var divider: Color { get }
    var overlay: Color { get }

    // Semantic roles
    var dateAccent: Color { get }         // Dates, times, urgency
    var highlight: Color { get }          // Yellow — dots, stars, emphasis
    var tabInactive: Color { get }        // Inactive tab icon/label
    var headerBackground: Color { get }   // Bold header bar
    var headerText: Color { get }         // Text on header bar

    // Complexity
    var complexityLight: Color { get }
    var complexityMediumLight: Color { get }
    var complexityMedium: Color { get }
    var complexityMediumHeavy: Color { get }
    var complexityHeavy: Color { get }

    // Shimmer
    var shimmer: Color { get }

    // Subtle variants (pre-computed for opacity on different backgrounds)
    var primarySubtle: Color { get }
    var accentSubtle: Color { get }
}

// MARK: - Light Palette (Warm Craft)
struct LightPalette: Palette {
    let background = Color(hex: "FAF7F2")          // Cream
    let backgroundElevated = Color(hex: "EDE6DA")   // Sand
    let cardBackground = Color(hex: "EDE6DA")       // Sand
    let cardBackgroundHover = Color(hex: "E3DACB")  // Deeper sand

    let primary = Color(hex: "7E9163")              // Sage green
    let primaryLight = Color(hex: "95A87A")
    let primaryDark = Color(hex: "6A7D50")

    let secondary = Color(hex: "8B6F4E")            // Cardboard
    let secondaryLight = Color(hex: "B09A7D")       // Tan

    let accent = Color(hex: "C4704B")               // Terracotta
    let accentLight = Color(hex: "D4886A")

    let success = Color(hex: "7E9163")              // Sage
    let warning = Color(hex: "C4704B")              // Terracotta
    let error = Color(hex: "B5433A")                // Warm red

    let textPrimary = Color(hex: "2C1F14")          // Dark espresso
    let textSecondary = Color(hex: "5C4433")        // Medium brown
    let textTertiary = Color(hex: "8B6F4E")         // Cardboard

    let divider = Color(hex: "DDD3C3")              // Border sand
    let overlay = Color.black.opacity(0.3)

    let dateAccent = Color(hex: "C4704B")           // Terracotta
    let highlight = Color(hex: "F8E945")            // Yellow
    let tabInactive = Color(hex: "B09A7D")          // Muted tan
    let headerBackground = Color(hex: "2C1F14")     // Dark espresso
    let headerText = Color(hex: "FAF7F2")           // Cream

    let complexityLight = Color(hex: "7E9163")       // Sage
    let complexityMediumLight = Color(hex: "A3B048") // Olive-lime
    let complexityMedium = Color(hex: "D4A843")      // Warm amber
    let complexityMediumHeavy = Color(hex: "C4704B") // Terracotta
    let complexityHeavy = Color(hex: "B5433A")       // Warm red

    let shimmer = Color.black.opacity(0.06)

    let primarySubtle = Color(hex: "7E9163").opacity(0.12)
    let accentSubtle = Color(hex: "C4704B").opacity(0.10)
}

// MARK: - Dark Palette (Original)
struct DarkPalette: Palette {
    let background = Color(hex: "08090A")
    let backgroundElevated = Color(hex: "121316")
    let cardBackground = Color(hex: "1C1D21")
    let cardBackgroundHover = Color(hex: "25262B")

    let primary = Color(hex: "3B82F6")              // Blue 500
    let primaryLight = Color(hex: "60A5FA")         // Blue 400
    let primaryDark = Color(hex: "2563EB")          // Blue 600

    let secondary = Color(hex: "64748B")            // Slate 500
    let secondaryLight = Color(hex: "94A3B8")       // Slate 400

    let accent = Color(hex: "14B8A6")               // Teal 500
    let accentLight = Color(hex: "2DD4BF")          // Teal 400

    let success = Color(hex: "10B981")              // Emerald 500
    let warning = Color(hex: "F59E0B")              // Amber 500
    let error = Color(hex: "EF4444")                // Red 500

    let textPrimary = Color(hex: "F8FAFC")          // Slate 50
    let textSecondary = Color(hex: "94A3B8")        // Slate 400
    let textTertiary = Color(hex: "64748B")         // Slate 500

    let divider = Color.white.opacity(0.08)
    let overlay = Color.black.opacity(0.6)

    let dateAccent = Color(hex: "3B82F6")           // Same as primary in dark
    let highlight = Color(hex: "F8E945")            // Yellow
    let tabInactive = Color(hex: "64748B")          // Slate 500
    let headerBackground = Color(hex: "1C1D21")     // Card background
    let headerText = Color(hex: "F8FAFC")           // Slate 50

    let complexityLight = Color(hex: "10B981")
    let complexityMediumLight = Color(hex: "84CC16")
    let complexityMedium = Color(hex: "F59E0B")
    let complexityMediumHeavy = Color(hex: "F97316")
    let complexityHeavy = Color(hex: "EF4444")

    let shimmer = Color.white.opacity(0.1)

    let primarySubtle = Color(hex: "3B82F6").opacity(0.15)
    let accentSubtle = Color(hex: "14B8A6").opacity(0.12)
}

// MARK: - ThemeManager
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var mode: ThemeMode = .light {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "themeMode")
            rebuildPalette()
        }
    }

    /// Updated from the environment when the system color scheme changes
    @Published var systemColorScheme: ColorScheme = .light {
        didSet { rebuildPalette() }
    }

    /// Cached active palette — avoids re-creating on every Theme.Colors access
    private(set) var activePalette: any Palette = LightPalette()

    /// Cached dark state
    private(set) var isDark: Bool = false

    var preferredColorScheme: ColorScheme? {
        switch mode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "themeMode"),
           let savedMode = ThemeMode(rawValue: saved) {
            self.mode = savedMode
        }
        rebuildPalette()
    }

    private func rebuildPalette() {
        let dark: Bool
        switch mode {
        case .light: dark = false
        case .dark: dark = true
        case .system: dark = systemColorScheme == .dark
        }
        isDark = dark
        activePalette = dark ? DarkPalette() : LightPalette()
    }
}

// MARK: - Theme
/// Design system for Game Night.
/// Warm craft palette (light) and dark mode, driven by ThemeManager.
struct Theme {

    // MARK: - Colors
    struct Colors {
        private static var p: any Palette { ThemeManager.shared.activePalette }

        // Backgrounds
        static var background: Color { p.background }
        static var backgroundElevated: Color { p.backgroundElevated }
        static var cardBackground: Color { p.cardBackground }
        static var cardBackgroundHover: Color { p.cardBackgroundHover }

        // Primary (sage / blue)
        static var primary: Color { p.primary }
        static var primaryLight: Color { p.primaryLight }
        static var primaryDark: Color { p.primaryDark }

        // Secondary
        static var secondary: Color { p.secondary }
        static var secondaryLight: Color { p.secondaryLight }

        // Accent (terracotta / teal)
        static var accent: Color { p.accent }
        static var accentLight: Color { p.accentLight }

        // Status
        static var success: Color { p.success }
        static var warning: Color { p.warning }
        static var error: Color { p.error }

        // Text
        static var textPrimary: Color { p.textPrimary }
        static var textSecondary: Color { p.textSecondary }
        static var textTertiary: Color { p.textTertiary }

        // Divider & overlay
        static var divider: Color { p.divider }
        static var overlay: Color { p.overlay }

        // Semantic
        static var dateAccent: Color { p.dateAccent }
        static var highlight: Color { p.highlight }
        static var tabInactive: Color { p.tabInactive }
        static var headerBackground: Color { p.headerBackground }
        static var headerText: Color { p.headerText }

        // Subtle pre-computed
        static var primarySubtle: Color { p.primarySubtle }
        static var accentSubtle: Color { p.accentSubtle }

        // Shimmer
        static var shimmer: Color { p.shimmer }

        // Complexity
        static var complexityLight: Color { p.complexityLight }
        static var complexityMediumLight: Color { p.complexityMediumLight }
        static var complexityMedium: Color { p.complexityMedium }
        static var complexityMediumHeavy: Color { p.complexityMediumHeavy }
        static var complexityHeavy: Color { p.complexityHeavy }

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
        static var primary: LinearGradient {
            LinearGradient(
                colors: [Colors.primary, Colors.primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var secondary: LinearGradient {
            LinearGradient(
                colors: [Colors.secondary, Colors.secondary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var accent: LinearGradient {
            LinearGradient(
                colors: [Colors.accent, Colors.accent.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var card: LinearGradient {
            LinearGradient(
                colors: [
                    Colors.shimmer,
                    Colors.shimmer.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var eventCard: LinearGradient {
            LinearGradient(
                colors: [
                    Colors.cardBackground,
                    Colors.backgroundElevated
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Typography
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
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
        static let jumbo: CGFloat = 64
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 18
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows
    struct Shadows {
        static func card() -> some View {
            Color.black.opacity(ThemeManager.shared.isDark ? 0.4 : 0.08)
        }
    }

    // MARK: - Animation
    struct Animation {
        static let snappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
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
