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
    var pageBackground: Color { get }
    var elevatedBackground: Color { get }
    var cardBackground: Color { get }
    var cardBackgroundHover: Color { get }
    var fieldBackground: Color { get }
    var selectedSegmentBackground: Color { get }
    var tabBarBackground: Color { get }

    // Actions
    var primaryAction: Color { get }
    var primaryActionLight: Color { get }
    var primaryActionPressed: Color { get }
    var primaryActionText: Color { get }

    // Accent
    var accentWarm: Color { get }
    var accentWarmLight: Color { get }

    // Status
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }

    // Text
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textDisabled: Color { get }

    // Divider & overlay
    var border: Color { get }
    var overlay: Color { get }

    // Semantic roles
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

extension Palette {
    // Compatibility aliases for the existing app theme API.
    var background: Color { pageBackground }
    var backgroundElevated: Color { elevatedBackground }

    var primary: Color { primaryAction }
    var primaryLight: Color { primaryActionLight }
    var primaryDark: Color { primaryActionPressed }

    var secondary: Color { textTertiary }
    var secondaryLight: Color { textDisabled }

    var accent: Color { accentWarm }
    var accentLight: Color { accentWarmLight }

    var divider: Color { border }
    var dateAccent: Color { accentWarm }
}

// MARK: - Light Palette (Warm Craft)
struct LightPalette: Palette {
    let pageBackground = Color(hex: BrandGuide.Warm.cream)
    let elevatedBackground = Color(hex: BrandGuide.Warm.sand)
    let cardBackground = Color(hex: BrandGuide.Warm.sand)
    let cardBackgroundHover = Color(hex: BrandGuide.Warm.deepSand)
    let fieldBackground = Color(hex: BrandGuide.Warm.sand)
    let selectedSegmentBackground = Color(hex: BrandGuide.Warm.sage)
    let tabBarBackground = Color(hex: BrandGuide.Warm.sand)

    let primaryAction = Color(hex: BrandGuide.Warm.sage)
    let primaryActionLight = Color(hex: BrandGuide.Warm.sageLight)
    let primaryActionPressed = Color(hex: BrandGuide.Warm.sageDark)
    let primaryActionText = Color.white

    let accentWarm = Color(hex: BrandGuide.Warm.terracotta)
    let accentWarmLight = Color(hex: BrandGuide.Warm.terracottaLight)

    let success = Color(hex: BrandGuide.Warm.success)
    let warning = Color(hex: BrandGuide.Warm.warning)
    let error = Color(hex: BrandGuide.Warm.error)

    let textPrimary = Color(hex: BrandGuide.Warm.espresso)
    let textSecondary = Color(hex: BrandGuide.Warm.mediumBrown)
    let textTertiary = Color(hex: BrandGuide.Warm.cardboard)
    let textDisabled = Color(hex: BrandGuide.Warm.mutedTan)

    let border = Color(hex: BrandGuide.Warm.borderSand)
    let overlay = Color.black.opacity(0.3)

    let highlight = Color(hex: BrandGuide.Warm.yellow)
    let tabInactive = Color(hex: BrandGuide.Warm.mutedTan)
    let headerBackground = Color(hex: BrandGuide.Warm.headerBackground)
    let headerText = Color(hex: BrandGuide.Warm.headerText)

    let complexityLight = Color(hex: BrandGuide.Warm.complexityLight)
    let complexityMediumLight = Color(hex: BrandGuide.Warm.complexityMediumLight)
    let complexityMedium = Color(hex: BrandGuide.Warm.complexityMedium)
    let complexityMediumHeavy = Color(hex: BrandGuide.Warm.complexityMediumHeavy)
    let complexityHeavy = Color(hex: BrandGuide.Warm.complexityHeavy)

    let shimmer = Color.black.opacity(0.06)

    let primarySubtle = Color(hex: BrandGuide.Warm.sage).opacity(0.12)
    let accentSubtle = Color(hex: BrandGuide.Warm.terracotta).opacity(0.10)
}

