import SwiftUI

struct GameLibraryView: View {
    @StateObject private var viewModel = GameLibraryViewModel()
    @State private var showAddGame = false
    @State private var showImportBGG = false
    @State private var showCreateCategory = false
    @State private var showLogPlay = false

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
                                    showLogPlay = true
                                } label: {
                                    Label("Log a Play", systemImage: "dice.fill")
                                }

                                Divider()

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
                            .onChange(of: viewModel.searchQuery) { _, _ in
                                viewModel.searchCachedGames()
                            }
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
                    } else if !viewModel.searchQuery.isEmpty {
                        // Dual-section search: My Library + BGG cache
                        LibrarySearchResultsView(viewModel: viewModel)
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
                                    NavigationLink(value: game) {
                                        GameCard(game: game)
                                    }
                                    .buttonStyle(.plain)
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
            .sheet(isPresented: $showLogPlay) {
                PlayLoggingSheet()
            }
            .sheet(isPresented: $showCreateCategory) {
                CreateCategorySheet { name, icon in
                    Task { await viewModel.createCategory(name: name, icon: icon) }
                }
            }
            .navigationDestination(for: Game.self) { game in
                GameDetailView(game: game)
            }
            .navigationDestination(for: CreatorDestination.self) { dest in
                if dest.role == .designer {
                    DesignerDetailView(name: dest.name)
                } else {
                    PublisherDetailView(name: dest.name)
                }
            }
            .navigationDestination(for: GameFamilyDestination.self) { destination in
                GameFamilyDetailView(destination: destination)
            }
            .toast($viewModel.toast)
        }
        .task {
            await viewModel.loadLibrary()
        }
    }
}

// MARK: - Dual-section Search Results

struct LibrarySearchResultsView: View {
    @ObservedObject var viewModel: GameLibraryViewModel

    private var libraryGameIds: Set<UUID> {
        Set(viewModel.libraryEntries.compactMap { $0.gameId })
    }

    /// Cached games that are NOT already in the user's library.
    private var newCachedGames: [Game] {
        viewModel.cachedGameResults.filter { game in !libraryGameIds.contains(game.id) }
    }

    var body: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {

            // ── My Library ──────────────────────────────────────
            Section {
                if viewModel.filteredEntries.isEmpty {
                    HStack {
                        Text("No matches in your library")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.sm)
                } else {
                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(viewModel.filteredEntries) { entry in
                            if let game = entry.game {
                                NavigationLink(value: game) {
                                    GameCard(game: game)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.removeFromLibrary(entryId: entry.id) }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }
            } header: {
                HStack {
                    Text("MY LIBRARY")
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.background)
            }

            // ── Thin divider ────────────────────────────────────
            Rectangle()
                .fill(Theme.Colors.divider)
                .frame(height: 0.5)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.md)

            // ── BGG Cache ────────────────────────────────────────
            Section {
                if viewModel.isSearchingCache {
                    ProgressView()
                        .tint(Theme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                } else if newCachedGames.isEmpty {
                    HStack {
                        Text("No other results in cache")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.sm)
                } else {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(newCachedGames) { game in
                            CachedGameRow(game: game) {
                                Task { await viewModel.addCachedGameToLibrary(game: game) }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }
            } header: {
                HStack {
                    Text("ALL GAMES")
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.background)
            }
        }
    }
}

// MARK: - Cached Game Row

struct CachedGameRow: View {
    let game: Game
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Thumbnail — tappable to game detail
            NavigationLink(value: game) {
                GameThumbnail(url: game.thumbnailUrl, size: 48)
            }
            .buttonStyle(.plain)

            // Name + year — tappable to game detail
            NavigationLink(value: game) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.name)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: Theme.Spacing.xs) {
                        if let year = game.yearPublished {
                            Text("(\(year))")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                        if let rank = game.bggRank {
                            Text("· BGG #\(rank)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Add to library button
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.Gradients.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(Theme.Colors.backgroundElevated)
        )
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
                            .fill(Theme.Colors.fieldBackground)
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
                            .fill(Theme.Colors.fieldBackground)
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
