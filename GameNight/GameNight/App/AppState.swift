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

    init() {
        checkAuthState()
    }

    func checkAuthState() {
        Task {
            do {
                let session = try await SupabaseService.shared.client.auth.session
                self.currentUser = try await SupabaseService.shared.fetchCurrentUser()
                self.isAuthenticated = true
            } catch {
                self.isAuthenticated = false
            }
            self.isLoading = false
        }
    }

    func signOut() async {
        try? await SupabaseService.shared.client.auth.signOut()
        isAuthenticated = false
        currentUser = nil
    }
}
