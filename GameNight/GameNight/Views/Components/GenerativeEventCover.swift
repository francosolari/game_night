import SwiftUI

/// Generates a deterministic, visually interesting cover from an event title
/// when no custom cover image is set. Uses the theme palette and the title's
/// hash to produce a unique but stable pattern per event.
struct GenerativeEventCover: View {
    let title: String
    let eventId: UUID

    /// Stable seed derived from event ID so the pattern never changes per event
    private var seed: Int {
        abs(eventId.hashValue)
    }

    private var patternIndex: Int {
        seed % Pattern.allCases.count
    }

    private var pattern: Pattern {
        Pattern.allCases[patternIndex]
    }

    /// Pick two theme-appropriate colors from a curated set
    private var colorPair: (Color, Color) {
        let pairs: [(Color, Color)] = [
            (Theme.Colors.primary, Theme.Colors.primaryLight),
            (Theme.Colors.accent, Theme.Colors.accentLight),
            (Theme.Colors.primary, Theme.Colors.accent),
            (Theme.Colors.accentLight, Theme.Colors.primaryLight),
            (Theme.Colors.highlight.opacity(0.6), Theme.Colors.accent),
            (Theme.Colors.primaryDark, Theme.Colors.primary),
        ]
        return pairs[seed % pairs.count]
    }

    private var rotationAngle: Double {
        let angles = [0.0, 15.0, 30.0, 45.0, -15.0, -30.0]
        return angles[(seed / 6) % angles.count]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [colorPair.0.opacity(0.3), colorPair.1.opacity(0.25)],
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

    private var titleDesign: Font.Design {
        let designs: [Font.Design] = [.rounded, .serif, .monospaced, .default, .rounded, .serif]
        return designs[(seed / 5) % designs.count]
    }

    private var titleWeight: Font.Weight {
        let weights: [Font.Weight] = [.black, .heavy, .bold, .ultraLight, .black, .heavy]
        return weights[(seed / 3) % weights.count]
    }

    private var titleRotation: Double {
        let angles = [-8.0, -5.0, -3.0, 0.0, 3.0, 5.0, 8.0, -12.0, 6.0]
        return angles[(seed / 7) % angles.count]
    }

    private func titleDecoration(size: CGSize) -> some View {
        let displayTitle = title.isEmpty ? "Game Night" : title

        // Scale font to fit width with some overflow allowed
        // Longer titles get smaller font, short titles get big dramatic font
        let charCount = max(displayTitle.count, 1)
        let baseFontSize = size.width * 0.38
        let scaledSize = min(baseFontSize, size.width * 6.0 / CGFloat(charCount))
        let fontSize = max(scaledSize, 16)

        // Vertical offset: nudge down so text is centered-to-bottom, partially clipped
        let yOffset = size.height * 0.12

        return Text(displayTitle.uppercased())
            .font(.system(size: fontSize, weight: titleWeight, design: titleDesign))
            .foregroundColor(colorPair.0.opacity(0.22))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.4)
            .rotationEffect(.degrees(titleRotation))
            .offset(y: yOffset)
            .frame(width: size.width * 1.15, height: size.height * 1.1)
            .clipped()
    }
}
