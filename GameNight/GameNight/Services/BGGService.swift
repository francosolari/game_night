import Foundation

/// Service for interacting with the BoardGameGeek XML API2 via Supabase edge functions.
/// All BGG API calls are proxied through edge functions that handle authentication,
/// rate limiting, and server-side caching. The iOS client never calls BGG directly.
actor BGGService {
    static let shared = BGGService()

    @MainActor private var supabase: SupabaseService { SupabaseService.shared }

    private init() {}

    // MARK: - Search (local-first, BGG fallback)

    /// Searches games by name. Queries local DB first; falls back to BGG via edge function if no results.
    func searchGames(query: String) async throws -> [BGGSearchResult] {
        guard !query.isEmpty else { return [] }

        // Local-first: search cached games table via Supabase PostgREST
        let localResults: [BGGSearchResult] = try await localGameSearch(query: query)
        if !localResults.isEmpty {
            return localResults
        }

        // Fallback: call BGG via edge function (results get cached server-side)
        let response: BGGSearchResponse = try await supabase.invokeAuthenticatedFunction(
            "bgg-search",
            body: BGGSearchRequest(query: query)
        )
        return response.games
    }

    // MARK: - Game Details

    func fetchGameDetails(bggId: Int) async throws -> Game {
        let response: BGGGamesResponse = try await supabase.invokeAuthenticatedFunction(
            "bgg-games",
            body: BGGGamesRequest(bggIds: [bggId])
        )
        guard let game = response.games.first else { throw BGGError.gameNotFound }
        return game
    }

    func fetchMultipleGameDetails(bggIds: [Int]) async throws -> [Game] {
        guard !bggIds.isEmpty else { return [] }
        let response: BGGGamesResponse = try await supabase.invokeAuthenticatedFunction(
            "bgg-games",
            body: BGGGamesRequest(bggIds: bggIds)
        )
        return response.games
    }

    func fetchGameDetailsWithRelations(bggId: Int) async throws -> BGGGameParseResult {
        let response: BGGGamesWithRelationsResponse = try await supabase.invokeAuthenticatedFunction(
            "bgg-games",
            body: BGGGamesRequest(bggIds: [bggId], includeRelations: true)
        )
        guard let result = response.games.first else { throw BGGError.gameNotFound }
        return result.toParseResult()
    }

    func fetchMultipleGameDetailsWithRelations(bggIds: [Int]) async throws -> [BGGGameParseResult] {
        guard !bggIds.isEmpty else { return [] }
        let response: BGGGamesWithRelationsResponse = try await supabase.invokeAuthenticatedFunction(
            "bgg-games",
            body: BGGGamesRequest(bggIds: bggIds, includeRelations: true)
        )
        return response.games.map { $0.toParseResult() }
    }

    // MARK: - Hot Games

    func fetchHotGames() async throws -> [BGGSearchResult] {
        let response: BGGSearchResponse = try await supabase.invokeAuthenticatedFunction(
            "bgg-search",
            body: BGGHotRequest(hot: true)
        )
        return response.games
    }

    // MARK: - User Collection (BGG username)

    func fetchUserCollection(username: String) async throws -> [BGGSearchResult] {
        let response: BGGCollectionResponse = try await supabase.invokeAuthenticatedFunction(
            "bgg-collection",
            body: BGGCollectionRequest(username: username)
        )

        // Convert collection items to search results for compatibility
        return response.games ?? []
    }

    // MARK: - Play Sync

    func syncPlaysFromBGG(username: String) async throws -> BGGPlaysSyncResponse {
        return try await supabase.invokeAuthenticatedFunction(
            "bgg-plays",
            body: BGGPlaysRequest(action: "import", username: username)
        )
    }

    /// Returns URL to log a play on BGG's website (deep link for manual logging)
    func bggPlayLogURL(bggId: Int) -> URL? {
        URL(string: "https://boardgamegeek.com/plays/log?objectid=\(bggId)&objecttype=thing")
    }

    // MARK: - Local Search Helper

    private func localGameSearch(query: String) async throws -> [BGGSearchResult] {
        struct SearchGamesFuzzyParams: Encodable {
            let searchQuery: String
            let resultLimit: Int

            enum CodingKeys: String, CodingKey {
                case searchQuery = "search_query"
                case resultLimit = "result_limit"
            }
        }

        let games: [Game] = try await supabase.client
            .rpc("search_games_fuzzy", params: SearchGamesFuzzyParams(
                searchQuery: query,
                resultLimit: 30
            ))
            .execute()
            .value

        return games.compactMap { game in
            guard let bggId = game.bggId else { return nil }
            return BGGSearchResult(
                id: bggId,
                name: game.name,
                yearPublished: game.yearPublished,
                thumbnailUrl: game.thumbnailUrl
            )
        }
    }
}

