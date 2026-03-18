import Foundation
@testable import GameNight

enum FixtureFactory {
    static func makeEvent(
        id: UUID = UUID(),
        title: String = "Game Night",
        status: EventStatus = .published,
        games: [EventGame] = [makeEventGame()],
        timeOptions: [TimeOption] = [makeTimeOption()],
        host: User? = makeUser(),
        visibility: EventVisibility = .private,
        rsvpDeadline: Date? = nil,
        allowGuestInvites: Bool = false,
        plusOneLimit: Int = 0,
        allowMaybeRSVP: Bool = true,
        requirePlusOneNames: Bool = false
    ) -> GameEvent {
        GameEvent(
            id: id,
            hostId: host?.id ?? UUID(),
            host: host,
            title: title,
            description: "Bring snacks",
            visibility: visibility,
            rsvpDeadline: rsvpDeadline,
            allowGuestInvites: allowGuestInvites,
            location: "Alex's House",
            locationAddress: "123 Main St",
            status: status,
            games: games,
            timeOptions: timeOptions,
            confirmedTimeOptionId: timeOptions.first?.id,
            allowTimeSuggestions: true,
            scheduleMode: .fixed,
            inviteStrategy: InviteStrategy(type: .allAtOnce, tierSize: nil, autoPromote: true),
            minPlayers: 3,
            maxPlayers: 6,
            allowGameVoting: false,
            confirmedGameId: nil,
            plusOneLimit: plusOneLimit,
            allowMaybeRSVP: allowMaybeRSVP,
            requirePlusOneNames: requirePlusOneNames,
            coverImageUrl: nil,
            draftInvitees: nil,
            deletedAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_710_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_710_000_100)
        )
    }

    static func makeInvite(
        id: UUID = UUID(),
        eventId: UUID = UUID(),
        status: InviteStatus = .pending
    ) -> Invite {
        Invite(
            id: id,
            eventId: eventId,
            hostUserId: UUID(),
            userId: UUID(),
            phoneNumber: "+15555550123",
            displayName: "Jordan",
            status: status,
            tier: 1,
            tierPosition: 0,
            isActive: true,
            respondedAt: nil,
            selectedTimeOptionIds: [],
            suggestedTimes: nil,
            sentVia: .both,
            smsDeliveryStatus: .delivered,
            createdAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
    }

    static func makeUser(id: UUID = UUID(), displayName: String = "Franco") -> User {
        User(
            id: id,
            phoneNumber: "19543482945",
            displayName: displayName,
            avatarUrl: nil,
            bio: nil,
            bggUsername: "francosolari",
            phoneVisible: false,
            discoverableByPhone: true,
            marketingOptIn: false,
            contactsSynced: false,
            phoneVerified: true,
            privacyAcceptedAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
    }

    static func makeGame(id: UUID = UUID(), name: String = "Dune") -> Game {
        Game(
            id: id,
            bggId: nil,
            name: name,
            yearPublished: nil,
            thumbnailUrl: nil,
            imageUrl: nil,
            minPlayers: 1,
            maxPlayers: 6,
            recommendedPlayers: nil,
            minPlaytime: 30,
            maxPlaytime: 120,
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

    static func makeEventGame(
        id: UUID = UUID(),
        game: Game = makeGame(),
        isPrimary: Bool = true,
        sortOrder: Int = 0
    ) -> EventGame {
        EventGame(
            id: id,
            gameId: game.id,
            game: game,
            isPrimary: isPrimary,
            sortOrder: sortOrder,
            yesCount: 0,
            maybeCount: 0,
            noCount: 0
        )
    }

    static func makeTimeOption(id: UUID = UUID()) -> TimeOption {
        TimeOption(
            id: id,
            eventId: UUID(),
            date: Date(timeIntervalSince1970: 1_710_100_000),
            startTime: Date(timeIntervalSince1970: 1_710_103_600),
            endTime: Date(timeIntervalSince1970: 1_710_107_200),
            label: "Friday Night",
            isSuggested: false,
            suggestedBy: nil,
            voteCount: 0,
            maybeCount: 0
        )
    }
}
