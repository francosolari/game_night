import Foundation
import Supabase
import Combine

protocol EventEditingProviding: AnyObject {
    func currentUserId() async throws -> UUID
    func fetchEvent(id: UUID) async throws -> GameEvent
    func createEvent(_ event: GameEvent) async throws -> GameEvent
    func updateEvent(_ event: GameEvent) async throws
    func updateEventCoverImageUrl(eventId: UUID, coverImageUrl: String) async throws
    func createTimeOptions(_ timeOptions: [TimeOption]) async throws
    func upsertTimeOptions(_ timeOptions: [TimeOption]) async throws
    func deleteTimeOptions(eventId: UUID) async throws
    func deleteTimeOptions(ids: [UUID]) async throws
    func resetEventPollState(eventId: UUID) async throws
    func resetEventRSVPsForScheduleChange(eventId: UUID) async throws
    func createEventGames(eventId: UUID, games: [EventGame]) async throws
    func upsertEventGames(eventId: UUID, games: [EventGame]) async throws
    func deleteEventGames(eventId: UUID) async throws
    func deleteEventGames(ids: [UUID]) async throws
    func fetchInvites(eventId: UUID) async throws -> [Invite]
    func createInvites(_ invites: [Invite]) async throws
    func updateInvite(_ invite: Invite) async throws
    func deleteInvites(ids: [UUID]) async throws
    func fetchFrequentContacts(limit: Int) async throws -> [FrequentContact]
    func fetchSavedContacts() async throws -> [SavedContact]
    func fetchGroups() async throws -> [GameGroup]
    func upsertGame(_ game: Game) async throws -> Game
    func updateGame(_ game: Game) async throws
    func updateGameImageUrl(gameId: UUID, imageUrl: String) async throws
    func addGameToLibrary(gameId: UUID, categoryId: UUID?) async throws
    func fetchGameLibrary() async throws -> [GameLibraryEntry]
    func upsertExpansionLinks(baseGameId: UUID, expansionGameIds: [UUID]) async throws
    func upsertFamilyLinks(gameId: UUID, families: [(bggFamilyId: Int, name: String)]) async throws
}

private struct BetaUserPayload: Encodable {
    let phone: String
    let password: String
    let mode: String
    let betaPassword: String

    enum CodingKeys: String, CodingKey {
        case phone
        case password
        case mode
        case betaPassword = "betaPassword"
    }
}

private struct BetaUserProbePayload: Encodable {
    let phone: String
    let mode: String
    let betaPassword: String
}

struct BetaUserProbeResponse: Decodable {
    let exists: Bool
    let userId: String?
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
    static let eventSelect = "*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*), groups(id, name, emoji)"

    let client: SupabaseClient
    private struct FrequentContactsCacheEntry: Codable {
        let fetchedAt: Date
        let contacts: [FrequentContact]
    }
    private enum FrequentContactsCacheStorage {
        static let keyPrefix = "frequent_contacts_cache"
    }
    private var frequentContactsCache: [UUID: FrequentContactsCacheEntry] = [:]
    private var frequentContactsInFlight: [UUID: Task<[FrequentContact], Error>] = [:]
    private let frequentContactsCacheTTL: TimeInterval = 24 * 60 * 60

    private init() {
        self.client = SupabaseClient(
            supabaseURL: Secrets.supabaseURL,
            supabaseKey: Secrets.supabasePublishableKey
        )
    }

    func probeBetaUser(phoneNumber: String, betaPassword: String) async throws -> BetaUserProbeResponse {
        try await client.functions.invoke(
            "beta-ensure-user",
            options: .init(body: BetaUserProbePayload(phone: phoneNumber, mode: "probe", betaPassword: betaPassword))
        )
    }

