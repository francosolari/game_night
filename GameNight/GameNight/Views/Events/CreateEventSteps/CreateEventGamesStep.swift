import SwiftUI

struct CreateEventGamesStep: View {
    @ObservedObject var viewModel: CreateEventViewModel
    @State private var expandedGameId: UUID?

    private static let playtimePresets = [5, 10, 15, 20, 30, 45, 60, 90, 120, 150, 180, 240]

    var body: some View {
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
                                .fill(Theme.Colors.fieldBackground)
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

            // Library autocomplete (when typing)
            if !viewModel.libraryAutocompleteResults.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("From Library")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.accent)

                    ForEach(viewModel.libraryAutocompleteResults.prefix(4)) { game in
                        Button {
                            let eventGame = EventGame(
                                id: UUID(),
                                gameId: game.id,
                                game: game,
                                isPrimary: viewModel.selectedGames.isEmpty,
                                sortOrder: viewModel.selectedGames.count
                            )
                            viewModel.selectedGames.append(eventGame)
                            viewModel.manualGameName = ""
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                GameThumbnail(url: game.thumbnailUrl, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.name)
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .lineLimit(1)
                                    if let year = game.yearPublished {
                                        Text("(\(String(year)))")
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textTertiary)
                                    }
                                }
                                Spacer()
                                Text("Library")
                                    .font(Theme.Typography.caption2)
                                    .foregroundColor(Theme.Colors.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.Colors.accent.opacity(0.12)))
                            }
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.backgroundElevated)
                            )
                        }
                        .buttonStyle(.plain)
                    }
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

            // From Your Library section (when no games selected)
            if viewModel.selectedGames.isEmpty && !viewModel.libraryGames.isEmpty && viewModel.manualGameName.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("From Your Library")
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)

                    ForEach(viewModel.libraryGames.prefix(6)) { game in
                        Button {
                            let eventGame = EventGame(
                                id: UUID(),
                                gameId: game.id,
                                game: game,
                                isPrimary: viewModel.selectedGames.isEmpty,
                                sortOrder: viewModel.selectedGames.count
                            )
                            viewModel.selectedGames.append(eventGame)
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                GameThumbnail(url: game.thumbnailUrl, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.name)
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .lineLimit(1)
                                    if let year = game.yearPublished {
                                        Text("(\(String(year)))")
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textTertiary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundColor(Theme.Colors.primary)
                            }
                            .padding(Theme.Spacing.sm)
                        }
                        .buttonStyle(.plain)
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
                            VStack(spacing: 0) {
                                HStack {
                                    Button {
                                        viewModel.setPrimaryGame(id: eventGame.id)
                                    } label: {
                                        Image(systemName: eventGame.isPrimary ? "star.fill" : "star")
                                            .foregroundColor(eventGame.isPrimary ? Theme.Colors.warning : Theme.Colors.textTertiary)
                                    }

                                    CompactGameCard(game: game, isPrimary: eventGame.isPrimary)

                                    if game.bggId == nil {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                expandedGameId = expandedGameId == eventGame.id ? nil : eventGame.id
                                            }
                                        } label: {
                                            Image(systemName: "slider.horizontal.3")
                                                .font(.system(size: 16))
                                                .foregroundColor(Theme.Colors.accent)
                                                .rotationEffect(.degrees(expandedGameId == eventGame.id ? 90 : 0))
                                        }
                                    }

                                    Button {
                                        if expandedGameId == eventGame.id {
                                            expandedGameId = nil
                                        }
                                        viewModel.removeGame(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Theme.Colors.error.opacity(0.7))
                                    }
                                }

                                // Expandable settings for manual games
                                if game.bggId == nil && expandedGameId == eventGame.id {
                                    ManualGameSettingsPanel(
                                        game: game,
                                        playtimePresets: Self.playtimePresets,
                                        onUpdate: { updatedGame in
                                            Task { await viewModel.updateManualGameSettings(at: index, game: updatedGame) }
                                        }
                                    )
                                    .padding(.top, Theme.Spacing.sm)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
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
        .task { await viewModel.loadLibrary() }
    }
}

// MARK: - Manual Game Settings Panel
private struct ManualGameSettingsPanel: View {
    let game: Game
    let playtimePresets: [Int]
    let onUpdate: (Game) -> Void

    @State private var complexity: Double
    @State private var minPlaytime: Int
    @State private var maxPlaytime: Int
    @State private var minPlayers: Int
    @State private var maxPlayers: Int

    init(game: Game, playtimePresets: [Int], onUpdate: @escaping (Game) -> Void) {
        self.game = game
        self.playtimePresets = playtimePresets
        self.onUpdate = onUpdate
        _complexity = State(initialValue: game.complexity)
        _minPlaytime = State(initialValue: game.minPlaytime)
        _maxPlaytime = State(initialValue: game.maxPlaytime)
        _minPlayers = State(initialValue: game.minPlayers)
        _maxPlayers = State(initialValue: game.maxPlayers)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Complexity
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Complexity")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)

                StarRatingPicker(rating: $complexity)
                    .onChange(of: complexity) { _, _ in commitChanges() }
            }

            Divider().background(Theme.Colors.divider)

            // Playing Time
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Playing Time")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)

                HStack(spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Min")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.textTertiary)
                        PlaytimeMenu(
                            value: $minPlaytime,
                            presets: playtimePresets,
                            onChange: {
                                if maxPlaytime < minPlaytime { maxPlaytime = minPlaytime }
                                commitChanges()
                            }
                        )
                    }

                    Text("–")
                        .foregroundColor(Theme.Colors.textTertiary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.textTertiary)
                        PlaytimeMenu(
                            value: $maxPlaytime,
                            presets: playtimePresets.filter { $0 >= minPlaytime },
                            onChange: { commitChanges() }
                        )
                    }
                }
            }

            Divider().background(Theme.Colors.divider)

            // Player Range
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Player Range")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)

                HStack(spacing: Theme.Spacing.lg) {
                    Stepper("Min: \(minPlayers)", value: $minPlayers, in: 1...20)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .onChange(of: minPlayers) { _, newVal in
                            if maxPlayers < newVal { maxPlayers = newVal }
                            commitChanges()
                        }

                    Stepper("Max: \(maxPlayers)", value: $maxPlayers, in: minPlayers...20)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .onChange(of: maxPlayers) { _, _ in commitChanges() }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(Theme.Colors.backgroundElevated)
        )
    }

    private func commitChanges() {
        var updated = game
        updated.complexity = complexity
        updated.minPlaytime = minPlaytime
        updated.maxPlaytime = maxPlaytime
        updated.minPlayers = minPlayers
        updated.maxPlayers = maxPlayers
        onUpdate(updated)
    }
}

// MARK: - Playtime Preset Menu
private struct PlaytimeMenu: View {
    @Binding var value: Int
    let presets: [Int]
    let onChange: () -> Void

    var body: some View {
        Menu {
            ForEach(presets, id: \.self) { preset in
                Button(formatMinutes(preset)) {
                    value = preset
                    onChange()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(formatMinutes(value))
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.fieldBackground)
            )
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 240 { return "4+ hrs" }
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes) min"
    }
}
