import SwiftUI

struct PlayerCountIndicator: View {
    let confirmedCount: Int
    let minPlayers: Int
    let maxPlayers: Int?
    var size: ComponentSize = .standard

    private var effectiveMax: Int {
        maxPlayers ?? minPlayers
    }

    private var useMeepleMode: Bool {
        effectiveMax <= 6
    }

    var body: some View {
        if useMeepleMode {
            meepleView
        } else {
            compactTextView
        }
    }

    private var meepleIconSize: CGFloat {
        switch size {
        case .compact: return 12
        case .standard: return 16
        case .expanded: return 20
        }
    }

    private var meepleView: some View {
        HStack(spacing: size == .compact ? 1 : 2) {
            ForEach(0..<effectiveMax, id: \.self) { index in
                Image(systemName: index < confirmedCount ? "person.fill" : "person")
                    .font(.system(size: meepleIconSize))
                    .foregroundColor(meepleColor(for: index))
            }
        }
    }

    private func meepleColor(for index: Int) -> Color {
        if index < confirmedCount {
            return Theme.Colors.success
        } else if index < minPlayers {
            return Theme.Colors.success.opacity(0.4)
        } else {
            return Theme.Colors.textTertiary.opacity(0.4)
        }
    }

    private var compactTextView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text("\(confirmedCount)")
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("/")
                    .foregroundColor(Theme.Colors.textTertiary)
                Text("\(minPlayers)")
                    .foregroundColor(Theme.Colors.success)
                if let max = maxPlayers, max != minPlayers {
                    Text("-\(max)")
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .font(size.captionFont)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.Colors.textTertiary.opacity(0.2))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.Colors.success)
                        .frame(width: fillWidth(totalWidth: geo.size.width), height: 3)

                    if effectiveMax > 0 {
                        let minPosition = CGFloat(minPlayers) / CGFloat(effectiveMax) * geo.size.width
                        Rectangle()
                            .fill(Theme.Colors.success.opacity(0.5))
                            .frame(width: 1, height: 5)
                            .offset(x: minPosition)
                    }
                }
            }
            .frame(height: 5)
        }
    }

    private func fillWidth(totalWidth: CGFloat) -> CGFloat {
        guard effectiveMax > 0 else { return 0 }
        let ratio = CGFloat(min(confirmedCount, effectiveMax)) / CGFloat(effectiveMax)
        return totalWidth * ratio
    }
}
