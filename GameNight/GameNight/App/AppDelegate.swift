import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    /// Stores a shortcut type that arrived before SwiftUI views were ready (cold-start).
    static var pendingShortcutType: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.gamenight.createEvent",
                localizedTitle: "New Game Night",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill")
            ),
            UIApplicationShortcutItem(
                type: "com.gamenight.viewGroups",
                localizedTitle: "My Groups",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "person.3.fill")
            ),
            UIApplicationShortcutItem(
                type: "com.gamenight.gameLibrary",
                localizedTitle: "Game Library",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "dice.fill")
            ),
        ]
        // Returning true causes performActionFor to be called for both cold-start and hot-start
        // shortcuts, so we handle everything in one place there.
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        print("[Shortcut] performActionFor called: \(shortcutItem.type)")
        AppDelegate.pendingShortcutType = shortcutItem.type
        // Defer one run-loop so SwiftUI has finished any in-progress update pass.
        DispatchQueue.main.async {
            print("[Shortcut] Posting homeScreenShortcutTriggered notification")
            NotificationCenter.default.post(
                name: .homeScreenShortcutTriggered,
                object: nil,
                userInfo: ["type": shortcutItem.type]
            )
        }
        completionHandler(true)
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await PushNotificationManager.shared.registerDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

extension Notification.Name {
    static let homeScreenShortcutTriggered = Notification.Name("homeScreenShortcutTriggered")
}

