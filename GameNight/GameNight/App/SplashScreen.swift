import SwiftUI

struct SplashScreen: View {
    @State private var scale: CGFloat = 0.95
    @State private var opacity: Double = 1.0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                ZStack {
                    // Subtle rotating loading ring
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            Theme.Gradients.primary,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }

                    Image("MeepleLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .scaleEffect(scale)
                }

                Text("CardboardWithMe")
                    .font(Theme.Typography.displayLarge)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Gather around the table")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)

                Spacer()

                Link(destination: URL(string: "https://boardgamegeek.com")!) {
                    Image("PoweredByBGG")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 36)
                }
                .padding(.bottom, 24)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
            }
        }
    }
}
