import SwiftUI

struct DetailHeroImage: View {
    let imageUrl: String?
    var badge: Double?
    var fallbackInitials: String?
    var gradientColors: [Color] = [Theme.Colors.accent.opacity(0.5), Theme.Colors.primary.opacity(0.5)]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipped()
                } placeholder: {
                    fallbackView
                }
            } else {
                fallbackView
            }

            if let badge {
                RatingBadge(rating: badge, size: .large)
                    .padding(Theme.Spacing.lg)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
    }

    private var fallbackView: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if let initials = fallbackInitials {
                Text(initials)
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
    }
}
