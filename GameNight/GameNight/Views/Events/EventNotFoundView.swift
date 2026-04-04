import SwiftUI

/// Shown when navigating to an event that has been deleted, cancelled,
/// or is no longer accessible (e.g. stale push notification or old DM invite card).
struct EventNotFoundView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "dice.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Gradients.primary)
                .opacity(0.5)

            VStack(spacing: Theme.Spacing.sm) {
                Text("This invite is gone")
                    .font(Theme.Typography.headlineLarge)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("It may have been cancelled, or\nyou might not have access anymore.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)
            }

            Spacer()

            Button("Go Back") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}
