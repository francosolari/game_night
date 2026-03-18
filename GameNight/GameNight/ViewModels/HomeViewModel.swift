import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var upcomingEvents: [GameEvent] = []
    @Published var myInvites: [Invite] = []
    @Published var drafts: [GameEvent] = []
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
        isLoading = true
        error = nil

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

        var upcomingEvents = snapshot.upcomingEvents
        var errorMessage = snapshot.errorMessage

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
            } catch {
                let detail = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
                let inviteEventsError = "Invite Events: \(detail)"
                errorMessage = [errorMessage, inviteEventsError]
                    .compactMap { $0 }
                    .joined(separator: "\n")
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

        isLoading = false
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
        events.sorted { a, b in
            let dateA = a.timeOptions.first?.date ?? a.createdAt
            let dateB = b.timeOptions.first?.date ?? b.createdAt
            return dateA < dateB
        }
    }
}
