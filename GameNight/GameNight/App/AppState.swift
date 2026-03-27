import SwiftUI
import Combine
import Supabase

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

    init() {}

    func checkAuthState() async {
        let startTime = Date()
        self.isLoading = true

        // 1. Quick check for session
        if let session = try? await SupabaseService.shared.client.auth.session {
            self.isAuthenticated = true
            
            // Start background warm-up
            Task {
                if let user = try? await SupabaseService.shared.fetchCurrentUser() {
                    self.currentUser = user
                }
            }
            refreshContactNames()
            startNotificationSubscription()
            refreshUnreadCounts()

            // 2. Preload Home Data while splash is visible
            let supabase = SupabaseService.shared
            let snapshot = await HomeDataLoader.load(
                fetchUpcomingEvents: { try await supabase.fetchUpcomingEvents() },
                fetchMyInvites: { try await supabase.fetchMyInvites() },
                fetchDrafts: { try await supabase.fetchDrafts() }
            )
            self.preloadedHomeSnapshot = snapshot
        } else {
            self.isAuthenticated = false
        }

        // 3. Minimum splash time (2 seconds for a polished feel, or until preload finishes)
        let elapsed = Date().timeIntervalSince(startTime)
        let minimumTime: TimeInterval = 2.0
        
        if elapsed < minimumTime {
            let delay = UInt64((minimumTime - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
        }
        
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        self.isLoading = false
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
        isAuthenticated = false
        currentUser = nil
        contactNameMap = [:]
        unreadNotificationCount = 0
        unreadMessageCount = 0
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
