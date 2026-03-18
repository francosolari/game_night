import SwiftUI

struct TagFlowSection: View {
    let title: String
    let tags: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .chipStyle(color: color)
                }
            }
        }
    }
}
