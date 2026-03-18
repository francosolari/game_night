import SwiftUI

struct CreateEventDetailsStep: View {
    @ObservedObject var viewModel: CreateEventViewModel
    @Binding var locationSheetMode: LocationSheetMode?
    @Binding var showDateTimePicker: Bool
    @Binding var showRSVPDeadlinePicker: Bool
    @Binding var pollEditorItem: PollEditorItem?

    @State private var showRSVPOptions = false
    @State private var showPlayerCountDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Event Details")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

            // Title
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Title")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("e.g. Dune Imperium Night", text: $viewModel.title)
                    .font(Theme.Typography.body)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.fieldBackground)
                    )
            }

            // Schedule (date/time)
            scheduleSection

            // Player Count (compact expandable)
            playerCountSection

            // Location (compact row)
            locationRow

            // RSVP Options (expandable)
            rsvpOptionsSection

            // Privacy
            privacySection

            // Description (at bottom)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Description (optional)")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("What's the plan?", text: $viewModel.description, axis: .vertical)
                    .lineLimit(3...6)
                    .font(Theme.Typography.body)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.fieldBackground)
                    )
            }
        }
    }

    // MARK: - Player Count Section

    private var playerCountSummary: String {
        if let max = viewModel.maxPlayers {
            return "\(viewModel.minPlayers)–\(max) players"
        }
        return "\(viewModel.minPlayers)+ players"
    }

    private var playerCountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPlayerCountDetail.toggle()
                }
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "person.2")
                        .foregroundColor(Theme.Colors.dateAccent)
                        .frame(width: 24)
                    Text("Player Count")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                    Text(playerCountSummary)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Image(systemName: showPlayerCountDetail ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.backgroundElevated)
                )
            }
            .buttonStyle(.plain)

            if showPlayerCountDetail {
                HStack(spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading) {
                        Text("Minimum")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                        Stepper("\(viewModel.minPlayers)", value: $viewModel.minPlayers, in: 1...20)
                            .font(Theme.Typography.bodyMedium)
                    }

                    VStack(alignment: .leading) {
                        Text("Maximum (optional)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                        Stepper(
                            viewModel.maxPlayers.map { "\($0)" } ?? "No max",
                            onIncrement: {
                                viewModel.maxPlayers = (viewModel.maxPlayers ?? viewModel.minPlayers) + 1
                            },
                            onDecrement: {
                                if let max = viewModel.maxPlayers {
                                    viewModel.maxPlayers = max > viewModel.minPlayers ? max - 1 : nil
                                }
                            }
                        )
                        .font(Theme.Typography.bodyMedium)
                    }
                }
                .padding(Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Location Row

    private var locationRow: some View {
        Button {
            if viewModel.location.isEmpty {
                locationSheetMode = .picker
            } else {
                locationSheetMode = .edit
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Theme.Colors.dateAccent)
                    .frame(width: 24)

                if viewModel.location.isEmpty {
                    Text("Location")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textTertiary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.location)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        if !viewModel.locationAddress.isEmpty {
                            Text(viewModel.locationAddress)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.backgroundElevated)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - RSVP Options Section

    private var rsvpOptionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRSVPOptions.toggle()
                }
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "envelope.badge")
                        .foregroundColor(Theme.Colors.dateAccent)
                        .frame(width: 24)
                    Text("RSVP Options")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: showRSVPOptions ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.backgroundElevated)
                )
            }
            .buttonStyle(.plain)

            if showRSVPOptions {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    // RSVP Deadline
                    rsvpDeadlineRow

                    Divider()
                        .overlay(Theme.Colors.divider)

                    // Allow guests to invite others
                    Toggle(isOn: $viewModel.allowGuestInvites) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allow guests to invite others")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Guests who RSVP can invite their friends from the event page.")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    .tint(Theme.Colors.primary)

                    Divider()
                        .overlay(Theme.Colors.divider)

                    // Plus Ones
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(Theme.Colors.dateAccent)
                            .frame(width: 24)
                        Text("Plus Ones")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Menu {
                            ForEach(0...9, id: \.self) { value in
                                Button {
                                    viewModel.plusOneLimit = value
                                } label: {
                                    if value == viewModel.plusOneLimit {
                                        Label(value == 0 ? "None" : "Up to \(value)", systemImage: "checkmark")
                                    } else {
                                        Text(value == 0 ? "None" : "Up to \(value)")
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.plusOneLimit == 0 ? "None" : "Up to \(viewModel.plusOneLimit)")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }
                    }

                    // Require plus-one names (only when plus-ones allowed)
                    if viewModel.plusOneLimit > 0 {
                        Toggle(isOn: $viewModel.requirePlusOneNames) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Require plus-one names")
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text("Guests must provide names for their plus-ones")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }
                        .tint(Theme.Colors.primary)
                    }

                    Divider()
                        .overlay(Theme.Colors.divider)

                    // Allow Maybe RSVPs
                    Toggle(isOn: $viewModel.allowMaybeRSVP) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Guests can RSVP 'Maybe'")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Guests can indicate they might attend")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    .tint(Theme.Colors.primary)
                }
                .padding(Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var rsvpDeadlineRow: some View {
        Button {
            if viewModel.rsvpDeadline == nil {
                viewModel.rsvpDeadline = defaultRSVPDeadline
            }
            showRSVPDeadlinePicker = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "hourglass")
                    .foregroundColor(Theme.Colors.dateAccent)
                    .frame(width: 24)
                Text("RSVP Deadline")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Text(rsvpDeadlineValueText)
                    .font(Theme.Typography.body)
                    .foregroundColor(viewModel.rsvpDeadline == nil ? Theme.Colors.textTertiary : Theme.Colors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showRSVPDeadlinePicker) {
            DateTimePickerSheet(
                title: "RSVP Deadline",
                allowsEndTime: false,
                date: rsvpDeadlineBinding,
                startTime: rsvpDeadlineTimeBinding,
                endDate: rsvpDeadlineEndDateBinding,
                endTime: rsvpDeadlineEndTimeBinding,
                hasEndTime: rsvpDeadlineHasEndTimeBinding,
                hasDate: rsvpDeadlineHasDateBinding,
                timezone: $viewModel.selectedTimezone,
                onClear: {
                    viewModel.rsvpDeadline = nil
                    showRSVPDeadlinePicker = false
                }
            )
        }
    }

    private var rsvpDeadlineValueText: String {
        guard let deadline = viewModel.rsvpDeadline else { return "Not set" }
        return RSVPDeadlineDisplay.label(for: deadline)
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Privacy")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textSecondary)

            Picker("", selection: $viewModel.visibility) {
                Text("Private").tag(EventVisibility.private)
                Text("Public").tag(EventVisibility.public)
            }
            .pickerStyle(.segmented)
            .sageSegmented()

            Text(visibilityHelperText)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
        }
    }

    private var visibilityHelperText: String {
        switch viewModel.visibility {
        case .private:
            return "Private events hide the exact address until guests RSVP."
        case .public:
            return "Public events show full event details before RSVP. Guest names stay hidden until guests RSVP."
        }
    }

    // MARK: - RSVP Deadline Helpers

    private var defaultRSVPDeadline: Date {
        if viewModel.scheduleMode == .fixed, viewModel.hasDate {
            return endOfDay(from: viewModel.fixedDate)
        }

        let fallback = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return endOfDay(from: fallback)
    }

    private var rsvpDeadlineBinding: Binding<Date> {
        Binding(
            get: { viewModel.rsvpDeadline ?? defaultRSVPDeadline },
            set: { newDate in
                let currentTime = viewModel.rsvpDeadline ?? defaultRSVPDeadline
                viewModel.rsvpDeadline = combine(date: newDate, time: currentTime)
            }
        )
    }

    private var rsvpDeadlineHasDateBinding: Binding<Bool> {
        Binding(
            get: { viewModel.rsvpDeadline != nil },
            set: { hasDate in
                if hasDate {
                    if viewModel.rsvpDeadline == nil {
                        viewModel.rsvpDeadline = defaultRSVPDeadline
                    }
                } else {
                    viewModel.rsvpDeadline = nil
                }
            }
        )
    }

    private var rsvpDeadlineTimeBinding: Binding<Date> {
        Binding(
            get: { viewModel.rsvpDeadline ?? defaultRSVPDeadline },
            set: { newTime in
                let baseDate = viewModel.rsvpDeadline ?? defaultRSVPDeadline
                viewModel.rsvpDeadline = combine(date: baseDate, time: newTime)
            }
        )
    }

    private var rsvpDeadlineEndDateBinding: Binding<Date> {
        .constant(viewModel.rsvpDeadline ?? defaultRSVPDeadline)
    }

    private var rsvpDeadlineEndTimeBinding: Binding<Date> {
        .constant(viewModel.rsvpDeadline ?? defaultRSVPDeadline)
    }

    private var rsvpDeadlineHasEndTimeBinding: Binding<Bool> {
        .constant(false)
    }

    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var mergedComponents = DateComponents()
        mergedComponents.year = dateComponents.year
        mergedComponents.month = dateComponents.month
        mergedComponents.day = dateComponents.day
        mergedComponents.hour = timeComponents.hour
        mergedComponents.minute = timeComponents.minute

        return calendar.date(from: mergedComponents) ?? date
    }

    private func endOfDay(from date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        return Calendar.current.date(from: components) ?? date
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("When is it?")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textSecondary)

            // Mode picker
            Picker("", selection: $viewModel.scheduleMode) {
                Text("Set a Date").tag(ScheduleMode.fixed)
                Text("Poll Attendees").tag(ScheduleMode.poll)
            }
            .pickerStyle(.segmented)
            .sageSegmented()

            if viewModel.scheduleMode == .fixed {
                // Fixed mode: tappable summary card
                Button {
                    showDateTimePicker = true
                } label: {
                    FixedDateSummaryCard(
                        hasDate: viewModel.hasDate,
                        date: viewModel.fixedDate,
                        startTime: viewModel.fixedStartTime,
                        endTime: viewModel.fixedEndTime,
                        hasEndTime: viewModel.hasEndTime
                    )
                }
                .sheet(isPresented: $showDateTimePicker) {
                    DateTimePickerSheet(
                        date: $viewModel.fixedDate,
                        startTime: $viewModel.fixedStartTime,
                        endDate: $viewModel.fixedEndDate,
                        endTime: $viewModel.fixedEndTime,
                        hasEndTime: $viewModel.hasEndTime,
                        hasDate: $viewModel.hasDate,
                        timezone: $viewModel.selectedTimezone
                    )
                }
            } else {
                // Poll mode: multiple time options
                Text("Add time options for invitees to vote on.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)

                // Existing time options
                ForEach(viewModel.timeOptions) { option in
                    Button {
                        pollEditorItem = .edit(option.id)
                    } label: {
                        FixedDateSummaryCard(
                            hasDate: true,
                            date: option.date,
                            startTime: option.startTime,
                            endTime: option.endTime,
                            hasEndTime: option.endTime != nil,
                            onDelete: {
                                viewModel.removeTimeOption(id: option.id)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }

                PollAddTimeButton {
                    pollEditorItem = .add
                }

                // Allow suggestions toggle (poll mode only)
                Toggle(isOn: $viewModel.allowTimeSuggestions) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow time suggestions")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("Invitees can suggest other times")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
                .tint(Theme.Colors.primary)
            }
        }
        .sheet(item: $pollEditorItem) { item in
            switch item {
            case .add:
                PollDateTimePickerSheet(
                    title: "Add Time Option",
                    saveTitle: "Add",
                    timezone: $viewModel.selectedTimezone,
                    initialDate: Date(),
                    initialStartTime: DateTimePickerSheet.defaultTime(hour: 19),
                    initialEndTime: nil,
                    onSave: { date, start, end, label in
                        viewModel.addTimeOption(date: date, startTime: start, endTime: end, label: label)
                    }
                )
            case .edit(let optionId):
                if let option = viewModel.timeOptions.first(where: { $0.id == optionId }) {
                    PollDateTimePickerSheet(
                        title: "Edit Time Option",
                        saveTitle: "Save",
                        timezone: $viewModel.selectedTimezone,
                        initialDate: option.date,
                        initialStartTime: option.startTime,
                        initialEndTime: option.endTime,
                        onSave: { date, start, end, label in
                            viewModel.updateTimeOption(
                                id: optionId,
                                date: date,
                                startTime: start,
                                endTime: end,
                                label: label
                            )
                        }
                    )
                }
            }
        }
    }
}

enum PollEditorItem: Identifiable {
    case add
    case edit(UUID)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let optionId):
            return optionId.uuidString
        }
    }
}

