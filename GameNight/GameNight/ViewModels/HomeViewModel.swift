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

    func loadData(preloadedSnapshot: HomeDataLoadSnapshot? = nil) async {
        // Only show skeleton on initial load, not on pull-to-refresh
        let isInitialLoad = upcomingEvents.isEmpty && myInvites.isEmpty && drafts.isEmpty
        if isInitialLoad && preloadedSnapshot == nil {
            isLoading = true
        }
        error = nil

        // Housekeeping runs during AppState preload. Avoid duplicate RPC load here.

        let snapshot: HomeDataLoadSnapshot
        if let preloaded = preloadedSnapshot {
            print("🏠 [HomeViewModel] Using preloaded snapshot.")
            snapshot = preloaded
        } else {
            snapshot = await HomeDataLoader.load(
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
        }

        // If the task was cancelled (e.g. SwiftUI .refreshable releasing),
        // don't overwrite existing good data with empty results.
        guard !Task.isCancelled else {
            return
        }

        var upcomingEvents = snapshot.upcomingEvents
        let errorMessage = snapshot.errorMessage

        if snapshot.isHydratedForHome {
            self.awaitingResponseEvents = snapshot.awaitingResponseEvents
            self.pendingGroupInvites = snapshot.pendingGroupInvites
            inviteCounts = snapshot.inviteCounts
            upcomingEvents = snapshot.upcomingEvents
            print("🏠 [HomeViewModel] using hydrated preloaded home snapshot")
        } else {
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
                    .filter { $0.status == .accepted || $0.status == .maybe || $0.status == .voted }
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
        }

        // Sort by event date ascending (soonest first)
        self.upcomingEvents = sortByEventDate(upcomingEvents)
        self.myInvites = snapshot.myInvites
        self.drafts = snapshot.drafts
        self.error = errorMessage

        if isInitialLoad {
            isLoading = false
        }

        if let error = errorMessage {
            print("🏠 [HomeViewModel] \(error)")
        }

        if !snapshot.isHydratedForHome {
            Task { @MainActor in
                await refreshPendingGroupInvites()
            }
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

    private func refreshPendingGroupInvites() async {
        // Keep this read-only on refresh; stale-expiry runs during AppState preload.
        if let groupInvites = try? await SupabaseService.shared.fetchMyPendingGroupInvites() {
            pendingGroupInvites = groupInvites
        }
    }
}
