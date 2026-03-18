import SwiftUI

enum BadgeSize {
    case small, medium, large

    var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }

    var padding: EdgeInsets {
        switch self {
        case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
        case .medium: return EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        case .large: return EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        }
    }
}

struct RatingBadge: View {
    let rating: Double
    var size: BadgeSize = .medium

    var body: some View {
        Text(String(format: "%.1f", rating))
            .font(.system(size: size.fontSize, weight: .black))
            .foregroundColor(.white)
            .padding(size.padding)
            .background(
                RoundedRectangle(cornerRadius: size == .small ? 6 : 12)
                    .fill(Theme.Colors.success)
            )
    }
}
