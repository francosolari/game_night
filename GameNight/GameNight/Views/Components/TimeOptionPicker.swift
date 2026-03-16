import SwiftUI

struct TimeOptionPicker: View {
    let timeOptions: [TimeOption]
    @Binding var selectedIds: Set<UUID>
    var allowMultiple: Bool = true
    var showVoteCounts: Bool = false

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(timeOptions) { option in
                TimeOptionRow(
                    option: option,
                    isSelected: selectedIds.contains(option.id),
                    showVoteCount: showVoteCounts
                ) {
                    withAnimation(Theme.Animation.snappy) {
                        if allowMultiple {
                            if selectedIds.contains(option.id) {
                                selectedIds.remove(option.id)
                            } else {
                                selectedIds.insert(option.id)
                            }
                        } else {
                            selectedIds = [option.id]
                        }
                    }
                }
            }
        }
    }
}

struct TimeOptionRow: View {
    let option: TimeOption
    let isSelected: Bool
    var showVoteCount: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.textTertiary, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Theme.Colors.primary)
                            .frame(width: 14, height: 14)
                    }
                }

                // Date and time
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(option.displayDate)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        if let label = option.label {
                            Text(label)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.primaryLight)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Theme.Colors.primary.opacity(0.15))
                                )
                        }

                        if option.isSuggested {
                            Text("Suggested")
                                .font(Theme.Typography.caption2)
                                .foregroundColor(Theme.Colors.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Theme.Colors.accent.opacity(0.15))
                                )
                        }
                    }

                    Text(option.displayTime)
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                }

                Spacer()

                // Vote count
                if showVoteCount {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 12))
                        Text("\(option.voteCount)")
                            .font(Theme.Typography.calloutMedium)
                    }
                    .foregroundColor(option.voteCount > 0 ? Theme.Colors.success : Theme.Colors.textTertiary)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(isSelected ? Theme.Colors.primary.opacity(0.1) : Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                            .stroke(isSelected ? Theme.Colors.primary.opacity(0.3) : Theme.Colors.divider, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Poll Voting View
struct PollVotingView: View {
    let timeOptions: [TimeOption]
    @Binding var votes: [UUID: TimeOptionVoteType]

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(timeOptions) { option in
                HStack(spacing: Theme.Spacing.md) {
                    // Date and time
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(option.displayDate)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            if let label = option.label {
                                Text(label)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.primaryLight)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.Colors.primary.opacity(0.15)))
                            }
                        }
                        Text(option.displayTime)
                            .font(Theme.Typography.headlineMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }

                    Spacer()

                    // Vote buttons
                    HStack(spacing: Theme.Spacing.sm) {
                        TriStateVoteButton(
                            icon: "checkmark",
                            label: "Yes",
                            color: Theme.Colors.success,
                            isSelected: votes[option.id] == .yes
                        ) {
                            votes[option.id] = votes[option.id] == .yes ? nil : .yes
                        }

                        TriStateVoteButton(
                            icon: "questionmark",
                            label: "Maybe",
                            color: Theme.Colors.warning,
                            isSelected: votes[option.id] == .maybe
                        ) {
                            votes[option.id] = votes[option.id] == .maybe ? nil : .maybe
                        }

                        TriStateVoteButton(
                            icon: "xmark",
                            label: "No",
                            color: Theme.Colors.error,
                            isSelected: votes[option.id] == .no
                        ) {
                            votes[option.id] = votes[option.id] == .no ? nil : .no
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(Theme.Colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Time Suggestion Sheet
struct TimeSuggestionSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDate = Date()
    @State private var startTime = Date()
    @State private var label = ""

    var onSuggest: (TimeOption) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Suggest a Time")
                            .font(Theme.Typography.displaySmall)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("The host will see your suggestion and may add it as an option.")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: Theme.Spacing.lg) {
                        DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Theme.Colors.primary)

                        VStack(alignment: .leading) {
                            Text("Start Time")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(Theme.Colors.primary)
                        }

                        TextField("Label (e.g. 'Friday Evening')", text: $label)
                            .font(Theme.Typography.body)
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.backgroundElevated)
                            )
                    }
                    .cardStyle()

                    Button("Suggest This Time") {
                        let option = TimeOption(
                            id: UUID(),
                            eventId: nil,
                            date: selectedDate,
                            startTime: startTime,
                            endTime: nil,
                            label: label.isEmpty ? nil : label,
                            isSuggested: true,
                            suggestedBy: nil,
                            voteCount: 0,
                            maybeCount: 0
                        )
                        onSuggest(option)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
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
