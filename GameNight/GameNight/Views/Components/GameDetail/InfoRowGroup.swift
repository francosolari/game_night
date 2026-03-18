import SwiftUI

struct InfoRowData: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
    var detail: String?
    var detailColor: Color?
}

struct InfoRow: View {
    let data: InfoRowData

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: data.icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 28)

            Text(data.value)
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)

            if let detail = data.detail {
                Text(detail)
                    .font(Theme.Typography.caption)
                    .foregroundColor(data.detailColor ?? Theme.Colors.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }
}

struct InfoRowGroup: View {
    let rows: [InfoRowData]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, rowData in
                InfoRow(data: rowData)
                if index < rows.count - 1 {
                    Divider()
                        .background(Theme.Colors.textTertiary.opacity(0.15))
                        .padding(.leading, 28 + Theme.Spacing.md + Theme.Spacing.lg)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.backgroundElevated)
        )
    }
}
