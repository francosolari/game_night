import Foundation

protocol GameDetailDataProviding {
    func upsertGame(_ game: Game) async throws -> Game
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

    private let supabase: GameDetailDataProviding
    private let bgg: GameDetailBGGProviding

    init(
        game: Game,
        supabase: GameDetailDataProviding = SupabaseService.shared,
        bgg: GameDetailBGGProviding = BGGService.shared
    ) {
        self.game = game
        self.supabase = supabase
        self.bgg = bgg
    }

    func loadRelatedData() async {
        isLoading = true

        async let expansionsResult = supabase.fetchExpansions(gameId: game.id)
        async let baseGameResult = supabase.fetchBaseGame(expansionGameId: game.id)
        async let familiesResult = supabase.fetchFamilyMembers(gameId: game.id)

        var hydrationSucceeded = false
        do {
            try await hydrateFromBGGIfNeeded()
            hydrationSucceeded = true
        } catch {
            // Non-critical — fallback to whatever local data is already available.
        }

        do {
            expansions = try await expansionsResult
            baseGame = try await baseGameResult
            families = try await familiesResult
        } catch {
            // Non-critical — detail page still shows game info
        }

        if hydrationSucceeded {
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
        isLoading = false
    }

    private func hydrateFromBGGIfNeeded() async throws {
        guard let bggId = game.bggId else { return }

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
