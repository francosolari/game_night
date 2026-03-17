import SwiftUI

// MARK: - DateTimePickerSheet

struct DateTimePickerSheet: View {
    let title: String
    let allowsEndTime: Bool
    let clearButtonTitle: String?
    let primaryActionTitle: String
    let isPrimaryActionDisabled: Bool
    let onClear: (() -> Void)?
    let onPrimaryAction: (() -> Void)?
    let accessory: AnyView?
    @Binding var startDate: Date
    @Binding var startTime: Date
    @Binding var endDate: Date
    @Binding var endTime: Date
    @Binding var hasEndTime: Bool
    @Binding var hasDate: Bool
    @Binding var timezone: TimeZone
    @Environment(\.dismiss) private var dismiss

    @State private var isEditingEnd = false
    @State private var showTimezonePicker = false

    init(
        title: String = "Date & Time",
        allowsEndTime: Bool = true,
        clearButtonTitle: String? = "Clear",
        date: Binding<Date>,
        startTime: Binding<Date>,
        endDate: Binding<Date>,
        endTime: Binding<Date>,
        hasEndTime: Binding<Bool>,
        hasDate: Binding<Bool> = .constant(true),
        timezone: Binding<TimeZone> = .constant(.current),
        primaryActionTitle: String = "Done",
        isPrimaryActionDisabled: Bool = false,
        onClear: (() -> Void)? = nil,
        onPrimaryAction: (() -> Void)? = nil,
        accessory: AnyView? = nil
    ) {
        self.title = title
        self.allowsEndTime = allowsEndTime
        self.clearButtonTitle = clearButtonTitle
        self.primaryActionTitle = primaryActionTitle
        self.isPrimaryActionDisabled = isPrimaryActionDisabled
        self.onClear = onClear
        self.onPrimaryAction = onPrimaryAction
        self.accessory = accessory
        _startDate = date
        _startTime = startTime
        _endDate = endDate
        _endTime = endTime
        _hasEndTime = hasEndTime
        _hasDate = hasDate
        _timezone = timezone
    }

    private var activeDate: Binding<Date> {
        allowsEndTime && isEditingEnd ? $endDate : $startDate
    }

    private var activeTime: Binding<Date> {
        allowsEndTime && isEditingEnd ? $endTime : $startTime
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let clearButtonTitle {
                    Button(clearButtonTitle) {
                        if let onClear {
                            onClear()
                        } else {
                            hasDate = false
                            hasEndTime = false
                            isEditingEnd = false
                            startDate = Date()
                            endDate = Date()
                            startTime = Self.defaultTime(hour: 19)
                            endTime = Self.defaultTime(hour: 22)
                        }
                    }
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textSecondary)
                } else {
                    Color.clear
                        .frame(width: 44, height: 20)
                }

                Spacer()

                Text(title)
                    .font(Theme.Typography.headlineMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                Color.clear.frame(width: 44)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xs)

            // Summary bar
            Group {
                if allowsEndTime {
                    DateTimeSummaryBar(
                        startDate: startDate,
                        startTime: startTime,
                        endDate: endDate,
                        endTime: endTime,
                        hasDate: hasDate,
                        hasEndTime: hasEndTime,
                        isEditingEnd: isEditingEnd,
                        onSelectStart: {
                            withAnimation(Theme.Animation.snappy) { isEditingEnd = false }
                        },
                        onSelectEnd: {
                            withAnimation(Theme.Animation.snappy) {
                                isEditingEnd = true
                                if !hasEndTime {
                                    hasEndTime = true
                                    endDate = startDate
                                    if !hasDate { hasDate = true }
                                }
                            }
                        }
                    )
                } else {
                    SingleDateTimeSummaryBar(
                        date: startDate,
                        time: startTime,
                        hasDate: hasDate
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)

            // Calendar + Time side by side
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                CalendarGridView(
                    selectedDate: activeDate,
                    hasSelection: $hasDate,
                    onDateSelected: {
                        if !hasDate { hasDate = true }
                    }
                )

                TimeSlotPicker(
                    selectedTime: activeTime,
                    label: isEditingEnd ? "End" : "Start",
                    onTimeSelected: {
                        if !hasDate { hasDate = true }
                    }
                )
                .frame(width: 96)
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)

            if let accessory {
                accessory
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.sm)
            }

            // Footer with timezone
            HStack {
                Button {
                    showTimezonePicker = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                        Text(timezone.shortDisplayName)
                            .font(Theme.Typography.caption)
                    }
                    .foregroundColor(Theme.Colors.textTertiary)
                }

                Spacer()

                Button {
                    if let onPrimaryAction {
                        onPrimaryAction()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text(primaryActionTitle)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.background)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .fill(isPrimaryActionDisabled ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                        )
                }
                .disabled(isPrimaryActionDisabled)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.cardBackground)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showTimezonePicker) {
            TimezonePicker(selectedTimezone: $timezone)
        }
    }

    static func defaultTime(hour: Int) -> Date {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour
        c.minute = 0
        return cal.date(from: c) ?? Date()
    }
}

