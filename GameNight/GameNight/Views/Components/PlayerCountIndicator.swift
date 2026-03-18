import SwiftUI

struct PlayerCountIndicator: View {
    let confirmedCount: Int
    let minPlayers: Int
    let maxPlayers: Int?
    var size: ComponentSize = .standard

    private var effectiveMax: Int {
        maxPlayers ?? minPlayers
    }

    private var hasQuorum: Bool {
        confirmedCount >= minPlayers
    }

    private var isFull: Bool {
        confirmedCount >= effectiveMax
    }

    private var statusColor: Color {
        if isFull { return Theme.Colors.textTertiary }
        if hasQuorum { return Theme.Colors.success }
        return Theme.Colors.warning
    }

    var body: some View {
        switch size {
        case .compact:
            compactView
        case .standard, .expanded:
            standardView
        }
    }

    // MARK: - Compact: minimal footprint for carousel cards
    // Shows "2/4–6" with a thin progress bar
    private var compactView: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 0) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundColor(statusColor)
                    .padding(.trailing, 2)

                Text("\(confirmedCount)")
                    .foregroundColor(statusColor)
                    .fontWeight(.semibold)
                Text("/\(minPlayers)")
                    .foregroundColor(Theme.Colors.textTertiary)
                if let max = maxPlayers, max != minPlayers {
                    Text("–\(max)")
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .font(Theme.Typography.caption2)

            progressBar
                .frame(width: 40, height: 3)
        }
    }

    // MARK: - Standard: fuller display for list cards and detail views
    private var standardView: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 2) {
                Image(systemName: "person.fill")
                    .font(.system(size: size == .expanded ? 12 : 10))
                    .foregroundColor(statusColor)

                Text("\(confirmedCount)")
                    .foregroundColor(statusColor)
                    .fontWeight(.semibold)
                Text("/ \(minPlayers)")
                    .foregroundColor(Theme.Colors.textTertiary)
                if let max = maxPlayers, max != minPlayers {
                    Text("– \(max)")
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .font(size.captionFont)

            if !hasQuorum {
                Text("\(minPlayers - confirmedCount) more needed")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.warning)
            } else if isFull {
                Text("Full")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.textTertiary)
            } else {
                Text("\(effectiveMax - confirmedCount) spots left")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.success)
            }

            progressBar
                .frame(width: size == .expanded ? 60 : 48, height: 3)
        }
    }

    // MARK: - Progress bar
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.Colors.textTertiary.opacity(0.2))

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(statusColor)
                    .frame(width: fillWidth(totalWidth: geo.size.width))

                // Min-players marker
                if effectiveMax > 0 && effectiveMax != minPlayers {
                    let minPos = CGFloat(minPlayers) / CGFloat(effectiveMax) * geo.size.width
                    Rectangle()
                        .fill(Theme.Colors.textTertiary.opacity(0.5))
                        .frame(width: 1, height: 5)
                        .offset(x: minPos)
                }
            }
        }
    }

    private func fillWidth(totalWidth: CGFloat) -> CGFloat {
        guard effectiveMax > 0 else { return 0 }
        let ratio = CGFloat(min(confirmedCount, effectiveMax)) / CGFloat(effectiveMax)
        return totalWidth * ratio
    }
}
