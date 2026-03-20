import SwiftUI

struct PlayLoggingSheet: View {
    @StateObject private var viewModel = PlayLoggingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var toast: ToastItem?
    @State private var showGamePicker = false

    let event: GameEvent?
    let group: GameGroup?
    let invites: [Invite]

    init(event: GameEvent? = nil, group: GameGroup? = nil, invites: [Invite] = []) {
        self.event = event
        self.group = group
        self.invites = invites
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Existing plays warning
                    if !viewModel.existingPlays.isEmpty {
                        existingPlaysSection
                    }

                    // Game selection
                    gameSelectionSection

                    // Per-game results
                    ForEach(viewModel.selectedGames) { game in
                        gameResultSection(game)
                    }

                    // Confirm
                    if !viewModel.selectedGameIds.isEmpty {
                        confirmSection
                    }
                }
                .padding(Theme.Spacing.xl)
                .padding(.bottom, 40)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Log Plays")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .toast($toast)
        }
        .task {
            if let event {
                viewModel.prefillFromEvent(event, invites: invites)
                await viewModel.checkExistingPlays()
            } else if let group {
                viewModel.prefillFromGroup(group)
            }
        }
    }

    // MARK: - Existing Plays Warning

    private var existingPlaysSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.warning)
                Text("Plays already logged for this event")
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            ForEach(viewModel.existingPlays) { play in
                HStack(spacing: Theme.Spacing.sm) {
                    Text(play.game?.name ?? "Unknown Game")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text("by \(play.logger?.displayName ?? "someone")")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.warning.opacity(0.1))
        )
    }

    // MARK: - Game Selection

    private var gameSelectionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "What was played?")

            if viewModel.availableGames.isEmpty {
                Button {
                    showGamePicker = true
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("Select a game")
                            .font(Theme.Typography.bodyMedium)
                    }
                    .foregroundColor(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .strokeBorder(Theme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )
                }
                .sheet(isPresented: $showGamePicker) {
                    GamePickerSheet { game in
                        viewModel.addGame(game)
                    }
                }
            } else if viewModel.availableGames.count > 1 {
                ForEach(viewModel.availableGames) { game in
                    let isSelected = viewModel.selectedGameIds.contains(game.id)
                    Button {
                        if isSelected {
                            viewModel.selectedGameIds.remove(game.id)
                        } else {
                            viewModel.selectedGameIds.insert(game.id)
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundColor(isSelected ? Theme.Colors.primary : Theme.Colors.textTertiary)

                            Text(game.name)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)

                            Spacer()

                            Text(game.playtimeDisplay)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(isSelected ? Theme.Colors.primary.opacity(0.08) : Theme.Colors.cardBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            // Single game: auto-selected, just show the name
            else if let game = viewModel.availableGames.first {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.primary)
                    Text(game.name)
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Per-Game Results

    private func gameResultSection(_ game: Game) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if viewModel.selectedGames.count > 1 {
                Text(game.name)
                    .font(Theme.Typography.headlineMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            // Co-op toggle
            let isCoop = Binding(
                get: { viewModel.isCooperativeByGame[game.id] ?? false },
                set: { viewModel.isCooperativeByGame[game.id] = $0 }
            )

            Toggle(isOn: isCoop) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text("Co-op game")
                        .font(Theme.Typography.callout)
                }
                .foregroundColor(Theme.Colors.textSecondary)
            }
            .tint(Theme.Colors.primary)

            // Co-op result
            if isCoop.wrappedValue {
                HStack(spacing: Theme.Spacing.md) {
                    coopResultButton(.won, gameId: game.id, label: "Won", icon: "trophy.fill")
                    coopResultButton(.lost, gameId: game.id, label: "Lost", icon: "xmark.circle")
                }
            }

            // Participants
            if let participants = viewModel.participantsByGame[game.id], !participants.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Players")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textSecondary)

                    ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                        participantRow(gameId: game.id, index: index, participant: participant, isCoop: isCoop.wrappedValue)
                    }
                }
            }

            // Notes
            let notes = Binding(
                get: { viewModel.notesByGame[game.id] ?? "" },
                set: { viewModel.notesByGame[game.id] = $0 }
            )
            TextField("Notes (optional)", text: notes, axis: .vertical)
                .lineLimit(2...4)
                .font(Theme.Typography.callout)
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.fieldBackground)
                )
        }
        .cardStyle()
    }

    private func coopResultButton(_ result: Play.CooperativeResult, gameId: UUID, label: String, icon: String) -> some View {
        let isSelected = viewModel.cooperativeResultByGame[gameId] == result
        return Button {
            viewModel.cooperativeResultByGame[gameId] = result
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(Theme.Typography.calloutMedium)
            }
            .foregroundColor(isSelected ? (result == .won ? Theme.Colors.success : Theme.Colors.error) : Theme.Colors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(isSelected ? (result == .won ? Theme.Colors.success.opacity(0.1) : Theme.Colors.error.opacity(0.1)) : Theme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .stroke(isSelected ? (result == .won ? Theme.Colors.success : Theme.Colors.error) : Theme.Colors.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func participantRow(gameId: UUID, index: Int, participant: PlayParticipantDraft, isCoop: Bool) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // Playing toggle
            Button {
                viewModel.participantsByGame[gameId]?[index].isPlaying.toggle()
            } label: {
                Image(systemName: participant.isPlaying ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(participant.isPlaying ? Theme.Colors.primary : Theme.Colors.textTertiary)
            }
            .buttonStyle(.plain)

            Text(participant.displayName)
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(participant.isPlaying ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)

            Spacer()

            // Winner toggle (only for competitive, playing participants)
            if participant.isPlaying && !isCoop {
                Button {
                    viewModel.participantsByGame[gameId]?[index].isWinner.toggle()
                } label: {
                    Image(systemName: participant.isWinner ? "crown.fill" : "crown")
                        .font(.system(size: 16))
                        .foregroundColor(participant.isWinner ? Theme.Colors.accentWarm : Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - Confirm

    private var confirmSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Summary
            ForEach(viewModel.selectedGames) { game in
                let participants = (viewModel.participantsByGame[game.id] ?? []).filter(\.isPlaying)
                let winners = participants.filter(\.isWinner)
                let isCoop = viewModel.isCooperativeByGame[game.id] ?? false

                HStack(spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.name)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("\(participants.count) player\(participants.count == 1 ? "" : "s")")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    Spacer()
                    if isCoop, let result = viewModel.cooperativeResultByGame[game.id] {
                        Text(result == .won ? "Won" : "Lost")
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(result == .won ? Theme.Colors.success : Theme.Colors.error)
                    } else if !winners.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.accentWarm)
                            Text(winners.map(\.displayName).joined(separator: ", "))
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.Colors.cardBackground)
                )
            }

            if let error = viewModel.error {
                Text(error)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.error)
            }

            Button(viewModel.isSaving ? "Saving..." : "Log Plays") {
                Task {
                    let success = await viewModel.savePlays()
                    if success {
                        toast = ToastItem(style: .success, message: "Plays logged!")
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        dismiss()
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: !viewModel.isSaving))
            .disabled(viewModel.isSaving)
        }
    }
}

// MARK: - Game Picker Sheet (simplified library picker)

private struct GamePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var libraryGames: [GameLibraryEntry] = []
    let onSelect: (Game) -> Void

    var filteredGames: [GameLibraryEntry] {
        if searchText.isEmpty { return libraryGames }
        return libraryGames.filter { entry in
            entry.game?.name.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredGames) { entry in
                if let game = entry.game {
                    Button {
                        onSelect(game)
                        dismiss()
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Text(game.name)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Text(game.playerCountDisplay)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search your library")
            .navigationTitle("Select Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .task {
            libraryGames = (try? await SupabaseService.shared.fetchGameLibrary()) ?? []
        }
    }
}
