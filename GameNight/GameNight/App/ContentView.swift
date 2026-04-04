import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showCreateEvent = false
    @State private var homeNavigationPath = NavigationPath()
    @State private var previousTab: AppState.Tab = .home

    private func applyShortcut(type: String) {
        print("[Shortcut] applyShortcut called with type: \(type)")
        print("[Shortcut] Current selectedTab before: \(appState.selectedTab)")
        switch type {
        case "com.gamenight.createEvent":
            appState.showCreateEvent = true
            print("[Shortcut] Set appState.showCreateEvent = true")
        case "com.gamenight.viewGroups":
            appState.selectedTab = .groups
            print("[Shortcut] Set selectedTab = .groups")
        case "com.gamenight.gameLibrary":
            appState.selectedTab = .games
            print("[Shortcut] Set selectedTab = .games")
        default:
            print("[Shortcut] Unknown type: \(type)")
        }
        print("[Shortcut] Current selectedTab after: \(appState.selectedTab)")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                NavigationStack(path: $homeNavigationPath) {
                    HomeView(navigationPath: $homeNavigationPath)
                        .navigationDestination(for: GameEvent.self) { event in
                            EventDetailView(eventId: event.id)
                        }
                        .navigationDestination(for: CalendarDestination.self) { dest in
                            CalendarView(
                                navigationPath: $homeNavigationPath,
                                defaultViewMode: dest.startInListMode ? .list : .calendar
                            )
                        }
                        .navigationDestination(for: Game.self) { game in
                            GameDetailView(game: game)
                        }
                        .navigationDestination(for: CreatorDestination.self) { dest in
                            if dest.role == .designer {
                                DesignerDetailView(name: dest.name)
                            } else {
                                PublisherDetailView(name: dest.name)
                            }
                        }
                        .navigationDestination(for: GameFamilyDestination.self) { destination in
                            GameFamilyDetailView(destination: destination)
                        }
                        .navigationDestination(for: HomeDestination.self) { destination in
                            switch destination {
                            case .notifications:
                                NotificationFeedView(navigationPath: $homeNavigationPath)
                            case .inbox:
                                InboxView(navigationPath: $homeNavigationPath)
                            case .eventDetail(let id):
                                EventDetailView(eventId: id)
                            case .groupDetail(let id):
                                GroupDetailLoadingView(groupId: id)
                            }
                        }
                        .navigationDestination(for: DMNavDestination.self) { dest in
                            let conversationVM = ConversationViewModel(
                                conversationId: dest.conversationId,
                                otherUser: ConversationViewModel.ConversationOtherUser(
                                    id: dest.otherUserId,
                                    displayName: dest.otherDisplayName,
                                    avatarUrl: dest.otherAvatarUrl
                                )
                            )
                            ConversationView(viewModel: conversationVM)
                        }
                }
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
        .sheet(item: $appState.scheduleNightGroup) { group in
            CreateEventView(group: group)
                .environmentObject(appState)
        }
        .onChange(of: appState.selectedTab) { oldTab, newTab in
            if newTab == .create {
                showCreateEvent = true
                appState.selectedTab = .home
                return
            }
            if newTab == .home && oldTab == .home {
                homeNavigationPath = NavigationPath()
            }
            previousTab = newTab
        }
        .onChange(of: appState.showCreateEvent) { _, newValue in
            if newValue {
                showCreateEvent = true
                appState.showCreateEvent = false
            }
        }
        .onChange(of: appState.deepLinkEventId) { _, newValue in
            guard let idString = newValue, let uuid = UUID(uuidString: idString) else { return }
            appState.deepLinkEventId = nil
            appState.selectedTab = .home
            homeNavigationPath.append(HomeDestination.eventDetail(uuid))
        }
        .onChange(of: appState.navigateToCalendar) { _, newValue in
            if newValue {
                appState.navigateToCalendar = false
                appState.selectedTab = .home
                homeNavigationPath.append(CalendarDestination(startInListMode: true))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapped)) { note in
            if let eventId = note.userInfo?["event_id"] as? String,
               let uuid = UUID(uuidString: eventId) {
                appState.selectedTab = .home
                homeNavigationPath.append(HomeDestination.eventDetail(uuid))
            } else if let groupId = note.userInfo?["group_id"] as? String,
                      let uuid = UUID(uuidString: groupId) {
                appState.selectedTab = .home
                homeNavigationPath.append(HomeDestination.groupDetail(uuid))
            } else if note.userInfo?["conversation_id"] != nil {
                appState.selectedTab = .home
                homeNavigationPath.append(HomeDestination.inbox)
            }
        }
        .onAppear {
            print("[Shortcut] MainTabView onAppear — pendingShortcutType: \(AppDelegate.pendingShortcutType ?? "nil")")
            if let type = AppDelegate.pendingShortcutType {
                AppDelegate.pendingShortcutType = nil
                // Defer so SwiftUI has fully mounted before we push a state change.
                DispatchQueue.main.async { applyShortcut(type: type) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeScreenShortcutTriggered)) { note in
            print("[Shortcut] onReceive homeScreenShortcutTriggered: \(note.userInfo ?? [:])")
            guard let type = note.userInfo?["type"] as? String else { return }
            AppDelegate.pendingShortcutType = nil
            applyShortcut(type: type)
        }
    }
}

struct CustomTabBar: View {
    @EnvironmentObject var themeManager: ThemeManager
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
