import SwiftUI

struct CalendarDayDetailView: View {
    let date: Date
    let events: [GameEvent]
    @ObservedObject var viewModel: CalendarViewModel
    let onEventTap: (GameEvent) -> Void

    private var headerText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE \u{00B7} MMMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Drag handle
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Theme.Colors.textTertiary.opacity(0.3))
                    .frame(width: 36, height: 5)
                Spacer()
            }

            Text(headerText)
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.textSecondary)

            ForEach(events) { event in
                ListEventCard(
                    event: event,
                    myInvite: viewModel.invite(for: event.id),
                    confirmedCount: viewModel.confirmedCount(for: event.id)
                ) {
                    onEventTap(event)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.md)
    }
}
