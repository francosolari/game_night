import SwiftUI

/// Generates a deterministic, visually interesting cover from an event title
/// when no custom cover image is set. Uses the theme palette and the title's
/// hash to produce a unique but stable pattern per event.
///
/// Pass `variant` to cycle through different styles for the same event.
struct GenerativeEventCover: View {
    let title: String
    let eventId: UUID
    var variant: Int = 0

    /// Stable seed derived from event ID bytes + variant offset.
    /// Uses UUID bytes instead of hashValue (which is randomized per process since Swift 4.2).
    private var seed: Int {
        let uuid = eventId.uuid
        let stableHash = Int(uuid.0) &+ Int(uuid.1) << 8
            &+ Int(uuid.2) << 16 &+ Int(uuid.3) << 4
            &+ Int(uuid.4) &+ Int(uuid.5) << 12
            &+ Int(uuid.6) << 8 &+ Int(uuid.7)
        return abs(stableHash &+ variant)
    }

    private var patternIndex: Int {
        seed % Pattern.allCases.count
    }

    private var pattern: Pattern {
        Pattern.allCases[patternIndex]
    }

    // MARK: - Extended palette (cream-compatible from reference + warm craft tones)

    // Blues & teals
    private static let dustyBlue = Color(red: 0.45, green: 0.55, blue: 0.65)
    private static let slate = Color(red: 0.35, green: 0.40, blue: 0.45)
    private static let ocean = Color(red: 0.30, green: 0.48, blue: 0.55)
    private static let teal = Color(hex: "00AFB9")        // bright teal
    private static let deepTeal = Color(hex: "13525F")     // dark teal-green

    // Greens
    private static let forest = Color(hex: "006B4C")       // deep emerald
    private static let moss = Color(red: 0.40, green: 0.50, blue: 0.35)
    private static let olive = Color(hex: "97A87C")        // muted olive sage
    private static let lime = Color(hex: "DAF07A")         // bright lime

    // Purples & plums
    private static let warmPlum = Color(red: 0.55, green: 0.35, blue: 0.45)
    private static let deepPlum = Color(red: 0.40, green: 0.22, blue: 0.35)
    private static let lavender = Color(hex: "9178B6")     // soft lavender
    private static let dusk = Color(red: 0.50, green: 0.40, blue: 0.55)

    // Warm tones
    private static let clay = Color(red: 0.65, green: 0.45, blue: 0.35)
    private static let copper = Color(red: 0.60, green: 0.38, blue: 0.25)
    private static let burgundy = Color(hex: "8B2A1A")     // deep wine
    private static let blush = Color(hex: "F4C4D9")        // soft pink
    private static let orange = Color(hex: "F7B544")       // warm amber-orange

    // Neutrals
    private static let charcoal = Color(hex: "3B3B3B")     // rich dark
    private static let espresso = Color(hex: "343D2A")     // dark olive-brown

    /// Background gradient colors and a contrasting text color.
    /// Each tuple: (gradient start, gradient end, text color).
    /// Text color is always chosen to contrast with the gradient.
    private var colorScheme: (gradient0: Color, gradient1: Color, text: Color) {
        let schemes: [(Color, Color, Color)] = [
            // Sage → terracotta text
            (Theme.Colors.primary, Theme.Colors.primaryLight, Theme.Colors.accent),
            // Terracotta → dark sage text
            (Theme.Colors.accent, Theme.Colors.accentLight, Theme.Colors.primaryDark),
            // Dusty blue / slate → espresso text
            (Self.dustyBlue, Self.slate, Theme.Colors.textPrimary),
            // Warm plum / deep plum → blush text
            (Self.warmPlum, Self.deepPlum, Self.blush),
            // Forest / moss → orange text
            (Self.forest, Self.moss, Self.orange),
            // Clay / copper → dark sage text
            (Self.clay, Self.copper, Theme.Colors.primaryDark),
            // Dusk / lavender → cream text
            (Self.dusk, Self.lavender, Theme.Colors.accentLight),
            // Ocean / teal → clay text
            (Self.ocean, Self.teal, Self.clay),
            // Burgundy / warm plum → blush text
            (Self.burgundy, Self.warmPlum, Self.blush),
            // Deep teal / forest → lime text
            (Self.deepTeal, Self.forest, Self.lime),
            // Charcoal / slate → teal text
            (Self.charcoal, Self.slate, Self.teal),
            // Olive / moss → burgundy text
            (Self.olive, Self.moss, Self.burgundy),
            // Lavender / blush → deep plum text
            (Self.lavender, Self.blush, Self.deepPlum),
            // Orange / clay → espresso text
            (Self.orange, Self.clay, Self.espresso),
            // Teal / ocean → orange text
            (Self.teal, Self.ocean, Self.orange),
            // Espresso / charcoal → lime text
            (Self.espresso, Self.charcoal, Self.lime),
        ]
        let scheme = schemes[seed % schemes.count]
        return (gradient0: scheme.0, gradient1: scheme.1, text: scheme.2)
    }

    // Used by pattern drawing functions
    private var colorPair: (Color, Color) {
        (colorScheme.gradient0, colorScheme.gradient1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [colorScheme.gradient0.opacity(0.4), colorScheme.gradient1.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Pattern layer
                patternView(size: geo.size)
                    .opacity(0.15)

                // Title overlay — large, clipped, decorative
                titleDecoration(size: geo.size)
            }
        }
        .background(Theme.Colors.cardBackground)
        .clipped()
    }

    // MARK: - Patterns

    private enum Pattern: CaseIterable {
        case diagonalStripes
        case concentricCircles
        case grid
        case chevrons
        case dots
    }

