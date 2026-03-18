import SwiftUI

struct GameDetailView: View {
    @StateObject private var viewModel: GameDetailViewModel
    @State private var isDescriptionExpanded = false
    @State private var showEditSheet = false

    private var isManualGame: Bool {
        viewModel.game.bggId == nil
    }

    init(game: Game) {
        _viewModel = StateObject(wrappedValue: GameDetailViewModel(game: game))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // 1. Hero image with rating badge
                DetailHeroImage(
                    imageUrl: viewModel.game.imageUrl,
                    badge: viewModel.game.bggRating
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // 2. Title cluster
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(viewModel.game.name)
                            .font(Theme.Typography.displayMedium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        titleMetadata
                    }

                    // 3. Info rows
                    InfoRowGroup(rows: buildInfoRows())

                    // 4. Tags
                    if !viewModel.game.categories.isEmpty {
                        TagFlowSection(title: "Categories", tags: viewModel.game.categories, color: Theme.Colors.primary)
                    }
                    if !viewModel.game.mechanics.isEmpty {
                        TagFlowSection(title: "Mechanics", tags: viewModel.game.mechanics, color: Theme.Colors.accent)
                    }

                    // 5. Description
                    if let desc = viewModel.game.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(desc)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(isDescriptionExpanded ? nil : 3)

                            Button(isDescriptionExpanded ? "Show less" : "Read more") {
                                withAnimation { isDescriptionExpanded.toggle() }
                            }
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(Theme.Colors.primary)
                        }
                    }

                    // 6. Base game link
                    if let baseGame = viewModel.baseGame {
                        NavigationLink(value: baseGame) {
                            HStack {
                                Image(systemName: "arrow.turn.up.left")
                                    .foregroundColor(Theme.Colors.accent)
                                Text("Expansion for \(baseGame.name)")
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundColor(Theme.Colors.accent)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.backgroundElevated)
                            )
                        }
                    }

                    // 7. Family links
                    ForEach(viewModel.families, id: \.family.id) { familyData in
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            NavigationLink(
                                value: GameFamilyDestination(
                                    family: familyData.family,
                                    games: familyData.games
                                )
                            ) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Text("Part of \(familyData.family.name)")
                                        .font(Theme.Typography.label)
                                        .foregroundColor(Theme.Colors.accent)
                                        .textCase(.uppercase)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)

                            HorizontalGameScroll(
                                title: "",
                                games: familyData.games.filter { $0.id != viewModel.game.id }
                            )
                        }
                    }

                    // 8. Expansions
                    if !viewModel.expansions.isEmpty {
                        HorizontalGameScroll(
                            title: "Expansions",
                            games: viewModel.expansions
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding(.bottom, 100)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isManualGame {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ManualGameEditSheet(game: $viewModel.game)
        }
        .task {
            await viewModel.loadRelatedData()
        }
    }

    @ViewBuilder
    private var titleMetadata: some View {
        let designerLinks = creatorLinks(
            names: viewModel.game.designers,
            role: .designer
        )
        let publisherLinks = creatorLinks(
            names: viewModel.game.publishers,
            role: .publisher
        )

        let hasMetadata = !designerLinks.isEmpty || !publisherLinks.isEmpty || viewModel.game.yearPublished != nil

        if hasMetadata {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if !designerLinks.isEmpty {
                    creatorRow(links: designerLinks)
                }
                if !publisherLinks.isEmpty {
                    creatorRow(links: publisherLinks)
                }
                if let year = viewModel.game.yearPublished {
                    Label(String(year), systemImage: "calendar")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
    }

    private func creatorLinks(names: [String], role: CreatorRole) -> [(name: String, destination: CreatorDestination)] {
        Array(NSOrderedSet(array: names)) // preserve order while removing duplicates
            .compactMap { $0 as? String }
            .map { ($0, CreatorDestination(name: $0, role: role)) }
    }

    @ViewBuilder
    private func creatorRow(links: [(name: String, destination: CreatorDestination)]) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(links.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Text("\u{00B7}")
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                NavigationLink(value: item.destination) {
                    Text(item.name)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.accent)
                }
            }
        }
    }

    private func buildInfoRows() -> [InfoRowData] {
        var rows: [InfoRowData] = []

        // Players
        let bestStr = viewModel.game.recommendedPlayers.map { recs in
            recs.isEmpty ? nil : "Best: \(recs.map(String.init).joined(separator: "\u{2013}"))"
        } ?? nil
        rows.append(InfoRowData(
            icon: "person.2.fill",
            label: "Players",
            value: viewModel.game.playerCountDisplay,
            detail: bestStr,
            detailColor: Theme.Colors.success
        ))

        // Playtime
        rows.append(InfoRowData(
            icon: "clock.fill",
            label: "Time",
            value: viewModel.game.playtimeDisplay
        ))

        // Weight
        rows.append(InfoRowData(
            icon: "scalemass.fill",
            label: "Weight",
            value: String(format: "%.2f / 5", viewModel.game.complexity),
            detail: viewModel.game.complexityLabel,
            detailColor: Theme.Colors.complexity(viewModel.game.complexity)
        ))

        // Age
        if let age = viewModel.game.minAge {
            rows.append(InfoRowData(
                icon: "number.circle",
                label: "Age",
                value: "Ages \(age)+"
            ))
        }

        return rows
    }
}

struct GameFamilyDetailView: View {
    let destination: GameFamilyDestination

    private var sortedGames: [Game] {
        destination.games.sorted { lhs, rhs in
            switch ((lhs.bggRating ?? 0), (rhs.bggRating ?? 0)) {
            case let (l, r) where l != r:
                return l > r
            default:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text(destination.family.name)
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Series / Family")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .textCase(.uppercase)

                ExpandableGameGrid(
                    games: sortedGames,
                    initialCount: 8,
                    sortMode: .topRated
                )
            }
            .padding(Theme.Spacing.xl)
            .padding(.bottom, 100)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
// MARK: - Manual Game Edit Sheet
private struct ManualGameEditSheet: View {
    @Binding var game: Game
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var minPlayers: String = ""
    @State private var maxPlayers: String = ""
    @State private var minPlaytime: String = ""
    @State private var maxPlaytime: String = ""
    @State private var description: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Players") {
                    HStack {
                        TextField("Min", text: $minPlayers)
                            .keyboardType(.numberPad)
                        Text("–")
                        TextField("Max", text: $maxPlayers)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Playtime (minutes)") {
                    HStack {
                        TextField("Min", text: $minPlaytime)
                            .keyboardType(.numberPad)
                        Text("–")
                        TextField("Max", text: $maxPlaytime)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Edit Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            name = game.name
            minPlayers = String(game.minPlayers)
            maxPlayers = String(game.maxPlayers)
            minPlaytime = String(game.minPlaytime)
            maxPlaytime = String(game.maxPlaytime)
            description = game.description ?? ""
        }
    }

    private func save() async {
        isSaving = true
        game.name = name.trimmingCharacters(in: .whitespaces)
        game.minPlayers = Int(minPlayers) ?? game.minPlayers
        game.maxPlayers = Int(maxPlayers) ?? game.maxPlayers
        game.minPlaytime = Int(minPlaytime) ?? game.minPlaytime
        game.maxPlaytime = Int(maxPlaytime) ?? game.maxPlaytime
        game.description = description.isEmpty ? nil : description

        do {
            try await SupabaseService.shared.updateGame(game)
        } catch {
            // Non-critical — local state is already updated
        }
        isSaving = false
        dismiss()
    }
}
