import SwiftUI

struct SplashScreen: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Gradients.primary)
                    .scaleEffect(scale)

                Text("Game Night")
                    .font(Theme.Typography.displayLarge)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Roll the dice on plans")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
