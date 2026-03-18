import SwiftUI

@main
struct GameNightApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var supabase = SupabaseService.shared
    @StateObject private var themeManager = ThemeManager.shared

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
            .environmentObject(appState)
            .environmentObject(supabase)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.preferredColorScheme)
            .tint(Theme.Colors.primary)
            .onChange(of: themeManager.mode) { _, _ in
                // Force tint update when theme changes
            }
        }
    }
}
