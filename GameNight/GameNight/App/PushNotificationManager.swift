import Foundation
import UserNotifications
import UIKit

@MainActor
final class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()

    @Published var isRegistered = false
    private var deviceToken: String?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            isRegistered = granted
            return granted
        } catch {
            print("Push permission error: \(error)")
            return false
        }
    }

    // MARK: - Token Registration

    func registerDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token

        do {
            try await SupabaseService.shared.registerPushToken(token)
            print("Push token registered: \(token.prefix(8))...")
        } catch {
            print("Failed to register push token: \(error)")
        }
    }

    func unregisterCurrentToken() async {
        guard let token = deviceToken else { return }
        do {
            try await SupabaseService.shared.unregisterPushToken(token)
        } catch {
            print("Failed to unregister push token: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            handleNotificationTap(userInfo: userInfo)
        }

        completionHandler()
    }

    // MARK: - Navigation

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // Route based on notification type
        if let eventId = userInfo["event_id"] as? String {
            // Navigate to event
            // AppState will handle this via deepLinkEventId
            NotificationCenter.default.post(
                name: .pushNotificationTapped,
                object: nil,
                userInfo: ["event_id": eventId]
            )
        } else if let conversationId = userInfo["conversation_id"] as? String {
            NotificationCenter.default.post(
                name: .pushNotificationTapped,
                object: nil,
                userInfo: ["conversation_id": conversationId]
            )
        }
    }
}

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}
