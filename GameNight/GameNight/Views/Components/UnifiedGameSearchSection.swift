import SwiftUI

struct UnifiedGameSearchSection: View {
    @ObservedObject var viewModel: CreateEventViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SearchBar(text: $viewModel.gameSearchQuery, placeholder: "Search games...") {
                viewModel.searchGames()
            }
            .onChange(of: viewModel.gameSearchQuery) { _, _ in
                viewModel.searchGames()
            }

            if viewModel.isSearchingGames {
                ProgressView()
                    .tint(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
            } else if !viewModel.libraryGameSearchResults.isEmpty {
                resultSection(title: "From Your Library") {
                    ForEach(viewModel.libraryGameSearchResults) { game in
                        gameRow(game: game, badge: "Library") {
                            viewModel.addExistingGame(game)
                        }
                    }
                }
            } else if !viewModel.cachedGameSearchResults.isEmpty {
                resultSection(title: "From Game Database") {
                    ForEach(viewModel.cachedGameSearchResults) { game in
                        gameRow(game: game, badge: nil) {
                            viewModel.addExistingGame(game)
                        }
                    }
                }
            } else if !viewModel.gameSearchResults.isEmpty {
                resultSection(title: "From BoardGameGeek") {
                    ForEach(viewModel.gameSearchResults.prefix(12)) { result in
                        bggRow(result: result) {
                            Task { await viewModel.addGame(bggId: result.id, isPrimary: true) }
                            viewModel.gameSearchQuery = ""
                            viewModel.gameSearchResults = []
                            viewModel.cachedGameSearchResults = []
                            viewModel.libraryGameSearchResults = []
                        }
                    }
                }
            } else if !viewModel.gameSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No matches found.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func resultSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
            content()
        }
    }

    private func gameRow(game: Game, badge: String?, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.sm) {
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
                if let badge {
                    Text(badge)
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.Colors.accent.opacity(0.12)))
                }
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.primary)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.backgroundElevated)
            )
        }
        .buttonStyle(.plain)
    }

    private func bggRow(result: BGGSearchResult, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.sm) {
                GameThumbnail(url: result.thumbnailUrl, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if let year = result.yearPublished {
                        Text("(\(String(year)))")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.primary)
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
