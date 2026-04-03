import SwiftUI

enum PlayDetailTab: String, CaseIterable {
    case overview = "Overview"
    case placements = "Placements"
    case stats = "Stats"
}

struct PlayDetailPlayerStat: Identifiable {
    let id: UUID
    let name: String
    let playsThisGame: Int
    let wins: Int
    var winPercent: Double { playsThisGame > 0 ? Double(wins) / Double(playsThisGame) : 0 }
    let averagePlacement: Double?
    let averageScore: Double?
}

@MainActor
final class PlayDetailViewModel: ObservableObject {
    @Published var play: Play
    let currentUserId: UUID?
    var onDelete: (() async -> Void)?

    @Published var selectedTab: PlayDetailTab = .overview
    @Published var linkedEvent: GameEvent?
    @Published var linkedEventPlays: [Play] = []
    @Published var linkedEventInvites: [Invite] = []
    @Published var gamePlayHistory: [Play] = []
    @Published var isLoadingStats = false
    @Published var participantAvatars: [UUID: String] = [:]
    @Published var showEditSheet = false

    private let supabase = SupabaseService.shared

    var isLogger: Bool {
        currentUserId == play.loggedBy
    }

    init(play: Play, currentUserId: UUID?, onDelete: (() async -> Void)? = nil) {
        self.play = play
        self.currentUserId = currentUserId
        self.onDelete = onDelete
    }

    func loadLinkedEvent() async {
        guard let eventId = play.eventId else { return }
        linkedEvent = try? await supabase.fetchEvent(id: eventId)
        linkedEventPlays = ((try? await supabase.fetchPlaysForEvent(eventId: eventId)) ?? []).filter { $0.id != play.id }
        linkedEventInvites = (try? await supabase.fetchInvites(eventId: eventId)) ?? []
    }

    func loadParticipantAvatars() async {
        let userIds = play.participants.compactMap(\.userId)
        guard !userIds.isEmpty else { return }
        participantAvatars = (try? await supabase.fetchUserAvatars(userIds: userIds)) ?? [:]
    }

    func loadStats() async {
        let userIds = play.participants.compactMap(\.userId)
        guard !userIds.isEmpty else { return }

        isLoadingStats = true
        do {
            gamePlayHistory = try await supabase.fetchPlaysForGameAmongUsers(gameId: play.gameId, userIds: userIds)
        } catch {
            // Non-fatal
        }
        isLoadingStats = false
    }

    /// Saves edited play fields and participants.
    func saveEdit(
        playedAt: Date,
        durationMinutes: Int?,
        notes: String?,
        isCooperative: Bool,
        cooperativeResult: Play.CooperativeResult?,
        participants: [PlayParticipant]
    ) async -> Bool {
        do {
            var fields: [String: AnyJSON] = [
                "played_at": .string(ISO8601DateFormatter().string(from: playedAt)),
                "is_cooperative": .bool(isCooperative),
            ]
            if let duration = durationMinutes {
                fields["duration_minutes"] = .double(Double(duration))
            } else {
                fields["duration_minutes"] = .null
            }
            if let notes, !notes.isEmpty {
                fields["notes"] = .string(notes)
            } else {
                fields["notes"] = .null
            }
            if let result = cooperativeResult {
                fields["cooperative_result"] = .string(result.rawValue)
            } else {
                fields["cooperative_result"] = .null
            }

            try await supabase.updatePlayFields(id: play.id, fields: fields)
            try await supabase.replacePlayParticipants(playId: play.id, participants: participants)

            // Refresh the play
            play = try await supabase.fetchPlayById(play.id)
            return true
        } catch {
            print("⚠️ [PlayDetailVM] Failed to save edit: \(error)")
            return false
        }
    }

    var perPlayerStats: [PlayDetailPlayerStat] {
        let participantUserIds = Set(play.participants.compactMap(\.userId))
        guard !participantUserIds.isEmpty else { return [] }

        var winsMap: [UUID: Int] = [:]
        var playsMap: [UUID: Int] = [:]
        var placementsMap: [UUID: [Int]] = [:]
        var scoresMap: [UUID: [Int]] = [:]
        var namesMap: [UUID: String] = [:]

        // Populate names from the current play's participants
        for p in play.participants {
            guard let uid = p.userId else { continue }
            namesMap[uid] = p.displayName
        }

        for historyPlay in gamePlayHistory {
            for p in historyPlay.participants {
                guard let uid = p.userId, participantUserIds.contains(uid) else { continue }
                if namesMap[uid] == nil { namesMap[uid] = p.displayName }
                playsMap[uid, default: 0] += 1
                if p.isWinner { winsMap[uid, default: 0] += 1 }
                if let placement = p.placement { placementsMap[uid, default: []].append(placement) }
                if let score = p.score { scoresMap[uid, default: []].append(score) }
            }
        }

        return participantUserIds.compactMap { uid in
            guard let name = namesMap[uid] else { return nil }
            let placements = placementsMap[uid]
            let scores = scoresMap[uid]
            return PlayDetailPlayerStat(
                id: uid,
                name: name,
                playsThisGame: playsMap[uid] ?? 0,
                wins: winsMap[uid] ?? 0,
                averagePlacement: placements.map { arr in arr.isEmpty ? nil : Double(arr.reduce(0, +)) / Double(arr.count) } ?? nil,
                averageScore: scores.map { arr in arr.isEmpty ? nil : Double(arr.reduce(0, +)) / Double(arr.count) } ?? nil
            )
        }.sorted { $0.wins > $1.wins }
    }
}
