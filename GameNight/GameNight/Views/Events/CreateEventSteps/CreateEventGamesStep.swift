import SwiftUI

struct CreateEventGamesStep: View {
    @ObservedObject var viewModel: CreateEventViewModel

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
}
