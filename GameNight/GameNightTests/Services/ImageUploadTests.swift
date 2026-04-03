import XCTest
import PhotosUI
@testable import GameNight

class ImageUploadTests: XCTestCase {
    var r2Service: R2StorageService!
    var mockSupabase: MockSupabaseService!

    override func setUp() {
        super.setUp()
        r2Service = R2StorageService()
        mockSupabase = MockSupabaseService()
    }

    override func tearDown() {
        r2Service = nil
        mockSupabase = nil
        super.tearDown()
    }

    func testUploadGameImageGeneratesCorrectPath() async throws {
        let gameId = UUID()
        let testImageData = createTestImageData()
        let publicUrl = try await r2Service.uploadGameImage(data: testImageData, gameId: gameId)
        XCTAssertTrue(publicUrl.contains("games"))
        XCTAssertTrue(publicUrl.contains(gameId.uuidString))
    }

    func testUploadGameImageReturnsPublicUrl() async throws {
        let testImageData = createTestImageData()
        let gameId = UUID()
        let publicUrl = try await r2Service.uploadGameImage(data: testImageData, gameId: gameId)
        XCTAssertFalse(publicUrl.isEmpty)
        XCTAssertTrue(publicUrl.hasPrefix("http"))
    }

    func testUpdateGameImageUrlSucceeds() async throws {
        let gameId = UUID()
        let imageUrl = "https://r2.example.com/games/\(gameId)/image.jpg"
        try await mockSupabase.updateGameImageUrl(gameId: gameId, imageUrl: imageUrl)
        let updated = try await mockSupabase.fetchGame(id: gameId)
        XCTAssertEqual(updated.imageUrl, imageUrl)
    }

    func testUpdateEventCoverUrlSucceeds() async throws {
        let eventId = UUID()
        let coverUrl = "https://r2.example.com/events/\(eventId)/cover.jpg"
        try await mockSupabase.updateEventCoverUrl(eventId: eventId, coverUrl: coverUrl)
        let updated = try await mockSupabase.fetchEvent(id: eventId)
        XCTAssertEqual(updated.coverImageUrl, coverUrl)
    }

    private func createTestImageData(format: ImageFormat = .jpeg) -> Data {
        let size = CGSize(width: 200, height: 200)
        let rect = CGRect(origin: .zero, size: size)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.blue.setFill()
            context.fill(rect)
        }
        switch format {
        case .jpeg:
            return image.jpegData(compressionQuality: 0.8) ?? Data()
        case .png:
            return image.pngData() ?? Data()
        }
    }

    enum ImageFormat {
        case jpeg, png
    }
}

class MockSupabaseService {
    private var games: [UUID: Game] = [:]
    private var events: [UUID: GameEvent] = [:]

    func updateGameImageUrl(gameId: UUID, imageUrl: String) async throws {
        guard URL(string: imageUrl) != nil else { throw NSError(domain: "Invalid URL", code: -1) }
        if var game = games[gameId] {
            game.imageUrl = imageUrl
            games[gameId] = game
        }
    }

    func updateEventCoverUrl(eventId: UUID, coverUrl: String) async throws {
        guard URL(string: coverUrl) != nil else { throw NSError(domain: "Invalid URL", code: -1) }
        if var event = events[eventId] {
            event.coverImageUrl = coverUrl
            events[eventId] = event
        }
    }

    func fetchGame(id: UUID) async throws -> Game {
        guard let game = games[id] else { throw NSError(domain: "Game not found", code: -1) }
        return game
    }

    func fetchEvent(id: UUID) async throws -> GameEvent {
        guard let event = events[id] else { throw NSError(domain: "Event not found", code: -1) }
        return event
    }

    func createTestGame(id: UUID) {
        games[id] = Game(id: id, name: "Test Game", minPlayers: 2, maxPlayers: 4, minPlaytime: 30, maxPlaytime: 60, complexity: 2.0)
    }

    func createTestEvent(id: UUID, hostId: UUID) {
        events[id] = GameEvent(
            id: id,
            hostId: hostId,
            title: "Test Event",
            status: .draft,
            games: [],
            timeOptions: [],
            allowTimeSuggestions: true,
            scheduleMode: .fixed,
            inviteStrategy: InviteStrategy(type: .allAtOnce, tierSize: nil, autoPromote: true),
            minPlayers: 2,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