// MARK: - Request/Response Types

private struct BGGSearchRequest: Encodable {
    let query: String
}

private struct BGGHotRequest: Encodable {
    let hot: Bool
}

private struct BGGGamesRequest: Encodable {
    let bggIds: [Int]
    var includeRelations: Bool = false
    var forceRefresh: Bool = false

    enum CodingKeys: String, CodingKey {
        case bggIds = "bgg_ids"
        case includeRelations = "include_relations"
        case forceRefresh = "force_refresh"
    }
}

private struct BGGCollectionRequest: Encodable {
    let username: String
}

private struct BGGPlaysRequest: Encodable {
    let action: String
    let username: String
}

private struct BGGSearchResponse: Decodable {
    let games: [BGGSearchResult]
}

private struct BGGCollectionResponse: Decodable {
    let total: Int?
    let added: Int?
    let skipped: Int?
    let message: String?
    let games: [BGGSearchResult]?
    let error: String?
}

struct BGGPlaysSyncResponse: Decodable {
    let imported: Int?
    let skipped: Int?
    let message: String?
    let error: String?
}

private struct BGGGamesResponse: Decodable {
    let games: [Game]
}

// Response type for games with relations (flat game + appended relation arrays)
private struct BGGGamesWithRelationsResponse: Decodable {
    let games: [GameWithRelations]
}

private struct GameWithRelations: Decodable {
    let game: Game
    let expansionLinks: [ExpansionLink]
    let familyLinks: [FamilyLink]

    init(from decoder: Decoder) throws {
        // The edge function returns flat objects: all Game fields + expansion_links + family_links
        // Decode Game from the same container (it ignores unknown keys)
        game = try Game(from: decoder)

        let container = try decoder.container(keyedBy: RelationKeys.self)
        expansionLinks = (try? container.decodeIfPresent([ExpansionLink].self, forKey: .expansionLinks)) ?? []
        familyLinks = (try? container.decodeIfPresent([FamilyLink].self, forKey: .familyLinks)) ?? []
    }

    private enum RelationKeys: String, CodingKey {
        case expansionLinks = "expansion_links"
        case familyLinks = "family_links"
    }

    func toParseResult() -> BGGGameParseResult {
        BGGGameParseResult(
            game: game,
            expansionLinks: expansionLinks.map {
                (bggId: $0.bggId, name: $0.name, isInbound: $0.isInbound)
            },
            familyLinks: familyLinks.map {
                (bggFamilyId: $0.bggFamilyId, name: $0.name)
            }
        )
    }
}

private struct ExpansionLink: Decodable {
    let bggId: Int
    let name: String
    let isInbound: Bool

    enum CodingKeys: String, CodingKey {
        case bggId = "bgg_id"
        case name
        case isInbound = "is_inbound"
    }
}

private struct FamilyLink: Decodable {
    let bggFamilyId: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case bggFamilyId = "bgg_family_id"
        case name
    }
}

// MARK: - BGG Game Parse Result

struct BGGGameParseResult {
    let game: Game
    let expansionLinks: [(bggId: Int, name: String, isInbound: Bool)]
    let familyLinks: [(bggFamilyId: Int, name: String)]
}

// MARK: - Errors

enum BGGError: LocalizedError {
    case parseFailed
    case gameNotFound
    case collectionTimeout
    case cooldownActive(hoursLeft: Int)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .parseFailed: return "Failed to parse BoardGameGeek response"
        case .gameNotFound: return "Game not found on BoardGameGeek"
        case .collectionTimeout: return "BGG collection request timed out"
        case .cooldownActive(let hours): return "BGG sync is on cooldown. Try again in \(hours) hour(s)."
        case .serverError(let msg): return msg
        }
    }
}
