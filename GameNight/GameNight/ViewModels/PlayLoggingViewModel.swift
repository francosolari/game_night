import SwiftUI

struct PlayParticipantDraft: Identifiable {
    let id: UUID
    var userId: UUID?
    var phoneNumber: String?
    var displayName: String
    var isPlaying: Bool
    var isWinner: Bool
    var placement: Int?
    var score: Int?
    var team: String?
}

@MainActor
final class PlayLoggingViewModel: ObservableObject {
    @Published var availableGames: [Game] = []
    @Published var selectedGameIds: Set<UUID> = []
    @Published var participantsByGame: [UUID: [PlayParticipantDraft]] = [:]
    @Published var notesByGame: [UUID: String] = [:]
    @Published var isCooperativeByGame: [UUID: Bool] = [:]
    @Published var cooperativeResultByGame: [UUID: Play.CooperativeResult] = [:]
    @Published var playedAt: Date = Date()
    @Published var durationMinutes: Int? = nil
    @Published var existingPlays: [Play] = []
    @Published var isSaving = false
    @Published var error: String?

    var eventId: UUID?
    var groupId: UUID?

    /// Phone numbers already in the participant list — used to exclude from contact picker
    var existingPhoneNumbers: Set<String> {
        var phones = Set<String>()
        for drafts in participantsByGame.values {
            for d in drafts {
                if let phone = d.phoneNumber {
                    phones.insert(phone)
                }
            }
        }
        return phones
    }

    private let supabase = SupabaseService.shared

    func prefillFromEvent(_ event: GameEvent, invites: [Invite]) {
        eventId = event.id
        groupId = event.groupId

        // Populate available games from event_games
        let games = event.games.compactMap(\.game)
        availableGames = games

        if games.count == 1, let game = games.first {
            selectedGameIds = [game.id]
        } else {
            selectedGameIds = Set(games.map(\.id))
        }

        // Build participant list from accepted invites + host
        var drafts: [PlayParticipantDraft] = []

        // Add host
        if let host = event.host {
            drafts.append(PlayParticipantDraft(
                id: UUID(),
                userId: host.id,
                displayName: host.displayName,
                isPlaying: true,
                isWinner: false
            ))
        }

        // Add accepted/maybe invitees
        for invite in invites where invite.status == .accepted || invite.status == .maybe {
            let name = invite.displayName ?? "Player"
            drafts.append(PlayParticipantDraft(
                id: UUID(),
                userId: invite.userId,
                phoneNumber: invite.phoneNumber,
                displayName: name,
                isPlaying: invite.status == .accepted,
                isWinner: false
            ))
        }

        // Assign same participants to all games
        for game in games {
            participantsByGame[game.id] = drafts
            notesByGame[game.id] = ""
            isCooperativeByGame[game.id] = false
        }
    }

    func prefillFromGroup(_ group: GameGroup) {
        groupId = group.id

        // Show all group members but none pre-selected — user picks who played
        var drafts: [PlayParticipantDraft] = []
        for member in group.members {
            drafts.append(PlayParticipantDraft(
                id: UUID(),
                userId: member.userId,
                phoneNumber: member.phoneNumber,
                displayName: member.displayName ?? "Player",
                isPlaying: false,
                isWinner: false
            ))
        }

        // No games preselected — user picks from library
        // Store drafts so they're available when games are added
        groupMemberDrafts = drafts
        for gameId in selectedGameIds {
            participantsByGame[gameId] = drafts
            notesByGame[gameId] = ""
            isCooperativeByGame[gameId] = false
        }
    }

    /// Cached group member drafts so new games get the same member list
    var groupMemberDrafts: [PlayParticipantDraft] = []

    func addGame(_ game: Game) {
        guard !availableGames.contains(where: { $0.id == game.id }) else { return }
        availableGames.append(game)
        selectedGameIds.insert(game.id)

        // Copy participants from first game if available, else use group member drafts
        if let firstGameId = participantsByGame.keys.first,
           let existingParticipants = participantsByGame[firstGameId] {
            participantsByGame[game.id] = existingParticipants.map { p in
                PlayParticipantDraft(
                    id: UUID(),
                    userId: p.userId,
                    phoneNumber: p.phoneNumber,
                    displayName: p.displayName,
                    isPlaying: p.isPlaying,
                    isWinner: false
                )
            }
        } else if !groupMemberDrafts.isEmpty {
            participantsByGame[game.id] = groupMemberDrafts.map { p in
                PlayParticipantDraft(
                    id: UUID(),
                    userId: p.userId,
                    phoneNumber: p.phoneNumber,
                    displayName: p.displayName,
                    isPlaying: p.isPlaying,
                    isWinner: false
                )
            }
        } else {
            participantsByGame[game.id] = []
        }
        notesByGame[game.id] = ""
        isCooperativeByGame[game.id] = false
    }

    func addParticipantsFromContacts(_ contacts: [UserContact]) {
        for contact in contacts {
            let draft = PlayParticipantDraft(
                id: UUID(),
                userId: nil,
                phoneNumber: contact.phoneNumber,
                displayName: contact.name,
                isPlaying: true,
                isWinner: false
            )
            // Add to all selected games
            for gameId in selectedGameIds {
                // Skip if already present (match by phone)
                let existing = participantsByGame[gameId] ?? []
                if existing.contains(where: { $0.phoneNumber == contact.phoneNumber }) { continue }
                participantsByGame[gameId, default: []].append(draft)
            }
        }
    }

    func checkExistingPlays() async {
        guard let eventId else { return }
        do {
            existingPlays = try await supabase.fetchPlaysForEvent(eventId: eventId)
        } catch {
            // Non-fatal
        }
    }

    var selectedGames: [Game] {
        availableGames.filter { selectedGameIds.contains($0.id) }
    }

    func savePlays() async -> Bool {
        guard !selectedGameIds.isEmpty else { return false }
        isSaving = true
        error = nil

        do {
            let userId = try await supabase.currentUserId()

            for gameId in selectedGameIds {
                let playId = UUID()
                let play = Play(
                    id: playId,
                    eventId: eventId,
                    groupId: groupId,
                    gameId: gameId,
                    loggedBy: userId,
                    playedAt: playedAt,
                    durationMinutes: durationMinutes,
                    notes: notesByGame[gameId]?.isEmpty == true ? nil : notesByGame[gameId],
                    isCooperative: isCooperativeByGame[gameId] ?? false,
                    cooperativeResult: cooperativeResultByGame[gameId]
                )

                let created = try await supabase.createPlay(play)

                // Create participants
                let drafts = (participantsByGame[gameId] ?? []).filter(\.isPlaying)
                let participants = drafts.map { draft in
                    PlayParticipant(
                        id: UUID(),
                        playId: created.id,
                        userId: draft.userId,
                        phoneNumber: draft.phoneNumber,
                        displayName: draft.displayName,
                        placement: draft.placement,
                        isWinner: draft.isWinner,
                        score: draft.score,
                        team: draft.team
                    )
                }

                if !participants.isEmpty {
                    try await supabase.createPlayParticipants(participants)
                }
            }

            isSaving = false
            return true
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            return false
        }
    }
}