// MARK: - Dark Palette (Warm Night)
struct DarkPalette: Palette {
    let pageBackground = Color(hex: BrandGuide.Dark.background)
    let elevatedBackground = Color(hex: BrandGuide.Dark.backgroundElevated)
    let cardBackground = Color(hex: BrandGuide.Dark.cardBackground)
    let cardBackgroundHover = Color(hex: BrandGuide.Dark.cardBackgroundHover)
    let fieldBackground = Color(hex: BrandGuide.Dark.inputBackground)
    let selectedSegmentBackground = Color(hex: BrandGuide.Dark.chipBackground)
    let tabBarBackground = Color(hex: BrandGuide.Dark.tabBarBackground)

    let primaryAction = Color(hex: BrandGuide.Dark.primary)
    let primaryActionLight = Color(hex: BrandGuide.Dark.primaryLight)
    let primaryActionPressed = Color(hex: BrandGuide.Dark.primaryDark)
    let primaryActionText = Color(hex: BrandGuide.Dark.textPrimary)

    let accentWarm = Color(hex: BrandGuide.Dark.secondaryAccent)
    let accentWarmLight = Color(hex: BrandGuide.Dark.secondaryAccentLight)

    let success = Color(hex: BrandGuide.Dark.success)
    let warning = Color(hex: BrandGuide.Dark.warning)
    let error = Color(hex: BrandGuide.Dark.error)

    let textPrimary = Color(hex: BrandGuide.Dark.textPrimary)
    let textSecondary = Color(hex: BrandGuide.Dark.textSecondary)
    let textTertiary = Color(hex: BrandGuide.Dark.textTertiary)
    let textDisabled = Color(hex: BrandGuide.Dark.textDisabled)

    let border = Color(hex: BrandGuide.Dark.border)
    let overlay = Color.black.opacity(0.6)

    let highlight = Color(hex: BrandGuide.Dark.highlight)
    let tabInactive = Color(hex: BrandGuide.Dark.tabIconInactive)
    let headerBackground = Color(hex: BrandGuide.Dark.headerBackground)
    let headerText = Color(hex: BrandGuide.Dark.headerText)

    let complexityLight = Color(hex: BrandGuide.Dark.complexityLight)
    let complexityMediumLight = Color(hex: BrandGuide.Dark.complexityMediumLight)
    let complexityMedium = Color(hex: BrandGuide.Dark.complexityMedium)
    let complexityMediumHeavy = Color(hex: BrandGuide.Dark.complexityMediumHeavy)
    let complexityHeavy = Color(hex: BrandGuide.Dark.complexityHeavy)

    let shimmer = Color.white.opacity(0.1)

    let primarySubtle = Color(hex: BrandGuide.Dark.primary).opacity(0.15)
    let accentSubtle = Color(hex: BrandGuide.Dark.secondaryAccent).opacity(0.12)
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

        // Semantic backgrounds
        static var pageBackground: Color { p.pageBackground }
        static var elevatedBackground: Color { p.elevatedBackground }
        static var cardBackground: Color { p.cardBackground }
        static var cardBackgroundHover: Color { p.cardBackgroundHover }
        static var fieldBackground: Color { p.fieldBackground }
        static var selectedSegmentBackground: Color { p.selectedSegmentBackground }
        static var tabBarBackground: Color { p.tabBarBackground }

        // Compatibility backgrounds
        static var background: Color { p.background }
        static var backgroundElevated: Color { p.backgroundElevated }

        // Semantic actions
        static var primaryAction: Color { p.primaryAction }
        static var primaryActionLight: Color { p.primaryActionLight }
        static var primaryActionPressed: Color { p.primaryActionPressed }
        static var primaryActionText: Color { p.primaryActionText }

        // Compatibility actions
        static var primary: Color { p.primary }
        static var primaryLight: Color { p.primaryLight }
        static var primaryDark: Color { p.primaryDark }
        static var secondary: Color { p.secondary }
        static var secondaryLight: Color { p.secondaryLight }

        // Semantic accent
        static var accentWarm: Color { p.accentWarm }
        static var accentWarmLight: Color { p.accentWarmLight }

        // Compatibility accent
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
        static var textDisabled: Color { p.textDisabled }

        // Borders & overlay
        static var border: Color { p.border }
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
