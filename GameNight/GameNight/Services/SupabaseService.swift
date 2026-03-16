import Foundation
import Supabase
import Combine

protocol EventEditingProviding: AnyObject {
    func currentUserId() async throws -> UUID
    func fetchEvent(id: UUID) async throws -> GameEvent
    func createEvent(_ event: GameEvent) async throws -> GameEvent
    func updateEvent(_ event: GameEvent) async throws
    func createTimeOptions(_ timeOptions: [TimeOption]) async throws
    func upsertTimeOptions(_ timeOptions: [TimeOption]) async throws
    func deleteTimeOptions(eventId: UUID) async throws
    func deleteTimeOptions(ids: [UUID]) async throws
    func createEventGames(eventId: UUID, games: [EventGame]) async throws
    func upsertEventGames(eventId: UUID, games: [EventGame]) async throws
    func deleteEventGames(eventId: UUID) async throws
    func deleteEventGames(ids: [UUID]) async throws
    func fetchInvites(eventId: UUID) async throws -> [Invite]
    func createInvites(_ invites: [Invite]) async throws
    func updateInvite(_ invite: Invite) async throws
    func deleteInvites(ids: [UUID]) async throws
    func fetchFrequentContacts(limit: Int) async throws -> [FrequentContact]
    func upsertGame(_ game: Game) async throws -> Game
}

private struct EventSoftDeletePatch: Encodable {
    let deletedAt: Date
    let status: EventStatus
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case deletedAt = "deleted_at"
        case status
        case updatedAt = "updated_at"
    }
}

