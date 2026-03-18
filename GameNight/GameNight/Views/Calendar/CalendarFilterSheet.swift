import SwiftUI

struct CalendarFilterSheet: View {
    @ObservedObject var viewModel: CalendarViewModel

    private let filterIcons: [CalendarViewModel.FilterCategory: String] = [
        .myEvents: "crown.fill",
        .attending: "checkmark.circle.fill",
        .deciding: "questionmark.circle.fill",
        .waitingOnHost: "hourglass",
        .notGoing: "xmark.circle.fill"
    ]

    private let filterIconColors: [CalendarViewModel.FilterCategory: Color] = [
        .myEvents: Theme.Colors.highlight,
        .attending: Theme.Colors.success,
        .deciding: Theme.Colors.warning,
        .waitingOnHost: Theme.Colors.textTertiary,
        .notGoing: Theme.Colors.error
    ]

    private let filterDescriptions: [CalendarViewModel.FilterCategory: String] = [
        .myEvents: "Hosting / Hosted",
        .attending: "Going / On the List",
        .deciding: "Invited / Maybe / Interested",
        .waitingOnHost: "Pending / Waitlisted / Responded",
        .notGoing: "Can't Go / Not approved / Canceled"
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Theme.Colors.textTertiary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, Theme.Spacing.sm)

            // Filter rows
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(CalendarViewModel.FilterCategory.allCases) { category in
                    filterRow(category)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()

            // Bottom buttons
            HStack {
                Button("Reset") {
                    viewModel.resetFilters()
                }
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                Button("Done") {
                    viewModel.showFilterSheet = false
                }
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .fill(Theme.Colors.cardBackground)
                )
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func filterRow(_ category: CalendarViewModel.FilterCategory) -> some View {
        Button {
            if viewModel.activeFilters.contains(category) {
                viewModel.activeFilters.remove(category)
            } else {
                viewModel.activeFilters.insert(category)
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: filterIcons[category] ?? "circle")
                    .font(.system(size: 22))
                    .foregroundColor(filterIconColors[category] ?? Theme.Colors.textSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(filterDescriptions[category] ?? "")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: viewModel.activeFilters.contains(category) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(viewModel.activeFilters.contains(category) ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
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
