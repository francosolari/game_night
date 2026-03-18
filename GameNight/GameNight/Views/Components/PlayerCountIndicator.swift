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

    // MARK: - Compact: icon + count + segmented bar
    private var compactView: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundColor(statusColor)

                Text("\(confirmedCount)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(statusColor)

                Text("of \(effectiveMax)")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

            segmentedBar
                .frame(width: 44, height: 4)
        }
    }

    // MARK: - Standard: fuller display with status label
    private var standardView: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: "person.fill")
                    .font(.system(size: size == .expanded ? 12 : 10))
                    .foregroundColor(statusColor)

                Text("\(confirmedCount)")
                    .font(.system(size: size == .expanded ? 16 : 14, weight: .semibold, design: .rounded))
                    .foregroundColor(statusColor)

                Text("of \(effectiveMax)")
                    .font(size.captionFont)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

            statusLabel

            segmentedBar
                .frame(width: size == .expanded ? 64 : 50, height: 4)
        }
    }

    // MARK: - Status label
    @ViewBuilder
    private var statusLabel: some View {
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
    }

    // MARK: - Segmented progress bar
    // Each segment = one player slot. Filled segments = confirmed.
    // A subtle marker separates "min needed" from "optional" slots.
    private var segmentedBar: some View {
        GeometryReader { geo in
            let totalSlots = effectiveMax
            guard totalSlots > 0 else { return AnyView(EmptyView()) }

            let gap: CGFloat = totalSlots <= 8 ? 1.5 : 0.5
            let totalGaps = CGFloat(totalSlots - 1) * gap
            let segWidth = (geo.size.width - totalGaps) / CGFloat(totalSlots)

            return AnyView(
                HStack(spacing: gap) {
                    ForEach(0..<totalSlots, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(segmentColor(for: i))
                            .frame(width: max(segWidth, 2))
                    }
                }
            )
        }
    }

    private func segmentColor(for index: Int) -> Color {
        if index < confirmedCount {
            // Filled — player confirmed
            return statusColor
        } else if index < minPlayers {
            // Unfilled but needed — show as faded status color
            return statusColor.opacity(0.25)
        } else {
            // Optional slot beyond minimum
            return Theme.Colors.textTertiary.opacity(0.15)
        }
    }
}
