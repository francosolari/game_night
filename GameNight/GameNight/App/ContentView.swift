import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateEvent = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tag(AppState.Tab.home)

                GameLibraryView()
                    .tag(AppState.Tab.games)

                // Placeholder for center create button
                Color.clear
                    .tag(AppState.Tab.create)

                GroupsView()
                    .tag(AppState.Tab.groups)

                ProfileView()
                    .tag(AppState.Tab.profile)
            }

            // Custom tab bar
            CustomTabBar(selectedTab: $appState.selectedTab, onCreateTap: {
                showCreateEvent = true
            })
        }
        .sheet(isPresented: $showCreateEvent) {
            CreateEventView()
                .environmentObject(appState)
        }
        .onChange(of: appState.selectedTab) { _, newTab in
            if newTab == .create {
                showCreateEvent = true
                // Reset to previous tab
                appState.selectedTab = .home
            }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppState.Tab
    let onCreateTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house.fill",
                label: "Home",
                isSelected: selectedTab == .home
            ) { selectedTab = .home }

            TabBarButton(
                icon: "dice.fill",
                label: "Games",
                isSelected: selectedTab == .games
            ) { selectedTab = .games }

            // Center create button
            Button(action: onCreateTap) {
                ZStack {
                    Circle()
                        .fill(Theme.Gradients.primary)
                        .frame(width: 56, height: 56)
                        .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 12, y: 4)

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.primaryActionText)
                }
            }
            .offset(y: -16)

            TabBarButton(
                icon: "person.3.fill",
                label: "Groups",
                isSelected: selectedTab == .groups
            ) { selectedTab = .groups }

            TabBarButton(
                icon: "person.crop.circle.fill",
                label: "Profile",
                isSelected: selectedTab == .profile
            ) { selectedTab = .profile }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Theme.Colors.tabBarBackground
                .shadow(color: .black.opacity(ThemeManager.shared.isDark ? 0.3 : 0.08), radius: 20, y: -5)
                .ignoresSafeArea()
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Theme.Colors.primary : Theme.Colors.tabInactive)

                Text(label)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(isSelected ? Theme.Colors.primary : Theme.Colors.tabInactive)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
