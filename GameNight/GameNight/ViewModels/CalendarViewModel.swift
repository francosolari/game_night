import SwiftUI
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {
    // MARK: - Data
    @Published var allEvents: [GameEvent] = []
    @Published var invitesByEventId: [UUID: Invite] = [:]
    @Published var isLoading = true
    @Published var error: String?
    private var inviteCounts: [UUID: Int] = [:]

    // MARK: - UI State
    @Published var selectedDate: Date? = Date()
    @Published var currentMonth: Date = Date()
    @Published var viewMode: ViewMode = .calendar
    @Published var searchQuery: String = ""
    @Published var showFilterSheet = false
    @Published var showSearch = false

    // MARK: - Filters
    @Published var activeFilters: Set<FilterCategory> = FilterCategory.defaultActive

    enum ViewMode {
        case calendar
        case list
    }

    enum FilterCategory: String, CaseIterable, Identifiable {
        case myEvents = "My events"
        case attending = "Attending"
        case deciding = "Deciding"
        case waitingOnHost = "Waiting on host"
        case notGoing = "Not going"

        var id: String { rawValue }

        static var defaultActive: Set<FilterCategory> {
            [.myEvents, .attending, .deciding, .waitingOnHost]
        }
    }

    private let supabase: any HomeDataProviding

    init(supabase: any HomeDataProviding = SupabaseService.shared) {
        self.supabase = supabase
    }

    // MARK: - Loading

    func loadData() async {
        isLoading = true
        error = nil

        do {
            async let eventsTask = supabase.fetchUpcomingEvents()
            async let invitesTask = supabase.fetchMyInvites()

            let (events, invites) = try await (eventsTask, invitesTask)

            // Also fetch events from accepted invites that might not be in upcoming
            let existingIds = Set(events.map(\.id))
            let missingIds = Set(invites.map(\.eventId)).subtracting(existingIds)

            var allFetched = events
            if !missingIds.isEmpty {
                let additional = try await supabase.fetchEvents(ids: Array(missingIds))
                allFetched.append(contentsOf: additional)
            }

            self.allEvents = allFetched.sorted { eventSortDate($0) < eventSortDate($1) }
            self.invitesByEventId = Dictionary(uniqueKeysWithValues: invites.map { ($0.eventId, $0) })

            // Fetch accepted invite counts
            let allIds = allFetched.map(\.id)
            self.inviteCounts = (try? await supabase.fetchAcceptedInviteCounts(eventIds: allIds)) ?? [:]
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Filtering

    var filteredEvents: [GameEvent] {
        var events = allEvents

        // Apply RSVP filters
        events = events.filter { event in
            let invite = invitesByEventId[event.id]
            let isHost = event.hostId == SupabaseService.shared.client.auth.currentSession?.user.id

            if activeFilters.contains(.myEvents) && isHost { return true }
            if activeFilters.contains(.attending) && invite?.status == .accepted { return true }
            if activeFilters.contains(.deciding) && (invite?.status == .pending || invite?.status == .maybe) { return true }
            if activeFilters.contains(.waitingOnHost) && invite?.status == .waitlisted { return true }
            if activeFilters.contains(.notGoing) {
                if invite?.status == .declined || invite?.status == .expired { return true }
                if event.status == .cancelled { return true }
            }
            return false
        }

        // Apply search
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            events = events.filter { event in
                event.title.lowercased().contains(query) ||
                event.games.contains { $0.game?.name.lowercased().contains(query) ?? false } ||
                (event.host?.displayName.lowercased().contains(query) ?? false)
            }
        }

        return events
    }

    // MARK: - Calendar Helpers

    func events(for date: Date) -> [GameEvent] {
        let calendar = Calendar.current
        return filteredEvents
            .filter { event in
                guard let timeOption = event.timeOptions.first else { return false }
                return calendar.isDate(timeOption.date, inSameDayAs: date)
            }
            .sorted { eventSortDate($0) < eventSortDate($1) }
    }

    func hasEvents(on date: Date) -> Bool {
        !events(for: date).isEmpty
    }

    func confirmedCount(for eventId: UUID) -> Int {
        let acceptedInvites = inviteCounts[eventId] ?? 0
        return acceptedInvites + 1 // +1 for the host
    }

    func invite(for eventId: UUID) -> Invite? {
        invitesByEventId[eventId]
    }

    func resetFilters() {
        activeFilters = FilterCategory.defaultActive
    }

    func scrollToToday() {
        currentMonth = Date()
        selectedDate = Date()
    }

    func previousMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
            selectedDate = nil
        }
    }

    func nextMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
            selectedDate = nil
        }
    }

    // MARK: - Helpers

    private func eventSortDate(_ event: GameEvent) -> Date {
        event.timeOptions.first?.startTime ?? event.timeOptions.first?.date ?? event.createdAt
    }

    /// Returns events grouped by day for list mode
    var eventsByDay: [(date: Date, events: [GameEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event -> Date in
            let eventDate = event.timeOptions.first?.date ?? event.createdAt
            return calendar.startOfDay(for: eventDate)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, events: $0.value.sorted { eventSortDate($0) < eventSortDate($1) }) }
    }

    var todayIndex: Int? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return eventsByDay.firstIndex { $0.date >= today }
    }
}
