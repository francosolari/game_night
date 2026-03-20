import SwiftUI

/// Card with a colored left-edge accent bar.
/// Shared across announcements, guest groups, and pinned items.
struct AccentBorderCard<Content: View>: View {
    let accentColor: Color
    var accentWidth: CGFloat = 2
    var backgroundColor: Color? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: accentWidth / 2)
                .fill(accentColor)
                .frame(width: accentWidth)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(backgroundColor ?? Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
    }
}
