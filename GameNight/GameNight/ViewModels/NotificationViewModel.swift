import SwiftUI
import Supabase

@MainActor
final class NotificationViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseService.shared
    private var channel: RealtimeChannelV2?

    func loadNotifications() async {
        isLoading = true
        do {
            notifications = try await supabase.fetchNotifications()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func markAsRead(_ notification: AppNotification) async {
        guard notification.readAt == nil else { return }
        do {
            try await supabase.markNotificationRead(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].readAt = Date()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markAllAsRead() async {
        do {
            try await supabase.markAllNotificationsRead()
            for i in notifications.indices {
                if notifications[i].readAt == nil {
                    notifications[i].readAt = Date()
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func subscribe() {
        channel = supabase.subscribeToNotifications { [weak self] in
            Task { @MainActor in
                await self?.loadNotifications()
            }
        }
    }

    func unsubscribe() {
        if let channel = channel {
            Task {
                await channel.unsubscribe()
            }
        }
        channel = nil
    }
}