    func ensureBetaUser(phoneNumber: String, password: String, betaPassword: String) async throws {
        struct EnsureBetaUserResponse: Decodable {
            let success: Bool
            let userId: String?
        }

        _ = try await client.functions.invoke(
            "beta-ensure-user",
            options: .init(
                body: BetaUserPayload(
                    phone: phoneNumber,
                    password: password,
                    mode: "ensure",
                    betaPassword: betaPassword
                )
            ),
            decoder: JSONDecoder()
        ) as EnsureBetaUserResponse
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

    // MARK: - Password Auth (Beta Bypass)

    func signUpWithPassword(phoneNumber: String, password: String) async throws {
        do {
            try await client.auth.signUp(
                phone: phoneNumber,
                password: password
            )
            print("✅ [SupabaseService] Successfully signed up user with phone: \(phoneNumber).")
        } catch {
            let message = String(describing: error).lowercased()
            if message.contains("sms_send_failed") {
                // Beta flow intentionally bypasses OTP delivery failures.
                print("⚠️ [SupabaseService] SMS send failed for \(phoneNumber). Bypassing OTP for beta sign-up.")
                return
            }
            print("❌ [SupabaseService] Unexpected error during signUpWithPassword: \(error)")
            throw error
        }
    }

    func signInWithPassword(phoneNumber: String, password: String) async throws {
        try await client.auth.signIn(
            phone: phoneNumber,
            password: password
        )
    }

    /// Validates the locally-cached session is accepted server-side.
    /// Returns true if the session is valid (or on network failure — give benefit of the doubt).
    /// Returns false only on a definitive auth rejection (bad_jwt, invalid token).
    /// Signs out the local session on hard rejection to clear the bad keychain entry.
    func validateSession() async -> Bool {
        do {
            let session = try await client.auth.session
            guard Self.isLikelyJWT(session.accessToken) else {
                print("⚠️ [SupabaseService] Local session token is malformed. Clearing keychain.")
                try? await client.auth.signOut()
                return false
            }
            // One lightweight authenticated DB call to confirm the JWT is accepted.
            let _: [[String: String]] = try await client
                .from("users")
                .select("id")
                .eq("id", value: session.user.id.uuidString)
                .limit(1)
                .execute()
                .value
            return true
        } catch let error as HTTPError where Self.isDefinitiveAuthRejection(error.response.statusCode) {
            // Hard auth rejection — the token is invalid server-side. Clear the stale session.
            print("⚠️ [SupabaseService] Session rejected by server (bad_jwt). Clearing keychain.")
            try? await client.auth.signOut()
            return false
        } catch {
            // Network error, timeout, etc. — don't sign the user out; let them proceed.
            print("⚠️ [SupabaseService] Session validation network error (giving benefit of doubt): \(error)")
            return true
        }
    }

    /// Returns true if an HTTP status code is a definitive server-side auth rejection.
    /// Extracted as a static pure function so it can be unit tested without a network stack.
    static func isDefinitiveAuthRejection(_ statusCode: Int) -> Bool {
        statusCode == 401 || statusCode == 403
    }

    private static func isLikelyJWT(_ token: String) -> Bool {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 3 && parts.allSatisfy { !$0.isEmpty }
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

    /// Upserts the user profile. Uses upsert (not update) so that if the handle_new_user
    /// trigger failed silently, the row is still created on first profile save.
    func updateUser(_ user: User) async throws {
        try await client
            .from("users")
            .upsert(user, onConflict: "id")
            .execute()
    }

    func updateCurrentUserTimeZoneIdentifier(_ timeZoneIdentifier: String) async throws {
        let session = try await client.auth.session
        let updates: [String: AnyJSON] = ["time_zone_identifier": .string(timeZoneIdentifier)]
        try await client
            .from("users")
            .update(updates)
            .eq("id", value: session.user.id.uuidString)
            .execute()
    }

    func fetchMyProfileSummary() async throws -> UserProfileSummary {
        let summaries: [UserProfileSummary] = try await client
            .rpc("get_my_profile_summary")
            .execute()
            .value

        guard let summary = summaries.first else {
            throw NSError(
                domain: "SupabaseService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Profile summary not found"]
            )
        }

        return summary
    }

    func invokeAuthenticatedFunction(
        _ functionName: String,
        body: some Encodable
    ) async throws {
        try await ensureSessionReadyForAuthenticatedCalls()
        try await invokeFunctionWithAuthRecovery(functionName) {
            try await self.client.functions.invoke(functionName, options: .init(body: body))
        }
    }

    func invokeAuthenticatedFunction<Response: Decodable>(
        _ functionName: String,
        body: some Encodable,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Response {
        // Let the SDK handle auth — it correctly handles the new sb_publishable_ key format.
        // Do NOT pass Authorization manually; the SDK injects the session JWT automatically.
        print("[Supabase] invokeAuthenticatedFunction<\(Response.self)> '\(functionName)' via SDK")
        try await ensureSessionReadyForAuthenticatedCalls()
        return try await invokeFunctionWithAuthRecovery(functionName) {
            let result: Response = try await self.client.functions.invoke(
                functionName,
                options: .init(body: body),
                decoder: decoder
            )
            print("[Supabase] '\(functionName)' succeeded")
            return result
        }
    }

    private func ensureSessionReadyForAuthenticatedCalls() async throws {
        let session = try await client.auth.session
        guard Self.isLikelyJWT(session.accessToken) else {
            print("⚠️ [SupabaseService] Malformed local access token, forcing re-auth.")
            try? await client.auth.signOut()
            throw NSError(
                domain: "SupabaseService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Session token is invalid. Please sign in again."]
            )
        }
    }

    private func invokeFunctionWithAuthRecovery<T>(
        _ functionName: String,
        invoke: () async throws -> T
    ) async throws -> T {
        do {
            return try await invoke()
        } catch let err as FunctionsError {
            switch err {
            case .httpError(let code, let data):
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                print("[Supabase] '\(functionName)' HTTP \(code): \(body)")

                guard Self.isDefinitiveAuthRejection(code) else {
                    throw err
                }

                print("[Supabase] '\(functionName)' got auth rejection. Refreshing session and retrying once.")
                do {
                    _ = try await client.auth.refreshSession()
                    try await ensureSessionReadyForAuthenticatedCalls()
                } catch {
                    print("[Supabase] '\(functionName)' refresh failed. Clearing keychain.")
                    try? await client.auth.signOut()
                    throw error
                }

                do {
                    return try await invoke()
                } catch let retryErr as FunctionsError {
                    if case .httpError(let retryCode, _) = retryErr,
                       Self.isDefinitiveAuthRejection(retryCode) {
                        print("[Supabase] '\(functionName)' still unauthorized after retry. Clearing keychain.")
                        try? await client.auth.signOut()
                    }
                    throw retryErr
                }
            case .relayError:
                print("[Supabase] '\(functionName)' relay error")
                throw err
            }
        }
    }

    // MARK: - Events

    func fetchUpcomingEvents() async throws -> [GameEvent] {
        let userId = try await homeUserId()

        let activeStatuses = "status.eq.published,status.eq.confirmed,status.eq.completed"

        let publicEvents: [GameEvent] = try await client
            .from("events")
            .select(Self.eventSelect)
            .eq("visibility", value: EventVisibility.public.rawValue)
            .or(activeStatuses)
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value

        let hostedEvents: [GameEvent] = try await client
            .from("events")
            .select(Self.eventSelect)
            .eq("host_id", value: userId)
            .or(activeStatuses)
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
            .select(Self.eventSelect)
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
            .select(Self.eventSelect)
            .eq("host_id", value: session.user.id.uuidString)
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value
        return events
    }

    func fetchDrafts() async throws -> [GameEvent] {
        let userId = try await homeUserId()
        let events: [GameEvent] = try await client
            .from("events")
            .select(Self.eventSelect)
            .eq("host_id", value: userId)
            .eq("status", value: "draft")
            .is("deleted_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()
            .value
        return events
    }

    func fetchAcceptedInviteCounts(eventIds: [UUID]) async throws -> [UUID: Int] {
        guard !eventIds.isEmpty else { return [:] }

        struct InviteRow: Decodable {
            let eventId: UUID
            enum CodingKeys: String, CodingKey {
                case eventId = "event_id"
            }
        }

        let ids = eventIds.map { $0.uuidString }
        let invites: [InviteRow] = try await client
            .from("invites")
            .select("event_id")
            .in("event_id", values: ids)
            .eq("status", value: InviteStatus.accepted.rawValue)
            .execute()
            .value

        var counts: [UUID: Int] = [:]
        for invite in invites {
            counts[invite.eventId, default: 0] += 1
        }
        return counts
    }

    func fetchEvent(id: UUID) async throws -> GameEvent {
        let event: GameEvent = try await client
            .from("events")
            .select(Self.eventSelect)
            .eq("id", value: id.uuidString)
            .is("deleted_at", value: nil)
            .single()
            .execute()
            .value
        return event
    }

    func fetchEventId(byShareToken shareToken: String) async throws -> UUID {
        struct EventIdRow: Decodable { let id: UUID }
        let row: EventIdRow = try await client
            .from("events")
            .select("id")
            .eq("share_token", value: shareToken)
            .is("deleted_at", value: nil)
            .single()
            .execute()
            .value
        return row.id
    }

    func createEvent(_ event: GameEvent) async throws -> GameEvent {
        let created: GameEvent = try await client
            .from("events")
            .insert(event)
            .select()
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

    func updateEventCoverImageUrl(eventId: UUID, coverImageUrl: String) async throws {
        let updates: [String: AnyJSON] = ["cover_image_url": .string(coverImageUrl)]
        try await client
            .from("events")
            .update(updates)
            .eq("id", value: eventId.uuidString)
            .execute()
    }

    func clearEventCoverImageUrl(eventId: UUID) async throws {
        let updates: [String: AnyJSON] = ["cover_image_url": .null]
        try await client
            .from("events")
            .update(updates)
            .eq("id", value: eventId.uuidString)
            .execute()
    }

    /// Marks past events as completed server-side. Call on app launch / home load.
    func completePastEvents() async {
        _ = try? await client.rpc("complete_past_events").execute()
    }

    /// Inserts reminder notifications for completed events with no play log yet.
    /// The reminder threshold is next-day noon in each recipient user's local timezone.
    func sendPendingPlayLogReminders() async {
        _ = try? await client.rpc("notify_unlogged_play_reminders").execute()
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

    private struct EventGameCreateInsert: Encodable {
        let eventId: UUID
        let gameId: UUID
        let isPrimary: Bool
        let sortOrder: Int

        enum CodingKeys: String, CodingKey {
            case eventId = "event_id"
            case gameId = "game_id"
            case isPrimary = "is_primary"
            case sortOrder = "sort_order"
        }
    }

    func createEventGames(eventId: UUID, games: [EventGame]) async throws {
        guard !games.isEmpty else { return }
        let inserts = games.map { game in
            EventGameCreateInsert(
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
        let userId = try await homeUserId()

        let invites: [Invite] = try await client
            .from("invites")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        print("📨 [SupabaseService] fetchMyInvites assigned: \(invites.count)")
        return invites
    }

    private func homeUserId() async throws -> String {
        if let currentUserId = client.auth.currentSession?.user.id.uuidString {
            return currentUserId
        }
        let session = try await client.auth.session
        return session.user.id.uuidString
    }

    func fetchInvite(id: UUID) async throws -> Invite {
        let invite: Invite = try await client
            .from("invites")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return invite
    }

    func fetchUserById(_ userId: UUID) async throws -> User {
        let user: User = try await client
            .from("users")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        return user
    }

    func respondToInvite(inviteId: UUID, status: InviteStatus, timeVotes: [TimeOptionVote], suggestedTimes: [TimeOption]?) async throws {
        struct VoteParam: Encodable {
            let timeOptionId: String
            let voteType: String
            enum CodingKeys: String, CodingKey {
                case timeOptionId = "time_option_id"
                case voteType = "vote_type"
            }
        }
        struct SuggestedTimeParam: Encodable {
            let date: String
            let startTime: String
            let endTime: String?
            let label: String?
            enum CodingKeys: String, CodingKey {
                case date, label
                case startTime = "start_time"
                case endTime = "end_time"
            }
        }
        struct RespondParams: Encodable {
            let pInviteId: String
            let pStatus: String
            let pVotes: [VoteParam]
            let pSuggestedTimes: [SuggestedTimeParam]
            enum CodingKeys: String, CodingKey {
                case pInviteId = "p_invite_id"
                case pStatus = "p_status"
                case pVotes = "p_votes"
                case pSuggestedTimes = "p_suggested_times"
            }
        }

        let iso = ISO8601DateFormatter()
        let votes = timeVotes.map { VoteParam(timeOptionId: $0.timeOptionId.uuidString, voteType: $0.voteType.rawValue) }
        let suggested = (suggestedTimes ?? []).map { t in
            SuggestedTimeParam(
                date: iso.string(from: t.date),
                startTime: iso.string(from: t.startTime),
                endTime: t.endTime.map { iso.string(from: $0) },
                label: t.label
            )
        }

        // Use the respond_to_invite RPC which correctly sets event_participant_id on votes
        try await client
            .rpc("respond_to_invite", params: RespondParams(
                pInviteId: inviteId.uuidString,
                pStatus: status.rawValue,
                pVotes: votes,
                pSuggestedTimes: suggested
            ))
            .execute()

        // Auto-save the host as a contact (fire-and-forget) — fetch the invite to get hostUserId
        Task {
            if let invite = try? await fetchInvite(id: inviteId),
               let hostId = invite.hostUserId {
                if let hostUser = try? await fetchUserById(hostId) {
                    let contact = UserContact(
                        id: UUID(),
                        name: hostUser.displayName,
                        phoneNumber: hostUser.phoneNumber,
                        avatarUrl: hostUser.avatarUrl,
                        isAppUser: true
                    )
                    _ = try? await saveContacts([contact])
                }
            }
        }

        // Trigger tiered invite processing on decline without blocking RSVP UI.
        if status == .declined {
            Task {
                try? await self.invokeAuthenticatedFunction(
                    "process-tiered-invites",
                    body: ["invite_id": inviteId.uuidString]
                )
            }
        }
    }

    func fetchMyPollVotes(inviteId: UUID) async throws -> [UUID: TimeOptionVoteType] {
        struct VoteRow: Decodable {
            let timeOptionId: UUID
            let voteType: String
            enum CodingKeys: String, CodingKey {
                case timeOptionId = "time_option_id"
                case voteType = "vote_type"
            }
        }

        let rows: [VoteRow] = try await client
            .from("time_option_votes")
            .select("time_option_id, vote_type")
            .eq("invite_id", value: inviteId.uuidString)
            .execute()
            .value

        var result: [UUID: TimeOptionVoteType] = [:]
        for row in rows {
            if let voteType = TimeOptionVoteType(rawValue: row.voteType) {
                result[row.timeOptionId] = voteType
            }
        }
        return result
    }

    func createInvites(_ invites: [Invite]) async throws {
        guard !invites.isEmpty else { return }
        let normalizedInvites = invites.map { invite in
            var normalizedInvite = invite
            normalizedInvite.phoneNumber = ContactPickerService.normalizePhone(invite.phoneNumber)
            return normalizedInvite
        }

        try await client
            .from("invites")
            .insert(normalizedInvites)
            .execute()

        // Auto-save invitees as contacts (fire-and-forget)
        Task {
            let contacts = normalizedInvites.map { invite in
                UserContact(
                    id: UUID(),
                    name: invite.displayName ?? invite.phoneNumber,
                    phoneNumber: invite.phoneNumber,
                    avatarUrl: nil,
                    isAppUser: invite.userId != nil
                )
            }
            _ = try? await saveContacts(contacts)
        }

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

    func fetchGame(id: UUID) async throws -> Game? {
        let games: [Game] = try await client
            .from("games")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return games.first
    }

    /// Search the cached BGG games table by name (local-first, no BGG API call).
    func searchCachedGames(query: String) async throws -> [Game] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        struct SearchGamesFuzzyParams: Encodable {
            let searchQuery: String
            let resultLimit: Int

            enum CodingKeys: String, CodingKey {
                case searchQuery = "search_query"
                case resultLimit = "result_limit"
            }
        }

        let games: [Game] = try await client
            .rpc("search_games_fuzzy", params: SearchGamesFuzzyParams(
                searchQuery: normalizedQuery,
                resultLimit: 100
            ))
            .execute()
            .value
        return games
    }

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

    func fetchGameLibraryForUser(userId: UUID) async throws -> [GameLibraryEntry] {
        let entries: [GameLibraryEntry] = try await client
            .from("game_library")
            .select("*, game:games(*)")
            .eq("user_id", value: userId.uuidString)
            .order("added_at", ascending: false)
            .execute()
            .value
        return entries
    }

    func fetchWishlistForUser(userId: UUID) async throws -> [GameWishlistEntry] {
        return try await client
            .from("game_wishlist")
            .select("*, game:games(*)")
            .eq("user_id", value: userId.uuidString)
            .order("added_at", ascending: false)
            .execute()
            .value
    }

    func updateGroupMemberRole(memberId: UUID, role: GroupMemberRole) async throws {
        try await client
            .from("group_members")
            .update(["role": role.rawValue])
            .eq("id", value: memberId.uuidString)
            .execute()
    }

    func addGameToLibrary(gameId: UUID, categoryId: UUID?) async throws {
        struct AddGameToLibraryParams: Encodable {
            let gameId: UUID
            let categoryId: UUID?

            enum CodingKeys: String, CodingKey {
                case gameId = "p_game_id"
                case categoryId = "p_category_id"
            }
        }

        _ = try await client
            .rpc("add_game_to_collection", params: AddGameToLibraryParams(gameId: gameId, categoryId: categoryId))
            .execute()
    }

    func removeGameFromLibrary(entryId: UUID) async throws {
        try await client
            .from("game_library")
            .delete()
            .eq("id", value: entryId.uuidString)
            .execute()
    }

    func libraryEntryId(gameId: UUID) async throws -> UUID? {
        struct EntryIdRow: Decodable { let id: UUID }
        let session = try await client.auth.session
        let entries: [EntryIdRow] = try await client
            .from("game_library")
            .select("id")
            .eq("user_id", value: session.user.id.uuidString)
            .eq("game_id", value: gameId.uuidString)
            .limit(1)
            .execute()
            .value
        return entries.first?.id
    }

    func libraryEntryIdByBGGId(_ bggId: Int) async throws -> UUID? {
        let entries = try await fetchGameLibrary()
        return entries.first(where: { $0.game?.bggId == bggId })?.id
    }

    // MARK: - Wishlist

    func fetchWishlist() async throws -> [GameWishlistEntry] {
        let entries: [GameWishlistEntry] = try await client
            .rpc("get_user_wishlist")
            .execute()
            .value
        return entries
    }

    func addToWishlist(gameId: UUID) async throws {
        let session = try await client.auth.session
        let entry: [String: AnyJSON] = [
            "user_id": .string(session.user.id.uuidString),
            "game_id": .string(gameId.uuidString),
        ]
        try await client
            .from("game_wishlist")
            .insert(entry)
            .execute()
    }

    func removeFromWishlist(entryId: UUID) async throws {
        try await client
            .from("game_wishlist")
            .delete()
            .eq("id", value: entryId.uuidString)
            .execute()
    }

    func isOnWishlist(gameId: UUID) async throws -> UUID? {
        struct EntryIdRow: Decodable { let id: UUID }
        let session = try await client.auth.session
        let entries: [EntryIdRow] = try await client
            .from("game_wishlist")
            .select("id")
            .eq("user_id", value: session.user.id.uuidString)
            .eq("game_id", value: gameId.uuidString)
            .limit(1)
            .execute()
            .value
        return entries.first?.id
    }

    func wishlistEntryIdByBGGId(_ bggId: Int) async throws -> UUID? {
        let entries = try await fetchWishlist()
        return entries.first(where: { $0.game?.bggId == bggId })?.id
    }

    func updateLibraryEntryCategory(entryId: UUID, categoryId: UUID?) async throws {
        let value: AnyJSON = categoryId.map { .string($0.uuidString) } ?? .null
        try await client
            .from("game_library")
            .update(["category_id": value])
            .eq("id", value: entryId.uuidString)
            .execute()
    }

    private func normalizedGameForUpsert(_ game: Game) async throws -> Game {
        var normalized = game
        if normalized.bggId == nil && normalized.ownerId == nil {
            let session = try await client.auth.session
            normalized.ownerId = session.user.id
        }
        return normalized
    }

    func upsertGame(_ game: Game) async throws -> Game {
        let normalizedGame = try await normalizedGameForUpsert(game)
        if game.bggId != nil {
            let saved: Game = try await client
                .from("games")
                .upsert(normalizedGame, onConflict: "bgg_id")
                .select()
                .single()
                .execute()
                .value
            return saved
        } else {
            let saved: Game = try await client
                .from("games")
                .insert(normalizedGame)
                .select()
                .single()
                .execute()
                .value
            return saved
        }
    }

    func updateGame(_ game: Game) async throws {
        try await client
            .from("games")
            .update(game)
            .eq("id", value: game.id.uuidString)
            .execute()
    }

    func updateGameImageUrl(gameId: UUID, imageUrl: String) async throws {
        let updates: [String: AnyJSON] = ["image_url": .string(imageUrl)]
        try await client
            .from("games")
            .update(updates)
            .eq("id", value: gameId.uuidString)
            .execute()
    }

    func clearGameImageUrl(gameId: UUID) async throws {
        let updates: [String: AnyJSON] = ["image_url": .null]
        try await client
            .from("games")
            .update(updates)
            .eq("id", value: gameId.uuidString)
            .execute()
    }

    // MARK: - Game Relations

    func fetchExpansions(gameId: UUID) async throws -> [Game] {
        struct ExpansionLink: Decodable {
            let expansionGameId: String
            enum CodingKeys: String, CodingKey {
                case expansionGameId = "expansion_game_id"
            }
        }
        let links: [ExpansionLink] = try await client
            .from("game_expansions")
            .select("expansion_game_id")
            .eq("base_game_id", value: gameId.uuidString)
            .execute()
            .value
        guard !links.isEmpty else { return [] }
        let ids = links.map(\.expansionGameId)
        let games: [Game] = try await client
            .from("games")
            .select()
            .in("id", values: ids)
            .execute()
            .value
        return games
    }

    func fetchBaseGame(expansionGameId: UUID) async throws -> Game? {
        struct BaseLink: Decodable {
            let baseGameId: String
            enum CodingKeys: String, CodingKey {
                case baseGameId = "base_game_id"
            }
        }
        let links: [BaseLink] = try await client
            .from("game_expansions")
            .select("base_game_id")
            .eq("expansion_game_id", value: expansionGameId.uuidString)
            .execute()
            .value
        guard let link = links.first, let baseId = UUID(uuidString: link.baseGameId) else { return nil }
        let game: Game = try await client
            .from("games")
            .select()
            .eq("id", value: baseId.uuidString)
            .single()
            .execute()
            .value
        return game
    }

    func fetchFamilyMembers(gameId: UUID) async throws -> [(family: GameFamily, games: [Game])] {
        struct FamilyLink: Decodable {
            let familyId: String
            enum CodingKeys: String, CodingKey {
                case familyId = "family_id"
            }
        }
        let links: [FamilyLink] = try await client
            .from("game_family_members")
            .select("family_id")
            .eq("game_id", value: gameId.uuidString)
            .execute()
            .value
        guard !links.isEmpty else { return [] }

        // Fetch all families in parallel
        return try await withThrowingTaskGroup(of: (GameFamily, [Game]).self) { group in
            for link in links {
                group.addTask {
                    let family: GameFamily = try await self.client
                        .from("game_families")
                        .select()
                        .eq("id", value: link.familyId)
                        .single()
                        .execute()
                        .value

                    struct MemberLink: Decodable {
                        let gameId: String
                        enum CodingKeys: String, CodingKey {
                            case gameId = "game_id"
                        }
                    }
                    let memberLinks: [MemberLink] = try await self.client
                        .from("game_family_members")
                        .select("game_id")
                        .eq("family_id", value: link.familyId)
                        .execute()
                        .value
                    let memberIds = memberLinks.map(\.gameId)
                    let games: [Game] = try await self.client
                        .from("games")
                        .select()
                        .in("id", values: memberIds)
                        .execute()
                        .value
                    return (family, games)
                }
            }

            var results: [(family: GameFamily, games: [Game])] = []
            for try await (family, games) in group {
                results.append((family: family, games: games))
            }
            return results
        }
    }

    private struct ExpansionLinkInsert: Encodable {
        let baseGameId: UUID
        let expansionGameId: UUID
        enum CodingKeys: String, CodingKey {
            case baseGameId = "base_game_id"
            case expansionGameId = "expansion_game_id"
        }
    }

    func upsertExpansionLinks(baseGameId: UUID, expansionGameIds: [UUID]) async throws {
        guard !expansionGameIds.isEmpty else { return }
        let inserts = expansionGameIds.map { ExpansionLinkInsert(baseGameId: baseGameId, expansionGameId: $0) }
        try await client
            .from("game_expansions")
            .upsert(inserts, onConflict: "base_game_id,expansion_game_id")
            .execute()
    }

    func upsertFamilyLinks(gameId: UUID, families: [(bggFamilyId: Int, name: String)]) async throws {
        for family in families {
            // Upsert family
            let familyEntry: [String: AnyJSON] = [
                "bgg_family_id": .int(family.bggFamilyId),
                "name": .string(family.name)
            ]
            let upsertedFamily: GameFamily = try await client
                .from("game_families")
                .upsert(familyEntry, onConflict: "bgg_family_id")
                .select()
                .single()
                .execute()
                .value

            // Upsert member link
            let memberEntry: [String: AnyJSON] = [
                "family_id": .string(upsertedFamily.id.uuidString),
                "game_id": .string(gameId.uuidString)
            ]
            try await client
                .from("game_family_members")
                .upsert(memberEntry, onConflict: "family_id,game_id")
                .execute()
        }
    }

    func fetchGamesByDesigner(name: String) async throws -> [Game] {
        try await client
            .rpc("fetch_games_by_designer", params: ["designer_name": name])
            .select("id,bgg_id,name,year_published,thumbnail_url,image_url,min_players,max_players,recommended_players,min_playtime,max_playtime,complexity,bgg_rating,bgg_rank,categories,mechanics,designers,publishers,artists,min_age,owner_id")
            .execute()
            .value
    }

    func fetchGamesByPublisher(name: String) async throws -> [Game] {
        try await client
            .rpc("fetch_games_by_publisher", params: ["publisher_name": name])
            .select("id,bgg_id,name,year_published,thumbnail_url,image_url,min_players,max_players,recommended_players,min_playtime,max_playtime,complexity,bgg_rating,bgg_rank,categories,mechanics,designers,publishers,artists,min_age,owner_id")
            .execute()
            .value
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

    nonisolated static func mergeOwnedAndAcceptedGroups(
        ownedGroups: [GameGroup],
        acceptedMembershipGroupIds: Set<UUID>,
        memberGroups: [GameGroup]
    ) -> [GameGroup] {
        var groupsById = Dictionary(uniqueKeysWithValues: ownedGroups.map { ($0.id, $0) })

        let memberGroupsById = Dictionary(uniqueKeysWithValues: memberGroups.map { ($0.id, $0) })
        for groupId in acceptedMembershipGroupIds where groupsById[groupId] == nil {
            if let group = memberGroupsById[groupId] {
                groupsById[groupId] = group
            }
        }

        return groupsById.values.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchGroups() async throws -> [GameGroup] {
        struct GroupMembershipRow: Decodable {
            let groupId: UUID

            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
            }
        }

        let session = try await client.auth.session

        // Groups the user owns.
        let ownedGroups: [GameGroup] = try await client
            .from("groups")
            .select("*, members:group_members(*)")
            .eq("owner_id", value: session.user.id.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        // Groups where the user has accepted membership but is not necessarily the owner.
        let acceptedMemberships: [GroupMembershipRow] = try await client
            .from("group_members")
            .select("group_id")
            .eq("user_id", value: session.user.id.uuidString)
            .eq("status", value: GroupMemberStatus.accepted.rawValue)
            .execute()
            .value

        let acceptedMembershipGroupIds = Set(acceptedMemberships.map(\.groupId))
        let ownedGroupIds = Set(ownedGroups.map(\.id))
        let missingGroupIds = acceptedMembershipGroupIds.subtracting(ownedGroupIds)

        var memberGroups: [GameGroup] = []
        if !missingGroupIds.isEmpty {
            memberGroups = try await client
                .from("groups")
                .select("*, members:group_members(*)")
                .in("id", values: missingGroupIds.map(\.uuidString))
                .order("created_at", ascending: false)
                .execute()
                .value
        }

        return Self.mergeOwnedAndAcceptedGroups(
            ownedGroups: ownedGroups,
            acceptedMembershipGroupIds: acceptedMembershipGroupIds,
            memberGroups: memberGroups
        )
    }

    func fetchGroupById(_ id: UUID) async throws -> GameGroup {
        let group: GameGroup = try await client
            .from("groups")
            .select("*, members:group_members(*)")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return group
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

    /// Fetches pending group invites for the current user — groups they've been invited to but haven't responded.
    func fetchMyPendingGroupInvites() async throws -> [(group: GameGroup, member: GroupMember)] {
        let session = try await client.auth.session

        // Step 1: fetch pending group_member rows for the current user
        let pendingMembers: [GroupMember] = try await client
            .from("group_members")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value

        guard !pendingMembers.isEmpty else { return [] }

        // Step 2: fetch the corresponding groups (accepted members only for preview)
        let groupIds = pendingMembers.map(\.groupId.uuidString)
        let groups: [GameGroup] = try await client
            .from("groups")
            .select("*, members:group_members(*)")
            .in("id", values: groupIds)
            .execute()
            .value

        let groupMap = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })

        return pendingMembers.compactMap { member in
            guard let group = groupMap[member.groupId] else { return nil }
            return (group: group, member: member)
        }
    }

    func respondToGroupInvite(memberId: UUID, accept: Bool) async throws {
        let newStatus = accept ? "accepted" : "declined"
        try await client
            .from("group_members")
            .update(["status": newStatus])
            .eq("id", value: memberId.uuidString)
            .execute()
    }

    func expireStaleGroupInvites() async throws {
        try await client.rpc("expire_stale_group_invites").execute()
    }

    func fetchGroupInvitePreview(groupId: UUID) async throws -> GroupInvitePreview {
        let response = try await client
            .rpc("get_group_invite_preview", params: ["p_group_id": groupId.uuidString])
            .execute()
        let preview = try JSONDecoder().decode(GroupInvitePreview.self, from: response.data)
        return preview
    }

    // MARK: - Saved Contacts

    func fetchSavedContacts() async throws -> [SavedContact] {
        let session = try await client.auth.session

        // Paginate to avoid PostgREST default 1000-row cap
        let pageSize = 1000
        var allContacts: [SavedContact] = []
        var offset = 0

        while true {
            let page: [SavedContact] = try await client
                .from("saved_contacts")
                .select()
                .eq("user_id", value: session.user.id.uuidString)
                .order("name")
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            allContacts.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += pageSize
        }

        guard !allContacts.isEmpty else { return allContacts }

        // Cross-reference with users table (chunked to avoid URL length limits)
        let digitsOnly = allContacts.map { $0.phoneNumber.filter(\.isNumber) }
        let appUsersByPhone = try await fetchAppUserPhones(from: digitsOnly)

        return allContacts.map { contact in
            var updated = contact
            let digits = contact.phoneNumber.filter(\.isNumber)
            if let info = appUsersByPhone[digits] {
                updated.isAppUser = true
                updated.appUserId = info.id
                // Use app user's profile avatar if contact doesn't have one
                if updated.avatarUrl == nil {
                    updated.avatarUrl = info.avatarUrl
                }
            } else {
                updated.isAppUser = false
            }
            return updated
        }
    }

    struct AppUserInfo {
        let id: UUID
        let avatarUrl: String?
    }

    /// Chunked lookup of which phone numbers belong to app users.
    /// Returns phone → (userId, avatarUrl) mapping.
    /// Splits into groups of 200 to avoid PostgREST URL length limits.
    private func fetchAppUserPhones(from phoneDigits: [String]) async throws -> [String: AppUserInfo] {
        guard !phoneDigits.isEmpty else { return [:] }
        let chunkSize = 200
        var result: [String: AppUserInfo] = [:]

        struct PhoneCheck: Decodable { let id: UUID; let phone_number: String; let avatar_url: String? }

        let unique = Array(Set(phoneDigits))
        for chunkStart in stride(from: 0, to: unique.count, by: chunkSize) {
            let chunk = Array(unique[chunkStart..<min(chunkStart + chunkSize, unique.count)])
            let results: [PhoneCheck] = try await client
                .from("users")
                .select("id,phone_number,avatar_url")
                .in("phone_number", values: chunk)
                .execute()
                .value
            for r in results {
                result[r.phone_number] = AppUserInfo(id: r.id, avatarUrl: r.avatar_url)
            }
        }
        return result
    }

    func saveContacts(_ contacts: [UserContact]) async throws -> [SavedContact] {
        guard !contacts.isEmpty else { return [] }
        let session = try await client.auth.session

        // Deduplicate by phone number (keep first occurrence)
        var seen = Set<String>()
        let uniqueContacts = contacts.filter { contact in
            let key = contact.phoneNumber.filter(\.isNumber)
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        // Fetch existing contacts to avoid upserting unchanged ones
        let existingContacts: [SavedContact] = try await client
            .from("saved_contacts")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
            .value

        let existingByPhone = Dictionary(
            existingContacts.map { ($0.phoneNumber.filter(\.isNumber), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Check which contacts are app users before saving
        let digitsOnly = uniqueContacts.map { $0.phoneNumber.filter(\.isNumber) }.filter { !$0.isEmpty }
        var appUserPhones = Set<String>()
        if !digitsOnly.isEmpty {
            struct PhoneCheck: Decodable { let phone_number: String }
            let results: [PhoneCheck] = try await client
                .from("users")
                .select("phone_number")
                .in("phone_number", values: digitsOnly)
                .execute()
                .value
            appUserPhones = Set(results.map(\.phone_number))
        }

        // Only upsert contacts that are new or have a different name
        let toUpsert = uniqueContacts.compactMap { contact -> SavedContact? in
            let normalized = contact.phoneNumber.filter(\.isNumber)
            let existing = existingByPhone[normalized]

            // Only include if new or name changed
            if existing == nil || existing?.name != contact.name {
                return SavedContact(
                    id: existing?.id ?? UUID(),
                    userId: session.user.id,
                    name: contact.name,
                    phoneNumber: contact.phoneNumber,
                    avatarUrl: contact.avatarUrl,
                    isAppUser: appUserPhones.contains(normalized),
                    createdAt: existing?.createdAt
                )
            }
            return nil
        }

        guard !toUpsert.isEmpty else { return existingContacts }

        let saved: [SavedContact] = try await client
            .from("saved_contacts")
            .upsert(toUpsert, onConflict: "user_id,phone_number")
            .select()
            .execute()
            .value
        return saved
    }

    /// Bulk-syncs device contacts to saved_contacts efficiently.
    /// Fetches existing contacts once, deduplicates, and upserts only new/changed entries.
    /// Returns the total number of contacts upserted.
    func saveContactsBulk(
        _ contacts: [UserContact],
        onBatchComplete: @Sendable (Int) -> Void = { _ in }
    ) async throws -> Int {
        guard !contacts.isEmpty else { return 0 }
        let session = try await client.auth.session

        // Deduplicate by phone number (keep first occurrence)
        var seen = Set<String>()
        let uniqueContacts = contacts.filter { contact in
            let key = contact.phoneNumber.filter(\.isNumber)
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // Fetch ALL existing contacts once (paginated)
        let pageSize = 1000
        var existingContacts: [SavedContact] = []
        var offset = 0
        while true {
            let page: [SavedContact] = try await client
                .from("saved_contacts")
                .select()
                .eq("user_id", value: session.user.id.uuidString)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            existingContacts.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += pageSize
        }

        let existingByPhone = Dictionary(
            existingContacts.map { ($0.phoneNumber.filter(\.isNumber), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Check which contacts are app users (chunked)
        let digitsOnly = uniqueContacts.map { $0.phoneNumber.filter(\.isNumber) }.filter { !$0.isEmpty }
        let appUserMap = try await fetchAppUserPhones(from: digitsOnly)

        // Filter to new or name-changed contacts only
        let toUpsert = uniqueContacts.compactMap { contact -> SavedContact? in
            let normalized = contact.phoneNumber.filter(\.isNumber)
            let existing = existingByPhone[normalized]

            if existing == nil || existing?.name != contact.name {
                let appInfo = appUserMap[normalized]
                return SavedContact(
                    id: existing?.id ?? UUID(),
                    userId: session.user.id,
                    name: contact.name,
                    phoneNumber: contact.phoneNumber,
                    avatarUrl: contact.avatarUrl ?? appInfo?.avatarUrl,
                    isAppUser: appInfo != nil,
                    createdAt: existing?.createdAt
                )
            }
            return nil
        }

        guard !toUpsert.isEmpty else { return 0 }

        // Upsert in batches of 100
        let batchSize = 100
        var totalUpserted = 0
        for batchStart in stride(from: 0, to: toUpsert.count, by: batchSize) {
            let batch = Array(toUpsert[batchStart..<min(batchStart + batchSize, toUpsert.count)])
            try await client
                .from("saved_contacts")
                .upsert(batch, onConflict: "user_id,phone_number")
                .execute()
            totalUpserted += batch.count
            onBatchComplete(totalUpserted)
        }

        return totalUpserted
    }

    func autoSaveInviteContact(name: String, phoneNumber: String, isAppUser: Bool) async {
        let contact = UserContact(id: UUID(), name: name, phoneNumber: phoneNumber, avatarUrl: nil, isAppUser: isAppUser)
        _ = try? await saveContacts([contact])
    }

    func deleteSavedContact(id: UUID) async throws {
        try await client
            .from("saved_contacts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func updateSavedContactName(id: UUID, name: String) async throws {
        try await client
            .from("saved_contacts")
            .update(["name": name])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func fetchFrequentContacts(limit: Int = 20) async throws -> [FrequentContact] {
        guard limit > 0 else { return [] }
        let session = try await client.auth.session
        let userId = session.user.id
        let now = Date()

        if let cached = frequentContactsCache[userId],
           now.timeIntervalSince(cached.fetchedAt) < frequentContactsCacheTTL,
           cached.contacts.count >= limit {
            return Array(cached.contacts.prefix(limit))
        }

        if let persisted = loadPersistedFrequentContacts(userId: userId),
           now.timeIntervalSince(persisted.fetchedAt) < frequentContactsCacheTTL,
           persisted.contacts.count >= limit {
            frequentContactsCache[userId] = persisted
            return Array(persisted.contacts.prefix(limit))
        }

        if let inFlight = frequentContactsInFlight[userId] {
            let contacts = try await inFlight.value
            return Array(contacts.prefix(limit))
        }

        let task = Task<[FrequentContact], Error> { [client] in
            try await client
                .rpc("get_frequent_contacts", params: [
                    "requesting_user_id": userId.uuidString,
                    "max_results": "\(max(limit, 20))"
                ])
                .execute()
                .value
        }
        frequentContactsInFlight[userId] = task

        do {
            let contacts = try await task.value
            let entry = FrequentContactsCacheEntry(fetchedAt: now, contacts: contacts)
            frequentContactsCache[userId] = entry
            persistFrequentContacts(entry, userId: userId)
            frequentContactsInFlight[userId] = nil
            return Array(contacts.prefix(limit))
        } catch {
            frequentContactsInFlight[userId] = nil
            throw error
        }
    }

    func clearFrequentContactsCache() {
        frequentContactsCache.removeAll()
        frequentContactsInFlight.removeAll()
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(FrequentContactsCacheStorage.keyPrefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func persistFrequentContacts(_ entry: FrequentContactsCacheEntry, userId: UUID) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        UserDefaults.standard.set(data, forKey: frequentContactsCacheKey(for: userId))
    }

    private func loadPersistedFrequentContacts(userId: UUID) -> FrequentContactsCacheEntry? {
        guard let data = UserDefaults.standard.data(forKey: frequentContactsCacheKey(for: userId)) else {
            return nil
        }
        return try? JSONDecoder().decode(FrequentContactsCacheEntry.self, from: data)
    }

    private func frequentContactsCacheKey(for userId: UUID) -> String {
        "\(FrequentContactsCacheStorage.keyPrefix).\(userId.uuidString)"
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

    // MARK: - Poll Voter Details

    func fetchTimeOptionVoters(eventId: UUID) async throws -> [TimeOptionVoter] {
        let voters: [TimeOptionVoter] = try await client
            .rpc("fetch_time_poll_voters", params: ["p_event_id": eventId.uuidString])
            .execute()
            .value
        return voters
    }

    private struct GameVoterRow: Decodable {
        let gameId: UUID
        let voteType: String
        let userId: UUID
        let displayName: String
        let avatarUrl: String?

        enum CodingKeys: String, CodingKey {
            case gameId = "game_id"
            case voteType = "vote_type"
            case userId = "user_id"
            case displayName = "display_name"
            case avatarUrl = "avatar_url"
        }
    }

    func fetchGameVoterDetails(eventId: UUID) async throws -> [GameVoterInfo] {
        let rows: [GameVoterRow] = try await client
            .rpc("fetch_game_poll_voters", params: ["p_event_id": eventId.uuidString])
            .execute()
            .value
        return rows.compactMap { row in
            guard let voteType = GameVoteType(rawValue: row.voteType) else { return nil }
            return GameVoterInfo(
                gameId: row.gameId,
                userId: row.userId,
                displayName: row.displayName,
                avatarUrl: row.avatarUrl,
                voteType: voteType
            )
        }
    }

    func confirmTimeOption(eventId: UUID, timeOptionId: UUID) async throws {
        try await client
            .rpc("confirm_time_option", params: [
                "p_event_id": eventId.uuidString,
                "p_time_option_id": timeOptionId.uuidString
            ])
            .execute()
    }

    func resetEventPollState(eventId: UUID) async throws {
        try await client
            .rpc("reset_event_poll_state", params: [
                "p_event_id": eventId.uuidString
            ])
            .execute()
    }

    func resetEventRSVPsForScheduleChange(eventId: UUID) async throws {
        try await client
            .rpc("reset_event_rsvps_for_schedule_change", params: [
                "p_event_id": eventId.uuidString
            ])
            .execute()
    }

    func confirmGame(eventId: UUID, gameId: UUID, gameName: String) async throws {
        // Set confirmed game and end game voting
        let updates: [String: AnyJSON] = [
            "confirmed_game_id": .string(gameId.uuidString),
            "allow_game_voting": .bool(false)
        ]
        try await client
            .from("events")
            .update(updates)
            .eq("id", value: eventId.uuidString)
            .execute()

        // Set confirmed game as primary, unset others
        try await client
            .from("event_games")
            .update(["is_primary": AnyJSON.bool(false)])
            .eq("event_id", value: eventId.uuidString)
            .execute()

        try await client
            .from("event_games")
            .update(["is_primary": AnyJSON.bool(true)])
            .eq("event_id", value: eventId.uuidString)
            .eq("game_id", value: gameId.uuidString)
            .execute()

        // Post game_confirmed announcement to activity feed
        let session = try await client.auth.session
        let announcement: [String: AnyJSON] = [
            "event_id": .string(eventId.uuidString),
            "user_id": .string(session.user.id.uuidString),
            "type": .string("game_confirmed"),
            "content": .string(gameName)
        ]
        try await client
            .from("activity_feed")
            .insert(announcement)
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

    // MARK: - Plays

    static let playSelect = "*, game:games(*), play_participants(*), logged_by_user:users!logged_by(*)"

    func createPlay(_ play: Play) async throws -> Play {
        let created: Play = try await client
            .from("plays")
            .insert(play)
            .select(Self.playSelect)
            .single()
            .execute()
            .value
        return created
    }

    func createPlayParticipants(_ participants: [PlayParticipant]) async throws {
        guard !participants.isEmpty else { return }
        try await client
            .from("play_participants")
            .insert(participants)
            .execute()
    }

    func fetchPlaysForEvent(eventId: UUID) async throws -> [Play] {
        let plays: [Play] = try await client
            .rpc("get_event_plays", params: ["p_event_id": eventId.uuidString])
            .execute()
            .value
        return plays
    }

    func fetchPlaysForGroup(groupId: UUID) async throws -> [Play] {
        let plays: [Play] = try await client
            .rpc("get_group_plays", params: ["p_group_id": groupId.uuidString])
            .execute()
            .value
        return plays
    }

    func fetchPlaysForGameAmongUsers(gameId: UUID, userIds: [UUID]) async throws -> [Play] {
        let plays: [Play] = try await client
            .from("plays")
            .select(Self.playSelect)
            .eq("game_id", value: gameId.uuidString)
            .order("played_at", ascending: false)
            .execute()
            .value

        let userIdSet = Set(userIds)
        return plays.filter { play in
            let playUserIds = Set(play.participants.compactMap(\.userId))
            return !playUserIds.isDisjoint(with: userIdSet)
        }
    }

    func updatePlay(_ play: Play) async throws {
        try await client
            .from("plays")
            .update(play)
            .eq("id", value: play.id.uuidString)
            .execute()
    }

    func deletePlay(id: UUID) async throws {
        struct DeletedPlayRow: Decodable { let id: UUID }
        let deleted: [DeletedPlayRow] = try await client
            .from("plays")
            .delete()
            .eq("id", value: id.uuidString)
            .select("id")
            .execute()
            .value

        guard deleted.contains(where: { $0.id == id }) else {
            throw NSError(
                domain: "SupabaseService",
                code: 403,
                userInfo: [
                    NSLocalizedDescriptionKey: "You don't have permission to delete this play."
                ]
            )
        }

        // Keep current method behavior: callers rely on throw/no-throw only.
    }

    /// Fetches avatar URLs for a list of user IDs.
    func fetchUserAvatars(userIds: [UUID]) async throws -> [UUID: String] {
        guard !userIds.isEmpty else { return [:] }
        struct UserAvatar: Decodable { let id: UUID; let avatar_url: String? }

        let chunkSize = 200
        var result: [UUID: String] = [:]
        let ids = userIds.map(\.uuidString)

        for chunkStart in stride(from: 0, to: ids.count, by: chunkSize) {
            let chunk = Array(ids[chunkStart..<min(chunkStart + chunkSize, ids.count)])
            let users: [UserAvatar] = try await client
                .from("users")
                .select("id,avatar_url")
                .in("id", values: chunk)
                .execute()
                .value
            for u in users {
                if let url = u.avatar_url { result[u.id] = url }
            }
        }
        return result
    }

    /// Replaces all participants for a play (delete + re-insert).
    func replacePlayParticipants(playId: UUID, participants: [PlayParticipant]) async throws {
        try await client
            .from("play_participants")
            .delete()
            .eq("play_id", value: playId.uuidString)
            .execute()

        if !participants.isEmpty {
            try await client
                .from("play_participants")
                .insert(participants)
                .execute()
        }
    }

    /// Updates specific fields on a play (partial update).
    func updatePlayFields(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client
            .from("plays")
            .update(fields)
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Re-fetches a single play with full joins.
    func fetchPlayById(_ id: UUID) async throws -> Play {
        let play: Play = try await client
            .from("plays")
            .select(Self.playSelect)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return play
    }

    // MARK: - Group Events

    func fetchEventsForGroup(groupId: UUID) async throws -> [GameEvent] {
        let events: [GameEvent] = try await client
            .rpc("get_group_events", params: ["p_group_id": groupId.uuidString])
            .execute()
            .value
        return events
    }

    func fetchCompletedEventsNeedingPlayLog(userId: UUID) async throws -> [GameEvent] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let formatter = ISO8601DateFormatter()
        let cutoff = formatter.string(from: sevenDaysAgo)

        // Fetch completed events where user is host
        let hostedEvents: [GameEvent] = try await client
            .from("events")
            .select(Self.eventSelect)
            .eq("host_id", value: userId.uuidString)
            .eq("status", value: "completed")
            .gte("updated_at", value: cutoff)
            .is("deleted_at", value: nil)
            .execute()
            .value

        // Fetch completed events where user has accepted invite
        let invitedEventIds: [UUID] = try await {
            struct InvRow: Decodable { let eventId: UUID; enum CodingKeys: String, CodingKey { case eventId = "event_id" } }
            let rows: [InvRow] = try await client
                .from("invites")
                .select("event_id")
                .eq("user_id", value: userId.uuidString)
                .eq("status", value: "accepted")
                .execute()
                .value
            return rows.map(\.eventId)
        }()

        var invitedEvents: [GameEvent] = []
        if !invitedEventIds.isEmpty {
            invitedEvents = try await client
                .from("events")
                .select(Self.eventSelect)
                .in("id", values: invitedEventIds.map(\.uuidString))
                .eq("status", value: "completed")
                .gte("updated_at", value: cutoff)
                .is("deleted_at", value: nil)
                .execute()
                .value
        }

        // Merge and deduplicate
        var byId = Dictionary(uniqueKeysWithValues: hostedEvents.map { ($0.id, $0) })
        for e in invitedEvents { byId[e.id] = e }
        let allCompleted = Array(byId.values)

        // Filter out events where anyone already logged a play for that event.
        let eventIds = allCompleted.map(\.id)
        guard !eventIds.isEmpty else { return [] }

        struct EventPlayRow: Decodable {
            let eventId: UUID?

            enum CodingKeys: String, CodingKey {
                case eventId = "event_id"
            }
        }

        let existingPlays: [EventPlayRow] = try await client
            .from("plays")
            .select("event_id")
            .in("event_id", values: eventIds.map(\.uuidString))
            .execute()
            .value

        let loggedEventIds = Set(existingPlays.compactMap(\.eventId))
        return allCompleted.filter { !loggedEventIds.contains($0.id) }
    }

    // MARK: - Group Messages

    func fetchGroupMessages(groupId: UUID) async throws -> [GroupMessage] {
        let messages: [GroupMessage] = try await client
            .from("group_messages")
            .select("*, user:users(*)")
            .eq("group_id", value: groupId.uuidString)
            .order("created_at")
            .execute()
            .value
        return messages
    }

    func postGroupMessage(groupId: UUID, content: String, parentId: UUID?) async throws {
        let session = try await client.auth.session
        var entry: [String: AnyJSON] = [
            "group_id": .string(groupId.uuidString),
            "user_id": .string(session.user.id.uuidString),
            "content": .string(content)
        ]
        if let parentId {
            entry["parent_id"] = .string(parentId.uuidString)
        }
        try await client
            .from("group_messages")
            .insert(entry)
            .execute()
    }

    func deleteGroupMessage(id: UUID) async throws {
        try await client
            .from("group_messages")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Notifications

    func fetchNotifications(limit: Int = 50, offset: Int = 0) async throws -> [AppNotification] {
        try await client
            .from("notifications")
            .select("*, event:events(*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*))")
            .neq("type", value: "dm_received")
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }

    func fetchUnreadNotificationCount() async throws -> Int {
        let response = try await client
            .from("notifications")
            .select("id", head: true, count: .exact)
            .neq("type", value: "dm_received")
            .is("read_at", value: nil)
            .execute()

        return response.count ?? 0
    }

    func markNotificationRead(id: UUID) async throws {
        try await client
            .from("notifications")
            .update(["read_at": Date().ISO8601Format()])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func markAllNotificationsRead() async throws {
        try await client
            .from("notifications")
            .update(["read_at": Date().ISO8601Format()])
            .is("read_at", value: nil)
            .execute()
    }

    func subscribeToNotifications(onUpdate: @escaping () -> Void) -> RealtimeChannelV2? {
        // Subscribe to all notification changes; filter is handled by RLS
        // Use a unique channel name to avoid conflicts when multiple subscribers exist
        let channel = client.realtimeV2.channel("notifications-\(UUID().uuidString.prefix(8))")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "notifications"
        )

        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                onUpdate()
            }
        }

        return channel
    }

    func fetchNotificationPreferences() async throws -> NotificationPreferences? {
        let results: [NotificationPreferences] = try await client
            .from("notification_preferences")
            .select("*")
            .execute()
            .value

        return results.first
    }

    func upsertNotificationPreferences(_ prefs: NotificationPreferences) async throws {
        try await client
            .from("notification_preferences")
            .upsert(prefs)
            .execute()
    }

    // MARK: - Push Tokens

    func registerPushToken(_ token: String, apnsEnvironment: String) async throws {
        let userId = try await currentUserId()
        struct PushTokenEntry: Encodable {
            let user_id: String
            let device_token: String
            let platform: String
            let apns_environment: String
            let updated_at: String
        }

        let normalizedEnvironment: String
        switch apnsEnvironment.lowercased() {
        case "sandbox":
            normalizedEnvironment = "sandbox"
        case "production":
            normalizedEnvironment = "production"
        default:
            normalizedEnvironment = "production"
        }

        let entry = PushTokenEntry(
            user_id: userId.uuidString,
            device_token: token,
            platform: "ios",
            apns_environment: normalizedEnvironment,
            updated_at: Date().ISO8601Format()
        )
        try await client
            .from("push_tokens")
            .upsert(entry, onConflict: "user_id,device_token,apns_environment")
            .execute()
    }

    func unregisterPushToken(_ token: String) async throws {
        try await client
            .from("push_tokens")
            .delete()
            .eq("device_token", value: token)
            .execute()
    }

    // MARK: - Direct Messages

    func fetchConversations() async throws -> [ConversationSummary] {
        try await client
            .rpc("fetch_conversations_for_user")
            .execute()
            .value
    }

    func fetchMessages(conversationId: UUID, limit: Int = 50, before: Date? = nil) async throws -> [DirectMessage] {
        var query = client
            .from("direct_messages")
            .select("*, sender:users!sender_id(*)")
            .eq("conversation_id", value: conversationId.uuidString)

        if let before = before {
            query = query.lt("created_at", value: before.ISO8601Format())
        }

        return try await query
            .order("created_at", ascending: true)
            .limit(limit)
            .execute()
            .value
    }

    func sendDirectMessage(conversationId: UUID, content: String, type: DirectMessage.MessageType = .text, metadata: MessageMetadata? = nil) async throws {
        let userId = try await currentUserId()
        struct DMEntry: Encodable {
            let conversation_id: String
            let sender_id: String
            let content: String
            let message_type: String
            let metadata: MessageMetadata?
        }
        let entry = DMEntry(
            conversation_id: conversationId.uuidString,
            sender_id: userId.uuidString,
            content: content,
            message_type: type.rawValue,
            metadata: metadata
        )
        try await client
            .from("direct_messages")
            .insert(entry)
            .execute()
    }

    func getOrCreateDM(otherUserId: UUID) async throws -> UUID {
        print("[DM] getOrCreateDM called with otherUserId: \(otherUserId)")
        do {
            let response = try await client
                .rpc("get_or_create_dm", params: ["p_other_user_id": otherUserId.uuidString])
                .execute()

            let rawBody = String(data: response.data, encoding: .utf8) ?? "<non-utf8>"
            print("[DM] Raw response body: \(rawBody)")
            print("[DM] Response status: \(response.status)")

            // Try decoding as a plain string first (scalar return)
            if let uuidString = try? JSONDecoder().decode(String.self, from: response.data),
               let uuid = UUID(uuidString: uuidString) {
                print("[DM] Decoded as scalar string UUID: \(uuid)")
                return uuid
            }

            // Try decoding as a single-element array of strings
            if let array = try? JSONDecoder().decode([String].self, from: response.data),
               let first = array.first,
               let uuid = UUID(uuidString: first) {
                print("[DM] Decoded as array[0] UUID: \(uuid)")
                return uuid
            }

            // Try raw string trimming quotes
            let trimmed = rawBody.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if let uuid = UUID(uuidString: trimmed) {
                print("[DM] Decoded from trimmed raw string UUID: \(uuid)")
                return uuid
            }

            print("[DM] ERROR: Could not parse UUID from response")
            throw NSError(domain: "GameNight", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid conversation ID: \(rawBody)"])
        } catch {
            print("[DM] ERROR: \(error)")
            throw error
        }
    }

    func markConversationRead(conversationId: UUID) async throws {
        try await client
            .rpc("mark_conversation_read", params: ["p_conversation_id": conversationId.uuidString])
            .execute()
    }

    func fetchUnreadMessageCount() async throws -> Int {
        let conversations: [ConversationSummary] = try await fetchConversations()
        return conversations.reduce(0) { $0 + $1.unreadCount }
    }

    func subscribeToDirectMessages(conversationId: UUID, onUpdate: @escaping () -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("dm-\(conversationId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "direct_messages",
            filter: .eq("conversation_id", value: conversationId)
        )

        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                onUpdate()
            }
        }

        return channel
    }

    func subscribeToGroupMessages(groupId: UUID, onUpdate: @escaping () -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("group-messages-\(groupId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "group_messages",
            filter: .eq("group_id", value: groupId)
        )

        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                onUpdate()
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
