import SwiftUI
import UIKit

// MARK: - Card Style
struct CardModifier: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    var padding: CGFloat = Theme.Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.cardBackground)
                    .shadow(color: Color.black.opacity(themeManager.isDark ? 0.3 : 0.06), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Glass Card Style
struct GlassCardModifier: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.bodySemibold)
            .foregroundColor(Theme.Colors.primaryActionText)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isEnabled ? Theme.Gradients.primary : LinearGradient(
                        colors: [Theme.Colors.textTertiary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.bodySemibold)
            .foregroundColor(Theme.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Theme.Colors.primary, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Sage Segmented Picker Style
struct SageSegmentedStyle: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .onAppear {
                applyAppearance()
            }
            .onChange(of: themeManager.mode) { _, _ in applyAppearance() }
            .onChange(of: themeManager.systemColorScheme) { _, _ in applyAppearance() }
    }

    private func applyAppearance() {
        let appearance = UISegmentedControl.appearance()
        let isDark = themeManager.isDark
        let selectedTint = UIColor(isDark ? Theme.Colors.selectedSegmentBackground : Theme.Colors.primaryAction)
        let background = UIColor(isDark ? Theme.Colors.fieldBackground : Theme.Colors.elevatedBackground)
        let selectedText = UIColor(isDark ? Theme.Colors.textPrimary : Theme.Colors.primaryActionText)
        let normalText = UIColor(isDark ? Theme.Colors.tabInactive : Theme.Colors.textSecondary)

        appearance.selectedSegmentTintColor = selectedTint
        appearance.backgroundColor = background
        appearance.setTitleTextAttributes(
            [.foregroundColor: selectedText],
            for: .selected
        )
        appearance.setTitleTextAttributes(
            [.foregroundColor: normalText],
            for: .normal
        )
    }
}

// MARK: - Add People Button Style
struct AddPeopleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Theme.Colors.primary : Theme.Colors.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(configuration.isPressed ? Theme.Colors.primary.opacity(0.08) : Theme.Colors.backgroundElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .stroke(configuration.isPressed ? Theme.Colors.primary : Theme.Colors.divider, lineWidth: configuration.isPressed ? 1.5 : 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Chip Style
struct ChipModifier: ViewModifier {
    let color: Color
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.label)
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.15))
            )
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle(padding: CGFloat = Theme.Spacing.lg) -> some View {
        modifier(CardModifier(padding: padding))
    }

    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }

    func chipStyle(color: Color = Theme.Colors.primary, isSelected: Bool = false) -> some View {
        modifier(ChipModifier(color: color, isSelected: isSelected))
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func sageSegmented() -> some View {
        modifier(SageSegmentedStyle())
    }
}

// MARK: - Shimmer Effect (Loading)
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if let metrics = ShimmerLayoutMetrics.make(width: geo.size.width, phase: phase) {
                        LinearGradient(
                            colors: [
                                .clear,
                                Theme.Colors.shimmer,
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: metrics.gradientWidth)
                        .offset(x: metrics.offsetX)
                    }
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Fade-in on appear
struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    opacity = 1
                }
            }
    }
}

extension View {
    func fadeIn(delay: Double = 0) -> some View {
        modifier(FadeInModifier(delay: delay))
    }
}

// MARK: - Keyboard Dismissal
extension View {
    /// Dismisses the keyboard when the user taps outside a text field.
    func hideKeyboardOnTap() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
    }
}
