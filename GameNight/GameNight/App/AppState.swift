import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading = true
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var selectedTab: Tab = .home
    @Published var showCreateEvent = false
    @Published var scheduleNightGroup: GameGroup?
    @Published var deepLinkEventId: String?
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

    init() {}

    func checkAuthState() async {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        let startTime = Date()

        // 1. Quick check for session to allow instant transition if not first launch
        if let session = try? await SupabaseService.shared.client.auth.session {
            self.isAuthenticated = true
            // If not first launch, we can stop loading immediately and fetch profile in background
            if !isFirstLaunch {
                self.isLoading = false
            }
            
            // Fetch full profile and contacts in background
            Task {
                if let user = try? await SupabaseService.shared.fetchCurrentUser() {
                    self.currentUser = user
                }
            }
            refreshContactNames()
        } else {
            self.isAuthenticated = false
            if !isFirstLaunch {
                self.isLoading = false
            }
        }

        if isFirstLaunch {
            // Exactly 1 second of splash screen on first launch
            let elapsed = Date().timeIntervalSince(startTime)
            let minimumTime: TimeInterval = 1.0
            
            if elapsed < minimumTime {
                let delay = UInt64((minimumTime - elapsed) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            self.isLoading = false
        }
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
        try? await SupabaseService.shared.client.auth.signOut()
        isAuthenticated = false
        currentUser = nil
        contactNameMap = [:]
    }
}
