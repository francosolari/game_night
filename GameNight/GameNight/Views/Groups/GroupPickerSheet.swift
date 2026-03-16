import SwiftUI

struct GroupPickerSheet: View {
    let groups: [GameGroup]
    let onSelect: (GameGroup) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(groups) { group in
                        Button {
                            onSelect(group)
                            dismiss()
                        } label: {
                            HStack(spacing: Theme.Spacing.lg) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.Gradients.primary)
                                        .frame(width: 44, height: 44)
                                    Text(group.emoji ?? "🎲")
                                        .font(.system(size: 22))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Text("\(group.memberCount) members")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .fill(Theme.Colors.cardBackground)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.md)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Select Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
    }
}
