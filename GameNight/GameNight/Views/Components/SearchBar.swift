import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.textTertiary)

            TextField(placeholder, text: $text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .focused($isFocused)
                .onSubmit { onSubmit?() }
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12) // Slightly taller
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.cardBackground) // Use card background
                .shadow(color: .black.opacity(ThemeManager.shared.isDark ? 0.2 : 0.06), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(isFocused ? Theme.Colors.primary : Theme.Colors.divider, lineWidth: 1) // Clearer focus state
        )
        .animation(Theme.Animation.snappy, value: isFocused)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var action: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            if let action {
                Button(action) { onAction?() }
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.primary)
            }
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String?
    var onAction: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Theme.Gradients.primary)

            Text(title)
                .font(Theme.Typography.headlineLarge)
                .foregroundColor(Theme.Colors.textPrimary)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxxl)

            if let actionLabel {
                Button(actionLabel) { onAction?() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Theme.Spacing.jumbo)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.Colors.primary)
                .scaleEffect(1.2)

            Text(message)
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
