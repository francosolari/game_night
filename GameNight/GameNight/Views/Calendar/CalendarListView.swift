import SwiftUI

struct CalendarListView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let onEventTap: (GameEvent) -> Void

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE MMMM d"
        return f
    }()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    ForEach(Array(viewModel.eventsByDay.enumerated()), id: \.element.date) { index, group in
                        // Today divider
                        if let todayIndex = viewModel.todayIndex, index == todayIndex {
                            todayDivider
                                .id("today")
                        }

                        // Day header
                        Text(dayFormatter.string(from: group.date))
                            .font(Theme.Typography.headlineMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal, Theme.Spacing.xl)

                        // Events for this day
                        ForEach(group.events) { event in
                            let isPast = group.date < Calendar.current.startOfDay(for: Date())
                            ListEventCard(
                                event: event,
                                myInvite: viewModel.invite(for: event.id),
                                confirmedCount: viewModel.confirmedCount(for: event.id)
                            ) {
                                onEventTap(event)
                            }
                            .padding(.horizontal, Theme.Spacing.xl)
                            .opacity(isPast ? 0.7 : 1.0)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .onAppear {
                proxy.scrollTo("today", anchor: .top)
            }
        }
    }

    private var todayDivider: some View {
        HStack {
            VStack { Divider() }
            Text("Today")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.primary)
                .padding(.horizontal, Theme.Spacing.sm)
            VStack { Divider() }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}
