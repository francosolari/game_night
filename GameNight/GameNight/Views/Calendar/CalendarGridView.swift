import SwiftUI

struct EventCalendarGridView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let onEventTap: (GameEvent) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            let days = daysInMonth()
            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, entry in
                    dayCellView(date: entry.date, isCurrentMonth: entry.isCurrentMonth)
                }
            }

            // Selected day detail
            if let selectedDate = viewModel.selectedDate {
                let dayEvents = viewModel.events(for: selectedDate)
                if dayEvents.isEmpty {
                    VStack(spacing: Theme.Spacing.sm) {
                        Text("No events this day")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Why not schedule a game night?")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xl)
                } else {
                    CalendarDayDetailView(
                        date: selectedDate,
                        events: dayEvents,
                        viewModel: viewModel,
                        onEventTap: onEventTap
                    )
                }
            }
        }
    }

    private func dayCellView(date: Date, isCurrentMonth: Bool) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isSelected = viewModel.selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let dayEvents = isCurrentMonth ? viewModel.events(for: date) : []

        return Button {
            withAnimation(Theme.Animation.snappy) {
                if isCurrentMonth {
                    viewModel.selectedDate = isSelected ? nil : date
                } else {
                    viewModel.navigateToDate(date)
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(Theme.Typography.callout)
                    .foregroundColor(
                        !isCurrentMonth ? Theme.Colors.textTertiary.opacity(0.4)
                        : isToday ? Theme.Colors.primary
                        : Theme.Colors.textPrimary
                    )
                    .frame(width: 32, height: 32)
                    .background {
                        if isCurrentMonth && isToday {
                            Circle().stroke(Theme.Colors.primary, lineWidth: 1.5)
                        }
                        if isCurrentMonth && isSelected {
                            Circle().fill(Theme.Colors.primary.opacity(0.15))
                        }
                    }

                if let firstEvent = dayEvents.first {
                    Image(systemName: gameCategoryIcon(for: firstEvent))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary)

                    Circle()
                        .fill(rsvpDotColor(for: firstEvent))
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(height: 14)
                    Color.clear.frame(height: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private struct CalendarDay: Equatable {
        let date: Date
        let isCurrentMonth: Bool
    }

    private func daysInMonth() -> [CalendarDay] {
        let calendar = Calendar.current
        let month = viewModel.currentMonth

        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingCount = weekday - 1

        var days: [CalendarDay] = []

        // Fill leading days from previous month
        if leadingCount > 0, let prevMonthEnd = calendar.date(byAdding: .day, value: -1, to: firstDay) {
            for i in stride(from: leadingCount - 1, through: 0, by: -1) {
                if let date = calendar.date(byAdding: .day, value: -i, to: prevMonthEnd) {
                    days.append(CalendarDay(date: date, isCurrentMonth: false))
                }
            }
        }

        // Current month days
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(CalendarDay(date: date, isCurrentMonth: true))
            }
        }

        // Fill trailing days from next month to complete 6 rows (42 cells)
        let totalCells = 42
        if let lastDay = calendar.date(byAdding: .day, value: range.count - 1, to: firstDay) {
            var nextDay = lastDay
            while days.count < totalCells {
                if let next = calendar.date(byAdding: .day, value: 1, to: nextDay) {
                    days.append(CalendarDay(date: next, isCurrentMonth: false))
                    nextDay = next
                }
            }
        }

        return days
    }

    private func gameCategoryIcon(for event: GameEvent) -> String {
        guard let primaryGame = event.games.first(where: { $0.isPrimary })?.game ?? event.games.first?.game else {
            return "gamecontroller.fill"
        }

        for category in primaryGame.categories {
            let lower = category.lowercased()
            if lower.contains("strategy") || lower.contains("board") { return "dice.fill" }
            if lower.contains("card") { return "suit.spade.fill" }
            if lower.contains("puzzle") || lower.contains("escape") { return "puzzlepiece.fill" }
            if lower.contains("party") || lower.contains("social") { return "person.3.fill" }
        }

        return "gamecontroller.fill"
    }

    private func rsvpDotColor(for event: GameEvent) -> Color {
        let isHost = event.hostId == SupabaseService.shared.client.auth.currentSession?.user.id
        if isHost { return Theme.Colors.success }

        guard let invite = viewModel.invite(for: event.id) else {
            return Theme.Colors.dateAccent
        }

        return invite.status.color
    }
}
