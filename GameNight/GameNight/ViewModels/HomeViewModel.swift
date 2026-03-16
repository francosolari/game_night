import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var upcomingEvents: [GameEvent] = []
    @Published var myInvites: [Invite] = []
    @Published var drafts: [GameEvent] = []
    @Published var isLoading = true
    @Published var error: String?

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

        self.upcomingEvents = upcomingEvents
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

    private func mergeUpcomingEvents(_ base: [GameEvent], with additional: [GameEvent]) -> [GameEvent] {
        var mergedById = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        for event in additional {
            mergedById[event.id] = event
        }

        return mergedById.values.sorted { $0.createdAt > $1.createdAt }
    }
}
