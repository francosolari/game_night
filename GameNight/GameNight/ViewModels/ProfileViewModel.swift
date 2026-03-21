import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var summary: UserProfileSummary?
    @Published var recentEvents: [GameEvent] = []
    @Published var recentEventInvites: [UUID: Invite] = [:]
    @Published var recentEventCounts: [UUID: Int] = [:]
    @Published var savedContactsCount: Int = 0
    @Published var gameLibraryCount: Int = 0
    @Published var isLoading = false

    private var hasLoaded = false

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { await loadData() }
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        async let summaryTask = fetchSummary()
        async let eventsTask = fetchRecentPastEvents()
        async let contactsTask = fetchContactsCount()
        async let gamesTask = fetchGameLibraryCount()

        await summaryTask
        await eventsTask
        await contactsTask
        await gamesTask
    }

    private func fetchSummary() async {
        do {
            summary = try await SupabaseService.shared.fetchMyProfileSummary()
        } catch {
            print("⚠️ [ProfileVM] Failed to fetch summary: \(error)")
        }
    }

    private func fetchRecentPastEvents() async {
        do {
            let invites = try await SupabaseService.shared.fetchMyInvites()
            let hostedEvents = try await SupabaseService.shared.fetchMyEvents()

            // Combine: events I hosted + events I was invited to (accepted)
            let acceptedInvites = invites.filter { $0.status == .accepted }
            let invitedEventIds = Set(acceptedInvites.map(\.eventId))

            // Fetch full event details for invited events
            let invitedEvents: [GameEvent]
            if !invitedEventIds.isEmpty {
                invitedEvents = try await SupabaseService.shared.fetchEvents(ids: Array(invitedEventIds))
            } else {
                invitedEvents = []
            }

            // Merge hosted + attended, dedup by id
            var eventMap: [UUID: GameEvent] = [:]
            for event in hostedEvents { eventMap[event.id] = event }
            for event in invitedEvents { eventMap[event.id] = event }

            // Build invite lookup
            var inviteMap: [UUID: Invite] = [:]
            for invite in acceptedInvites {
                inviteMap[invite.eventId] = invite
            }

            // Filter to past events, sort by date descending, take 3
            let now = Date()
            let pastEvents = eventMap.values
                .filter { $0.effectiveStartDate < now }
                .sorted { $0.effectiveStartDate > $1.effectiveStartDate }

            let recent = Array(pastEvents.prefix(3))
            recentEvents = recent
            recentEventInvites = inviteMap

            // Fetch confirmed counts for these events
            if !recent.isEmpty {
                let counts = try await SupabaseService.shared.fetchAcceptedInviteCounts(
                    eventIds: recent.map(\.id)
                )
                recentEventCounts = counts
            }
        } catch {
            print("⚠️ [ProfileVM] Failed to fetch recent events: \(error)")
        }
    }

    private func fetchContactsCount() async {
        do {
            let contacts = try await SupabaseService.shared.fetchSavedContacts()
            savedContactsCount = contacts.count
        } catch {
            print("⚠️ [ProfileVM] Failed to fetch contacts count: \(error)")
        }
    }

    private func fetchGameLibraryCount() async {
        do {
            let library = try await SupabaseService.shared.fetchGameLibrary()
            gameLibraryCount = library.count
        } catch {
            print("⚠️ [ProfileVM] Failed to fetch game library count: \(error)")
        }
    }

    // MARK: - Computed

    var joinedDateString: String {
        guard let date = summary?.joinedAt ?? nil else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "Joined \(formatter.string(from: date))"
    }

    var hostedCount: Int { summary?.hostedEventCount ?? 0 }
    var attendedCount: Int { summary?.attendedEventCount ?? 0 }
    var groupCount: Int { summary?.groupCount ?? 0 }
}
