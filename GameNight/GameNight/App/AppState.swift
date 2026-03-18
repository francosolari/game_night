import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading = true
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var selectedTab: Tab = .home
    @Published var showCreateEvent = false
    @Published var deepLinkEventId: String?

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
            
            // Fetch full profile in background (or foreground if first launch)
            Task {
                if let user = try? await SupabaseService.shared.fetchCurrentUser() {
                    self.currentUser = user
                }
            }
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

    func signOut() async {
        try? await SupabaseService.shared.client.auth.signOut()
        isAuthenticated = false
        currentUser = nil
    }
}
