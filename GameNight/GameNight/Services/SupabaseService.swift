import Foundation
import Supabase
import Combine

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    let client: SupabaseClient

    // TODO: Move to environment config / plist
    private static let supabaseURL = URL(string: "https://YOUR_PROJECT.supabase.co")!
    private static let supabaseAnonKey = "YOUR_ANON_KEY"

    private init() {
        self.client = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseAnonKey
        )
    }

    // MARK: - Auth

    func signInWithOTP(phoneNumber: String) async throws {
        try await client.auth.signInWithOTP(phone: phoneNumber)
    }

    func verifyOTP(phoneNumber: String, code: String) async throws {
        try await client.auth.verifyOTP(
            phone: phoneNumber,
            token: code,
            type: .sms
        )
    }

    func fetchCurrentUser() async throws -> User {
        let session = try await client.auth.session
        let user: User = try await client
            .from("users")
            .select()
            .eq("id", value: session.user.id.uuidString)
            .single()
            .execute()
            .value
        return user
    }

    func updateUser(_ user: User) async throws {
        try await client
            .from("users")
            .update(user)
            .eq("id", value: user.id.uuidString)
            .execute()
    }

    // MARK: - Events

    func fetchUpcomingEvents() async throws -> [GameEvent] {
        let events: [GameEvent] = try await client
            .from("events")
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options(*)")
            .or("status.eq.published,status.eq.confirmed")
            .order("created_at", ascending: false)
            .execute()
            .value
        return events
    }

    func fetchMyEvents() async throws -> [GameEvent] {
        let session = try await client.auth.session
        let events: [GameEvent] = try await client
            .from("events")
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options(*)")
            .eq("host_id", value: session.user.id.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return events
    }

    func fetchEvent(id: UUID) async throws -> GameEvent {
        let event: GameEvent = try await client
            .from("events")
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options(*)")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return event
    }

    func createEvent(_ event: GameEvent) async throws -> GameEvent {
        let created: GameEvent = try await client
            .from("events")
            .insert(event)
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options(*)")
            .single()
            .execute()
            .value
        return created
    }

    func updateEvent(_ event: GameEvent) async throws {
        try await client
            .from("events")
            .update(event)
            .eq("id", value: event.id.uuidString)
            .execute()
    }

    // MARK: - Time Options & Event Games Persistence

    func createTimeOptions(_ timeOptions: [TimeOption]) async throws {
        guard !timeOptions.isEmpty else { return }
        try await client
            .from("time_options")
            .insert(timeOptions)
            .execute()
    }

    private struct EventGameInsert: Encodable {
        let id: UUID
        let eventId: UUID
        let gameId: UUID
        let isPrimary: Bool
        let sortOrder: Int

        enum CodingKeys: String, CodingKey {
            case id
            case eventId = "event_id"
            case gameId = "game_id"
            case isPrimary = "is_primary"
            case sortOrder = "sort_order"
        }
    }

    func createEventGames(eventId: UUID, games: [EventGame]) async throws {
        guard !games.isEmpty else { return }
        let inserts = games.map { game in
            EventGameInsert(
                id: game.id,
                eventId: eventId,
                gameId: game.gameId,
                isPrimary: game.isPrimary,
                sortOrder: game.sortOrder
            )
        }
        try await client
            .from("event_games")
            .insert(inserts)
            .execute()
    }

    func deleteTimeOptions(eventId: UUID) async throws {
        try await client
            .from("time_options")
            .delete()
            .eq("event_id", value: eventId.uuidString)
            .execute()
    }

    func deleteEventGames(eventId: UUID) async throws {
        try await client
            .from("event_games")
            .delete()
            .eq("event_id", value: eventId.uuidString)
            .execute()
    }

    // MARK: - Invites

    func fetchInvites(eventId: UUID) async throws -> [Invite] {
        let invites: [Invite] = try await client
            .from("invites")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .order("tier")
            .order("tier_position")
            .execute()
            .value
        return invites
    }

    func fetchMyInvites() async throws -> [Invite] {
        let session = try await client.auth.session
        let invites: [Invite] = try await client
            .from("invites")
            .select("*, event:events(*, host:users(*), games:event_games(*, game:games(*)), time_options(*))")
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
            .value
        return invites
    }

    func respondToInvite(inviteId: UUID, status: InviteStatus, timeVotes: [TimeOptionVote], suggestedTimes: [TimeOption]?) async throws {
        // selected_time_option_ids stores 'yes' votes for backward compat
        let yesIds = timeVotes.filter { $0.voteType == .yes }.map { $0.timeOptionId }

        let updates: [String: AnyJSON] = [
            "status": .string(status.rawValue),
            "responded_at": .string(ISO8601DateFormatter().string(from: Date())),
            "selected_time_option_ids": .array(yesIds.map { .string($0.uuidString) })
        ]

        try await client
            .from("invites")
            .update(updates)
            .eq("id", value: inviteId.uuidString)
            .execute()

        // Delete existing votes for this invite, then insert new ones
        try await client
            .from("time_option_votes")
            .delete()
            .eq("invite_id", value: inviteId.uuidString)
            .execute()

        if !timeVotes.isEmpty {
            struct VoteInsert: Encodable {
                let timeOptionId: UUID
                let inviteId: UUID
                let voteType: String
                enum CodingKeys: String, CodingKey {
                    case timeOptionId = "time_option_id"
                    case inviteId = "invite_id"
                    case voteType = "vote_type"
                }
            }
            let voteInserts = timeVotes.map { vote in
                VoteInsert(timeOptionId: vote.timeOptionId, inviteId: inviteId, voteType: vote.voteType.rawValue)
            }
            try await client
                .from("time_option_votes")
                .insert(voteInserts)
                .execute()
        }

        // Insert suggested times if any
        if let suggestedTimes, !suggestedTimes.isEmpty {
            try await client
                .from("time_options")
                .insert(suggestedTimes)
                .execute()
        }

        // Trigger tiered invite processing via Edge Function
        try await client.functions.invoke(
            "process-tiered-invites",
            options: .init(body: ["invite_id": inviteId.uuidString])
        )
    }

    func createInvites(_ invites: [Invite]) async throws {
        try await client
            .from("invites")
            .insert(invites)
            .execute()

        // Trigger SMS sending for active invites
        let activeInvites = invites.filter { $0.isActive }
        for invite in activeInvites {
            try await client.functions.invoke(
                "send-invite",
                options: .init(body: [
                    "invite_id": invite.id.uuidString,
                    "event_id": invite.eventId.uuidString
                ])
            )
        }
    }

    // MARK: - Games

    func fetchGameLibrary() async throws -> [GameLibraryEntry] {
        let session = try await client.auth.session
        let entries: [GameLibraryEntry] = try await client
            .from("game_library")
            .select("*, game:games(*)")
            .eq("user_id", value: session.user.id.uuidString)
            .order("added_at", ascending: false)
            .execute()
            .value
        return entries
    }

    func addGameToLibrary(gameId: UUID, categoryId: UUID?) async throws {
        let session = try await client.auth.session
        let entry = [
            "user_id": session.user.id.uuidString,
            "game_id": gameId.uuidString,
            "category_id": categoryId?.uuidString ?? "",
            "play_count": "0"
        ]
        try await client
            .from("game_library")
            .insert(entry)
            .execute()
    }

    func removeGameFromLibrary(entryId: UUID) async throws {
        try await client
            .from("game_library")
            .delete()
            .eq("id", value: entryId.uuidString)
            .execute()
    }

    func upsertGame(_ game: Game) async throws -> Game {
        let saved: Game = try await client
            .from("games")
            .upsert(game, onConflict: "bgg_id")
            .select()
            .single()
            .execute()
            .value
        return saved
    }

    // MARK: - Categories

    func fetchCategories() async throws -> [GameCategory] {
        let session = try await client.auth.session
        let cats: [GameCategory] = try await client
            .from("game_categories")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .order("sort_order")
            .execute()
            .value
        return cats
    }

    func createCategory(_ category: GameCategory) async throws {
        try await client
            .from("game_categories")
            .insert(category)
            .execute()
    }

    // MARK: - Groups

    func fetchGroups() async throws -> [GameGroup] {
        let session = try await client.auth.session
        let groups: [GameGroup] = try await client
            .from("groups")
            .select("*, members:group_members(*)")
            .eq("owner_id", value: session.user.id.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return groups
    }

    func createGroup(_ group: GameGroup) async throws -> GameGroup {
        let created: GameGroup = try await client
            .from("groups")
            .insert(group)
            .select("*, members:group_members(*)")
            .single()
            .execute()
            .value
        return created
    }

    func updateGroup(_ group: GameGroup) async throws {
        try await client
            .from("groups")
            .update(group)
            .eq("id", value: group.id.uuidString)
            .execute()
    }

    func deleteGroup(id: UUID) async throws {
        try await client
            .from("groups")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func addGroupMember(_ member: GroupMember) async throws {
        try await client
            .from("group_members")
            .insert(member)
            .execute()
    }

    func removeGroupMember(id: UUID) async throws {
        try await client
            .from("group_members")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Blocking

    func blockUser(blockedId: UUID?, blockedPhone: String?, reason: String?) async throws {
        let session = try await client.auth.session
        let block = BlockedUser(
            id: UUID(),
            blockerId: session.user.id,
            blockedId: blockedId ?? UUID(),
            blockedPhone: blockedPhone,
            reason: reason,
            createdAt: Date()
        )
        try await client
            .from("blocked_users")
            .insert(block)
            .execute()
    }

    func unblockUser(blockId: UUID) async throws {
        try await client
            .from("blocked_users")
            .delete()
            .eq("id", value: blockId.uuidString)
            .execute()
    }

    func fetchBlockedUsers() async throws -> [BlockedUser] {
        let session = try await client.auth.session
        let blocked: [BlockedUser] = try await client
            .from("blocked_users")
            .select()
            .eq("blocker_id", value: session.user.id.uuidString)
            .execute()
            .value
        return blocked
    }

    // MARK: - Consent Logging

    func logConsent(type: String, granted: Bool) async throws {
        let session = try await client.auth.session
        let entry: [String: String] = [
            "user_id": session.user.id.uuidString,
            "consent_type": type,
            "granted": granted ? "true" : "false"
        ]
        try await client
            .from("consent_log")
            .insert(entry)
            .execute()
    }

    // MARK: - Realtime

    func subscribeToEventUpdates(eventId: UUID, onUpdate: @escaping (GameEvent) -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("event-\(eventId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "invites",
            filter: "event_id=eq.\(eventId.uuidString)"
        )

        Task {
            await channel.subscribe()
            for await _ in changes {
                if let event = try? await fetchEvent(id: eventId) {
                    onUpdate(event)
                }
            }
        }

        return channel
    }
}

// MARK: - AnyJSON Helper
enum AnyJSON: Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyJSON])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}
