import SwiftUI

@main
struct GameNightApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var appState = AppState()
    @StateObject private var supabase = SupabaseService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var pushManager = PushNotificationManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoading {
                    SplashScreen()
                } else if appState.isAuthenticated {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: themeManager.isDark)
            .task {
                await appState.checkAuthState()
                // Request push permission after auth check
                if appState.isAuthenticated {
                    _ = await pushManager.requestPermission()
                }
            }
            .onAppear {
                themeManager.updateSystemColorScheme(colorScheme)
            }
            .onChange(of: colorScheme) { _, newScheme in
                themeManager.updateSystemColorScheme(newScheme)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                themeManager.updateSystemColorScheme(colorScheme)
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .sheet(item: $appState.deepLinkInviteToken) { token in
                InviteClaimView(inviteToken: token)
                    .environmentObject(appState)
            }
            .environmentObject(appState)
            .environmentObject(supabase)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.preferredColorScheme)
            .tint(Theme.Colors.primary)
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Handle gamenight://invite/<token>
        if url.scheme == "gamenight" {
            if url.host == "invite", let token = url.pathComponents.last, token != "/" {
                appState.deepLinkInviteToken = token
                return
            }
        }

        // Handle https://cardboardwithme.com/invite/<token> or /event/<shareToken> (Universal Links)
        if url.host == "cardboardwithme.com" || url.host == "www.cardboardwithme.com" {
            let pathComponents = url.pathComponents
            if let inviteIndex = pathComponents.firstIndex(of: "invite"),
               inviteIndex + 1 < pathComponents.count {
                let token = pathComponents[inviteIndex + 1]
                appState.deepLinkInviteToken = token
                return
            }

            // Handle /event/<shareToken> — resolve share token to event ID
            if let eventIndex = pathComponents.firstIndex(of: "event"),
               eventIndex + 1 < pathComponents.count {
                let shareToken = pathComponents[eventIndex + 1]
                Task {
                    if let eventId = try? await SupabaseService.shared.fetchEventId(byShareToken: shareToken) {
                        await MainActor.run { appState.deepLinkEventId = eventId.uuidString }
                    }
                }
                return
            }
        }

        // Handle gamenight://event/<shareToken>
        if url.scheme == "gamenight", url.host == "event",
           let shareToken = url.pathComponents.last, shareToken != "/" {
            Task {
                if let eventId = try? await SupabaseService.shared.fetchEventId(byShareToken: shareToken) {
                    await MainActor.run { appState.deepLinkEventId = eventId.uuidString }
                }
            }
            return
        }

        // Handle event deep links
        if let eventId = url.queryParameters?["event_id"] {
            appState.deepLinkEventId = eventId
        }
    }
}

// Make String identifiable for sheet binding
extension String: @retroactive Identifiable {
    public var id: String { self }
}

// URL query parameter helper
extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }
        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value
        }
        return params
    }
}
