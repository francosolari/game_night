import SwiftUI

struct GameLibraryView: View {
    @StateObject private var viewModel = GameLibraryViewModel()
    @State private var showAddGame = false
    @State private var showImportBGG = false
    @State private var showCreateCategory = false
    @State private var selectedGame: Game?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Header with search
                    VStack(spacing: Theme.Spacing.md) {
                        HStack {
                            Text("My Games")
                                .font(Theme.Typography.displayLarge)
                                .foregroundColor(Theme.Colors.textPrimary)

                            Spacer()

                            Menu {
                                Button {
                                    showAddGame = true
                                } label: {
                                    Label("Search BGG", systemImage: "magnifyingglass")
                                }

                                Button {
                                    showImportBGG = true
                                } label: {
                                    Label("Import BGG Collection", systemImage: "square.and.arrow.down")
                                }

                                Button {
                                    showCreateCategory = true
                                } label: {
                                    Label("New Category", systemImage: "folder.badge.plus")
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Theme.Gradients.primary)
                            }
                        }

                        SearchBar(text: $viewModel.searchQuery, placeholder: "Search your library...")
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.lg)

                    // Category filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Button {
                                viewModel.selectedCategory = nil
                            } label: {
                                Text("All")
                                    .chipStyle(
                                        color: Theme.Colors.primary,
                                        isSelected: viewModel.selectedCategory == nil
                                    )
                            }

                            ForEach(viewModel.categories) { category in
                                Button {
                                    viewModel.selectedCategory = category
                                } label: {
                                    Text(category.name)
                                        .chipStyle(
                                            color: Theme.Colors.primary,
                                            isSelected: viewModel.selectedCategory?.id == category.id
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }

                    // Game list
                    if viewModel.isLoading {
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(0..<5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                    .fill(Theme.Colors.cardBackground)
                                    .frame(height: 100)
                                    .shimmer()
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    } else if viewModel.filteredEntries.isEmpty {
                        EmptyStateView(
                            icon: "dice.fill",
                            title: "No Games Yet",
                            message: "Add games from BoardGameGeek or import your collection.",
                            actionLabel: "Add a Game"
                        ) {
                            showAddGame = true
                        }
                        .frame(minHeight: 300)
                    } else {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(viewModel.filteredEntries) { entry in
                                if let game = entry.game {
                                    GameCard(game: game) {
                                        selectedGame = game
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.removeFromLibrary(entryId: entry.id)
                                            }
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .sheet(isPresented: $showAddGame) {
                AddGameSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showImportBGG) {
                ImportBGGSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showCreateCategory) {
                CreateCategorySheet { name, icon in
                    Task { await viewModel.createCategory(name: name, icon: icon) }
                }
            }
            .sheet(item: $selectedGame) { game in
                GameDetailSheet(game: game)
            }
        }
        .task {
            await viewModel.loadLibrary()
        }
    }
}

// MARK: - Add Game Sheet (BGG Search)
struct AddGameSheet: View {
    @ObservedObject var viewModel: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    SearchBar(text: $viewModel.bggSearchQuery, placeholder: "Search BoardGameGeek...")
                        .onChange(of: viewModel.bggSearchQuery) { _, _ in
                            viewModel.searchBGG()
                        }

                    if viewModel.isSearchingBGG {
                        ProgressView().tint(Theme.Colors.primary)
                    } else if !viewModel.bggSearchResults.isEmpty {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(viewModel.bggSearchResults.prefix(20)) { result in
                                BGGSearchResultRow(result: result) {
                                    Task {
                                        await viewModel.loadGameDetail(bggId: result.id)
                                        if let game = viewModel.selectedGameDetail {
                                            await viewModel.addGameToLibrary(game: game, categoryId: nil)
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    } else if viewModel.bggSearchQuery.isEmpty && !viewModel.hotGames.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Trending on BGG")
                                .font(Theme.Typography.headlineMedium)
                                .foregroundColor(Theme.Colors.textPrimary)

                            ForEach(viewModel.hotGames.prefix(10)) { result in
                                BGGSearchResultRow(result: result) {
                                    Task {
                                        await viewModel.loadGameDetail(bggId: result.id)
                                        if let game = viewModel.selectedGameDetail {
                                            await viewModel.addGameToLibrary(game: game, categoryId: nil)
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Add Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .task {
            await viewModel.loadHotGames()
        }
    }
}

// MARK: - BGG Search Result Row
struct BGGSearchResultRow: View {
    let result: BGGSearchResult
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: Theme.Spacing.md) {
                GameThumbnail(url: result.thumbnailUrl, size: 48)

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

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.Gradients.primary)
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

// MARK: - Import BGG Sheet
struct ImportBGGSheet: View {
    @ObservedObject var viewModel: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var username = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xxl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Import from BoardGameGeek")
                        .font(Theme.Typography.displaySmall)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("Enter your BGG username to import your game collection.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                TextField("BGG Username", text: $username)
                    .font(Theme.Typography.body)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.backgroundElevated)
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button("Import Collection") {
                    Task {
                        await viewModel.importBGGCollection(username: username)
                        dismiss()
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: !username.isEmpty))
                .disabled(username.isEmpty)

                Spacer()
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Create Category Sheet
struct CreateCategorySheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var icon: String?

    let onCreate: (String, String?) -> Void

    private let iconOptions = [
        "star.fill", "heart.fill", "bolt.fill", "crown.fill",
        "flag.fill", "trophy.fill", "person.2.fill", "brain.head.profile",
        "puzzlepiece.fill", "theatermasks.fill", "map.fill", "clock.fill"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xxl) {
                TextField("Category Name", text: $name)
                    .font(Theme.Typography.body)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .fill(Theme.Colors.backgroundElevated)
                    )

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Icon (optional)")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textSecondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Theme.Spacing.md) {
                        ForEach(iconOptions, id: \.self) { iconName in
                            Button {
                                icon = iconName
                            } label: {
                                Image(systemName: iconName)
                                    .font(.system(size: 20))
                                    .foregroundColor(icon == iconName ? Theme.Colors.primary : Theme.Colors.textTertiary)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                            .fill(icon == iconName ? Theme.Colors.primary.opacity(0.15) : Theme.Colors.backgroundElevated)
                                    )
                            }
                        }
                    }
                }

                Button("Create Category") {
                    onCreate(name, icon)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: !name.isEmpty))
                .disabled(name.isEmpty)

                Spacer()
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Game Detail Sheet
struct GameDetailSheet: View {
    let game: Game
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Hero image
                    if let imageUrl = game.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                .fill(Theme.Colors.cardBackground)
                                .frame(height: 200)
                                .shimmer()
                        }
                    }

                    // Title and year
                    VStack(spacing: Theme.Spacing.sm) {
                        Text(game.name)
                            .font(Theme.Typography.displayMedium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        if let year = game.yearPublished {
                            Text("(\(String(year)))")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }

                    // Stats grid
                    HStack(spacing: Theme.Spacing.lg) {
                        StatBox(label: "Players", value: game.playerCountDisplay, icon: "person.2.fill")
                        StatBox(label: "Time", value: game.playtimeDisplay, icon: "clock.fill")
                        StatBox(label: "Weight", value: String(format: "%.1f", game.complexity), icon: "scalemass.fill")
                        if let rating = game.bggRating {
                            StatBox(label: "BGG", value: String(format: "%.1f", rating), icon: "star.fill")
                        }
                    }

                    // Complexity
                    ComplexityBadge(weight: game.complexity)

                    // Recommended players
                    if let recommended = game.recommendedPlayers, !recommended.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Best at")
                                .font(Theme.Typography.label)
                                .foregroundColor(Theme.Colors.textTertiary)
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(recommended, id: \.self) { count in
                                    Text("\(count)p")
                                        .chipStyle(color: Theme.Colors.success, isSelected: true)
                                }
                            }
                        }
                        .cardStyle()
                    }

                    // Categories & mechanics
                    if !game.categories.isEmpty {
                        TagSection(title: "Categories", tags: game.categories, color: Theme.Colors.primary)
                    }

                    if !game.mechanics.isEmpty {
                        TagSection(title: "Mechanics", tags: game.mechanics, color: Theme.Colors.accent)
                    }

                    // Description
                    if let desc = game.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Description")
                                .font(Theme.Typography.headlineMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text(desc)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .cardStyle()
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }
}

// Helper Views
struct StatBox: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.primary)
            Text(value)
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(label)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(Theme.Colors.backgroundElevated)
        )
    }
}

struct TagSection: View {
    let title: String
    let tags: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .chipStyle(color: color)
                }
            }
        }
        .cardStyle()
    }
}

// Simple flow layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }
            self.size.height = y + rowHeight
        }
    }
}
