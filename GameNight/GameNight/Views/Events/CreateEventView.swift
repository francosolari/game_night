import SwiftUI

struct CreateEventView: View {
    @StateObject private var viewModel: CreateEventViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showContactPicker = false
    @State private var showContactList = false
    @State private var showCancelConfirmation = false
    @State private var showGroupPicker = false
    @State private var showDateTimePicker = false
    @State private var showRSVPDeadlinePicker = false
    @State private var locationSheetMode: LocationSheetMode? = nil
    @State private var pollEditorItem: PollEditorItem? = nil
    @StateObject private var groupsViewModel = GroupsViewModel()
    let onSaved: ((GameEvent) -> Void)?

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.error?.isEmpty == false },
            set: { isPresented in
                if !isPresented {
                    viewModel.error = nil
                }
            }
        )
    }

    init(eventToEdit: GameEvent? = nil, initialInvites: [Invite] = [], onSaved: ((GameEvent) -> Void)? = nil) {
        _viewModel = StateObject(
            wrappedValue: CreateEventViewModel(
                eventToEdit: eventToEdit,
                initialInvites: initialInvites
            )
        )
        self.onSaved = onSaved
    }

    init(group: GameGroup, onSaved: ((GameEvent) -> Void)? = nil) {
        _viewModel = StateObject(
            wrappedValue: CreateEventViewModel(group: group)
        )
        self.onSaved = onSaved
    }

    private var visibleSteps: [CreateEventViewModel.CreateStep] {
        CreateEventViewModel.CreateStep.allCases
    }

    private var currentStepIndex: Int {
        visibleSteps.firstIndex(of: viewModel.currentStep) ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: Theme.Spacing.xxl) {
                        // Step indicator
                        StepIndicator(
                            steps: visibleSteps.map { step in
                                switch step {
                                case .details: return "Details"
                                case .games: return "Games"
                                case .invites: return "Invites"
                                case .review: return "Review"
                                }
                            },
                            currentStep: currentStepIndex,
                            completedSteps: Set(visibleSteps.enumerated().compactMap { index, step in
                                viewModel.completedSteps.contains(step) ? index : nil
                            }),
                            onStepTapped: { index in
                                let step = visibleSteps[index]
                                if viewModel.canNavigateToStep(step) {
                                    withAnimation(Theme.Animation.snappy) {
                                        viewModel.navigateToStep(step)
                                    }
                                }
                            }
                        )
                        .padding(.horizontal, Theme.Spacing.xl)

                        // Step content
                        Group {
                            switch viewModel.currentStep {
                            case .details:
                                CreateEventDetailsStep(
                                    viewModel: viewModel,
                                    locationSheetMode: $locationSheetMode,
                                    showDateTimePicker: $showDateTimePicker,
                                    showRSVPDeadlinePicker: $showRSVPDeadlinePicker,
                                    pollEditorItem: $pollEditorItem
                                )
                            case .games:
                                CreateEventGamesStep(viewModel: viewModel)
                            case .invites:
                                CreateEventInvitesStep(
                                    viewModel: viewModel,
                                    groupsViewModel: groupsViewModel,
                                    showGroupPicker: $showGroupPicker,
                                    showContactList: $showContactList,
                                    showContactPicker: $showContactPicker
                                )
                            case .review:
                                CreateEventReviewStep(viewModel: viewModel)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Theme.Colors.background.ignoresSafeArea())
                .gesture(
                    DragGesture(minimumDistance: 50, coordinateSpace: .local)
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            // Only trigger if swipe is more horizontal than vertical
                            guard abs(horizontal) > abs(vertical) * 1.5 else { return }

                            let steps = visibleSteps
                            guard let idx = steps.firstIndex(of: viewModel.currentStep) else { return }

                            if horizontal < -50, idx < steps.count - 1 {
                                // Swipe left → next step
                                let nextStep = steps[idx + 1]
                                if viewModel.canNavigateToStep(nextStep) {
                                    withAnimation(Theme.Animation.snappy) {
                                        viewModel.navigateToStep(nextStep)
                                    }
                                }
                            } else if horizontal > 50, idx > 0 {
                                // Swipe right → previous step
                                withAnimation(Theme.Animation.snappy) {
                                    viewModel.currentStep = steps[idx - 1]
                                }
                            }
                        }
                )
                .hideKeyboardOnTap()

                // Bottom action bar
                VStack(spacing: 0) {
                    Divider().background(Theme.Colors.divider)

                    HStack(spacing: Theme.Spacing.md) {
                        // Save Draft — visible during create and draft-edit, not for published events
                        if !viewModel.isEditing || viewModel.isDraftEdit {
                            Button("Save Draft") {
                                Task {
                                    await viewModel.saveDraft()
                                    if let savedEvent = viewModel.createdEvent {
                                        await finishSave(savedEvent)
                                    }
                                }
                            }
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .disabled(viewModel.isSaving)
                        }

                        Spacer()

                        if viewModel.currentStep != visibleSteps.first && viewModel.primaryAction != .saveChanges {
                            Button("Back") {
                                withAnimation(Theme.Animation.snappy) {
                                    let steps = visibleSteps
                                    if let idx = steps.firstIndex(of: viewModel.currentStep), idx > 0 {
                                        viewModel.currentStep = steps[idx - 1]
                                    }
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }

                        Button(viewModel.nextButtonLabel) {
                            switch viewModel.primaryAction {
                            case .saveChanges:
                                Task {
                                    await viewModel.saveChanges()
                                    if let savedEvent = viewModel.createdEvent {
                                        await finishSave(savedEvent)
                                    }
                                }
                            case .submit:
                                Task {
                                    await viewModel.createEvent()
                                    if let savedEvent = viewModel.createdEvent {
                                        await finishSave(savedEvent)
                                    }
                                }
                            case .next:
                                withAnimation(Theme.Animation.snappy) {
                                    viewModel.markCurrentStepCompleted()
                                    let steps = visibleSteps
                                    if let idx = steps.firstIndex(of: viewModel.currentStep),
                                       idx < steps.count - 1 {
                                        viewModel.currentStep = steps[idx + 1]
                                    }
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.canProceed))
                        .disabled(!viewModel.canProceed || viewModel.isSaving)
                    }
                    .padding(Theme.Spacing.xl)
                    .background(Theme.Colors.cardBackground.ignoresSafeArea())
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Game Night" : "Create Game Night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if !viewModel.isEditing || viewModel.isDraftEdit {
                            showCancelConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .confirmationDialog(
                "Unsaved Changes",
                isPresented: $showCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Save Draft") {
                    Task {
                        await viewModel.saveDraft()
                        if viewModel.createdEvent != nil {
                            await finishSave(viewModel.createdEvent!)
                        }
                    }
                }
                Button("Discard", role: .destructive) {
                    viewModel.discardCreateSession()
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            }
            .sheet(isPresented: $showContactList) {
                ContactListSheet(
                    excludedPhones: viewModel.invitedPhones,
                    onSelect: { contacts in
                        for contact in contacts {
                            viewModel.addContact(contact)
                        }
                    }
                )
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerSheet { selectedContacts in
                    // Save to Supabase for future reuse
                    Task {
                        let supabase = SupabaseService.shared
                        _ = try? await supabase.saveContacts(selectedContacts)
                    }
                    // Add to invite list
                    for contact in selectedContacts {
                        viewModel.addContact(contact)
                    }
                }
            }
            .alert("Couldn't save changes", isPresented: saveErrorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.error ?? "Please try again.")
            }
            .task(id: appState.currentUser?.phoneNumber) {
                viewModel.configureCurrentUser(appState.currentUser)
            }
            .sheet(item: $locationSheetMode) { mode in
                LocationFlowSheet(
                    initialMode: mode,
                    locationName: $viewModel.location,
                    locationAddress: $viewModel.locationAddress,
                    onRemove: {
                        viewModel.location = ""
                        viewModel.locationAddress = ""
                    }
                )
            }
        }
    }

    private func finishSave(_ savedEvent: GameEvent) async {
        onSaved?(savedEvent)
        let refreshAreas: [AppState.RefreshArea] = savedEvent.status == .draft ? [.home] : [.home, .groups]
        dismiss()
        Task {
            await appState.refresh(refreshAreas)
        }
    }
}

// MARK: - Step Indicator
struct StepIndicator: View {
    let steps: [String]
    let currentStep: Int
    var completedSteps: Set<Int> = []
    var onStepTapped: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                let isCurrent = index == currentStep
                let isCompleted = completedSteps.contains(index)
                let isTappable = isCurrent || isCompleted || index <= currentStep
                    || index == (completedSteps.max() ?? -1) + 1

                Button {
                    onStepTapped?(index)
                } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                isCurrent ? Theme.Colors.primary
                                : isCompleted ? Theme.Colors.primary.opacity(0.6)
                                : Theme.Colors.divider
                            )
                            .frame(height: 3)

                        Text(step)
                            .font(Theme.Typography.caption2)
                            .foregroundColor(
                                isCurrent ? Theme.Colors.primary
                                : isCompleted ? Theme.Colors.primary.opacity(0.6)
                                : Theme.Colors.textTertiary
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isTappable)
                .opacity(isTappable ? 1.0 : 0.5)
            }
        }
    }
}

