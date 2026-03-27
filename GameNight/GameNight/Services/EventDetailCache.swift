import Foundation

@MainActor
final class EventDetailCache {
    static let shared = EventDetailCache()

    struct Snapshot {
        let event: GameEvent
        let invites: [Invite]
        let myInvite: Invite?
        let myPollVotes: [UUID: TimeOptionVoteType]
        let activityFeed: [ActivityFeedItem]
        let gameVotes: [GameVote]
        let myGameVotes: [UUID: GameVoteType]
        let timeOptionVoters: [UUID: [TimeOptionVoter]]
        let gameVoterDetails: [UUID: [GameVoterInfo]]
        let cachedAt: Date
    }

    private var cache: [UUID: Snapshot] = [:]
    private let maxAge: TimeInterval = 300

    private init() {}

    func get(_ eventId: UUID) -> Snapshot? {
        guard let snapshot = cache[eventId] else { return nil }
        if Date().timeIntervalSince(snapshot.cachedAt) > maxAge {
            cache.removeValue(forKey: eventId)
            return nil
        }
        return snapshot
    }

    func set(_ eventId: UUID, snapshot: Snapshot) {
        cache[eventId] = snapshot
    }

    func invalidate(_ eventId: UUID) {
        cache.removeValue(forKey: eventId)
    }
}
