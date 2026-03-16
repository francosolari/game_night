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
    @State private var showPollDateTimePicker = false
    @State private var showLocationPicker = false
    @State private var showLocationEditForm = false
    @State private var editPollIndex: Int? = nil
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

    private var visibleSteps: [CreateEventViewModel.CreateStep] {
        // Edit mode (including drafts) shows all 5 steps; new creation also shows all 5
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
                            case .details: detailsStep
                            case .games: gamesStep
                            case .invites: invitesStep
                            case .review: reviewStep
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                    .padding(.bottom, 120)
                }
                .background(Theme.Colors.background.ignoresSafeArea())

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
                                        onSaved?(savedEvent)
                                        dismiss()
                                    }
                                }
                            }
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .disabled(viewModel.isSaving)
                        }

                        Spacer()

                        if viewModel.currentStep != visibleSteps.first {
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
                                        onSaved?(savedEvent)
                                        dismiss()
                                    }
                                }
                            case .submit:
                                Task {
                                    await viewModel.createEvent()
                                    if let savedEvent = viewModel.createdEvent {
                                        onSaved?(savedEvent)
                                        dismiss()
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
                            onSaved?(viewModel.createdEvent!)
                        }
                        dismiss()
                    }
                }
                Button("Discard", role: .destructive) {
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
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerSheet(
                    locationName: $viewModel.location,
                    locationAddress: $viewModel.locationAddress
                )
            }
        }
    }

    // MARK: - Step 1: Details
    private var detailsStep: some View {
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

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Location")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textSecondary)

                Button {
                    if viewModel.location.isEmpty {
                        showLocationPicker = true
                    } else {
                        showLocationEditForm = true
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

    // MARK: - Step 2: Games
    private var gamesStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("What are we playing?")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

            // Search BGG
            SearchBar(text: $viewModel.gameSearchQuery, placeholder: "Search BoardGameGeek...") {
                Task { await viewModel.searchGames() }
            }
            .onChange(of: viewModel.gameSearchQuery) { _, _ in
                Task { await viewModel.searchGames() }
            }

            // Manual entry
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Or type a game name")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)

                HStack(spacing: Theme.Spacing.sm) {
                    TextField("e.g. Catan, Ticket to Ride...", text: $viewModel.manualGameName)
                        .font(Theme.Typography.body)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.backgroundElevated)
                        )

                    Button {
                        guard !viewModel.manualGameName.isEmpty else { return }
                        Task { await viewModel.addManualGame(name: viewModel.manualGameName) }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.Gradients.primary)
                    }
                    .disabled(viewModel.manualGameName.isEmpty)
                }
            }

            // Search results
            if viewModel.isSearchingGames {
                ProgressView()
                    .tint(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
            } else if !viewModel.gameSearchResults.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.gameSearchResults.prefix(8)) { result in
                        Button {
                            Task { await viewModel.addGame(bggId: result.id, isPrimary: true) }
                            viewModel.gameSearchQuery = ""
                            viewModel.gameSearchResults = []
                        } label: {
                            HStack {
                                if let thumb = result.thumbnailUrl, let url = URL(string: thumb) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.clear
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                VStack(alignment: .leading) {
                                    Text(result.name)
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    if let year = result.yearPublished {
                                        Text("(\(String(year)))")
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textTertiary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "plus.circle")
                                    .foregroundColor(Theme.Colors.primary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.backgroundElevated)
                            )
                        }
                    }
                }
            }

            // Selected games
            if !viewModel.selectedGames.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Selected Games")
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("Tap the star to set the primary game")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)

                    ForEach(Array(viewModel.selectedGames.enumerated()), id: \.element.id) { index, eventGame in
                        if let game = eventGame.game {
                            HStack {
                                Button {
                                    viewModel.setPrimaryGame(id: eventGame.id)
                                } label: {
                                    Image(systemName: eventGame.isPrimary ? "star.fill" : "star")
                                        .foregroundColor(eventGame.isPrimary ? Theme.Colors.warning : Theme.Colors.textTertiary)
                                }

                                CompactGameCard(game: game, isPrimary: eventGame.isPrimary)

                                Button {
                                    viewModel.removeGame(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Theme.Colors.error.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }

            // Game voting toggle
            if viewModel.selectedGames.count > 1 {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Toggle(isOn: $viewModel.allowGameVoting) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allow Game Voting")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Guests can vote on which games to play")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    .tint(Theme.Colors.primary)
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Schedule Section (Inside Details)
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
                ForEach(Array(viewModel.timeOptions.enumerated()), id: \.element.id) { index, option in
                    Button {
                        editPollIndex = index
                    } label: {
                        FixedDateSummaryCard(
                            hasDate: true,
                            date: option.date,
                            startTime: option.startTime,
                            endTime: option.endTime,
                            hasEndTime: option.endTime != nil,
                            label: option.label,
                            onDelete: {
                                viewModel.removeTimeOption(at: index)
                            }
                        )
                    }
                }

                // Add time option via Partiful-style picker
                PollAddTimeButton(onAdd: { date, start, end in
                    viewModel.addTimeOption(date: date, startTime: start, endTime: end, label: nil)
                })

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
        .sheet(item: Binding(
            get: { editPollIndex.map { PollEditItem(index: $0) } },
            set: { editPollIndex = $0?.index }
        )) { item in
            let option = viewModel.timeOptions[item.index]
            PollEditSheet(
                initialDate: option.date,
                initialStartTime: option.startTime,
                initialEndTime: option.endTime,
                initialLabel: option.label,
                onSave: { date, start, end, label in
                    viewModel.updateTimeOption(at: item.index, date: date, startTime: start, endTime: end, label: label)
                }
            )
        }
    }

    struct PollEditItem: Identifiable {
        let index: Int
        var id: Int { index }
    }

    // MARK: - Step 4: Invites
    @ViewBuilder
    private func tierInviteeList(tier: Int, benchTier: Int) -> some View {
        let grouped = viewModel.groupedInvitees(forTier: tier)

        // Grouped invitees
        ForEach(grouped.groups, id: \.id) { group in
            let isCollapsed = viewModel.collapsedGroups.contains(group.id)

            GroupInviteeHeader(
                emoji: group.emoji,
                groupId: group.id,
                memberCount: group.entries.count,
                isCollapsed: isCollapsed,
                onToggle: {
                    withAnimation(Theme.Animation.snappy) {
                        viewModel.toggleGroupCollapse(group.id)
                    }
                }
            )

            if !isCollapsed {
                ForEach(group.entries) { invitee in
                    InviteeRow(
                        invitee: invitee,
                        groupEmoji: invitee.groupEmoji,
                        onBench: {
                            viewModel.setInviteeTier(invitee.id, tier: benchTier)
                        },
                        onRemove: {
                            if let idx = viewModel.invitees.firstIndex(where: { $0.id == invitee.id }) {
                                viewModel.removeInvitee(at: idx)
                            }
                        }
                    )
                }
            }
        }

        // Ungrouped invitees
        ForEach(grouped.ungrouped) { invitee in
            InviteeRow(
                invitee: invitee,
                onBench: {
                    viewModel.setInviteeTier(invitee.id, tier: benchTier)
                },
                onRemove: {
                    if let idx = viewModel.invitees.firstIndex(where: { $0.id == invitee.id }) {
                        viewModel.removeInvitee(at: idx)
                    }
                }
            )
        }
    }

    private var invitesStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Who's playing?")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

            // Quick-add: suggested contacts (top 3 frequent)
            if !viewModel.topSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Suggested")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textTertiary)

                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.topSuggestions) { contact in
                            Button {
                                viewModel.addFrequentContact(contact)
                            } label: {
                                HStack(spacing: 6) {
                                    AvatarView(url: contact.contactAvatarUrl, size: 24)
                                    Text(contact.contactName.components(separatedBy: " ").first ?? contact.contactName)
                                        .font(Theme.Typography.calloutMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .lineLimit(1)
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Theme.Colors.primary)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(
                                    Capsule()
                                        .fill(Theme.Colors.backgroundElevated)
                                        .overlay(
                                            Capsule()
                                                .stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }
            }

            // Add people row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    if !groupsViewModel.groups.isEmpty {
                        Button {
                            showGroupPicker = true
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 14))
                                Text("Groups")
                                    .font(Theme.Typography.calloutMedium)
                            }
                            .foregroundColor(Theme.Colors.secondary)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.secondary.opacity(0.1))
                            )
                        }
                    }

                    Button {
                        showContactList = true
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 14))
                            Text("All Contacts")
                                .font(Theme.Typography.calloutMedium)
                        }
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.primary.opacity(0.1))
                        )
                    }

                    Button {
                        showContactPicker = true
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14))
                            Text("Phone")
                                .font(Theme.Typography.calloutMedium)
                        }
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.accent.opacity(0.1))
                        )
                    }
                }
            }

            // Manual entry
            AddInviteeField { name, phone in
                viewModel.addInvitee(name: name, phoneNumber: phone, tier: 1)
            }

            // Unified invite list
            if viewModel.invitees.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text("Add people to invite")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xxl)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    // Playing section (Tier 1)
                    HStack {
                        Image(systemName: "person.fill.checkmark")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.success)
                        Text("Playing (\(viewModel.tier1Invitees.count))")
                            .font(Theme.Typography.headlineMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text("Drag to reorder")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }

                    tierInviteeList(tier: 1, benchTier: 2)

                    // Bench section (Tier 2 / Waitlist)
                    HStack {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.accent)
                        Text("Bench (\(viewModel.tier2Invitees.count))")
                            .font(Theme.Typography.headlineMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(.top, Theme.Spacing.md)

                    if viewModel.tier2Invitees.isEmpty {
                        Text("Move people here to waitlist them. They get invited in order when someone declines.")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                    .foregroundColor(Theme.Colors.divider)
                            )
                    } else {
                        tierInviteeList(tier: 2, benchTier: 1)
                    }

                    // Auto-promote toggle
                    Toggle(isOn: $viewModel.inviteStrategy.autoPromote) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-invite from bench")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Next on bench gets invited when someone declines")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    .tint(Theme.Colors.primary)
                    .padding(.top, Theme.Spacing.md)
                }
            }
        }
        .task {
            await viewModel.loadSuggestedContacts()
            await groupsViewModel.loadGroups()
        }
        .sheet(isPresented: $showGroupPicker) {
            GroupPickerSheet(groups: groupsViewModel.groups) { group in
                viewModel.loadGroupMembers(group)
            }
        }
    }

    // MARK: - Step 5: Review
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Review & Send")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

            // Preview card
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(viewModel.title)
                    .font(Theme.Typography.headlineLarge)
                    .foregroundColor(Theme.Colors.textPrimary)

                if !viewModel.location.isEmpty {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "mappin")
                            .foregroundColor(Theme.Colors.secondary)
                        Text(viewModel.location)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                Divider().background(Theme.Colors.divider)

                // Games
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Games")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textTertiary)

                    if viewModel.selectedGames.isEmpty {
                        Text("No games selected — you can add later")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textTertiary)
                    } else {
                        ForEach(viewModel.selectedGames) { eventGame in
                            if let game = eventGame.game {
                                CompactGameCard(game: game, isPrimary: eventGame.isPrimary)
                            }
                        }
                    }
                }

                Divider().background(Theme.Colors.divider)

                // Schedule
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(viewModel.scheduleMode == .fixed ? "Date" : "Time Options")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textTertiary)

                    if viewModel.scheduleMode == .fixed {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "calendar")
                                .foregroundColor(Theme.Colors.primary)
                            if viewModel.hasDate {
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
                                if viewModel.hasEndTime {
                                    Text("\(dateF.string(from: viewModel.fixedDate)) at \(timeF.string(from: viewModel.fixedStartTime)) - \(timeF.string(from: viewModel.fixedEndTime))")
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                } else {
                                    Text("\(dateF.string(from: viewModel.fixedDate)) at \(timeF.string(from: viewModel.fixedStartTime))")
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                }
                            } else {
                                Text("Date not set")
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }
                    } else {
                        ForEach(viewModel.timeOptions) { option in
                            HStack {
                                Text(option.displayDate)
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text(option.displayTime)
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }

                        if viewModel.allowTimeSuggestions {
                            Text("Time suggestions enabled")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.accent)
                        }
                    }
                }

                Divider().background(Theme.Colors.divider)

                // Invite summary
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Invites")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textTertiary)

                    Text("\(viewModel.tier1Invitees.count) playing")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textPrimary)

                    if !viewModel.tier2Invitees.isEmpty {
                        Text("\(viewModel.tier2Invitees.count) on bench")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            .cardStyle()

            if let error = viewModel.error {
                Text(error)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.error)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.error.opacity(0.1))
                    )
            }
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

