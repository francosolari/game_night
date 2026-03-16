import SwiftUI

struct PlayerCountIndicator: View {
    let confirmedCount: Int
    let minPlayers: Int
    let maxPlayers: Int?

    private var totalSlots: Int {
        maxPlayers ?? max(minPlayers, confirmedCount)
    }

    private var isViable: Bool {
        confirmedCount >= minPlayers
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("Players")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)

            HStack(spacing: 2) {
                ForEach(0..<totalSlots, id: \.self) { index in
                    Image(systemName: index < confirmedCount ? "person.fill" : "person")
                        .font(.system(size: 11))
                        .foregroundColor(index < confirmedCount ? Theme.Colors.success : Theme.Colors.textTertiary.opacity(0.4))
                }
            }

            Text("\(confirmedCount)/\(totalSlots)")
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)

            if isViable {
                Text("Ready!")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.success)
            } else {
                let needed = minPlayers - confirmedCount
                Text("Need \(needed) more")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.warning)
            }
        }
    }
}
