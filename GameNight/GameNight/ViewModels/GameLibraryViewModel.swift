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

    // BGG Search
    @Published var bggSearchQuery = ""
    @Published var bggSearchResults: [BGGSearchResult] = []
    @Published var isSearchingBGG = false
    @Published var hotGames: [BGGSearchResult] = []

    // Add game state
    @Published var selectedGameDetail: Game?
    @Published var isLoadingDetail = false
    @Published var showAddSheet = false

    private let supabase = SupabaseService.shared
    private let bgg = BGGService.shared
    private var searchTask: Task<Void, Never>?

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
            selectedGameDetail = try await bgg.fetchGameDetails(bggId: bggId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingDetail = false
    }

    func addGameToLibrary(game: Game, categoryId: UUID?) async {
        do {
            let saved = try await supabase.upsertGame(game)
            try await supabase.addGameToLibrary(gameId: saved.id, categoryId: categoryId)
            await loadLibrary()
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
            // Fetch details for all games
            let bggIds = collection.map(\.id)
            let games = try await bgg.fetchMultipleGameDetails(bggIds: bggIds)

            for game in games {
                let saved = try await supabase.upsertGame(game)
                try await supabase.addGameToLibrary(gameId: saved.id, categoryId: nil)
            }

            await loadLibrary()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