    @ViewBuilder
    private func patternView(size: CGSize) -> some View {
        switch pattern {
        case .diagonalStripes:
            diagonalStripes(size: size)
        case .concentricCircles:
            concentricCircles(size: size)
        case .grid:
            gridPattern(size: size)
        case .chevrons:
            chevronPattern(size: size)
        case .dots:
            dotPattern(size: size)
        }
    }

    private func diagonalStripes(size: CGSize) -> some View {
        let stripeWidth: CGFloat = 12
        let count = Int(max(size.width, size.height) / stripeWidth) + 4
        return Canvas { context, canvasSize in
            for i in stride(from: -count, to: count * 2, by: 2) {
                var path = Path()
                let x = CGFloat(i) * stripeWidth
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x - canvasSize.height, y: canvasSize.height))
                context.stroke(path, with: .color(colorPair.0), lineWidth: stripeWidth * 0.6)
            }
        }
    }

    private func concentricCircles(size: CGSize) -> some View {
        let centerX = size.width * CGFloat((seed % 3 + 1)) / 4.0
        let centerY = size.height * CGFloat(((seed / 3) % 3 + 1)) / 4.0
        return Canvas { context, _ in
            for i in stride(from: 0, to: 8, by: 1) {
                let radius = CGFloat(i) * 20 + 10
                let rect = CGRect(
                    x: centerX - radius,
                    y: centerY - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(colorPair.0),
                    lineWidth: 2
                )
            }
        }
    }

    private func gridPattern(size: CGSize) -> some View {
        let spacing: CGFloat = 20
        return Canvas { context, canvasSize in
            for x in stride(from: CGFloat(0), to: canvasSize.width, by: spacing) {
                for y in stride(from: CGFloat(0), to: canvasSize.height, by: spacing) {
                    let rect = CGRect(x: x + 4, y: y + 4, width: spacing - 8, height: spacing - 8)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 3),
                        with: .color(colorPair.0)
                    )
                }
            }
        }
    }

    private func chevronPattern(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            for i in stride(from: 0, to: Int(canvasSize.height) + 40, by: 24) {
                var path = Path()
                let y = CGFloat(i)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width / 2, y: y - 12))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                context.stroke(path, with: .color(colorPair.0), lineWidth: 2)
            }
        }
    }

    private func dotPattern(size: CGSize) -> some View {
        let spacing: CGFloat = 16
        return Canvas { context, canvasSize in
            for x in stride(from: spacing / 2, to: canvasSize.width, by: spacing) {
                for y in stride(from: spacing / 2, to: canvasSize.height, by: spacing) {
                    let radius: CGFloat = 3
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(colorPair.0))
                }
            }
        }
    }

    // MARK: - Title decoration

    /// Font options mixing system designs with named iOS typefaces for variety
    private enum TitleFont: CaseIterable {
        case systemBlackRounded
        case systemHeavySerif
        case systemBoldMono
        case condensedBold       // Avenir Next Condensed
        case didot               // Classic high-contrast serif
        case futura              // Geometric sans
        case copperplate         // Engraved small-caps feel
        case papyrus             // Playful/adventurous (game night vibe)
        case snellRoundhand      // Script/cursive
        case americanTypewriter  // Retro slab
        case rockwell            // Bold slab serif
        case georgia             // Elegant serif
        case impact              // Ultra-condensed bold
        case chalkboard          // Casual hand-drawn
        case markerFelt          // Marker pen feel
        case zapfino             // Calligraphic flourish

        func font(size: CGFloat) -> Font {
            switch self {
            case .systemBlackRounded:
                return .system(size: size, weight: .black, design: .rounded)
            case .systemHeavySerif:
                return .system(size: size, weight: .heavy, design: .serif)
            case .systemBoldMono:
                return .system(size: size, weight: .bold, design: .monospaced)
            case .condensedBold:
                return .custom("AvenirNextCondensed-Bold", size: size)
            case .didot:
                return .custom("Didot-Bold", size: size)
            case .futura:
                return .custom("Futura-Bold", size: size)
            case .copperplate:
                return .custom("Copperplate-Bold", size: size)
            case .papyrus:
                return .custom("Menlo", size: size)
            case .snellRoundhand:
                return .custom("SnellRoundhand-Black", size: size)
            case .americanTypewriter:
                return .custom("AmericanTypewriter-Bold", size: size)
            case .rockwell:
                return .custom("Rockwell-Bold", size: size)
            case .georgia:
                return .custom("Georgia-Bold", size: size)
            case .impact:
                return .custom("Impact", size: size)
            case .chalkboard:
                return .custom("Optima-Bold", size: size)
            case .markerFelt:
                return .custom("MarkerFelt-Wide", size: size)
            case .zapfino:
                return .custom("Zapfino", size: size * 0.6)
            }
        }
    }

    private var titleFont: TitleFont {
        TitleFont.allCases[(seed / 3) % TitleFont.allCases.count]
    }

    private var titleRotation: Double {
        let angles = [-8.0, -5.0, -3.0, 0.0, 3.0, 5.0, 8.0, -12.0, 6.0]
        return angles[(seed / 7) % angles.count]
    }

    private func titleDecoration(size: CGSize) -> some View {
        let displayTitle = title.isEmpty ? "Game Night" : title

        let charCount = max(displayTitle.count, 1)
        let baseFontSize = size.width * 0.38
        let scaledSize = min(baseFontSize, size.width * 6.0 / CGFloat(charCount))
        let fontSize = max(scaledSize, 16)

        let yOffset = size.height * 0.12

        return Text(displayTitle.uppercased())
            .font(titleFont.font(size: fontSize))
            .foregroundColor(colorScheme.text.opacity(0.42))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.4)
            .rotationEffect(.degrees(titleRotation))
            .offset(y: yOffset)
            .frame(width: size.width * 1.15, height: size.height * 1.1)
            .clipped()
    }
}
