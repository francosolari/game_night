import Foundation

/// Service for interacting with the BoardGameGeek XML API2
actor BGGService {
    static let shared = BGGService()

    private let baseURL = "https://boardgamegeek.com/xmlapi2"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search

    func searchGames(query: String) async throws -> [BGGSearchResult] {
        guard !query.isEmpty else { return [] }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/search?query=\(encoded)&type=boardgame")!

        let (data, _) = try await session.data(from: url)
        return try BGGXMLParser.parseSearchResults(data: data)
    }

    // MARK: - Game Details

    func fetchGameDetails(bggId: Int) async throws -> Game {
        let url = URL(string: "\(baseURL)/thing?id=\(bggId)&stats=1")!

        let (data, _) = try await session.data(from: url)
        return try BGGXMLParser.parseGameDetails(data: data, bggId: bggId)
    }

    func fetchMultipleGameDetails(bggIds: [Int]) async throws -> [Game] {
        guard !bggIds.isEmpty else { return [] }

        let ids = bggIds.map(String.init).joined(separator: ",")
        let url = URL(string: "\(baseURL)/thing?id=\(ids)&stats=1")!

        let (data, _) = try await session.data(from: url)
        return try BGGXMLParser.parseMultipleGames(data: data)
    }

    func fetchGameDetailsWithRelations(bggId: Int) async throws -> BGGGameParseResult {
        let url = URL(string: "\(baseURL)/thing?id=\(bggId)&stats=1")!
        let (data, _) = try await session.data(from: url)
        let results = try BGGXMLParser.parseMultipleGamesWithRelations(data: data)
        guard let result = results.first else { throw BGGError.gameNotFound }
        return result
    }

    // MARK: - Hot Games

    func fetchHotGames() async throws -> [BGGSearchResult] {
        let url = URL(string: "\(baseURL)/hot?type=boardgame")!
        let (data, _) = try await session.data(from: url)
        return try BGGXMLParser.parseHotGames(data: data)
    }

    // MARK: - User Collection (BGG username)

    func fetchUserCollection(username: String) async throws -> [BGGSearchResult] {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let url = URL(string: "\(baseURL)/collection?username=\(encoded)&own=1&subtype=boardgame")!

        // BGG collection API may return 202 (queued), need to retry
        var attempts = 0
        while attempts < 5 {
            let (data, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 202 {
                attempts += 1
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                continue
            }
            return try BGGXMLParser.parseCollection(data: data)
        }
        throw BGGError.collectionTimeout
    }
}

// MARK: - BGG XML Parser
struct BGGXMLParser {

    static func parseSearchResults(data: Data) throws -> [BGGSearchResult] {
        let parser = XMLParser(data: data)
        let delegate = BGGSearchDelegate()
        parser.delegate = delegate
        guard parser.parse() else { throw BGGError.parseFailed }
        return delegate.results
    }

    static func parseGameDetails(data: Data, bggId: Int) throws -> Game {
        let games = try parseMultipleGames(data: data)
        guard let game = games.first else { throw BGGError.gameNotFound }
        return game
    }

    static func parseMultipleGames(data: Data) throws -> [Game] {
        let parser = XMLParser(data: data)
        let delegate = BGGGameDetailDelegate()
        parser.delegate = delegate
        guard parser.parse() else { throw BGGError.parseFailed }
        return delegate.games
    }

    static func parseHotGames(data: Data) throws -> [BGGSearchResult] {
        let parser = XMLParser(data: data)
        let delegate = BGGHotDelegate()
        parser.delegate = delegate
        guard parser.parse() else { throw BGGError.parseFailed }
        return delegate.results
    }

    static func parseCollection(data: Data) throws -> [BGGSearchResult] {
        let parser = XMLParser(data: data)
        let delegate = BGGCollectionDelegate()
        parser.delegate = delegate
        guard parser.parse() else { throw BGGError.parseFailed }
        return delegate.results
    }

    static func parseMultipleGamesWithRelations(data: Data) throws -> [BGGGameParseResult] {
        let parser = XMLParser(data: data)
        let delegate = BGGGameDetailDelegate()
        parser.delegate = delegate
        guard parser.parse() else { throw BGGError.parseFailed }
        return delegate.parseResults
    }
}

// MARK: - BGG Game Parse Result

struct BGGGameParseResult {
    let game: Game
    let expansionLinks: [(bggId: Int, name: String, isInbound: Bool)]
    let familyLinks: [(bggFamilyId: Int, name: String)]
}

// MARK: - XML Delegates

class BGGSearchDelegate: NSObject, XMLParserDelegate {
    var results: [BGGSearchResult] = []
    private var currentId: Int?
    private var currentName: String?
    private var currentYear: Int?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "item":
            currentId = Int(attributeDict["id"] ?? "")
            currentName = nil
            currentYear = nil
        case "name":
            if attributeDict["type"] == "primary" {
                currentName = attributeDict["value"]
            }
        case "yearpublished":
            currentYear = Int(attributeDict["value"] ?? "")
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        if elementName == "item", let id = currentId, let name = currentName {
            results.append(BGGSearchResult(
                id: id,
                name: name,
                yearPublished: currentYear,
                thumbnailUrl: nil
            ))
        }
    }
}

