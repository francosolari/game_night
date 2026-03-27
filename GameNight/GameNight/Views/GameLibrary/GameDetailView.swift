import SwiftUI

struct GameDetailView: View {
    @StateObject private var viewModel: GameDetailViewModel
    @EnvironmentObject private var appState: AppState
    @State private var isDescriptionExpanded = false
    @State private var isEditingManualGame = false
    @State private var manualDraftGame: Game?
    @State private var isSavingManualGame = false
    @State private var showImageCropPicker = false
    @State private var isUploadingImage = false
    @State private var imageUploadError: String?
    @State private var expandedCreatorRoles: Set<CreatorRole> = []

    private var isManualGame: Bool {
        displayedGame.isManual
    }

    private var canEditManualGame: Bool {
        displayedGame.isEditable(by: appState.currentUser?.id)
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

    private static let filteredFamilyPrefixes = [
        "Mechanism:",
        "Category:",
        "Theme:",
        "Continents:",
        "Players:",
        "Digital Implementations:",
        "Components:",
        "Setting:",
        "Crowdfunding:",
        "Admin:"
    ]

    private var relevantFamilies: [(family: GameFamily, games: [Game])] {
        viewModel.families.filter { familyData in
            !Self.filteredFamilyPrefixes.contains { prefix in
                familyData.family.name.lowercased().hasPrefix(prefix.lowercased())
            }
        }
    }

    private var visibleFamilies: [(family: GameFamily, games: [Game])] {
        Array(relevantFamilies.prefix(3))
    }

    private var hiddenFamilyCount: Int {
        max(relevantFamilies.count - visibleFamilies.count, 0)
    }

    init(game: Game) {
        _viewModel = StateObject(wrappedValue: GameDetailViewModel(game: game))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ZStack(alignment: .bottomLeading) {
                    DetailHeroImage(
                        imageUrl: displayedGame.imageUrl,
                        badge: nil,
                        fallbackInitials: gameInitials,
                        gradientColors: isManualGame
                            ? [Theme.Colors.primary.opacity(0.65), Theme.Colors.accent.opacity(0.45)]
                            : [Theme.Colors.accent.opacity(0.5), Theme.Colors.primary.opacity(0.5)]
                    )
                    if let rating = displayedGame.bggRating {
                        RatingBadge(rating: rating, size: .large)
                            .offset(x: Theme.Spacing.xl * 0.5, y: Theme.Spacing.sm * 0.5)
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    }

                    if isEditingManualGame {
                        // Full-frame tap area for upload/change
                        Button {
                            showImageCropPicker = true
                        } label: {
                            ZStack {
                                Color.black.opacity(0.35)
                                VStack(spacing: 6) {
                                    if isUploadingImage {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: displayedGame.imageUrl == nil ? "photo.badge.plus" : "camera.fill")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(displayedGame.imageUrl == nil ? "Add Photo" : "Change Photo")
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            }
                        }
                        .disabled(isUploadingImage)
                        .buttonStyle(.plain)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))

                        if let err = imageUploadError {
                            Text(err)
                                .font(Theme.Typography.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                                .padding(Theme.Spacing.sm)
                        }
                    }
                }
                // Remove photo button — top-trailing when editing and image exists
                .overlay(alignment: .topTrailing) {
                    if isEditingManualGame, displayedGame.imageUrl != nil, !isUploadingImage {
                        Button {
                            Task { await removeGameImage() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                        }
                        .buttonStyle(.plain)
                        .padding(Theme.Spacing.sm)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, -Theme.Spacing.xl)
                .fullScreenCover(isPresented: $showImageCropPicker) {
                    ImageCropPicker(isPresented: $showImageCropPicker) { image in
                        Task { await uploadGameImage(image) }
                    }
                    .ignoresSafeArea()
                }

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
                        DescriptionSection(
                            text: desc.strippingHTML(),
                            isExpanded: $isDescriptionExpanded
                        )
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
                        ForEach(visibleFamilies, id: \.family.id) { familyData in
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

                        if hiddenFamilyCount > 0 {
                            Text("+ \(hiddenFamilyCount) more series")
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.textTertiary)
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
            .padding(.bottom, 160)
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
                } else if canEditManualGame {
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
                    creatorRow(links: designerLinks, maxVisible: 2, role: .designer)
                }
                if !publisherLinks.isEmpty {
                    creatorRow(links: publisherLinks, maxVisible: 1, role: .publisher)
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
    private func creatorRow(
        links: [(name: String, destination: CreatorDestination)],
        maxVisible: Int,
        role: CreatorRole
    ) -> some View {
        ExpandableCreatorRow(
            links: links,
            maxVisible: maxVisible,
            isExpanded: Binding(
                get: { expandedCreatorRoles.contains(role) },
                set: { newValue in
                    if newValue {
                        expandedCreatorRoles.insert(role)
                    } else {
                        expandedCreatorRoles.remove(role)
                    }
                }
            )
        )
    }

    private var manualDraftBinding: Binding<Game>? {
        guard isEditingManualGame, manualDraftGame != nil else { return nil }
        return Binding(
            get: { manualDraftGame ?? viewModel.game },
            set: { manualDraftGame = $0 }
        )
    }

    private func startManualEditing() {
        guard canEditManualGame else { return }
        manualDraftGame = viewModel.game
        isEditingManualGame = true
    }

    private func cancelManualEditing() {
        manualDraftGame = nil
        isEditingManualGame = false
        isSavingManualGame = false
        imageUploadError = nil
    }

    private func uploadGameImage(_ image: UIImage) async {
        isUploadingImage = true
        imageUploadError = nil
        defer { isUploadingImage = false }

        do {
            guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
                imageUploadError = "Could not process image"
                return
            }

            let gameId = viewModel.game.id
            let publicUrl = try await R2StorageService.shared.uploadGameImage(data: jpeg, gameId: gameId)
            try await SupabaseService.shared.updateGameImageUrl(gameId: gameId, imageUrl: publicUrl)

            manualDraftGame?.imageUrl = publicUrl
            viewModel.game.imageUrl = publicUrl
        } catch {
            imageUploadError = "Upload failed: \(error.localizedDescription)"
        }
    }

    private func removeGameImage() async {
        do {
            try await SupabaseService.shared.clearGameImageUrl(gameId: viewModel.game.id)
            manualDraftGame?.imageUrl = nil
            viewModel.game.imageUrl = nil
        } catch {
            imageUploadError = "Could not remove photo"
        }
    }

    private func saveManualGameEdits() async {
        guard var updatedGame = manualDraftGame else { return }

        updatedGame.name = updatedGame.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updatedGame.name.isEmpty else { return }

        isSavingManualGame = true

        do {
            try await SupabaseService.shared.updateGame(updatedGame)
            viewModel.game = updatedGame
        } catch {
            isSavingManualGame = false
            return
        }

        manualDraftGame = nil
        isEditingManualGame = false
        isSavingManualGame = false
    }

    private func buildInfoRows(for game: Game) -> [InfoRowData] {
        var rows: [InfoRowData] = []

        // Players
        let bestStr = Game.formatPlayerRanges(game.recommendedPlayers)
            .map { "Best: \($0)" }
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
                        clampRecommendedPlayers()
                    },
                    increment: {
                        guard game.minPlayers < 20 else { return }
                        game.minPlayers += 1
                        game.maxPlayers = max(game.maxPlayers, game.minPlayers)
                        clampRecommendedPlayers()
                    }
                )

                stepperRow(
                    title: "Maximum Players",
                    value: game.maxPlayers,
                    decrement: {
                        guard game.maxPlayers > game.minPlayers else { return }
                        game.maxPlayers -= 1
                        clampRecommendedPlayers()
                    },
                    increment: {
                        guard game.maxPlayers < 20 else { return }
                        game.maxPlayers += 1
                        clampRecommendedPlayers()
                    }
                )

                stepperRow(
                    title: "Minimum Time",
                    value: game.minPlaytime,
                    suffix: "min",
                    decrement: {
                        guard game.minPlaytime > 30 else { return }
                        game.minPlaytime -= 30
                        game.maxPlaytime = max(game.maxPlaytime, game.minPlaytime)
                    },
                    increment: {
                        guard game.minPlaytime < 600 else { return }
                        game.minPlaytime += 30
                        game.maxPlaytime = max(game.maxPlaytime, game.minPlaytime)
                    }
                )

                stepperRow(
                    title: "Maximum Time",
                    value: game.maxPlaytime,
                    suffix: "min",
                    decrement: {
                        guard game.maxPlaytime > game.minPlaytime else { return }
                        game.maxPlaytime -= 30
                    },
                    increment: {
                        guard game.maxPlaytime < 600 else { return }
                        game.maxPlaytime += 30
                    }
                )

                ComplexitySliderPicker(complexity: $game.complexity)

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

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 52), spacing: Theme.Spacing.sm)],
                        spacing: Theme.Spacing.sm
                    ) {
                        ForEach(game.minPlayers...game.maxPlayers, id: \.self) { count in
                            let isSelected = recommendedPlayersSelection.contains(count)
                            Button {
                                toggleRecommendedPlayer(count)
                            } label: {
                                Text("\(count)")
                                    .font(Theme.Typography.calloutMedium)
                                    .padding(.vertical, Theme.Spacing.xs)
                                    .padding(.horizontal, Theme.Spacing.sm)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Theme.Colors.primary : Theme.Colors.backgroundElevated)
                                    )
                                    .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Tap to mark the best player counts.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
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

    private var recommendedPlayersRange: ClosedRange<Int> {
        game.minPlayers...game.maxPlayers
    }

    private var recommendedPlayersSelection: Set<Int> {
        let base = game.recommendedPlayers ?? Array(recommendedPlayersRange)
        return Set(base.filter { recommendedPlayersRange.contains($0) })
    }

    private func toggleRecommendedPlayer(_ count: Int) {
        var selection = recommendedPlayersSelection
        if selection.contains(count) {
            selection.remove(count)
        } else {
            selection.insert(count)
        }
        updateRecommendedPlayers(with: selection)
    }

    private func updateRecommendedPlayers(with selection: Set<Int>) {
        if selection.isEmpty {
            game.recommendedPlayers = nil
        } else {
            game.recommendedPlayers = Array(selection).sorted()
        }
    }

    private func clampRecommendedPlayers() {
        guard let recs = game.recommendedPlayers else { return }
        let filtered = recs.filter { recommendedPlayersRange.contains($0) }
        game.recommendedPlayers = filtered.isEmpty ? nil : filtered.sorted()
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

// MARK: - Description Section (isolated view for reliable tap handling)

private struct DescriptionSection: View {
    let text: String
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(isExpanded ? nil : 3)
                .animation(.easeInOut(duration: 0.25), value: isExpanded)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                Text(isExpanded ? "Show less" : "Read more")
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.primary)
                    .padding(.vertical, Theme.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Expandable Creator Row (isolated view for reliable tap handling)

private struct ExpandableCreatorRow: View {
    let links: [(name: String, destination: CreatorDestination)]
    let maxVisible: Int
    @Binding var isExpanded: Bool

    private var displayLinks: [(name: String, destination: CreatorDestination)] {
        isExpanded ? links : Array(links.prefix(maxVisible))
    }

    private var hiddenCount: Int {
        isExpanded ? 0 : max(links.count - maxVisible, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Array(displayLinks.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Text("\u{00B7}")
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    NavigationLink(value: item.destination) {
                        Text(item.name)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }

                if hiddenCount > 0 {
                    Text("\u{00B7}")
                        .foregroundColor(Theme.Colors.textTertiary)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = true
                        }
                    } label: {
                        Text("+ \(hiddenCount) more")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.vertical, Theme.Spacing.xs)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if isExpanded && links.count > maxVisible {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = false
                    }
                } label: {
                    Text("Show less")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private extension String {
    func strippingHTML() -> String {
        let wrapped = "<div>\(self)</div>"
        if let data = wrapped.data(using: .utf8),
           let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
           ) {
            return attributed.string
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return self
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