@MainActor
final class SupabaseService: ObservableObject, HomeDataProviding, EventEditingProviding {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: Secrets.supabaseURL,
            supabaseKey: Secrets.supabasePublishableKey
        )
    }

    // MARK: - Auth

    func currentUserId() async throws -> UUID {
        let session = try await client.auth.session
        return session.user.id
    }

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

    func invokeAuthenticatedFunction(
        _ functionName: String,
        body: some Encodable
    ) async throws {
        let session = try await client.auth.session
        try await client.functions.invoke(
            functionName,
            options: .init(
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: body
            )
        )
    }

    func invokeAuthenticatedFunction<Response: Decodable>(
        _ functionName: String,
        body: some Encodable,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Response {
        let session = try await client.auth.session
        return try await client.functions.invoke(
            functionName,
            options: .init(
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: body
            ),
            decoder: decoder
        )
    }

    // MARK: - Events

    func fetchUpcomingEvents() async throws -> [GameEvent] {
        let session = try await client.auth.session

        let publicEvents: [GameEvent] = try await client
            .from("events")
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)")
            .eq("visibility", value: EventVisibility.public.rawValue)
            .or("status.eq.published,status.eq.confirmed")
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value

        let hostedEvents: [GameEvent] = try await client
            .from("events")
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)")
            .eq("host_id", value: session.user.id.uuidString)
            .or("status.eq.published,status.eq.confirmed")
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value

        var mergedById = Dictionary(uniqueKeysWithValues: publicEvents.map { ($0.id, $0) })
        for event in hostedEvents {
            mergedById[event.id] = event
        }

        return mergedById.values.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchEvents(ids: [UUID]) async throws -> [GameEvent] {
        guard !ids.isEmpty else { return [] }

        let events: [GameEvent] = try await client
            .from("events")
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)")
            .in("id", values: ids.map(\.uuidString))
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value

        return events
    }

    func fetchMyEvents() async throws -> [GameEvent] {
        let session = try await client.auth.session
        let events: [GameEvent] = try await client
            .from("events")
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)")
            .eq("host_id", value: session.user.id.uuidString)
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value
        return events
    }

    func fetchDrafts() async throws -> [GameEvent] {
        let session = try await client.auth.session
        let events: [GameEvent] = try await client
            .from("events")
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)")
            .eq("host_id", value: session.user.id.uuidString)
            .eq("status", value: "draft")
            .is("deleted_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()
            .value
        return events
    }

    func fetchEvent(id: UUID) async throws -> GameEvent {
        let event: GameEvent = try await client
            .from("events")
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)")
            .eq("id", value: id.uuidString)
            .is("deleted_at", value: nil)
            .single()
            .execute()
            .value
        return event
    }

    func createEvent(_ event: GameEvent) async throws -> GameEvent {
        let created: GameEvent = try await client
            .from("events")
            .insert(event)
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)")
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

    func softDeleteEvent(id: UUID) async throws {
        let updates: [String: AnyJSON] = [
            "deleted_at": .string(ISO8601DateFormatter().string(from: Date())),
            "status": .string("cancelled")
        ]
        try await client
            .from("events")
            .update(updates)
            .eq("id", value: id.uuidString)
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

    func upsertTimeOptions(_ timeOptions: [TimeOption]) async throws {
        guard !timeOptions.isEmpty else { return }
        try await client
            .from("time_options")
            .upsert(timeOptions, onConflict: "id")
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

    func upsertEventGames(eventId: UUID, games: [EventGame]) async throws {
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
            .upsert(inserts, onConflict: "id")
            .execute()
    }

    func deleteTimeOptions(eventId: UUID) async throws {
        try await client
            .from("time_options")
            .delete()
            .eq("event_id", value: eventId.uuidString)
            .execute()
    }

    func deleteTimeOptions(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        try await client
            .from("time_options")
            .delete()
            .in("id", values: ids.map(\.uuidString))
            .execute()
    }

    func deleteEventGames(eventId: UUID) async throws {
        try await client
            .from("event_games")
            .delete()
            .eq("event_id", value: eventId.uuidString)
            .execute()
    }

    func deleteEventGames(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        try await client
            .from("event_games")
            .delete()
            .in("id", values: ids.map(\.uuidString))
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
            .select("*, event:events(*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*))")
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

        // Trigger tiered invite processing on decline
        if status == .declined {
            try await invokeAuthenticatedFunction(
                "process-tiered-invites",
                body: ["invite_id": inviteId.uuidString]
            )
        }
    }

    func createInvites(_ invites: [Invite]) async throws {
        let normalizedInvites = invites.map { invite in
            var normalizedInvite = invite
            normalizedInvite.phoneNumber = ContactPickerService.normalizePhone(invite.phoneNumber)
            return normalizedInvite
        }

        try await client
            .from("invites")
            .insert(normalizedInvites)
            .execute()

        // Trigger SMS sending for active invites
        let activeInvites = normalizedInvites.filter { $0.isActive }
        for invite in activeInvites {
            do {
                try await invokeAuthenticatedFunction(
                    "send-invite",
                    body: [
                        "invite_id": invite.id.uuidString
                    ]
                )
            } catch {
                // Invite creation has already succeeded; delivery failures should be retriable, not fatal.
                print("send-invite failed for \(invite.id): \(error.localizedDescription)")
            }
        }
    }

    func updateInvite(_ invite: Invite) async throws {
        var normalizedInvite = invite
        normalizedInvite.phoneNumber = ContactPickerService.normalizePhone(invite.phoneNumber)
        try await client
            .from("invites")
            .update(normalizedInvite)
            .eq("id", value: invite.id.uuidString)
            .execute()
    }

    func deleteInvites(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        try await client
            .from("invites")
            .delete()
            .in("id", values: ids.map(\.uuidString))
            .execute()
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
        var entry: [String: AnyJSON] = [
            "user_id": .string(session.user.id.uuidString),
            "game_id": .string(gameId.uuidString),
            "play_count": .int(0)
        ]
        if let categoryId = categoryId {
            entry["category_id"] = .string(categoryId.uuidString)
        }
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
        if game.bggId != nil {
            let saved: Game = try await client
                .from("games")
                .upsert(game, onConflict: "bgg_id")
                .select()
                .single()
                .execute()
                .value
            return saved
        } else {
            let saved: Game = try await client
                .from("games")
                .insert(game)
                .select()
                .single()
                .execute()
                .value
            return saved
        }
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

    // MARK: - Saved Contacts

    func fetchSavedContacts() async throws -> [SavedContact] {
        let session = try await client.auth.session
        let contacts: [SavedContact] = try await client
            .from("saved_contacts")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .order("name")
            .execute()
            .value
        return contacts
    }

    func saveContacts(_ contacts: [UserContact]) async throws -> [SavedContact] {
        let session = try await client.auth.session
        let toSave = contacts.map { contact in
            SavedContact(
                id: UUID(),
                userId: session.user.id,
                name: contact.name,
                phoneNumber: contact.phoneNumber,
                avatarUrl: contact.avatarUrl,
                isAppUser: contact.isAppUser,
                createdAt: nil
            )
        }
        let saved: [SavedContact] = try await client
            .from("saved_contacts")
            .upsert(toSave, onConflict: "user_id,phone_number")
            .select()
            .execute()
            .value
        return saved
    }

    func deleteSavedContact(id: UUID) async throws {
        try await client
            .from("saved_contacts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func fetchFrequentContacts(limit: Int = 20) async throws -> [FrequentContact] {
        let session = try await client.auth.session
        let contacts: [FrequentContact] = try await client
            .rpc("get_frequent_contacts", params: [
                "requesting_user_id": session.user.id.uuidString,
                "max_results": "\(limit)"
            ])
            .execute()
            .value
        return contacts
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

    // MARK: - Activity Feed

    func fetchActivityFeed(eventId: UUID) async throws -> [ActivityFeedItem] {
        let items: [ActivityFeedItem] = try await client
            .from("activity_feed")
            .select("*, user:users(*)")
            .eq("event_id", value: eventId.uuidString)
            .order("created_at")
            .execute()
            .value
        return items
    }

    func postComment(eventId: UUID, content: String, parentId: UUID?) async throws {
        let session = try await client.auth.session
        var entry: [String: AnyJSON] = [
            "event_id": .string(eventId.uuidString),
            "user_id": .string(session.user.id.uuidString),
            "type": .string("comment"),
            "content": .string(content)
        ]
        if let parentId {
            entry["parent_id"] = .string(parentId.uuidString)
        }
        try await client
            .from("activity_feed")
            .insert(entry)
            .execute()
    }

    func postAnnouncement(eventId: UUID, content: String) async throws {
        let session = try await client.auth.session
        let entry: [String: AnyJSON] = [
            "event_id": .string(eventId.uuidString),
            "user_id": .string(session.user.id.uuidString),
            "type": .string("announcement"),
            "content": .string(content)
        ]
        try await client
            .from("activity_feed")
            .insert(entry)
            .execute()
    }

    func togglePinComment(itemId: UUID, isPinned: Bool) async throws {
        let updates: [String: AnyJSON] = ["is_pinned": .bool(isPinned)]
        try await client
            .from("activity_feed")
            .update(updates)
            .eq("id", value: itemId.uuidString)
            .execute()
    }

    func deleteComment(itemId: UUID) async throws {
        try await client
            .from("activity_feed")
            .delete()
            .eq("id", value: itemId.uuidString)
            .execute()
    }

    // MARK: - Game Voting

    func fetchGameVotes(eventId: UUID) async throws -> [GameVote] {
        let votes: [GameVote] = try await client
            .from("game_votes")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value
        return votes
    }

    func upsertGameVote(eventId: UUID, gameId: UUID, voteType: GameVoteType) async throws {
        let session = try await client.auth.session
        let entry: [String: AnyJSON] = [
            "event_id": .string(eventId.uuidString),
            "game_id": .string(gameId.uuidString),
            "user_id": .string(session.user.id.uuidString),
            "vote_type": .string(voteType.rawValue)
        ]
        try await client
            .from("game_votes")
            .upsert(entry, onConflict: "event_id,game_id,user_id")
            .execute()
    }

    func deleteGameVote(eventId: UUID, gameId: UUID) async throws {
        let session = try await client.auth.session
        try await client
            .from("game_votes")
            .delete()
            .eq("event_id", value: eventId.uuidString)
            .eq("game_id", value: gameId.uuidString)
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
    }

    func confirmGame(eventId: UUID, gameId: UUID) async throws {
        let updates: [String: AnyJSON] = [
            "confirmed_game_id": .string(gameId.uuidString)
        ]
        try await client
            .from("events")
            .update(updates)
            .eq("id", value: eventId.uuidString)
            .execute()
    }

    // MARK: - Realtime

    func subscribeToActivityFeed(eventId: UUID, onUpdate: @escaping () -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("activity-\(eventId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "activity_feed",
            filter: .eq("event_id", value: eventId)
        )

        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                onUpdate()
            }
        }

        return channel
    }

    func subscribeToEventUpdates(eventId: UUID, onUpdate: @escaping (GameEvent) -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("event-\(eventId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "invites",
            filter: .eq("event_id", value: eventId)
        )

        Task {
            try? await channel.subscribeWithError()
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
