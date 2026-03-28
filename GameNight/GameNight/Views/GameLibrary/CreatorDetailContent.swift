import SwiftUI

struct CreatorDetailContent: View {
    @ObservedObject var viewModel: CreatorDetailViewModel

    private var initials: String {
        viewModel.name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // 1. Hero with initials
                DetailHeroImage(
                    imageUrl: nil,
                    fallbackInitials: initials,
                    gradientColors: [Theme.Colors.accent.opacity(0.6), Theme.Colors.primary.opacity(0.4)]
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // 2. Title
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(viewModel.name)
                            .font(Theme.Typography.displayMedium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text(viewModel.subtitle)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }

                    // 3. Stats
                    if !viewModel.games.isEmpty {
                        InfoRowGroup(rows: buildStatsRows())
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Theme.Colors.primary)
                            .frame(maxWidth: .infinity)
                    } else if viewModel.games.isEmpty {
                        Text("No games found in the database yet.")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textTertiary)
                    } else {
                        // 4. Sort bar
                        SortFilterBar(
                            options: SortOption.allCases,
                            selected: $viewModel.sortMode
                        )

                        // 5. Game grid
                        ExpandableGameGrid(
                            games: viewModel.displayedGames,
                            sortMode: viewModel.sortMode
                        )

                        if viewModel.showExpandButton {
                            Button {
                                Task { await viewModel.loadAllGames() }
                            } label: {
                                Text("Show All Games")
                                    .font(Theme.Typography.calloutMedium)
                                    .foregroundColor(Theme.Colors.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(Theme.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                            .fill(Theme.Colors.primary.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding(.bottom, 100)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildStatsRows() -> [InfoRowData] {
        var rows: [InfoRowData] = []
        if let avg = viewModel.averageRating {
            rows.append(InfoRowData(
                icon: "star.fill",
                label: "Avg. Rating",
                value: String(format: "Avg. Rating: %.1f", avg)
            ))
        }
        if let avgWeight = viewModel.averageWeight {
            rows.append(InfoRowData(
                icon: "scalemass.fill",
                label: "Avg. Weight",
                value: String(format: "Avg. Weight: %.1f / 5", avgWeight)
            ))
        }
        return rows
    }
}