// MARK: - Add Time Option View
struct AddTimeOptionView: View {
    @State private var date = Date()
    @State private var startTime = Date()
    @State private var label = ""
    @State private var isExpanded = false

    let onAdd: (Date, Date, Date?, String?) -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button {
                withAnimation(Theme.Animation.snappy) { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.Gradients.primary)
                    Text("Add Time Option")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }

            if isExpanded {
                VStack(spacing: Theme.Spacing.md) {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .tint(Theme.Colors.primary)

                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .tint(Theme.Colors.primary)

                    TextField("Label (e.g. Monday Evening)", text: $label)
                        .font(Theme.Typography.body)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.backgroundElevated)
                        )

                    Button("Add") {
                        onAdd(date, startTime, nil, label.isEmpty ? nil : label)
                        withAnimation(Theme.Animation.snappy) { isExpanded = false }
                        label = ""
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .cardStyle()
            }
        }
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
                .foregroundColor(Theme.Colors.primary)

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
                Button(action: deleteAction) {
                    Image(systemName: "trash")
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
    let onAdd: (Date, Date, Date?) -> Void

    @State private var showPicker = false
    @State private var pickerDate = Date()
    @State private var pickerEndDate = Date()
    @State private var pickerStartTime = DateTimePickerSheet.defaultTime(hour: 19)
    @State private var pickerEndTime = DateTimePickerSheet.defaultTime(hour: 22)
    @State private var pickerHasEndTime = false

    var body: some View {
        Button {
            pickerDate = Date()
            pickerEndDate = Date()
            pickerStartTime = DateTimePickerSheet.defaultTime(hour: 19)
            pickerEndTime = DateTimePickerSheet.defaultTime(hour: 22)
            pickerHasEndTime = false
            showPicker = true
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
        .sheet(isPresented: $showPicker, onDismiss: {
            onAdd(pickerDate, pickerStartTime, pickerHasEndTime ? pickerEndTime : nil)
        }) {
            DateTimePickerSheet(
                date: $pickerDate,
                startTime: $pickerStartTime,
                endDate: $pickerEndDate,
                endTime: $pickerEndTime,
                hasEndTime: $pickerHasEndTime
            )
        }
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
                            .fill(Theme.Colors.backgroundElevated)
                    )

                TextField("Phone", text: $phone)
                    .font(Theme.Typography.body)
                    .keyboardType(.phonePad)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.backgroundElevated)
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

                Text("\(memberCount) members")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.Colors.backgroundElevated))

                Spacer()

                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .padding(.horizontal, Theme.Spacing.sm)
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
                Text(invitee.phoneNumber)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
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
