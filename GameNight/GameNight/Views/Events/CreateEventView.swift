import SwiftUI

struct CreateEventView: View {
    @StateObject private var viewModel: CreateEventViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showContactPicker = false
    @State private var showContactList = false
    let onSaved: ((GameEvent) -> Void)?

    init(eventToEdit: GameEvent? = nil, onSaved: ((GameEvent) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: CreateEventViewModel(eventToEdit: eventToEdit))
        self.onSaved = onSaved
    }

    private var visibleSteps: [CreateEventViewModel.CreateStep] {
        viewModel.isEditing ? [.details, .games, .schedule, .review] : CreateEventViewModel.CreateStep.allCases
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
                                case .schedule: return "Schedule"
                                case .invites: return "Invites"
                                case .review: return "Review"
                                }
                            },
                            currentStep: currentStepIndex
                        )
                        .padding(.horizontal, Theme.Spacing.xl)

                        // Step content
                        Group {
                            switch viewModel.currentStep {
                            case .details: detailsStep
                            case .games: gamesStep
                            case .schedule: scheduleStep
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
                        if viewModel.currentStep != .details {
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
                            if viewModel.currentStep == .review {
                                Task {
                                    await viewModel.createEvent()
                                    if let savedEvent = viewModel.createdEvent {
                                        onSaved?(savedEvent)
                                        dismiss()
                                    }
                                }
                            } else {
                                withAnimation(Theme.Animation.snappy) {
                                    let steps = visibleSteps
                                    if let idx = steps.firstIndex(of: viewModel.currentStep),
                                       idx < steps.count - 1 {
                                        viewModel.currentStep = steps[idx + 1]
                                    }
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.canProceed))
                        .disabled(!viewModel.canProceed)
                    }
                    .padding(Theme.Spacing.xl)
                    .background(Theme.Colors.cardBackground.ignoresSafeArea())
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Game Night" : "Create Game Night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
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

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Location")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("e.g. Alex's Place", text: $viewModel.location)
                    .font(Theme.Typography.body)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.backgroundElevated)
                    )
                TextField("Address (optional)", text: $viewModel.locationAddress)
                    .font(Theme.Typography.body)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.backgroundElevated)
                    )
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
        }
    }

    // MARK: - Step 3: Schedule
    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("When works?")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Add multiple time options so invitees can vote on what works best.")
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textSecondary)

            // Existing time options
            ForEach(Array(viewModel.timeOptions.enumerated()), id: \.element.id) { index, option in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.displayDate)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(option.displayTime)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textSecondary)
                        if let label = option.label {
                            Text(label)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.primaryLight)
                        }
                    }

                    Spacer()

                    Button { viewModel.removeTimeOption(at: index) } label: {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.Colors.error.opacity(0.7))
                    }
                }
                .cardStyle()
            }

            // Add time option
            AddTimeOptionView { date, start, end, label in
                viewModel.addTimeOption(date: date, startTime: start, endTime: end, label: label)
            }

            // Allow suggestions toggle
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

    // MARK: - Step 4: Invites
    private var invitesStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Who's playing?")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

            if viewModel.isEditing {
                Text("Invite list editing is separate for now. This flow updates the event without changing existing invites.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

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
            HStack(spacing: Theme.Spacing.md) {
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

                Spacer()
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

                    ForEach(viewModel.tier1Invitees) { invitee in
                        InviteeRow(
                            invitee: invitee,
                            onBench: {
                                viewModel.setInviteeTier(invitee.id, tier: 2)
                            },
                            onRemove: {
                                if let idx = viewModel.invitees.firstIndex(where: { $0.id == invitee.id }) {
                                    viewModel.removeInvitee(at: idx)
                                }
                            }
                        )
                    }
                    .onMove { from, to in
                        viewModel.moveInvitee(from: from, to: to, inTier: 1)
                    }

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
                        ForEach(viewModel.tier2Invitees) { invitee in
                            InviteeRow(
                                invitee: invitee,
                                onBench: {
                                    viewModel.setInviteeTier(invitee.id, tier: 1)
                                },
                                onRemove: {
                                    if let idx = viewModel.invitees.firstIndex(where: { $0.id == invitee.id }) {
                                        viewModel.removeInvitee(at: idx)
                                    }
                                }
                            )
                        }
                        .onMove { from, to in
                            viewModel.moveInvitee(from: from, to: to, inTier: 2)
                        }
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
                    Text("Time Options")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textTertiary)

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
                }

                Divider().background(Theme.Colors.divider)

                // Invite summary
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Invites")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textTertiary)

                    if viewModel.isEditing {
                        Text("Existing invitees stay unchanged in edit mode")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                    } else {
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

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= currentStep ? Theme.Colors.primary : Theme.Colors.divider)
                        .frame(height: 3)

                    Text(step)
                        .font(Theme.Typography.caption2)
                        .foregroundColor(index <= currentStep ? Theme.Colors.primary : Theme.Colors.textTertiary)
                }
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
    @State private var endTime = Date()
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

                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                        .tint(Theme.Colors.primary)

                    TextField("Label (e.g. Monday Evening)", text: $label)
                        .font(Theme.Typography.body)
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.backgroundElevated)
                        )

                    Button("Add") {
                        onAdd(date, startTime, endTime, label.isEmpty ? nil : label)
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

// MARK: - Invitee Row
struct InviteeRow: View {
    let invitee: InviteeEntry
    let onBench: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.textTertiary)

            AvatarView(url: nil, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(invitee.name)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
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
