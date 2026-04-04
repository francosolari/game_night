import SwiftUI
import Combine
import Supabase
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading = true
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var selectedTab: Tab = .home
    @Published var showCreateEvent = false
    @Published var scheduleNightGroup: GameGroup?
    @Published var deepLinkEventId: String?
    @Published var deepLinkInviteToken: String?
    @Published var unreadNotificationCount: Int = 0
    @Published var unreadMessageCount: Int = 0
    @Published var preloadedHomeSnapshot: HomeDataLoadSnapshot?
    @Published var navigateToCalendar = false

    enum RefreshArea: Hashable {
        case home
        case groups
    }

    typealias RefreshHandler = @MainActor () async -> Void

    /// Maps digits-only phone number → the current user's contact name for that person.
    /// Used to show contact names instead of app display names for people in your address book.
    var contactNameMap: [String: String] = [:]

    enum Tab: Int, CaseIterable {
        case home = 0
        case games
        case create
        case groups
        case profile
    }

    private var cancellables = Set<AnyCancellable>()
    private var notificationChannel: RealtimeChannelV2?
    private var refreshHandlers: [RefreshArea: RefreshHandler] = [:]

    init() {}

    func checkAuthState() async {
        let startTime = Date()
        self.isLoading = true

        // 1. Local session check (handles token refresh automatically)
        guard (try? await SupabaseService.shared.client.auth.session) != nil else {
            self.isAuthenticated = false
            let elapsed = Date().timeIntervalSince(startTime)
            let minimumTime: TimeInterval = 2.0
            if elapsed < minimumTime {
                let delay = UInt64((minimumTime - elapsed) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            self.isLoading = false
            return
        }

        // 2. Server-validate the session with one real DB call before firing all
        //    background tasks. Catches stale/cross-env tokens that pass the local
        //    keychain check but are rejected by the server (bad_jwt).
        guard await SupabaseService.shared.validateSession() else {
            self.isAuthenticated = false
            let elapsed = Date().timeIntervalSince(startTime)
            let minimumTime: TimeInterval = 2.0
            if elapsed < minimumTime {
                let delay = UInt64((minimumTime - elapsed) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            self.isLoading = false
            return
        }

        self.isAuthenticated = true

        // 3. Background warm-up (session is confirmed valid)
        Task {
            if let user = try? await SupabaseService.shared.fetchCurrentUser() {
                self.currentUser = user
            }
        }
        refreshContactNames()
        startNotificationSubscription()
        refreshUnreadCounts()
        Task {
            _ = try? await SupabaseService.shared.fetchFrequentContacts(limit: 200)
        }

        // 4. Preload Home Data while splash is visible
        let supabase = SupabaseService.shared
        let snapshot = await HomeDataLoader.load(
            fetchUpcomingEvents: { try await supabase.fetchUpcomingEvents() },
            fetchMyInvites: { try await supabase.fetchMyInvites() },
            fetchDrafts: { try await supabase.fetchDrafts() }
        )
        let hydratedSnapshot = await hydrateHomeSnapshot(snapshot, supabase: supabase)
        self.preloadedHomeSnapshot = hydratedSnapshot
        preloadImages(for: hydratedSnapshot)

        // 5. Minimum splash time (2 seconds for a polished feel, or until preload finishes)
        let elapsed = Date().timeIntervalSince(startTime)
        let minimumTime: TimeInterval = 2.0
        
        if elapsed < minimumTime {
            let delay = UInt64((minimumTime - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
        }
        
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        self.isLoading = false
    }

    private func preloadImages(for snapshot: HomeDataLoadSnapshot) {
        let upcomingUrls = snapshot.upcomingEvents.compactMap { $0.preferredCoverImageURLString }
        let inviteUrls = snapshot.myInvites.compactMap { $0.event?.preferredCoverImageURLString }
        let draftUrls = snapshot.drafts.compactMap { $0.preferredCoverImageURLString }
        
        let urls = Set(upcomingUrls + inviteUrls + draftUrls)
        
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            // Trigger a data task to fill the system cache
            URLSession.shared.dataTask(with: url).resume()
        }
    }

    private func hydrateHomeSnapshot(
        _ base: HomeDataLoadSnapshot,
        supabase: SupabaseService
    ) async -> HomeDataLoadSnapshot {
        await supabase.completePastEvents()

        var upcomingEvents = base.upcomingEvents

        let pendingInvites = base.myInvites.filter { $0.status == .pending }
        var awaitingResponseEvents: [(event: GameEvent, invite: Invite)] = []
        if !pendingInvites.isEmpty {
            let pendingIds = Set(pendingInvites.map(\.eventId))
            if let fetched = try? await supabase.fetchEvents(ids: Array(pendingIds)) {
                let eventsById = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
                awaitingResponseEvents = pendingInvites.compactMap { invite in
                    guard let event = eventsById[invite.eventId] else { return nil }
                    return (event, invite)
                }
                awaitingResponseEvents.sort { a, b in
                    a.event.effectiveStartDate < b.event.effectiveStartDate
                }
            }
        }

        let existingEventIds = Set(upcomingEvents.map(\.id))
        let acceptedInviteEventIds = Set(
            base.myInvites
                .filter { $0.status == .accepted || $0.status == .maybe || $0.status == .voted }
                .map(\.eventId)
        )
        let missingInviteEventIds = acceptedInviteEventIds.subtracting(existingEventIds)
        if !missingInviteEventIds.isEmpty,
           let inviteEvents = try? await supabase.fetchEvents(ids: Array(missingInviteEventIds)) {
            upcomingEvents = mergeAndSortUpcomingEvents(upcomingEvents, with: inviteEvents)
        } else {
            upcomingEvents = sortByEventDate(upcomingEvents)
        }

        let inviteCounts = (try? await supabase.fetchAcceptedInviteCounts(eventIds: upcomingEvents.map(\.id))) ?? [:]

        try? await supabase.expireStaleGroupInvites()
        let pendingGroupInvites = (try? await supabase.fetchMyPendingGroupInvites()) ?? []

        return HomeDataLoadSnapshot(
            upcomingEvents: upcomingEvents,
            myInvites: base.myInvites,
            drafts: base.drafts,
            awaitingResponseEvents: awaitingResponseEvents,
            pendingGroupInvites: pendingGroupInvites,
            inviteCounts: inviteCounts,
            isHydratedForHome: true,
            errorMessage: base.errorMessage
        )
    }

    private func mergeAndSortUpcomingEvents(_ base: [GameEvent], with additional: [GameEvent]) -> [GameEvent] {
        var mergedById = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        for event in additional {
            mergedById[event.id] = event
        }
        return sortByEventDate(Array(mergedById.values))
    }

    private func sortByEventDate(_ events: [GameEvent]) -> [GameEvent] {
        events.sorted { $0.effectiveStartDate < $1.effectiveStartDate }
    }

    /// Loads device contacts into the contactNameMap (fire-and-forget; silently fails if no permission).
    func refreshContactNames() {
        Task {
            let map = await ContactPickerService.shared.buildContactNameMap()
            await MainActor.run { self.contactNameMap = map }
        }
    }

    /// Returns how the current user should see a person: contact name (if in address book)
    /// falling back to the given display name string.
    func resolveDisplayName(phone: String?, fallback: String?) -> String {
        if let phone, !phone.isEmpty {
            let digits = phone.filter(\.isNumber)
            if let contactName = contactNameMap[digits] {
                return contactName
            }
        }
        return fallback ?? "Unknown"
    }

    func signOut() async {
        await PushNotificationManager.shared.unregisterCurrentToken()
        stopNotificationSubscription()
        try? await SupabaseService.shared.client.auth.signOut()
        SupabaseService.shared.clearFrequentContactsCache()
        isAuthenticated = false
        currentUser = nil
        contactNameMap = [:]
        unreadNotificationCount = 0
        unreadMessageCount = 0
        refreshHandlers = [:]
    }

    func registerRefreshHandler(for area: RefreshArea, handler: @escaping RefreshHandler) {
        refreshHandlers[area] = handler
    }

    func refresh(_ areas: [RefreshArea]) async {
        for area in areas {
            guard let handler = refreshHandlers[area] else { continue }
            await handler()
        }
    }

    // MARK: - Unread Counts

    func refreshUnreadCounts() {
        Task {
            do {
                let notifCount = try await SupabaseService.shared.fetchUnreadNotificationCount()
                let msgCount = try await SupabaseService.shared.fetchUnreadMessageCount()
                await MainActor.run {
                    self.unreadNotificationCount = notifCount
                    self.unreadMessageCount = msgCount
                    if #available(iOS 17.0, *) {
                        UNUserNotificationCenter.current().setBadgeCount(notifCount)
                    } else {
                        UIApplication.shared.applicationIconBadgeNumber = notifCount
                    }
                }
            } catch {
                print("Failed to refresh unread counts: \(error)")
            }
        }
    }

    func startNotificationSubscription() {
        notificationChannel = SupabaseService.shared.subscribeToNotifications { [weak self] in
            Task { @MainActor in
                self?.refreshUnreadCounts()
            }
        }
    }

    func stopNotificationSubscription() {
        if let channel = notificationChannel {
            Task {
                await channel.unsubscribe()
            }
        }
        notificationChannel = nil
    }
}
