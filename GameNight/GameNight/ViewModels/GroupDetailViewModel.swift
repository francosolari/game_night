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
    @Published var playFilter: PlayFilterMode = .groupNights
    @Published var customFilterMembers: Set<UUID> = []
    @Published var isLoadingPlays = false
    @Published var isLoadingEvents = false
    @Published var isLoadingMessages = false
    @Published var newMessageText = ""
    @Published var isPostingMessage = false
    @Published var replyingTo: GroupMessage?
    @Published var mentionCandidates: [GroupMember] = []
    @Published var memberUsers: [UUID: User] = [:]
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
        async let profilesTask: () = loadMemberProfiles()
        _ = await (playsTask, eventsTask, messagesTask, profilesTask)
    }

    func loadMemberProfiles() async {
        for member in group.members {
            guard let userId = member.userId, memberUsers[userId] == nil else { continue }
            if let user = try? await supabase.fetchUserById(userId) {
                memberUsers[userId] = user
            }
        }
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

    func addMembers(contacts: [UserContact]) async {
        let existingPhones = Set(group.members.map(\.phoneNumber))
        let currentUserId = try? await supabase.client.auth.session.user.id
        for contact in contacts {
            let normalized = ContactPickerService.normalizePhone(contact.phoneNumber)
            guard !existingPhones.contains(normalized) else { continue }
            let member = GroupMember(
                id: UUID(),
                groupId: group.id,
                userId: contact.appUserId,
                phoneNumber: normalized,
                displayName: contact.name,
                tier: 1,
                sortOrder: group.members.count,
                addedAt: Date(),
                status: .pending,
                invitedBy: currentUserId
            )
            do {
                try await supabase.addGroupMember(member)
                group.members.append(member)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func removeMember(id: UUID) async {
        do {
            try await supabase.removeGroupMember(id: id)
            group.members.removeAll { $0.id == id }
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

    func updateMemberRole(memberId: UUID, role: GroupMemberRole) async {
        do {
            try await supabase.updateGroupMemberRole(memberId: memberId, role: role)
            if let index = group.members.firstIndex(where: { $0.id == memberId }) {
                group.members[index].role = role
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Head-to-Head

    func headToHead(currentUserId: UUID, targetUserId: UUID) -> HeadToHeadStats {
        var wins = 0, losses = 0, ties = 0

        for play in plays where !play.isCooperative {
            let participants = play.participants
            guard let currentP = participants.first(where: { $0.userId == currentUserId }),
                  let targetP = participants.first(where: { $0.userId == targetUserId }) else {
                continue
            }

            if let cp = currentP.placement, let tp = targetP.placement {
                if cp < tp { wins += 1 }
                else if cp > tp { losses += 1 }
                else { ties += 1 }
            } else {
                if currentP.isWinner && !targetP.isWinner { wins += 1 }
                else if !currentP.isWinner && targetP.isWinner { losses += 1 }
                else { ties += 1 }
            }
        }

        return HeadToHeadStats(wins: wins, losses: losses, ties: ties)
    }

    func eventsTogether(currentUserId: UUID, targetUserId: UUID) -> [GameEvent] {
        let eventIds = Set(plays.filter { play in
            let userIds = Set(play.participants.compactMap(\.userId))
            return userIds.contains(currentUserId) && userIds.contains(targetUserId)
        }.compactMap(\.eventId))

        return linkedEvents
            .filter { eventIds.contains($0.id) }
            .sorted { $0.effectiveStartDate > $1.effectiveStartDate }
    }

    func mostPlayedGame(for userId: UUID) -> (gameName: String, count: Int)? {
        var counts: [String: Int] = [:]
        for play in plays {
            guard play.participants.contains(where: { $0.userId == userId }) else { continue }
            let name = play.game?.name ?? "Unknown"
            counts[name, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return (top.key, top.value)
    }

    func playCount(for userId: UUID) -> Int {
        plays.filter { $0.participants.contains(where: { $0.userId == userId }) }.count
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
            Task { await channel.unsubscribe() }
            chatChannel = nil
        }
    }

    // MARK: - Mentions

    var mentionableMembers: [GroupMember] {
        group.members.filter(\.isAccepted)
    }

    func handleTextChange(_ text: String) {
        guard let atIndex = text.lastIndex(of: "@") else {
            mentionCandidates = []
            return
        }

        let afterAt = text[text.index(after: atIndex)...]
        // If there's a space before the @ (or it's the start), it's a valid mention trigger
        let beforeAt = text[text.startIndex..<atIndex]
        let isValidTrigger = beforeAt.isEmpty || beforeAt.last == " " || beforeAt.last == "\n"
        guard isValidTrigger else {
            mentionCandidates = []
            return
        }

        let query = String(afterAt)
        // If query contains a space followed by more text with another space, it's probably done
        // Allow multi-word names but stop after a clear sentence break
        if query.contains("  ") || query.hasSuffix(" ") {
            mentionCandidates = []
            return
        }

        if query.isEmpty {
            mentionCandidates = mentionableMembers
        } else {
            mentionCandidates = mentionableMembers.filter {
                ($0.displayName ?? "").localizedCaseInsensitiveContains(query)
            }
        }
    }

    func insertMention(_ member: GroupMember) {
        guard let name = member.displayName else { return }
        // Find the last @ and replace everything after it with the mention
        if let atIndex = newMessageText.lastIndex(of: "@") {
            newMessageText = String(newMessageText[newMessageText.startIndex..<atIndex]) + "@\(name) "
        }
        mentionCandidates = []
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
        let now = Date()
        return linkedEvents.filter { $0.status != .cancelled && $0.effectiveEndDate >= now }
    }

    var pastLinkedEvents: [GameEvent] {
        let now = Date()
        return linkedEvents.filter { $0.status != .cancelled && $0.effectiveEndDate < now }
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
    let longestWinStreak: Int
    let mostPlayedGame: String?
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
        var playerGameCounts: [UUID: [String: Int]] = [:]  // userId -> gameName -> count

        // Plays sorted chronologically for streak calculation
        let chronologicalPlays = plays.sorted { $0.playedAt < $1.playedAt }
        var playerWinStreaks: [UUID: (current: Int, max: Int)] = [:]

        for play in chronologicalPlays {
            for p in play.participants {
                guard let userId = p.userId else { continue }
                playerNames[userId] = p.displayName
                playerPlays[userId, default: 0] += 1
                if let gameName = play.game?.name {
                    playerGameCounts[userId, default: [:]][gameName, default: 0] += 1
                }
                if let placement = p.placement {
                    playerPlacements[userId, default: []].append(placement)
                }

                // Win streak tracking
                var streak = playerWinStreaks[userId] ?? (current: 0, max: 0)
                if p.isWinner {
                    playerWins[userId, default: 0] += 1
                    streak.current += 1
                    streak.max = max(streak.max, streak.current)
                } else {
                    streak.current = 0
                }
                playerWinStreaks[userId] = streak
            }
        }

        let leaderboard = playerNames.map { (userId, name) in
            let placements = playerPlacements[userId]
            let avgPlacement = placements.map { arr in
                arr.isEmpty ? nil : Double(arr.reduce(0, +)) / Double(arr.count)
            } ?? nil
            let gameCounts = playerGameCounts[userId] ?? [:]
            let topGame = gameCounts.max(by: { $0.value < $1.value })?.key
            return PlayerStats(
                id: userId,
                name: name,
                wins: playerWins[userId] ?? 0,
                totalPlays: playerPlays[userId] ?? 0,
                averagePlacement: avgPlacement,
                longestWinStreak: playerWinStreaks[userId]?.max ?? 0,
                mostPlayedGame: topGame
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

        // Extra fun stats
        if let biggestWinner = leaderboard.first, biggestWinner.wins > 0 {
            funStats.append(FunStat(emoji: "👑", title: "Most Wins", value: biggestWinner.name))
        }

        if let mostActive = leaderboard.max(by: { $0.totalPlays < $1.totalPlays }), mostActive.totalPlays > 0 {
            funStats.append(FunStat(emoji: "🔥", title: "Most Active", value: mostActive.name))
        }

        let eligible = leaderboard.filter { $0.totalPlays >= 3 }
        if let bestRate = eligible.max(by: { $0.winRate < $1.winRate }) {
            funStats.append(FunStat(emoji: "🏆", title: "Best Win Rate", value: "\(bestRate.name) (\(Int(bestRate.winRate * 100))%)"))
        }

        let withPlacements = leaderboard.filter { $0.averagePlacement != nil }
        if let bestPlacement = withPlacements.min(by: { ($0.averagePlacement ?? 99) < ($1.averagePlacement ?? 99) }) {
            funStats.append(FunStat(emoji: "🥇", title: "Best Avg Place", value: "\(bestPlacement.name) (#\(String(format: "%.1f", bestPlacement.averagePlacement ?? 0)))"))
        }

        return GroupStatsData(
            leaderboard: leaderboard,
            mostPlayedGames: mostPlayedGames,
            funStats: funStats,
            totalPlays: totalPlays,
            uniqueGames: uniqueGames
        )
    }
}

// MARK: - Head-to-Head Stats

struct HeadToHeadStats {
    let wins: Int
    let losses: Int
    let ties: Int
    var totalGames: Int { wins + losses + ties }
    var hasData: Bool { totalGames > 0 }
}
