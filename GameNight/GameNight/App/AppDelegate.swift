import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
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
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        NotificationCenter.default.post(
            name: .homeScreenShortcutTriggered,
            object: nil,
            userInfo: ["type": shortcutItem.type]
        )
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
