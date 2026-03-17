import SwiftUI

struct CreateEventDetailsStep: View {
    @ObservedObject var viewModel: CreateEventViewModel
    @Binding var locationSheetMode: LocationSheetMode?
    @Binding var showDateTimePicker: Bool
    @Binding var showRSVPDeadlinePicker: Bool
    @Binding var pollEditorItem: PollEditorItem?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Event Details")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Title")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("e.g. Dune Imperium Night", text: $viewModel.title)
                    .font(Theme.Typography.body)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.backgroundElevated)
                    )
            }

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
                            .fill(Theme.Colors.backgroundElevated)
                    )
            }

            scheduleSection

            rsvpDeadlineSection

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Location")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textSecondary)

                Button {
                    if viewModel.location.isEmpty {
                        locationSheetMode = .picker
                    } else {
                        locationSheetMode = .edit
                    }
                } label: {
                    HStack {
                        if viewModel.location.isEmpty {
                            Text("e.g. Alex's Place")
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

                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.backgroundElevated)
                    )
                }
            }

            privacySection

            // Player count
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Player Count")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textSecondary)

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
            }
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Privacy")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textSecondary)

                Picker("", selection: $viewModel.visibility) {
                    Text("Private").tag(EventVisibility.private)
                    Text("Public").tag(EventVisibility.public)
                }
                .pickerStyle(.segmented)

                Text(visibilityHelperText)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

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

    // MARK: - RSVP Deadline

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

    private var rsvpDeadlineSection: some View {
        Button {
            if viewModel.rsvpDeadline == nil {
                viewModel.rsvpDeadline = defaultRSVPDeadline
            }
            showRSVPDeadlinePicker = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Text(rsvpDeadlineRowText)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(viewModel.rsvpDeadline == nil ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.cardBackground)
            )
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

    private var rsvpDeadlineRowText: String {
        guard let deadline = viewModel.rsvpDeadline else { return "RSVP deadline" }
        return RSVPDeadlineDisplay.label(for: deadline)
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
                            label: option.label,
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
                PollEditSheet(
                    title: "Add Time Option",
                    saveTitle: "Add",
                    initialDate: Date(),
                    initialStartTime: DateTimePickerSheet.defaultTime(hour: 19),
                    initialEndTime: nil,
                    initialLabel: nil,
                    onSave: { date, start, end, label in
                        viewModel.addTimeOption(date: date, startTime: start, endTime: end, label: label)
                    }
                )
            case .edit(let optionId):
                if let option = viewModel.timeOptions.first(where: { $0.id == optionId }) {
                    PollEditSheet(
                        title: "Edit Time Option",
                        saveTitle: "Save",
                        initialDate: option.date,
                        initialStartTime: option.startTime,
                        initialEndTime: option.endTime,
                        initialLabel: option.label,
                        onSave: { date, start, end, label in
                            viewModel.updateTimeOption(
                                id: optionId,
                                date: date,
                                startTime: start,
                                endTime: end,
                                label: label
                            )
                        },
                        onDelete: {
                            viewModel.removeTimeOption(id: optionId)
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
