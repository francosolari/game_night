import XCTest
@testable import GameNight

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testLoadDataKeepsSuccessfulResultsWhenOneSourceFails() async {
        let event = FixtureFactory.makeEvent()
        let draft = FixtureFactory.makeEvent(status: .draft)
        let provider = StubHomeDataProvider(
            upcomingEventsResult: .success([event]),
            invitesResult: .failure(TestError.message("invite query failed")),
            draftsResult: .success([draft])
        )
        let sut = HomeViewModel(supabase: provider)

        await sut.loadData()

        XCTAssertEqual(sut.upcomingEvents.map(\.id), [event.id])
        XCTAssertEqual(sut.drafts.map(\.id), [draft.id])
        XCTAssertEqual(sut.myInvites.count, 0)
        XCTAssertEqual(sut.error, "Invites: invite query failed")
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadDataClearsPreviousErrorAfterSuccessfulReload() async {
        let event = FixtureFactory.makeEvent()
        let provider = StubHomeDataProvider(
            upcomingEventsResult: .failure(TestError.message("events failed")),
            invitesResult: .success([]),
            draftsResult: .success([]),
            fetchedEventsResult: .success([])
        )
        let sut = HomeViewModel(supabase: provider)

        await sut.loadData()
        XCTAssertEqual(sut.error, "Upcoming Events: events failed")

        provider.upcomingEventsResult = .success([event])

        await sut.loadData()

        XCTAssertEqual(sut.upcomingEvents.map(\.id), [event.id])
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadDataMergesAcceptedPrivateInviteEventsIntoUpcoming() async {
        let publicEvent = FixtureFactory.makeEvent(visibility: .public)
        let privateInviteEvent = FixtureFactory.makeEvent(visibility: .private)
        let provider = StubHomeDataProvider(
            upcomingEventsResult: .success([publicEvent]),
            invitesResult: .success([
                FixtureFactory.makeInvite(
                    eventId: privateInviteEvent.id,
                    status: .accepted
                )
            ]),
            draftsResult: .success([]),
            fetchedEventsResult: .success([privateInviteEvent])
        )
        let sut = HomeViewModel(supabase: provider)

        await sut.loadData()

        XCTAssertEqual(Set(sut.upcomingEvents.map(\.id)), Set([publicEvent.id, privateInviteEvent.id]))
        XCTAssertEqual(provider.fetchedEventIds, [privateInviteEvent.id])
    }

    func testLoadDataDoesNotSurfacePendingPrivateInvitesInUpcoming() async {
        let publicEvent = FixtureFactory.makeEvent(visibility: .public)
        let privateInviteEvent = FixtureFactory.makeEvent(visibility: .private)
        let pendingInvite = FixtureFactory.makeInvite(
            eventId: privateInviteEvent.id,
            status: .pending
        )
        let provider = StubHomeDataProvider(
            upcomingEventsResult: .success([publicEvent]),
            invitesResult: .success([pendingInvite]),
            draftsResult: .success([]),
            fetchedEventsResult: .success([privateInviteEvent])
        )
        let sut = HomeViewModel(supabase: provider)

        await sut.loadData()

        XCTAssertEqual(sut.upcomingEvents.map(\.id), [publicEvent.id])
        XCTAssertEqual(provider.fetchedEventIds, [privateInviteEvent.id])
        XCTAssertEqual(sut.awaitingResponseEvents.map(\.event.id), [privateInviteEvent.id])
        XCTAssertEqual(sut.awaitingResponseEvents.first?.invite.id, pendingInvite.id)
    }
}

private final class StubHomeDataProvider: HomeDataProviding {
    var upcomingEventsResult: Result<[GameEvent], Error>
    var invitesResult: Result<[Invite], Error>
    var draftsResult: Result<[GameEvent], Error>
    var fetchedEventsResult: Result<[GameEvent], Error>
    var fetchedEventIds: [UUID] = []

    init(
        upcomingEventsResult: Result<[GameEvent], Error>,
        invitesResult: Result<[Invite], Error>,
        draftsResult: Result<[GameEvent], Error>,
        fetchedEventsResult: Result<[GameEvent], Error> = .success([])
    ) {
        self.upcomingEventsResult = upcomingEventsResult
        self.invitesResult = invitesResult
        self.draftsResult = draftsResult
        self.fetchedEventsResult = fetchedEventsResult
    }

    func fetchUpcomingEvents() async throws -> [GameEvent] {
        try upcomingEventsResult.get()
    }

    func fetchMyInvites() async throws -> [Invite] {
        try invitesResult.get()
    }

    func fetchDrafts() async throws -> [GameEvent] {
        try draftsResult.get()
    }

    func fetchEvents(ids: [UUID]) async throws -> [GameEvent] {
        fetchedEventIds = ids
        return try fetchedEventsResult.get()
    }

    func fetchAcceptedInviteCounts(eventIds: [UUID]) async throws -> [UUID: Int] {
        [:]
    }
}

@MainActor
final class GameDetailViewModelMembershipCacheTests: XCTestCase {
    func testLoadRelatedDataUsesCachedMembershipImmediately() async {
        let game = makeBGGGame()
        let cache = GameMembershipCache()
        let entryId = UUID()
        await cache.cacheRemoteState(
            gameId: game.id,
            bggId: game.bggId,
            isInCollection: true,
            isInWishlist: false,
            libraryEntryId: entryId,
            wishlistEntryId: nil
        )

        let provider = StubGameDetailDataProvider(
            libraryEntryIdResult: .success(entryId),
            wishlistEntryIdResult: .success(nil),
            lookupDelayNanoseconds: 250_000_000
        )
        let sut = GameDetailViewModel(
            game: game,
            supabase: provider,
            bgg: StubGameDetailBGGProvider(),
            membershipCache: cache
        )

        let loadTask = Task { await sut.loadRelatedData() }
        await Task.yield()
        for _ in 0..<20 where !sut.isInCollection {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertTrue(sut.isInCollection)
        XCTAssertFalse(sut.isInWishlist)

        await loadTask.value
    }

    func testToggleCollectionAppliesOptimisticMembershipBeforeNetworkCompletes() async {
        let game = makeBGGGame()
        let cache = GameMembershipCache()
        let provider = StubGameDetailDataProvider(
            addToCollectionDelayNanoseconds: 250_000_000
        )
        let sut = GameDetailViewModel(
            game: game,
            supabase: provider,
            bgg: StubGameDetailBGGProvider(),
            membershipCache: cache
        )

        let toggleTask = Task { await sut.toggleCollection() }
        await Task.yield()
        for _ in 0..<20 {
            let cachedState = await cache.cachedState(for: game.id, bggId: game.bggId)
            if cachedState?.isInCollection == true { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertTrue(sut.isInCollection)
        let cachedState = await cache.cachedState(for: game.id, bggId: game.bggId)
        XCTAssertEqual(cachedState?.isInCollection, true)

        await toggleTask.value
    }

    func testLoadRelatedDataFallsBackToBGGMembershipLookupWhenGameIdLookupMisses() async {
        let game = makeBGGGame()
        let entryId = UUID()
        let provider = StubGameDetailDataProvider(
            libraryEntryIdResult: .success(nil),
            libraryEntryIdByBGGIdResult: .success(entryId),
            wishlistEntryIdResult: .success(nil),
            wishlistEntryIdByBGGIdResult: .success(nil)
        )
        let sut = GameDetailViewModel(
            game: game,
            supabase: provider,
            bgg: StubGameDetailBGGProvider(),
            membershipCache: GameMembershipCache()
        )

        await sut.loadRelatedData()

        XCTAssertTrue(sut.isInCollection)
        XCTAssertFalse(sut.isInWishlist)
    }

    private func makeBGGGame() -> Game {
        Game(
            id: UUID(),
            bggId: 123,
            name: "Dune",
            yearPublished: nil,
            thumbnailUrl: nil,
            imageUrl: nil,
            minPlayers: 1,
            maxPlayers: 4,
            recommendedPlayers: nil,
            minPlaytime: 30,
            maxPlaytime: 90,
            complexity: 3.0,
            bggRating: nil,
            description: nil,
            categories: [],
            mechanics: [],
            designers: [],
            publishers: [],
            artists: [],
            minAge: nil,
            bggRank: nil
        )
    }
}

private final class StubGameDetailDataProvider: GameDetailDataProviding {
    var libraryEntryIdResult: Result<UUID?, Error>
    var libraryEntryIdByBGGIdResult: Result<UUID?, Error>
    var wishlistEntryIdResult: Result<UUID?, Error>
    var wishlistEntryIdByBGGIdResult: Result<UUID?, Error>
    var lookupDelayNanoseconds: UInt64
    var addToCollectionDelayNanoseconds: UInt64

    init(
        libraryEntryIdResult: Result<UUID?, Error> = .success(nil),
        libraryEntryIdByBGGIdResult: Result<UUID?, Error> = .success(nil),
        wishlistEntryIdResult: Result<UUID?, Error> = .success(nil),
        wishlistEntryIdByBGGIdResult: Result<UUID?, Error> = .success(nil),
        lookupDelayNanoseconds: UInt64 = 0,
        addToCollectionDelayNanoseconds: UInt64 = 0
    ) {
        self.libraryEntryIdResult = libraryEntryIdResult
        self.libraryEntryIdByBGGIdResult = libraryEntryIdByBGGIdResult
        self.wishlistEntryIdResult = wishlistEntryIdResult
        self.wishlistEntryIdByBGGIdResult = wishlistEntryIdByBGGIdResult
        self.lookupDelayNanoseconds = lookupDelayNanoseconds
        self.addToCollectionDelayNanoseconds = addToCollectionDelayNanoseconds
    }

    func fetchGame(id: UUID) async throws -> Game? { nil }
    func upsertGame(_ game: Game) async throws -> Game { game }

    func addGameToLibrary(gameId: UUID, categoryId: UUID?) async throws {
        if addToCollectionDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: addToCollectionDelayNanoseconds)
        }
    }

    func removeGameFromLibrary(entryId: UUID) async throws {}
    func addToWishlist(gameId: UUID) async throws {}
    func removeFromWishlist(entryId: UUID) async throws {}

    func libraryEntryId(gameId: UUID) async throws -> UUID? {
        if lookupDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: lookupDelayNanoseconds)
        }
        return try libraryEntryIdResult.get()
    }

    func libraryEntryIdByBGGId(_ bggId: Int) async throws -> UUID? {
        try libraryEntryIdByBGGIdResult.get()
    }

    func isOnWishlist(gameId: UUID) async throws -> UUID? {
        if lookupDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: lookupDelayNanoseconds)
        }
        return try wishlistEntryIdResult.get()
    }

    func wishlistEntryIdByBGGId(_ bggId: Int) async throws -> UUID? {
        try wishlistEntryIdByBGGIdResult.get()
    }

    func fetchExpansions(gameId: UUID) async throws -> [Game] { [] }
    func fetchBaseGame(expansionGameId: UUID) async throws -> Game? { nil }
    func fetchFamilyMembers(gameId: UUID) async throws -> [(family: GameFamily, games: [Game])] { [] }
    func upsertExpansionLinks(baseGameId: UUID, expansionGameIds: [UUID]) async throws {}
    func upsertFamilyLinks(gameId: UUID, families: [(bggFamilyId: Int, name: String)]) async throws {}
}

private struct StubGameDetailBGGProvider: GameDetailBGGProviding {
    func fetchGameDetailsWithRelations(bggId: Int) async throws -> BGGGameParseResult {
        throw TestError.message("not needed")
    }
}
