import SwiftUI

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
