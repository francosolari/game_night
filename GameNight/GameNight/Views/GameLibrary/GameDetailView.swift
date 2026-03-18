import SwiftUI

struct GameDetailView: View {
    @StateObject private var viewModel: GameDetailViewModel
    @State private var isDescriptionExpanded = false
    @State private var isEditingManualGame = false
    @State private var manualDraftGame: Game?
    @State private var isSavingManualGame = false

    private var isManualGame: Bool {
        viewModel.game.bggId == nil
    }

    private var displayedGame: Game {
        if isEditingManualGame, let manualDraftGame {
            return manualDraftGame
        }
        return viewModel.game
    }

    private var gameInitials: String {
        let parts = displayedGame.name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        let initials = String(parts)
        return initials.isEmpty ? "GM" : initials
    }

    init(game: Game) {
        _viewModel = StateObject(wrappedValue: GameDetailViewModel(game: game))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // 1. Hero image with rating badge
                DetailHeroImage(
                    imageUrl: displayedGame.imageUrl,
                    badge: displayedGame.bggRating,
                    fallbackInitials: gameInitials,
                    gradientColors: isManualGame
                        ? [Theme.Colors.primary.opacity(0.65), Theme.Colors.accent.opacity(0.45)]
                        : [Theme.Colors.accent.opacity(0.5), Theme.Colors.primary.opacity(0.5)]
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // 2. Title cluster
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        if isEditingManualGame, let draftBinding = manualDraftBinding {
                            TextField("Game Name", text: draftBinding.name)
                                .font(Theme.Typography.displayMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .textInputAutocapitalization(.words)
                        } else {
                            Text(displayedGame.name)
                                .font(Theme.Typography.displayMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }

                        titleMetadata
                    }

                    // 3. Info rows
                    if isEditingManualGame, let draftBinding = manualDraftBinding {
                        ManualGameEditorSection(game: draftBinding)
                    } else {
                        InfoRowGroup(rows: buildInfoRows(for: displayedGame))
                    }

                    // 4. Tags
                    if isEditingManualGame, let draftBinding = manualDraftBinding {
                        ManualTagEditorSection(game: draftBinding)
                    } else {
                        if !displayedGame.categories.isEmpty {
                            TagFlowSection(title: "Categories", tags: displayedGame.categories, color: Theme.Colors.primary)
                        }
                        if !displayedGame.mechanics.isEmpty {
                            TagFlowSection(title: "Mechanics", tags: displayedGame.mechanics, color: Theme.Colors.accent)
                        }
                    }

                    // 5. Description
                    if isEditingManualGame, let draftBinding = manualDraftBinding {
                        ManualDescriptionEditorSection(game: draftBinding)
                    } else if let desc = displayedGame.description, !desc.isEmpty {
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
                    if !isEditingManualGame, let baseGame = viewModel.baseGame {
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
                    if !isEditingManualGame {
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
                                    games: familyData.games.filter { $0.id != displayedGame.id }
                                )
                            }
                        }
                    }

                    // 8. Expansions
                    if !isEditingManualGame, !viewModel.expansions.isEmpty {
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
                if isEditingManualGame {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            cancelManualEditing()
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSavingManualGame ? "Saving..." : "Save") {
                            Task { await saveManualGameEdits() }
                        }
                        .disabled(
                            isSavingManualGame ||
                            (manualDraftGame?.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                        )
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            startManualEditing()
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadRelatedData()
        }
    }

    @ViewBuilder
    private var titleMetadata: some View {
        let designerLinks = creatorLinks(
            names: displayedGame.designers,
            role: .designer
        )
        let publisherLinks = creatorLinks(
            names: displayedGame.publishers,
            role: .publisher
        )

        let hasMetadata = !designerLinks.isEmpty || !publisherLinks.isEmpty || displayedGame.yearPublished != nil || isManualGame

        if hasMetadata {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if isManualGame {
                    Label(
                        isEditingManualGame ? "Editing Manual Game" : "Manual Library Game",
                        systemImage: isEditingManualGame ? "slider.horizontal.3" : "square.and.pencil"
                    )
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textTertiary)
                }
                if !designerLinks.isEmpty {
                    creatorRow(links: designerLinks)
                }
                if !publisherLinks.isEmpty {
                    creatorRow(links: publisherLinks)
                }
                if let year = displayedGame.yearPublished {
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

    private var manualDraftBinding: Binding<Game>? {
        guard isEditingManualGame, manualDraftGame != nil else { return nil }
        return Binding(
            get: { manualDraftGame ?? viewModel.game },
            set: { manualDraftGame = $0 }
        )
    }

    private func startManualEditing() {
        manualDraftGame = viewModel.game
        isEditingManualGame = true
    }

    private func cancelManualEditing() {
        manualDraftGame = nil
        isEditingManualGame = false
        isSavingManualGame = false
    }

    private func saveManualGameEdits() async {
        guard var updatedGame = manualDraftGame else { return }

        updatedGame.name = updatedGame.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updatedGame.name.isEmpty else { return }

        isSavingManualGame = true
        viewModel.game = updatedGame

        do {
            try await SupabaseService.shared.updateGame(updatedGame)
        } catch {
            // Non-critical — local state is already updated
        }

        manualDraftGame = nil
        isEditingManualGame = false
        isSavingManualGame = false
    }

    private func buildInfoRows(for game: Game) -> [InfoRowData] {
        var rows: [InfoRowData] = []

        // Players
        let bestStr = game.recommendedPlayers.map { recs in
            recs.isEmpty ? nil : "Best: \(recs.map(String.init).joined(separator: "\u{2013}"))"
        } ?? nil
        rows.append(InfoRowData(
            icon: "person.2.fill",
            label: "Players",
            value: game.playerCountDisplay,
            detail: bestStr,
            detailColor: Theme.Colors.success
        ))

        // Playtime
        rows.append(InfoRowData(
            icon: "clock.fill",
            label: "Time",
            value: game.playtimeDisplay
        ))

        // Weight
        rows.append(InfoRowData(
            icon: "scalemass.fill",
            label: "Weight",
            value: String(format: "%.2f / 5", game.complexity),
            detail: game.complexityLabel,
            detailColor: Theme.Colors.complexity(game.complexity)
        ))

        if let rating = game.bggRating {
            rows.append(InfoRowData(
                icon: "star.fill",
                label: "Rating",
                value: String(format: "%.1f / 10", rating),
                detailColor: Theme.Colors.primary
            ))
        }

        // Age
        if let age = game.minAge {
            rows.append(InfoRowData(
                icon: "number.circle",
                label: "Age",
                value: "Ages \(age)+"
            ))
        }

        return rows
    }
}

private struct ManualGameEditorSection: View {
    @Binding var game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Game Details")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)

            VStack(spacing: Theme.Spacing.md) {
                numericRow(
                    title: "Published",
                    value: optionalIntBinding(\.yearPublished),
                    placeholder: "Year"
                )

                stepperRow(
                    title: "Minimum Players",
                    value: game.minPlayers,
                    decrement: {
                        guard game.minPlayers > 1 else { return }
                        game.minPlayers -= 1
                        game.maxPlayers = max(game.maxPlayers, game.minPlayers)
                    },
                    increment: {
                        guard game.minPlayers < 20 else { return }
                        game.minPlayers += 1
                        game.maxPlayers = max(game.maxPlayers, game.minPlayers)
                    }
                )

                stepperRow(
                    title: "Maximum Players",
                    value: game.maxPlayers,
                    decrement: {
                        guard game.maxPlayers > game.minPlayers else { return }
                        game.maxPlayers -= 1
                    },
                    increment: {
                        guard game.maxPlayers < 20 else { return }
                        game.maxPlayers += 1
                    }
                )

                stepperRow(
                    title: "Minimum Time",
                    value: game.minPlaytime,
                    suffix: "min",
                    decrement: {
                        guard game.minPlaytime > 5 else { return }
                        game.minPlaytime -= 5
                        game.maxPlaytime = max(game.maxPlaytime, game.minPlaytime)
                    },
                    increment: {
                        guard game.minPlaytime < 600 else { return }
                        game.minPlaytime += 5
                        game.maxPlaytime = max(game.maxPlaytime, game.minPlaytime)
                    }
                )

                stepperRow(
                    title: "Maximum Time",
                    value: game.maxPlaytime,
                    suffix: "min",
                    decrement: {
                        guard game.maxPlaytime > game.minPlaytime else { return }
                        game.maxPlaytime -= 5
                    },
                    increment: {
                        guard game.maxPlaytime < 600 else { return }
                        game.maxPlaytime += 5
                    }
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("Complexity")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text(String(format: "%.1f / 5", game.complexity))
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(Theme.Colors.complexity(game.complexity))
                    }

                    Slider(
                        value: Binding(
                            get: { game.complexity },
                            set: { game.complexity = min(max($0, 0), 5) }
                        ),
                        in: 0...5,
                        step: 0.1
                    )
                    .tint(Theme.Colors.complexity(game.complexity))

                    Text(game.complexityLabel)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("Rating")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text(String(format: "%.1f", game.bggRating ?? 0))
                            .font(Theme.Typography.calloutMedium)
                            .foregroundColor(Theme.Colors.accent)
                    }
                    Slider(
                        value: Binding(
                            get: { game.bggRating ?? 0 },
                            set: { game.bggRating = min(max($0, 0), 10) }
                        ),
                        in: 0...10,
                        step: 0.1
                    )
                    .tint(Theme.Colors.accent)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Recommended Players")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    TextField(
                        "Example: 3, 4",
                        text: Binding(
                            get: { playerString(from: game.recommendedPlayers) },
                            set: {
                                game.recommendedPlayers = parsePlayerString($0)
                            }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(1...2)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("Recommended Age")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        if let age = game.minAge {
                            Text("\(age)+")
                                .font(Theme.Typography.calloutMedium)
                                .foregroundColor(Theme.Colors.textSecondary)
                        } else {
                            Text("Not set")
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }

                    HStack(spacing: Theme.Spacing.sm) {
                        Button(game.minAge == nil ? "Add Age" : "Clear") {
                            if game.minAge == nil {
                                game.minAge = 8
                            } else {
                                game.minAge = nil
                            }
                        }
                        .buttonStyle(.plain)
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.primary)

                        if game.minAge != nil {
                            Spacer()

                            Button("-") {
                                if let age = game.minAge, age > 1 {
                                    game.minAge = age - 1
                                }
                            }
                            .buttonStyle(.plain)
                            .font(Theme.Typography.calloutMedium)

                            Button("+") {
                                if let age = game.minAge {
                                    game.minAge = min(age + 1, 21)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(Theme.Typography.calloutMedium)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.backgroundElevated)
            )
        }
    }

    private func numericRow(title: String, value: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
            TextField(placeholder, text: value)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 84)
        }
    }

    private func optionalIntBinding(_ keyPath: WritableKeyPath<Game, Int?>) -> Binding<String> {
        Binding(
            get: {
                if let value = game[keyPath: keyPath] {
                    return String(value)
                }
                return ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                game[keyPath: keyPath] = Int(trimmed)
            }
        )
    }

    private func stepperRow(
        title: String,
        value: Int,
        suffix: String = "",
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
            Button(action: decrement) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            Text(suffix.isEmpty ? "\(value)" : "\(value) \(suffix)")
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(minWidth: 70)
            Button(action: increment) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Theme.Colors.primary)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ManualTagEditorSection: View {
    @Binding var game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Categories & Mechanics")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)

            VStack(spacing: Theme.Spacing.md) {
                tagField(
                    title: "Categories",
                    placeholder: "Strategy, Party, Co-op",
                    binding: commaSeparatedBinding(\.categories)
                )
                tagField(
                    title: "Mechanics",
                    placeholder: "Deck Building, Drafting",
                    binding: commaSeparatedBinding(\.mechanics)
                )
                tagField(
                    title: "Designers",
                    placeholder: "Designer names",
                    binding: commaSeparatedBinding(\.designers)
                )
                tagField(
                    title: "Publishers",
                    placeholder: "Publisher names",
                    binding: commaSeparatedBinding(\.publishers)
                )
            }
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.backgroundElevated)
            )
        }
    }

    private func tagField(title: String, placeholder: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.bodyMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            TextField(placeholder, text: binding, axis: .vertical)
                .lineLimit(2...4)
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    private func commaSeparatedBinding(_ keyPath: WritableKeyPath<Game, [String]>) -> Binding<String> {
        Binding(
            get: { game[keyPath: keyPath].joined(separator: ", ") },
            set: { newValue in
                game[keyPath: keyPath] = newValue
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}

private struct ManualDescriptionEditorSection: View {
    @Binding var game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Description")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)

            TextField(
                "Add a description, notes, or house rules",
                text: Binding(
                    get: { game.description ?? "" },
                    set: { game.description = $0.isEmpty ? nil : $0 }
                ),
                axis: .vertical
            )
            .lineLimit(5...10)
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.backgroundElevated)
            )
            .font(Theme.Typography.body)
            .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

private func parsePlayerString(_ input: String) -> [Int]? {
    let cleaned = input
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .compactMap { Int($0) }
    return cleaned.isEmpty ? nil : cleaned
}

private func playerString(from players: [Int]?) -> String {
    players?.map(String.init).joined(separator: ", ") ?? ""
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