class BGGGameDetailDelegate: NSObject, XMLParserDelegate {
    var games: [Game] = []
    var parseResults: [BGGGameParseResult] = []

    private var currentId: Int?
    private var currentName: String?
    private var currentYear: Int?
    private var thumbnail: String?
    private var image: String?
    private var minPlayers: Int = 1
    private var maxPlayers: Int = 4
    private var minPlaytime: Int = 30
    private var maxPlaytime: Int = 60
    private var weight: Double = 2.5
    private var rating: Double = 0
    private var gameDescription: String?
    private var categories: [String] = []
    private var mechanics: [String] = []
    private var designers: [String] = []
    private var publishers: [String] = []
    private var artists: [String] = []
    private var minAge: Int?
    private var bggRank: Int?
    private var expansionBggIds: [(bggId: Int, name: String, isInbound: Bool)] = []
    private var familyLinks: [(bggFamilyId: Int, name: String)] = []
    private var currentText = ""
    private var inItem = false

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentText = ""
        switch elementName {
        case "item":
            if attributeDict["type"] == "boardgame" {
                inItem = true
                currentId = Int(attributeDict["id"] ?? "")
                currentName = nil
                currentYear = nil
                thumbnail = nil
                image = nil
                categories = []
                mechanics = []
                designers = []
                publishers = []
                artists = []
                minAge = nil
                bggRank = nil
                expansionBggIds = []
                familyLinks = []
                gameDescription = nil
            }
        case "name":
            if inItem && attributeDict["type"] == "primary" {
                currentName = attributeDict["value"]
            }
        case "yearpublished":
            if inItem { currentYear = Int(attributeDict["value"] ?? "") }
        case "minplayers":
            if inItem { minPlayers = Int(attributeDict["value"] ?? "1") ?? 1 }
        case "maxplayers":
            if inItem { maxPlayers = Int(attributeDict["value"] ?? "4") ?? 4 }
        case "minplaytime":
            if inItem { minPlaytime = Int(attributeDict["value"] ?? "30") ?? 30 }
        case "maxplaytime":
            if inItem { maxPlaytime = Int(attributeDict["value"] ?? "60") ?? 60 }
        case "average":
            if inItem { rating = Double(attributeDict["value"] ?? "0") ?? 0 }
        case "averageweight":
            if inItem { weight = Double(attributeDict["value"] ?? "2.5") ?? 2.5 }
        case "minage":
            if inItem { minAge = Int(attributeDict["value"] ?? "") }
        case "rank":
            if inItem && attributeDict["name"] == "boardgame" {
                bggRank = Int(attributeDict["value"] ?? "")
            }
        case "link":
            if inItem {
                let type = attributeDict["type"] ?? ""
                let value = attributeDict["value"] ?? ""
                if type == "boardgamecategory" { categories.append(value) }
                if type == "boardgamemechanic" { mechanics.append(value) }
                if type == "boardgamedesigner" { designers.append(value) }
                if type == "boardgamepublisher" { publishers.append(value) }
                if type == "boardgameartist" { artists.append(value) }
                if type == "boardgameexpansion", let bggId = Int(attributeDict["id"] ?? "") {
                    let isInbound = attributeDict["inbound"] == "true"
                    expansionBggIds.append((bggId: bggId, name: value, isInbound: isInbound))
                }
                if type == "boardgamefamily", let bggId = Int(attributeDict["id"] ?? "") {
                    familyLinks.append((bggFamilyId: bggId, name: value))
                }
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        if inItem {
            switch elementName {
            case "thumbnail": thumbnail = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            case "image": image = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            case "description": gameDescription = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            case "item":
                if let id = currentId, let name = currentName {
                    games.append(Game(
                        id: UUID(),
                        bggId: id,
                        name: name,
                        yearPublished: currentYear,
                        thumbnailUrl: thumbnail,
                        imageUrl: image,
                        minPlayers: minPlayers,
                        maxPlayers: maxPlayers,
                        recommendedPlayers: nil,
                        minPlaytime: minPlaytime,
                        maxPlaytime: maxPlaytime,
                        complexity: weight,
                        bggRating: rating > 0 ? rating : nil,
                        description: gameDescription,
                        categories: categories,
                        mechanics: mechanics,
                        designers: designers,
                        publishers: publishers,
                        artists: artists,
                        minAge: minAge,
                        bggRank: bggRank
                    ))
                    parseResults.append(BGGGameParseResult(
                        game: games.last!,
                        expansionLinks: expansionBggIds,
                        familyLinks: familyLinks
                    ))
                }
                inItem = false
            default: break
            }
        }
    }
}

class BGGHotDelegate: NSObject, XMLParserDelegate {
    var results: [BGGSearchResult] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String : String] = [:]) {
        if elementName == "item", let idStr = attributeDict["id"], let id = Int(idStr) {
            results.append(BGGSearchResult(id: id, name: "", yearPublished: nil, thumbnailUrl: nil))
        }
        if elementName == "name", let value = attributeDict["value"], !results.isEmpty {
            let last = results.removeLast()
            results.append(BGGSearchResult(id: last.id, name: value, yearPublished: last.yearPublished, thumbnailUrl: last.thumbnailUrl))
        }
        if elementName == "thumbnail", let value = attributeDict["value"], !results.isEmpty {
            let last = results.removeLast()
            results.append(BGGSearchResult(id: last.id, name: last.name, yearPublished: last.yearPublished, thumbnailUrl: value))
        }
        if elementName == "yearpublished", let value = attributeDict["value"], !results.isEmpty {
            let last = results.removeLast()
            results.append(BGGSearchResult(id: last.id, name: last.name, yearPublished: Int(value), thumbnailUrl: last.thumbnailUrl))
        }
    }
}

class BGGCollectionDelegate: NSObject, XMLParserDelegate {
    var results: [BGGSearchResult] = []
    private var currentId: Int?
    private var currentName: String?
    private var currentYear: Int?
    private var currentThumbnail: String?
    private var currentText = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentText = ""
        if elementName == "item" {
            currentId = Int(attributeDict["objectid"] ?? "")
            currentName = nil
            currentYear = nil
            currentThumbnail = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "name": currentName = text
        case "yearpublished": currentYear = Int(text)
        case "thumbnail": currentThumbnail = text
        case "item":
            if let id = currentId, let name = currentName {
                results.append(BGGSearchResult(
                    id: id, name: name,
                    yearPublished: currentYear,
                    thumbnailUrl: currentThumbnail
                ))
            }
        default: break
        }
    }
}

// MARK: - Errors

enum BGGError: LocalizedError {
    case parseFailed
    case gameNotFound
    case collectionTimeout

    var errorDescription: String? {
        switch self {
        case .parseFailed: return "Failed to parse BoardGameGeek response"
        case .gameNotFound: return "Game not found on BoardGameGeek"
        case .collectionTimeout: return "BGG collection request timed out"
        }
    }
}