// MARK: - DateTimeSummaryBar (Reusable)

struct SingleDateTimeSummaryBar: View {
    let date: Date
    let time: Date
    let hasDate: Bool

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        HStack {
            VStack(spacing: 1) {
                if hasDate {
                    Text(Self.dateFormatter.string(from: date))
                        .font(Theme.Typography.caption)
                    Text(Self.timeFormatter.string(from: time))
                        .font(Theme.Typography.headlineMedium)
                } else {
                    Text("Date")
                        .font(Theme.Typography.caption)
                    Text("Not set")
                        .font(Theme.Typography.headlineMedium)
                }
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
        )
    }
}

// MARK: - DateTimeSummaryBar (Reusable)

struct DateTimeSummaryBar: View {
    let startDate: Date
    let startTime: Date
    let endDate: Date
    let endTime: Date
    let hasDate: Bool
    let hasEndTime: Bool
    let isEditingEnd: Bool
    let onSelectStart: () -> Void
    let onSelectEnd: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            // Start side
            Button(action: onSelectStart) {
                VStack(spacing: 1) {
                    if hasDate {
                        Text(Self.dateFormatter.string(from: startDate))
                            .font(Theme.Typography.caption)
                        Text(Self.timeFormatter.string(from: startTime))
                            .font(Theme.Typography.headlineMedium)
                    } else {
                        Text("Date")
                            .font(Theme.Typography.caption)
                        Text("Not set")
                            .font(Theme.Typography.headlineMedium)
                    }
                }
                .foregroundColor(isEditingEnd ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.Colors.textTertiary)
                .padding(.horizontal, 2)

            // End side
            Button(action: onSelectEnd) {
                VStack(spacing: 1) {
                    if hasEndTime {
                        let sameDay = Calendar.current.isDate(startDate, inSameDayAs: endDate)
                        Text(sameDay ? "End Time" : Self.dateFormatter.string(from: endDate))
                            .font(Theme.Typography.caption)
                        Text(Self.timeFormatter.string(from: endTime))
                            .font(Theme.Typography.headlineMedium)
                    } else {
                        Text("End Time")
                            .font(Theme.Typography.caption)
                        Text("Optional")
                            .font(Theme.Typography.headlineMedium)
                    }
                }
                .foregroundColor(isEditingEnd ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
        )
    }
}

// MARK: - CalendarGridView (Reusable)

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    @Binding var hasSelection: Bool
    var onDateSelected: (() -> Void)? = nil

    @State private var displayedMonth: Date
    @State private var showMonthYearPicker = false