// MARK: - Strategy Option
struct StrategyOption: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Theme.Colors.primary : Theme.Colors.textTertiary)

                Text(title)
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)

                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isSelected ? Theme.Colors.primary.opacity(0.1) : Theme.Colors.backgroundElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.divider, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fixed Date Summary Card
struct FixedDateSummaryCard: View {
    let hasDate: Bool
    let date: Date
    let startTime: Date
    let endTime: Date?
    let hasEndTime: Bool

    // Optional props for poll mode features
    var label: String? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "calendar")
                .font(.system(size: 20))
                .foregroundColor(Theme.Colors.dateAccent)

            if hasDate {
                let dateF: DateFormatter = {
                    let f = DateFormatter()
                    f.dateFormat = "EEE, MMM d"
                    return f
                }()
                let timeF: DateFormatter = {
                    let f = DateFormatter()
                    f.dateFormat = "h:mm a"
                    return f
                }()

                HStack(spacing: Theme.Spacing.sm) {
                    Text(dateF.string(from: date))
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("•")
                        .foregroundColor(Theme.Colors.textTertiary)

                    HStack(spacing: 2) {
                        Text(timeF.string(from: startTime))
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        if hasEndTime, let end = endTime {
                            Text("-")
                                .foregroundColor(Theme.Colors.textTertiary)
                            Text(timeF.string(from: end))
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                    }

                    if let customLabel = label {
                        Text(customLabel)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryLight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.Colors.primary.opacity(0.15)))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Date & Time")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text("Optional")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }

            Spacer()

            if let deleteAction = onDelete {
                HStack(spacing: Theme.Spacing.xl) {
                    Button(action: deleteAction) {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .buttonStyle(.borderless)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.cardBackground)
        )
    }
}

// MARK: - Poll Add Time Button (uses DateTimePickerSheet)
struct PollAddTimeButton: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Theme.Gradients.primary)
                Text("Add Time Option")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Invitee Field
