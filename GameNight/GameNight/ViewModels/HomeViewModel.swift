import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var upcomingEvents: [GameEvent] = []
    @Published var myInvites: [Invite] = []
    @Published var drafts: [GameEvent] = []
    @Published var awaitingResponseEvents: [(event: GameEvent, invite: Invite)] = []
    @Published var pendingGroupInvites: [(group: GameGroup, member: GroupMember)] = []
    @Published var isLoading = true
    @Published var error: String?

    /// Accepted invite counts per event (does NOT include host)
    private var inviteCounts: [UUID: Int] = [:]

    private let supabase: any HomeDataProviding

    init(supabase: any HomeDataProviding) {
        self.supabase = supabase
    }

    convenience init() {
        self.init(supabase: SupabaseService.shared)
    }

    func loadData() async {
        // Only show skeleton on initial load, not on pull-to-refresh
        let isInitialLoad = upcomingEvents.isEmpty && myInvites.isEmpty && drafts.isEmpty
        if isInitialLoad {
            isLoading = true
        }
        // Guarantee isLoading is always set to false, even if something unexpected happens
        defer {
            if isInitialLoad {
                isLoading = false
            }
        }
        error = nil

        // Mark past events as completed before fetching
        await SupabaseService.shared.completePastEvents()

        let snapshot = await HomeDataLoader.load(
            fetchUpcomingEvents: { [supabase] in
                try await supabase.fetchUpcomingEvents()
            },
            fetchMyInvites: { [supabase] in
                try await supabase.fetchMyInvites()
            },
            fetchDrafts: { [supabase] in
                try await supabase.fetchDrafts()
            }
        )

        // If the task was cancelled (e.g. SwiftUI .refreshable releasing),
        // don't overwrite existing good data with empty results.
        guard !Task.isCancelled else {
            return
        }

        var upcomingEvents = snapshot.upcomingEvents
        let errorMessage = snapshot.errorMessage

        let pendingInvites = snapshot.myInvites.filter { $0.status == .pending }
        print("🏠 [HomeViewModel] pending invites count: \(pendingInvites.count)")
        var pendingEvents: [(event: GameEvent, invite: Invite)] = []
        if !pendingInvites.isEmpty {
            let pendingIds = Set(pendingInvites.map(\.eventId))
            do {
                let fetched = try await supabase.fetchEvents(ids: Array(pendingIds))
                let eventsById = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
                pendingEvents = pendingInvites.compactMap { invite in
                    guard let event = eventsById[invite.eventId] else { return nil }
                    return (event, invite)
                }
                pendingEvents.sort { a, b in
                    a.event.effectiveStartDate < b.event.effectiveStartDate
                }
            } catch is CancellationError {
                // Ignore cancellations — pending list can stay empty
            } catch {
                print("🏠 [HomeViewModel] Pending invite fetch failed: \(error)")
            }
        }
        self.awaitingResponseEvents = pendingEvents
        print("🏠 [HomeViewModel] awaiting response events count: \(pendingEvents.count)")

        let existingEventIds = Set(upcomingEvents.map(\.id))
        let acceptedInviteEventIds = Set(
            snapshot.myInvites
                .filter { $0.status == .accepted || $0.status == .maybe }
                .map(\.eventId)
        )
        let missingInviteEventIds = acceptedInviteEventIds.subtracting(existingEventIds)

        if !missingInviteEventIds.isEmpty {
            do {
                let inviteEvents = try await supabase.fetchEvents(ids: Array(missingInviteEventIds))
                upcomingEvents = mergeUpcomingEvents(upcomingEvents, with: inviteEvents)
            } catch is CancellationError {
                // Ignore — don't treat cancellation as a failure
            } catch {
                // Non-fatal — accepted invite events are supplemental data
                print("🏠 [HomeViewModel] Invite events fetch failed: \(error)")
            }
        }

        // Fetch accepted invite counts for all events
        let allEventIds = upcomingEvents.map(\.id)
        do {
            inviteCounts = try await supabase.fetchAcceptedInviteCounts(eventIds: allEventIds)
        } catch {
            // Non-fatal — counts will just show 0
            inviteCounts = [:]
        }

        // Sort by event date ascending (soonest first)
        self.upcomingEvents = sortByEventDate(upcomingEvents)
        self.myInvites = snapshot.myInvites
        self.drafts = snapshot.drafts
        self.error = errorMessage

        if let error = errorMessage {
            print("🏠 [HomeViewModel] \(error)")
        }

        // defer handles isLoading = false

        // Expire stale group invites, then load pending ones
        try? await SupabaseService.shared.expireStaleGroupInvites()
        if let groupInvites = try? await SupabaseService.shared.fetchMyPendingGroupInvites() {
            self.pendingGroupInvites = groupInvites
        }
    }

    func respondToGroupInvite(memberId: UUID, accept: Bool) async {
        do {
            try await SupabaseService.shared.respondToGroupInvite(memberId: memberId, accept: accept)
            pendingGroupInvites.removeAll { $0.member.id == memberId }
        } catch {
            print("🏠 [HomeViewModel] Group invite response failed: \(error)")
        }
    }

    func invite(for eventId: UUID) -> Invite? {
        myInvites.first { $0.eventId == eventId }
    }

    /// Returns confirmed player count: accepted invites + 1 for the host
    func confirmedCount(for eventId: UUID) -> Int {
        let acceptedInvites = inviteCounts[eventId] ?? 0
        return acceptedInvites + 1 // +1 for the host who is always attending
    }

    private func mergeUpcomingEvents(_ base: [GameEvent], with additional: [GameEvent]) -> [GameEvent] {
        var mergedById = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        for event in additional {
            mergedById[event.id] = event
        }
        return sortByEventDate(Array(mergedById.values))
    }

    private func sortByEventDate(_ events: [GameEvent]) -> [GameEvent] {
        events.sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }
}