    init(selectedDate: Binding<Date>, hasSelection: Binding<Bool>, onDateSelected: (() -> Void)? = nil) {
        _selectedDate = selectedDate
        _hasSelection = hasSelection
        self.onDateSelected = onDateSelected
        _displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    private static let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    // Always 6 rows (42 cells) to prevent resizing
    private static let totalCells = 42

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            // Month/Year header — tappable for quick navigation
            HStack {
                Button {
                    withAnimation(Theme.Animation.snappy) {
                        showMonthYearPicker.toggle()
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(monthYearString(displayedMonth))
                            .font(Theme.Typography.titleMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: showMonthYearPicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }

                Spacer()

                if !showMonthYearPicker {
                    HStack(spacing: Theme.Spacing.md) {
                        Button {
                            withAnimation(Theme.Animation.smooth) { changeMonth(by: -1) }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .frame(width: 28, height: 28)
                        }
                        Button {
                            withAnimation(Theme.Animation.smooth) { changeMonth(by: 1) }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
            }

            if showMonthYearPicker {
                MonthYearPickerView(
                    displayedMonth: $displayedMonth,
                    onDismiss: {
                        withAnimation(Theme.Animation.snappy) {
                            showMonthYearPicker = false
                        }
                    }
                )
            } else {
                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(Array(Self.weekdayLabels.enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Date grid — always 6 rows
                let days = calendarDays(for: displayedMonth)
                let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(0..<Self.totalCells, id: \.self) { index in
                        if index < days.count, let day = days[index] {
                            let isSelected = hasSelection && Calendar.current.isDate(day, inSameDayAs: selectedDate)
                            let isToday = Calendar.current.isDateInToday(day)
                            let isPast = day < Calendar.current.startOfDay(for: Date()) && !isToday

                            Button {
                                withAnimation(Theme.Animation.snappy) {
                                    selectedDate = day
                                    hasSelection = true
                                    onDateSelected?()
                                }
                            } label: {
                                Text("\(Calendar.current.component(.day, from: day))")
                                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                                    .foregroundColor(
                                        isSelected ? Theme.Colors.background
                                        : isPast ? Theme.Colors.textTertiary.opacity(0.3)
                                        : isToday ? Theme.Colors.primary
                                        : Theme.Colors.textPrimary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(
                                        Circle().fill(isSelected ? Theme.Colors.primary : Color.clear)
                                    )
                            }
                            .disabled(isPast)
                        } else {
                            Color.clear.frame(height: 32)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
        )
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
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay) - 1

        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        // Pad to exactly 42 cells (6 rows)
        while days.count < Self.totalCells {
            days.append(nil)
        }
        return days
    }
}

// MARK: - MonthYearPickerView (Reusable)

struct MonthYearPickerView: View {
    @Binding var displayedMonth: Date

    let onDismiss: () -> Void

    private let monthSymbols = Calendar.current.shortMonthSymbols
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 3)

    @State private var displayedYear: Int

    init(displayedMonth: Binding<Date>, onDismiss: @escaping () -> Void) {
        _displayedMonth = displayedMonth
        self.onDismiss = onDismiss
        _displayedYear = State(initialValue: Calendar.current.component(.year, from: displayedMonth.wrappedValue))
    }

    private var currentMonth: Int {
        Calendar.current.component(.month, from: displayedMonth)
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: displayedMonth)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Year navigation
            HStack {
                Button {
                    withAnimation(Theme.Animation.smooth) { displayedYear -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                }

                Spacer()

                Text(String(displayedYear))
                    .font(Theme.Typography.headlineMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                Button {
                    withAnimation(Theme.Animation.smooth) { displayedYear += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                }
            }

            // Month grid (3x4)
            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(1...12, id: \.self) { month in
                    let isSelected = month == currentMonth && displayedYear == currentYear
                    let isPastMonth = isPast(year: displayedYear, month: month)

                    Button {
                        selectMonth(month)
                    } label: {
                        Text(monthSymbols[month - 1])
                            .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                            .foregroundColor(
                                isSelected ? Theme.Colors.background
                                : isPastMonth ? Theme.Colors.textTertiary.opacity(0.3)
                                : Theme.Colors.textPrimary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(isSelected ? Theme.Colors.primary : Color.clear)
                            )
                    }
                    .disabled(isPastMonth)
                }
            }
        }
    }

    private func isPast(year: Int, month: Int) -> Bool {
        let now = Date()
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: now)
        let currentMonth = cal.component(.month, from: now)
        return year < currentYear || (year == currentYear && month < currentMonth)
    }

    private func selectMonth(_ month: Int) {
        var components = DateComponents()
        components.year = displayedYear
        components.month = month
        components.day = 1
        if let date = Calendar.current.date(from: components) {
            displayedMonth = date
            onDismiss()
        }
    }
}

// MARK: - TimeSlotPicker (Reusable)

struct TimeSlotPicker: View {
    @Binding var selectedTime: Date
    var label: String = "Time"
    var onTimeSelected: (() -> Void)? = nil

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 1) {
                        ForEach(timeSlots, id: \.self) { time in
                            let isSelected = isSameTime(time, selectedTime)

                            Button {
                                selectedTime = time
                                onTimeSelected?()
                            } label: {
                                Text(Self.timeFormatter.string(from: time))
                                    .font(.system(size: isSelected ? 12 : 11, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? Theme.Colors.background : Theme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                            .fill(isSelected ? Theme.Colors.textPrimary : Color.clear)
                                    )
                            }
                            .id(time)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xs)
                }
                .onAppear {
                    scrollToSelected(proxy: proxy)
                }
                .onChange(of: selectedTime) { _, _ in
                    scrollToSelected(proxy: proxy)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
        )
    }

    private var timeSlots: [Date] {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: Date())
        var slots: [Date] = []
        for hour in 0..<24 {
            for minute in stride(from: 0, to: 60, by: 15) {
                components.hour = hour
                components.minute = minute
                if let d = cal.date(from: components) {
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

    private func scrollToSelected(proxy: ScrollViewProxy) {
        let nearest = timeSlots.min(by: {
            abs(timeMinutes($0) - timeMinutes(selectedTime)) < abs(timeMinutes($1) - timeMinutes(selectedTime))
        })
        if let nearest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { proxy.scrollTo(nearest, anchor: .center) }
            }
        }
    }

    private func timeMinutes(_ d: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: d) * 60 + cal.component(.minute, from: d)
    }
}

// MARK: - TimezonePicker (Reusable)

struct TimezonePicker: View {
    @Binding var selectedTimezone: TimeZone
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredTimezones: [TimeZone] {
        let all = TimeZone.knownTimeZoneIdentifiers
            .compactMap { TimeZone(identifier: $0) }
            .sorted { $0.identifier < $1.identifier }

        if searchText.isEmpty { return all }

        let query = searchText.lowercased()
        return all.filter {
            $0.identifier.lowercased().contains(query)
                || ($0.abbreviation() ?? "").lowercased().contains(query)
                || $0.localizedName(for: .standard, locale: .current)?.lowercased().contains(query) == true
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredTimezones, id: \.identifier) { tz in
                Button {
                    selectedTimezone = tz
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tz.identifier.replacingOccurrences(of: "_", with: " "))
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text(tz.abbreviation() ?? "")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                        Spacer()
                        if tz.identifier == selectedTimezone.identifier {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search timezone...")
            .navigationTitle("Timezone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }
}

// MARK: - TimeZone Display Extension

extension TimeZone {
    var shortDisplayName: String {
        abbreviation() ?? identifier
    }
}