struct AddInviteeField: View {
    @State private var name = ""
    @State private var phone = ""

    let onAdd: (String, String) -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                TextField("Name", text: $name)
                    .font(Theme.Typography.body)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.fieldBackground)
                    )

                TextField("Phone", text: $phone)
                    .font(Theme.Typography.body)
                    .keyboardType(.phonePad)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.fieldBackground)
                    )

                Button {
                    guard !name.isEmpty, !phone.isEmpty else { return }
                    onAdd(name, phone)
                    name = ""
                    phone = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.Gradients.primary)
                }
            }
        }
    }
}

// MARK: - Group Invitee Header
struct GroupInviteeHeader: View {
    let emoji: String
    let groupName: String
    let groupId: UUID
    let memberCount: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Text(emoji)
                        .font(.system(size: 14))
                }

                Text(groupName)
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("\(memberCount)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.Colors.backgroundElevated))

                Spacer()

                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Invitee Row
struct InviteeRow: View {
    let invitee: InviteeEntry
    var groupEmoji: String? = nil
    let onBench: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.textTertiary)

            AvatarView(url: nil, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(invitee.name)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    if let emoji = groupEmoji {
                        Text(emoji)
                            .font(.system(size: 12))
                    }
                }
                if invitee.source != .appConnection {
                    Text(invitee.phoneNumber)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                } else {
                    Text("via Game Night")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary.opacity(0.6))
                }
            }

            Spacer()

            Button(action: onBench) {
                Image(systemName: invitee.tier == 1 ? "arrow.down.to.line" : "arrow.up.to.line")
                    .font(.system(size: 14))
                    .foregroundColor(invitee.tier == 1 ? Theme.Colors.accent : Theme.Colors.success)
                    .padding(8)
                    .background(
                        Circle()
                            .fill((invitee.tier == 1 ? Theme.Colors.accent : Theme.Colors.success).opacity(0.1))
                    )
            }

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
                    .padding(8)
                    .background(
                        Circle().fill(Theme.Colors.backgroundElevated)
                    )
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(Theme.Colors.backgroundElevated)
        )
    }
}
