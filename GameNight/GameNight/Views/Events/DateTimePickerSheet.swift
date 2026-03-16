import SwiftUI

struct DateTimePickerSheet: View {
    @Binding var date: Date
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var hasEndTime: Bool
    @Environment(\.dismiss) private var dismiss

    /// When true, the picker is editing the end date/time
    @State private var isEditingEnd = false
    @State private var displayedMonth: Date

    init(date: Binding<Date>, startTime: Binding<Date>, endTime: Binding<Date>, hasEndTime: Binding<Bool>) {
        _date = date
        _startTime = startTime
        _endTime = endTime
        _hasEndTime = hasEndTime
        _displayedMonth = State(initialValue: date.wrappedValue)
    }

    private var selectedDate: Date {
        isEditingEnd ? date : date
    }

    private var selectedTime: Date {
        isEditingEnd ? endTime : startTime
    }

    var body: some View {
        VStack(spacing: 0) {
            // A. Header bar
            headerBar

            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // B. Summary bar
                    summaryBar

                    // C. Calendar grid
                    calendarGrid

                    // D. Time scroll carousel
                    timeCarousel
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.jumbo)
            }

            // E. Footer bar
            footerBar
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button("Clear") {
                date = Date()
                startTime = defaultStartTime
                endTime = Calendar.current.date(byAdding: .hour, value: 3, to: defaultStartTime)!
                hasEndTime = false
                isEditingEnd = false
                displayedMonth = Date()
            }
            .font(Theme.Typography.bodyMedium)
            .foregroundColor(Theme.Colors.textSecondary)

            Spacer()

            Text("Date & Time")
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            // Balance the Clear button width
            Color.clear.frame(width: 44)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 0) {
            // Left: start date/time
            Button {
                withAnimation(Theme.Animation.snappy) { isEditingEnd = false }
            } label: {
                VStack(spacing: 2) {
                    Text(shortDateString(date))
                        .font(Theme.Typography.calloutMedium)
                    Text(shortTimeString(startTime))
                        .font(Theme.Typography.headlineMedium)
                }
                .foregroundColor(isEditingEnd ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Colors.textTertiary)

            // Right: end date/time
            Button {
                withAnimation(Theme.Animation.snappy) {
                    isEditingEnd = true
                    if !hasEndTime {
                        hasEndTime = true
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    if hasEndTime {
                        Text(shortDateString(date))
                            .font(Theme.Typography.calloutMedium)
                        Text(shortTimeString(endTime))
                            .font(Theme.Typography.headlineMedium)
                    } else {
                        Text("End Time")
                            .font(Theme.Typography.calloutMedium)
                        Text("Optional")
                            .font(Theme.Typography.headlineMedium)
                    }
                }
                .foregroundColor(isEditingEnd ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
        )
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Month header with navigation
            HStack {
                Text(monthYearString(displayedMonth))
                    .font(Theme.Typography.headlineMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                HStack(spacing: Theme.Spacing.lg) {
                    Button {
                        withAnimation(Theme.Animation.smooth) { changeMonth(by: -1) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Button {
                        withAnimation(Theme.Animation.smooth) { changeMonth(by: 1) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }

            // Day-of-week row
            let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Date grid
            let days = calendarDays(for: displayedMonth)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(days, id: \.self) { day in
                    if let day {
                        let isSelected = Calendar.current.isDate(day, inSameDayAs: date)
                        let isToday = Calendar.current.isDateInToday(day)
                        let isPast = day < Calendar.current.startOfDay(for: Date()) && !isToday

                        Button {
                            withAnimation(Theme.Animation.snappy) {
                                date = day
                            }
                        } label: {
                            Text("\(Calendar.current.component(.day, from: day))")
                                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                                .foregroundColor(
                                    isSelected ? Theme.Colors.background
                                    : isPast ? Theme.Colors.textTertiary.opacity(0.4)
                                    : isToday ? Theme.Colors.primary
                                    : Theme.Colors.textPrimary
                                )
                                .frame(width: 38, height: 38)
                                .background(
                                    Circle()
                                        .fill(isSelected ? Theme.Colors.primary : Color.clear)
                                )
                        }
                        .disabled(isPast)
                    } else {
                        Color.clear
                            .frame(width: 38, height: 38)
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
        )
    }

    // MARK: - Time Carousel

    private var currentTimeForCarousel: Date {
        isEditingEnd ? endTime : startTime
    }

    @ViewBuilder
    private var timeCarousel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(isEditingEnd ? "End Time" : "Start Time")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textTertiary)

            TimeSlotCarousel(
                times: generateTimeSlots(),
                currentTime: currentTimeForCarousel,
                isEditingEnd: isEditingEnd,
                onSelect: { time in
                    if isEditingEnd {
                        endTime = time
                    } else {
                        startTime = time
                    }
                }
            )
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
        )
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                Text(timezoneAbbreviation)
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(Theme.Colors.textTertiary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.background)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.textPrimary)
                    )
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
    }

    // MARK: - Helpers

    private var defaultStartTime: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 19
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }

    private var timezoneAbbreviation: String {
        let tz = TimeZone.current
        return tz.abbreviation() ?? tz.identifier
    }

    private func shortDateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: d)
    }

    private func shortTimeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: d)
    }

    private func monthYearString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: d)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func calendarDays(for month: Date) -> [Date?] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay) - 1 // 0=Sun

        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        // Pad to fill last row
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private func generateTimeSlots() -> [Date] {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        var slots: [Date] = []
        for hour in 0..<24 {
            for minute in stride(from: 0, to: 60, by: 15) {
                components.hour = hour
                components.minute = minute
                if let d = calendar.date(from: components) {
                    slots.append(d)
                }
            }
        }
        return slots
    }

    private func isSameTime(_ a: Date, _ b: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.hour, from: a) == cal.component(.hour, from: b)
            && cal.component(.minute, from: a) == cal.component(.minute, from: b)
    }

    private func scrollToNearest(proxy: ScrollViewProxy, times: [Date], target: Date) {
        let nearest = times.min(by: {
            abs(timeDistance($0, target)) < abs(timeDistance($1, target))
        })
        if let nearest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { proxy.scrollTo(nearest, anchor: .center) }
            }
        }
    }

    private func timeDistance(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        let aMin = cal.component(.hour, from: a) * 60 + cal.component(.minute, from: a)
        let bMin = cal.component(.hour, from: b) * 60 + cal.component(.minute, from: b)
        return aMin - bMin
    }
}

