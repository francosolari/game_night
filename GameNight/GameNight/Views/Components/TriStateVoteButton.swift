import SwiftUI

struct TriStateVoteButton: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    var size: CGFloat = 32
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: size * 0.375, weight: .bold))
                .foregroundColor(isSelected ? .white : color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}
