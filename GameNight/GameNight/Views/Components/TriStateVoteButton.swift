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
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: max(10, size * 0.32), weight: .bold))
                Text(label)
                    .font(.system(size: max(10, size * 0.32), weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, max(8, size * 0.28))
            .padding(.vertical, max(6, size * 0.2))
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.14))
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? color : color.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
