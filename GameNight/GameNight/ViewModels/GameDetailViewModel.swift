import Foundation

protocol GameDetailDataProviding {
    func fetchGame(id: UUID) async throws -> Game?
    func upsertGame(_ game: Game) async throws -> Game
    func addGameToLibrary(gameId: UUID, categoryId: UUID?) async throws
    func removeGameFromLibrary(entryId: UUID) async throws
    func addToWishlist(gameId: UUID) async throws
    func removeFromWishlist(entryId: UUID) async throws
    func libraryEntryId(gameId: UUID) async throws -> UUID?
    func isOnWishlist(gameId: UUID) async throws -> UUID?
    func fetchExpansions(gameId: UUID) async throws -> [Game]
    func fetchBaseGame(expansionGameId: UUID) async throws -> Game?
    func fetchFamilyMembers(gameId: UUID) async throws -> [(family: GameFamily, games: [Game])]
    func upsertExpansionLinks(baseGameId: UUID, expansionGameIds: [UUID]) async throws
    func upsertFamilyLinks(gameId: UUID, families: [(bggFamilyId: Int, name: String)]) async throws
}

protocol GameDetailBGGProviding {
    func fetchGameDetailsWithRelations(bggId: Int) async throws -> BGGGameParseResult
}

extension SupabaseService: GameDetailDataProviding {}
extension BGGService: GameDetailBGGProviding {}

@MainActor
final class GameDetailViewModel: ObservableObject {
    @Published var game: Game
    @Published var expansions: [Game] = []
    @Published var baseGame: Game?
    @Published var families: [(family: GameFamily, games: [Game])] = []
    @Published var isLoading = true
    @Published var isInCollection = false
    @Published var isInWishlist = false
    @Published var isSavingCollection = false
    @Published var isSavingWishlist = false
    @Published var actionError: String?
    @Published var toast: ToastItem?

    private var libraryEntryId: UUID?
    private var wishlistEntryId: UUID?

    private let supabase: GameDetailDataProviding
    private let bgg: GameDetailBGGProviding

    init(
        game: Game,
        supabase: GameDetailDataProviding? = nil,
        bgg: GameDetailBGGProviding = BGGService.shared
    ) {
        self.game = game
        self.supabase = supabase ?? SupabaseService.shared
        self.bgg = bgg
    }

    func loadRelatedData() async {
        isLoading = true
        actionError = nil

        // Search RPC returns a lightweight payload for speed; refresh to full row
        // so detail fields (description/designers/publishers/etc.) render immediately.
        if let fullGame = try? await supabase.fetchGame(id: game.id) {
            game = fullGame
        }

        await refreshLibraryState()

        async let expansionsResult = supabase.fetchExpansions(gameId: game.id)
        async let baseGameResult = supabase.fetchBaseGame(expansionGameId: game.id)
        async let familiesResult = supabase.fetchFamilyMembers(gameId: game.id)

        do {
            expansions = try await expansionsResult
            baseGame = try await baseGameResult
            families = try await familiesResult
        } catch {
            // Non-critical — detail page still shows game info
        }
        isLoading = false

        // Hydrate sparse BGG games in the background so detail rendering is not blocked
        // on a network round-trip to the edge function.
        do {
            try await hydrateFromBGGIfNeeded()
        } catch {
            return
        }

        async let refreshedExpansions = supabase.fetchExpansions(gameId: game.id)
        async let refreshedBase = supabase.fetchBaseGame(expansionGameId: game.id)
        async let refreshedFamilies = supabase.fetchFamilyMembers(gameId: game.id)

        do {
            expansions = try await refreshedExpansions
            baseGame = try await refreshedBase
            families = try await refreshedFamilies
        } catch {
            // Non-critical — keep initial relation fetch.
        }
    }

    func toggleCollection() async {
        guard game.bggId != nil, !isSavingCollection else { return }
        isSavingCollection = true
        actionError = nil
        defer { isSavingCollection = false }

        do {
            if isInCollection {
                let entryId = try await resolvedLibraryEntryId()
                guard let entryId else {
                    isInCollection = false
                    libraryEntryId = nil
                    return
                }
                try await supabase.removeGameFromLibrary(entryId: entryId)
                isInCollection = false
                libraryEntryId = nil
                toast = ToastItem(style: .info, message: "Removed \(game.name) from collection")
            } else {
                try await supabase.addGameToLibrary(gameId: game.id, categoryId: nil)
                libraryEntryId = try await supabase.libraryEntryId(gameId: game.id)
                isInCollection = true
                if let wishlistId = try await resolvedWishlistEntryId() {
                    try await supabase.removeFromWishlist(entryId: wishlistId)
                }
                isInWishlist = false
                wishlistEntryId = nil
                toast = ToastItem(style: .success, message: "\(game.name) is in your collection")
            }
        } catch {
            await refreshLibraryState()
            if isInCollection {
                actionError = nil
            } else {
                actionError = error.localizedDescription
                toast = ToastItem(style: .error, message: error.localizedDescription)
            }
        }
    }

