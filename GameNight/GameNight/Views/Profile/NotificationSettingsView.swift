import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @State private var prefs: NotificationPreferences?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var pushEnabled = false
    @State private var toast: ToastItem?

    private let supabase = SupabaseService.shared

    var body: some View {
        List {
            Section {
                pushPermissionRow
            } header: {
                Text("System")
            } footer: {
                Text("Push notifications require system permission. Tap to open Settings if disabled.")
            }

            if prefs != nil {
                Section {
                    preferenceToggle("Event Invites", isOn: binding(for: \.invitesEnabled))
                    preferenceToggle("Direct Messages", isOn: binding(for: \.dmsEnabled))
                    preferenceToggle("Text Blasts from Hosts", isOn: binding(for: \.textBlastsEnabled))
                    preferenceToggle("RSVP Updates (when hosting)", isOn: binding(for: \.rsvpUpdatesEnabled))
                } header: {
                    Text("Notification Types")
                } footer: {
                    Text("Choose which notifications you'd like to receive.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .task {
            await loadPreferences()
            await checkPushPermission()
        }
    }

    // MARK: - Push Permission

    private var pushPermissionRow: some View {
        HStack {
            Label {
                Text("Push Notifications")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
            } icon: {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(Theme.Colors.primary)
            }

            Spacer()

            if pushEnabled {
                Text("Enabled")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.success)
            } else {
                Button("Enable") {
                    Task { await requestPushPermission() }
                }
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.primary)
            }
        }
    }

    // MARK: - Toggle Row

    private func preferenceToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .tint(Theme.Colors.primary)
        .onChange(of: isOn.wrappedValue) { _, _ in
            Task { await savePreferences() }
        }
    }

    // MARK: - Binding Helper

    private func binding(for keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { prefs?[keyPath: keyPath] ?? true },
            set: { newValue in
                prefs?[keyPath: keyPath] = newValue
            }
        )
    }

    // MARK: - Data

    private func loadPreferences() async {
        isLoading = true
        do {
            if let existing = try await supabase.fetchNotificationPreferences() {
                prefs = existing
            } else {
                // Create default preferences
                let userId = try await supabase.currentUserId()
                let defaultPrefs = NotificationPreferences(userId: userId)
                try await supabase.upsertNotificationPreferences(defaultPrefs)
                prefs = defaultPrefs
            }
        } catch {
            toast = ToastItem(style: .error, message: "Failed to load preferences")
        }
        isLoading = false
    }

    private func savePreferences() async {
        guard let prefs = prefs else { return }
        do {
            try await supabase.upsertNotificationPreferences(prefs)
        } catch {
            toast = ToastItem(style: .error, message: "Failed to save preferences")
        }
    }

    private func checkPushPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        pushEnabled = settings.authorizationStatus == .authorized
    }

    private func requestPushPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            pushEnabled = granted
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                toast = ToastItem(style: .success, message: "Push notifications enabled")
            }
        } catch {
            // Open Settings if permission was previously denied
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}
