import Foundation
import Supabase
import Combine

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
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: Secrets.supabaseURL,
            supabaseKey: Secrets.supabasePublishableKey
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
        let events: [GameEvent] = try await client
            .from("events")
            .select("*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)")
            .or("status.eq.published,status.eq.confirmed")
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
        let patch = EventSoftDeletePatch(
            deletedAt: Date(),
            status: .cancelled,
            updatedAt: Date()
        )
        try await client
            .from("events")
            .update(patch, returning: .minimal)
            .eq("id", value: id.uuidString)
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

    func respondToInvite(inviteId: UUID, status: InviteStatus, selectedTimeIds: [UUID], suggestedTimes: [TimeOption]?) async throws {
        struct SuggestedTimePayload: Encodable {
            let date: String
            let start_time: String
            let end_time: String?
            let label: String?
        }

        struct RespondToInviteParams: Encodable {
            let p_invite_id: String
            let p_status: String
            let p_selected_time_option_ids: [String]
            let p_suggested_times: [SuggestedTimePayload]
        }

        let isoDateFormatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let suggestedPayload = (suggestedTimes ?? []).map { option in
            SuggestedTimePayload(
                date: dateFormatter.string(from: option.date),
                start_time: isoDateFormatter.string(from: option.startTime),
                end_time: option.endTime.map { isoDateFormatter.string(from: $0) },
                label: option.label
            )
        }

        try await client
            .rpc("respond_to_invite", params: RespondToInviteParams(
                p_invite_id: inviteId.uuidString,
                p_status: status.rawValue,
                p_selected_time_option_ids: selectedTimeIds.map(\.uuidString),
                p_suggested_times: suggestedPayload
            ))
            .execute()

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