    func toggleWishlist() async {
        guard game.bggId != nil, !isSavingWishlist, !isInCollection else { return }
        isSavingWishlist = true
        actionError = nil
        defer { isSavingWishlist = false }

        do {
            if isInWishlist {
                let entryId = try await resolvedWishlistEntryId()
                guard let entryId else {
                    isInWishlist = false
                    wishlistEntryId = nil
                    return
                }
                try await supabase.removeFromWishlist(entryId: entryId)
                isInWishlist = false
                wishlistEntryId = nil
                toast = ToastItem(style: .info, message: "Removed \(game.name) from wishlist")
            } else {
                try await supabase.addToWishlist(gameId: game.id)
                wishlistEntryId = try await supabase.isOnWishlist(gameId: game.id)
                isInWishlist = true
                toast = ToastItem(style: .success, message: "\(game.name) is in your wishlist")
            }
        } catch {
            await refreshLibraryState()
            if isInWishlist {
                actionError = nil
            } else {
                actionError = error.localizedDescription
                toast = ToastItem(style: .error, message: error.localizedDescription)
            }
        }
    }

    private func refreshLibraryState() async {
        guard game.bggId != nil else {
            isInCollection = false
            isInWishlist = false
            libraryEntryId = nil
            wishlistEntryId = nil
            return
        }

        do {
            async let libraryId = supabase.libraryEntryId(gameId: game.id)
            async let wishlistId = supabase.isOnWishlist(gameId: game.id)
            let (resolvedLibraryId, resolvedWishlistId) = try await (libraryId, wishlistId)

            libraryEntryId = resolvedLibraryId
            wishlistEntryId = resolvedWishlistId
            isInCollection = resolvedLibraryId != nil
            isInWishlist = resolvedLibraryId == nil && resolvedWishlistId != nil
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func resolvedLibraryEntryId() async throws -> UUID? {
        if let libraryEntryId {
            return libraryEntryId
        }
        let fetched = try await supabase.libraryEntryId(gameId: game.id)
        libraryEntryId = fetched
        return fetched
    }

    private func resolvedWishlistEntryId() async throws -> UUID? {
        if let wishlistEntryId {
            return wishlistEntryId
        }
        let fetched = try await supabase.isOnWishlist(gameId: game.id)
        wishlistEntryId = fetched
        return fetched
    }

    private func hydrateFromBGGIfNeeded() async throws {
        guard let bggId = game.bggId else { return }

        // Skip hydration if the game is already fully populated.
        // Key signal: description + at least one mechanic/category means BGG data is present.
        let isHydrated = game.description != nil
            && !game.mechanics.isEmpty
            && !game.categories.isEmpty
        if isHydrated { return }

        let parseResult = try await bgg.fetchGameDetailsWithRelations(bggId: bggId)
        let savedGame = try await supabase.upsertGame(
            Game(
                id: game.id,
                bggId: parseResult.game.bggId,
                name: parseResult.game.name,
                yearPublished: parseResult.game.yearPublished,
                thumbnailUrl: parseResult.game.thumbnailUrl,
                imageUrl: parseResult.game.imageUrl,
                minPlayers: parseResult.game.minPlayers,
                maxPlayers: parseResult.game.maxPlayers,
                recommendedPlayers: parseResult.game.recommendedPlayers,
                minPlaytime: parseResult.game.minPlaytime,
                maxPlaytime: parseResult.game.maxPlaytime,
                complexity: parseResult.game.complexity,
                bggRating: parseResult.game.bggRating,
                description: parseResult.game.description,
                categories: parseResult.game.categories,
                mechanics: parseResult.game.mechanics,
                designers: parseResult.game.designers,
                publishers: parseResult.game.publishers,
                artists: parseResult.game.artists,
                minAge: parseResult.game.minAge,
                bggRank: parseResult.game.bggRank
            )
        )
        game = savedGame

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
    }
}