struct PollDateTimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let saveTitle: String
    @Binding var timezone: TimeZone
    @State private var date: Date
    @State private var startTime: Date
    @State private var endDate: Date
    @State private var endTime: Date
    @State private var hasEndTime: Bool
    @State private var hasDate: Bool

    let onSave: (Date, Date, Date?, String?) -> Void

    init(
        title: String,
        saveTitle: String,
        timezone: Binding<TimeZone>,
        initialDate: Date,
        initialStartTime: Date,
        initialEndTime: Date?,
        onSave: @escaping (Date, Date, Date?, String?) -> Void
    ) {
        self.title = title
        self.saveTitle = saveTitle
        _timezone = timezone
        _date = State(initialValue: initialDate)
        _startTime = State(initialValue: initialStartTime)
        _endDate = State(initialValue: initialEndTime.map { Calendar.current.startOfDay(for: $0) } ?? initialDate)
        _endTime = State(initialValue: initialEndTime ?? DateTimePickerSheet.defaultTime(hour: 22))
        _hasEndTime = State(initialValue: initialEndTime != nil)
        _hasDate = State(initialValue: true)
        self.onSave = onSave
    }

    var body: some View {
        DateTimePickerSheet(
            title: title,
            date: $date,
            startTime: $startTime,
            endDate: $endDate,
            endTime: $endTime,
            hasEndTime: $hasEndTime,
            hasDate: $hasDate,
            timezone: $timezone,
            primaryActionTitle: saveTitle,
            isPrimaryActionDisabled: !hasDate,
            onPrimaryAction: {
                onSave(
                    date,
                    resolvedDateTime(date: date, time: startTime),
                    hasEndTime ? resolvedDateTime(date: endDate, time: endTime) : nil,
                    nil
                )
                dismiss()
            }
        )
    }

    private func resolvedDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var resolved = DateComponents()
        resolved.year = dateComponents.year
        resolved.month = dateComponents.month
        resolved.day = dateComponents.day
        resolved.hour = timeComponents.hour
        resolved.minute = timeComponents.minute

        return calendar.date(from: resolved) ?? time
    }
}
