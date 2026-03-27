import SwiftUI
import Combine

@MainActor
final class GameLibraryViewModel: ObservableObject {
    @Published var libraryEntries: [GameLibraryEntry] = []
    @Published var categories: [GameCategory] = []
    @Published var selectedCategory: GameCategory?
    @Published var searchQuery = ""
    @Published var isLoading = true
    @Published var error: String?
    @Published var toast: ToastItem?

    // BGG Search (AddGameSheet)
    @Published var bggSearchQuery = ""
    @Published var bggSearchResults: [BGGSearchResult] = []
    @Published var isSearchingBGG = false
    @Published var hotGames: [BGGSearchResult] = []

    // Cached game search (inline in library tab)
    @Published var cachedGameResults: [Game] = []
    @Published var isSearchingCache = false

    // Add game state
    @Published var selectedGameDetail: Game?
    @Published var isLoadingDetail = false
    @Published var showAddSheet = false

    private let supabase = SupabaseService.shared
    private let bgg = BGGService.shared
    private var searchTask: Task<Void, Never>?
    private var cacheSearchTask: Task<Void, Never>?
    private var selectedGameParseResult: BGGGameParseResult?

    var filteredEntries: [GameLibraryEntry] {
        var entries = libraryEntries

        if let category = selectedCategory {
            entries = entries.filter { $0.categoryId == category.id }
        }

        if !searchQuery.isEmpty {
            entries = entries.filter { entry in
                entry.game?.name.localizedCaseInsensitiveContains(searchQuery) ?? false
            }
        }

        return entries
    }

    func loadLibrary() async {
        isLoading = true
        do {
            async let entriesResult = supabase.fetchGameLibrary()
            async let catsResult = supabase.fetchCategories()

            self.libraryEntries = try await entriesResult
            self.categories = try await catsResult
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func searchBGG() {
        searchTask?.cancel()
        searchTask = Task {
            guard !bggSearchQuery.isEmpty else {
                bggSearchResults = []
                return
            }

            // Debounce
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            isSearchingBGG = true
            do {
                bggSearchResults = try await bgg.searchGames(query: bggSearchQuery)
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
            }
            isSearchingBGG = false
        }
    }

    /// Search the cached games table — triggered from the inline library search bar.
    func searchCachedGames() {
        cacheSearchTask?.cancel()
        cacheSearchTask = Task {
            guard !searchQuery.isEmpty else {
                cachedGameResults = []
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            isSearchingCache = true
            do {
                cachedGameResults = try await supabase.searchCachedGames(query: searchQuery)
            } catch {
                if !Task.isCancelled { cachedGameResults = [] }
            }
            isSearchingCache = false
        }
    }

    /// Add a cached Game (from the search results) to the user's library.
    func addCachedGameToLibrary(game: Game) async {
        do {
            let saved = try await supabase.upsertGame(game)
            try await supabase.addGameToLibrary(gameId: saved.id, categoryId: nil)
            await loadLibrary()
            toast = ToastItem(style: .success, message: "Added \(game.name) to library")
        } catch {
            toast = ToastItem(style: .error, message: error.localizedDescription)
        }
    }

    func loadHotGames() async {
        do {
            hotGames = try await bgg.fetchHotGames()
        } catch {
            // Non-critical, ignore
        }
    }

    func loadGameDetail(bggId: Int) async {
        isLoadingDetail = true
        do {
            let parseResult = try await bgg.fetchGameDetailsWithRelations(bggId: bggId)
            selectedGameParseResult = parseResult
            selectedGameDetail = parseResult.game
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingDetail = false
    }

    func addGameToLibrary(game: Game, categoryId: UUID?) async {
        do {
            let saved: Game
            if let parseResult = selectedGameParseResult, parseResult.game.bggId == game.bggId {
                saved = try await persistBGGGame(parseResult)
            } else {
                saved = try await supabase.upsertGame(game)
            }
            try await supabase.addGameToLibrary(gameId: saved.id, categoryId: categoryId)
            selectedGameParseResult = nil
            selectedGameDetail = nil
            await loadLibrary()
            toast = ToastItem(style: .success, message: "Added \(game.name) to library")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeFromLibrary(entryId: UUID) async {
        do {
            try await supabase.removeGameFromLibrary(entryId: entryId)
            libraryEntries.removeAll { $0.id == entryId }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createCategory(name: String, icon: String?) async {
        let session = try? await supabase.client.auth.session
        guard let userId = session?.user.id else { return }

        let category = GameCategory(
            id: UUID(),
            userId: userId,
            name: name,
            icon: icon,
            sortOrder: categories.count,
            isDefault: false
        )

        do {
            try await supabase.createCategory(category)
            categories.append(category)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func importBGGCollection(username: String) async {
        isLoading = true
        do {
            let collection = try await bgg.fetchUserCollection(username: username)
            let bggIds = collection.map(\.id)
            let parseResults = try await bgg.fetchMultipleGameDetailsWithRelations(bggIds: bggIds)

            for parseResult in parseResults {
                let saved = try await persistBGGGame(parseResult)
                try await supabase.addGameToLibrary(gameId: saved.id, categoryId: nil)
            }

            await loadLibrary()
            toast = ToastItem(style: .success, message: "Imported \(parseResults.count) game\(parseResults.count == 1 ? "" : "s")!")
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func persistBGGGame(_ parseResult: BGGGameParseResult) async throws -> Game {
        let savedGame = try await supabase.upsertGame(parseResult.game)

        var outboundExpansionIds: [UUID] = []
        var inboundBaseIds: [UUID] = []

        for link in parseResult.expansionLinks {
            let linkedGame = try await supabase.upsertGame(
                Game(
                    id: UUID(),
                    bggId: link.bggId,
                    name: link.name
                )
            )

            if link.isInbound {
                inboundBaseIds.append(linkedGame.id)
            } else {
                outboundExpansionIds.append(linkedGame.id)
            }
        }

        if !outboundExpansionIds.isEmpty {
            try await supabase.upsertExpansionLinks(baseGameId: savedGame.id, expansionGameIds: outboundExpansionIds)
        }

        for baseGameId in inboundBaseIds {
            try await supabase.upsertExpansionLinks(baseGameId: baseGameId, expansionGameIds: [savedGame.id])
        }

        if !parseResult.familyLinks.isEmpty {
            try await supabase.upsertFamilyLinks(gameId: savedGame.id, families: parseResult.familyLinks)
        }

        return savedGame
    }
}