// MARK: - Time Slot Carousel (extracted for opaque return type)
private struct TimeSlotCarousel: View {
    let times: [Date]
    let currentTime: Date
    let isEditingEnd: Bool
    let onSelect: (Date) -> Void

    private func isSameTime(_ a: Date, _ b: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.hour, from: a) == cal.component(.hour, from: b)
            && cal.component(.minute, from: a) == cal.component(.minute, from: b)
    }

    private func shortTimeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: d)
    }

    private func timeDistance(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        let aMin = cal.component(.hour, from: a) * 60 + cal.component(.minute, from: a)
        let bMin = cal.component(.hour, from: b) * 60 + cal.component(.minute, from: b)
        return aMin - bMin
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(times, id: \.self) { time in
                        let isSelected = isSameTime(time, currentTime)

                        Button {
                            onSelect(time)
                        } label: {
                            Text(shortTimeString(time))
                                .font(isSelected ? Theme.Typography.headlineMedium : Theme.Typography.bodyMedium)
                                .foregroundColor(isSelected ? Theme.Colors.background : Theme.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                        .fill(isSelected ? Theme.Colors.textPrimary : Color.clear)
                                )
                        }
                        .id(time)
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
            .frame(height: 220)
            .onAppear {
                scrollToNearest(proxy: proxy)
            }
            .onChange(of: isEditingEnd) { _, _ in
                scrollToNearest(proxy: proxy)
            }
        }
    }

    private func scrollToNearest(proxy: ScrollViewProxy) {
        let nearest = times.min(by: {
            abs(timeDistance($0, currentTime)) < abs(timeDistance($1, currentTime))
        })
        if let nearest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { proxy.scrollTo(nearest, anchor: .center) }
            }
        }
    }
}
