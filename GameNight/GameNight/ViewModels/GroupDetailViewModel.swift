import SwiftUI
import Supabase

enum GroupDetailTab: String, CaseIterable {
    case members = "Members"
    case history = "History"
    case stats = "Stats"
    case chat = "Chat"
}

enum PlayFilterMode: String, CaseIterable {
    case groupNights = "Group Nights"
    case all = "All"
    case custom = "Custom"
}

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published var group: GameGroup
    @Published var plays: [Play] = []
    @Published var linkedEvents: [GameEvent] = []
    @Published var messages: [GroupMessage] = []
    @Published var selectedTab: GroupDetailTab = .members
    @Published var playFilter: PlayFilterMode = .all
    @Published var customFilterMembers: Set<UUID> = []
    @Published var isLoadingPlays = false
    @Published var isLoadingEvents = false
    @Published var isLoadingMessages = false
    @Published var newMessageText = ""
    @Published var isPostingMessage = false
    @Published var replyingTo: GroupMessage?
    @Published var error: String?

    private let supabase = SupabaseService.shared
    private var chatChannel: RealtimeChannelV2?

    init(group: GameGroup) {
        self.group = group
    }

    func loadAllData() async {
        async let playsTask: () = loadPlays()
        async let eventsTask: () = loadLinkedEvents()
        async let messagesTask: () = loadMessages()
        _ = await (playsTask, eventsTask, messagesTask)
    }

    func loadPlays() async {
        isLoadingPlays = true
        do {
            plays = try await supabase.fetchPlaysForGroup(groupId: group.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingPlays = false
    }

    func loadLinkedEvents() async {
        isLoadingEvents = true
        do {
            linkedEvents = try await supabase.fetchEventsForGroup(groupId: group.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingEvents = false
    }

    func loadMessages() async {
        isLoadingMessages = true
        do {
            let flat = try await supabase.fetchGroupMessages(groupId: group.id)
            messages = buildMessageTree(flat)
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingMessages = false
    }

    func postMessage() async {
        let content = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        isPostingMessage = true
        newMessageText = ""

        do {
            try await supabase.postGroupMessage(
                groupId: group.id,
                content: content,
                parentId: replyingTo?.id
            )
            replyingTo = nil
            await loadMessages()
        } catch {
            self.error = error.localizedDescription
        }
        isPostingMessage = false
    }

    func deleteMessage(id: UUID) async {
        do {
            try await supabase.deleteGroupMessage(id: id)
            await loadMessages()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deletePlay(id: UUID) async {
        do {
            try await supabase.deletePlay(id: id)
            plays.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func subscribeToChatUpdates() {
        chatChannel = supabase.subscribeToGroupMessages(groupId: group.id) { [weak self] in
            Task { @MainActor in
                await self?.loadMessages()
            }
        }
    }

    func unsubscribeFromChat() {
        if let channel = chatChannel {
            Task { try? await channel.unsubscribe() }
            chatChannel = nil
        }
    }

    // MARK: - Filtered Plays

    var filteredPlays: [Play] {
        switch playFilter {
        case .all:
            return plays
        case .groupNights:
            let memberUserIds = Set(group.members.compactMap(\.userId))
            let threshold = max(1, memberUserIds.count / 2)
            return plays.filter { play in
                let playUserIds = Set(play.participants.compactMap(\.userId))
                return playUserIds.intersection(memberUserIds).count >= threshold
            }
        case .custom:
            guard !customFilterMembers.isEmpty else { return plays }
            return plays.filter { play in
                let playUserIds = Set(play.participants.compactMap(\.userId))
                return customFilterMembers.isSubset(of: playUserIds)
            }
        }
    }

    // MARK: - Stats

    var stats: GroupStatsData {
        GroupStatsData.compute(from: filteredPlays, groupMembers: group.members)
    }

    // MARK: - Linked Events

    var upcomingLinkedEvents: [GameEvent] {
        linkedEvents.filter { $0.status != .completed && $0.status != .cancelled }
    }

    var pastLinkedEvents: [GameEvent] {
        linkedEvents.filter { $0.status == .completed }
    }

    // MARK: - Helpers

    private func buildMessageTree(_ flat: [GroupMessage]) -> [GroupMessage] {
        let topLevel = flat.filter { $0.parentId == nil }
        let childrenByParent = Dictionary(grouping: flat.filter { $0.parentId != nil }) { $0.parentId! }

        return topLevel.map { msg in
            var m = msg
            m.replies = childrenByParent[msg.id]?.sorted(by: { $0.createdAt < $1.createdAt })
            return m
        }
    }
}

// MARK: - Group Stats Data

struct PlayerStats: Identifiable {
    let id: UUID
    let name: String
    let wins: Int
    let totalPlays: Int
    var winRate: Double { totalPlays > 0 ? Double(wins) / Double(totalPlays) : 0 }
    let averagePlacement: Double?
}

struct GamePlayCount: Identifiable {
    var id: UUID { gameId }
    let gameId: UUID
    let gameName: String
    let count: Int
}

struct FunStat: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let value: String
}

struct GroupStatsData {
    let leaderboard: [PlayerStats]
    let mostPlayedGames: [GamePlayCount]
    let funStats: [FunStat]
    let totalPlays: Int
    let uniqueGames: Int

    static func compute(from plays: [Play], groupMembers: [GroupMember]) -> GroupStatsData {
        let totalPlays = plays.count

        // Game play counts
        var gameCountMap: [UUID: (name: String, count: Int)] = [:]
        for play in plays {
            let name = play.game?.name ?? "Unknown"
            let existing = gameCountMap[play.gameId] ?? (name: name, count: 0)
            gameCountMap[play.gameId] = (name: existing.name, count: existing.count + 1)
        }
        let mostPlayedGames = gameCountMap.map { GamePlayCount(gameId: $0.key, gameName: $0.value.name, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        let uniqueGames = gameCountMap.count

        // Player stats
        var playerWins: [UUID: Int] = [:]
        var playerPlays: [UUID: Int] = [:]
        var playerPlacements: [UUID: [Int]] = [:]
        var playerNames: [UUID: String] = [:]

        for play in plays {
            for p in play.participants {
                guard let userId = p.userId else { continue }
                playerNames[userId] = p.displayName
                playerPlays[userId, default: 0] += 1
                if p.isWinner { playerWins[userId, default: 0] += 1 }
                if let placement = p.placement {
                    playerPlacements[userId, default: []].append(placement)
                }
            }
        }

        let leaderboard = playerNames.map { (userId, name) in
            let placements = playerPlacements[userId]
            let avgPlacement = placements.map { arr in
                arr.isEmpty ? nil : Double(arr.reduce(0, +)) / Double(arr.count)
            } ?? nil
            return PlayerStats(
                id: userId,
                name: name,
                wins: playerWins[userId] ?? 0,
                totalPlays: playerPlays[userId] ?? 0,
                averagePlacement: avgPlacement
            )
        }.sorted { $0.wins > $1.wins }

        // Fun stats
        var funStats: [FunStat] = []

        if let topGame = mostPlayedGames.first {
            funStats.append(FunStat(emoji: "🎯", title: "Most Played", value: topGame.gameName))
        }

        if totalPlays > 1 {
            if let first = plays.last?.playedAt, let last = plays.first?.playedAt {
                let days = max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 1)
                let freq = max(1, days / totalPlays)
                funStats.append(FunStat(emoji: "📅", title: "Play Frequency", value: "Every ~\(freq) days"))
            }
        }

        funStats.append(FunStat(emoji: "🎲", title: "Total Plays", value: "\(totalPlays)"))
        funStats.append(FunStat(emoji: "🃏", title: "Unique Games", value: "\(uniqueGames)"))

        return GroupStatsData(
            leaderboard: leaderboard,
            mostPlayedGames: mostPlayedGames,
            funStats: funStats,
            totalPlays: totalPlays,
            uniqueGames: uniqueGames
        )
    }
}
