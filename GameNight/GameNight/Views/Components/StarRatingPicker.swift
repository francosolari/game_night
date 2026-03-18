import SwiftUI

struct ComplexitySliderPicker: View {
    @Binding var complexity: Double
    var titleFont: Font = Theme.Typography.bodyMedium
    var valueFont: Font = Theme.Typography.calloutMedium
    var detailFont: Font = Theme.Typography.caption

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Complexity")
                    .font(titleFont)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Text(String(format: "%.1f / 5", complexity))
                    .font(valueFont)
                    .foregroundColor(Theme.Colors.complexity(complexity))
            }

            Slider(
                value: Binding(
                    get: { complexity },
                    set: { complexity = min(max($0, 0), 5) }
                ),
                in: 0...5,
                step: 0.1
            )
            .tint(Theme.Colors.complexity(complexity))

            Text(Theme.Colors.complexityLabel(complexity))
                .font(detailFont)
                .foregroundColor(Theme.Colors.textTertiary)
        }
    }
}

struct StarRatingPicker: View {
    @Binding var rating: Double
    let maxRating: Int = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                starView(for: star)
                    .onTapGesture { location in
                        let halfWidth: CGFloat = 14
                        if location.x < halfWidth {
                            rating = Double(star) - 0.5
                        } else {
                            rating = Double(star)
                        }
                    }
            }

            Text(String(format: "%.1f / 5", rating))
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.leading, Theme.Spacing.sm)
        }
    }

    @ViewBuilder
    private func starView(for star: Int) -> some View {
        let fillAmount = rating - Double(star - 1)

        ZStack {
            Image(systemName: "star")
                .font(.system(size: 22))
                .foregroundColor(Theme.Colors.textTertiary.opacity(0.3))

            if fillAmount >= 1.0 {
                Image(systemName: "star.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.Colors.warning)
            } else if fillAmount >= 0.5 {
                Image(systemName: "star.leadinghalf.filled")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.Colors.warning)
            }
        }
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
    }
}
