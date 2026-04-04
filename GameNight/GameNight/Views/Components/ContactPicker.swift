import SwiftUI
import Contacts
import ContactsUI

// MARK: - Reusable Contact Row (shared by all contact sheets)
struct ContactRow: View {
    let contact: UserContact
    let isSelected: Bool
    let onTap: () -> Void

    /// Resolves avatar: prefers stored URL, falls back to local contact cache.
    private var resolvedAvatarUrl: String? {
        if let url = contact.avatarUrl, !url.isEmpty { return url }
        return ContactPickerService.cachedAvatarUrl(for: contact.phoneNumber)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.textTertiary, lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.Colors.primary)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.Colors.primaryActionText)
                            )
                    }
                }

                AvatarView(url: resolvedAvatarUrl, size: 40, placeholder: "person.fill")

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    if contact.source != .appConnection {
                        Text(PhoneNumberFormatter.formatForDisplay(contact.phoneNumber))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    } else {
                        Text("via Game Night")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary.opacity(0.6))
                    }
                }

                Spacer()

                if contact.isAppUser {
                    HStack(spacing: 4) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 10))
                        Text("cardboardwithme")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.sm + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Native Contact Picker (replaces over-engineered custom sheet)
/// Wraps CNContactPickerViewController — the system native picker.
/// Handles all access levels: full, limited, denied.
struct ContactPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @State private var showLimitedExpansionAlert = false
    @State private var showNativePicker = false
    @State private var showDeniedView = false
    @State private var isChecking = true
    @State private var isSyncing = false
    @State private var syncedCount = 0
    @State private var totalCount = 0
    @State private var syncError: String?
    @State private var didOpenSettings = false
    @State private var syncedDeviceContacts: [UserContact] = []

    let onSelect: ([UserContact]) -> Void

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            if isChecking {
                ProgressView().tint(Theme.Colors.primary)
            } else if isSyncing {
                VStack(spacing: Theme.Spacing.lg) {
                    if totalCount > 0 {
                        ProgressView(value: Double(syncedCount) / Double(totalCount))
                            .progressViewStyle(.linear)
                            .tint(Theme.Colors.primary)
                            .frame(width: 200)
                    } else {
                        ProgressView()
                            .tint(Theme.Colors.primary)
                    }

                    Text("Syncing contacts...")
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)

                    if totalCount > 0 {
                        Text("\(syncedCount) of \(totalCount)")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                .padding(Theme.Spacing.xl)
            } else if let syncError {
                VStack(spacing: Theme.Spacing.xl) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.warning)
                    Text("Sync Failed")
                        .font(Theme.Typography.headlineLarge)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(syncError)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xxxl)
                    Button("Try Again") {
                        self.syncError = nil
                        Task { await syncAllContacts() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Theme.Spacing.jumbo)
                    Button("Cancel") { dismiss() }
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                }
            } else if showDeniedView {
                deniedView
            }
        }
        .task { await checkAndPresent() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && didOpenSettings {
                didOpenSettings = false
                isChecking = true
                Task { await checkAndPresent() }
            }
        }
        .alert("Contacts Synced", isPresented: $showLimitedExpansionAlert) {
            Button("Add More from Settings") {
                didOpenSettings = true
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Done", role: .cancel) {
                onSelect(syncedDeviceContacts)
                dismiss()
            }
        } message: {
            Text("Synced \(syncedDeviceContacts.count) contacts. To share more, go to Settings and select additional contacts.")
        }
        .sheet(isPresented: $showNativePicker, onDismiss: { dismiss() }) {
            NativeContactPicker(onSelect: onSelect)
        }
    }

    private var deniedView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("Contact Access Needed")
                .font(Theme.Typography.headlineLarge)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("To invite friends, allow contact access in Settings. We only read contacts locally and never upload your address book.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxxl)
            Button("Open Settings") {
                didOpenSettings = true
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.jumbo)
            Spacer()
        }
    }

    private func checkAndPresent() async {
        let picker = ContactPickerService.shared
        let status = await picker.authorizationStatus

        switch status {
        case .authorized:
            isChecking = false
            await syncAllContacts()

        case .notDetermined:
            let granted = (try? await picker.requestAccess()) ?? false
            isChecking = false
            if granted {
                // Sync whatever is available (full or limited)
                await syncAllContacts()
                // If limited, offer to expand after sync
                let newStatus = await picker.authorizationStatus
                if #available(iOS 18, *), newStatus == .limited {
                    showLimitedExpansionAlert = true
                }
            } else {
                showDeniedView = true
            }

        default:
            isChecking = false
            if #available(iOS 18, *), status == .limited {
                // Sync the contacts that ARE available under limited access
                await syncAllContacts()
                showLimitedExpansionAlert = true
            } else {
                showDeniedView = true
            }
        }
    }

    /// Fetches all device contacts and upserts them into saved_contacts using bulk save.
    /// Re-running catches any contacts added since the last sync.
    private func syncAllContacts() async {
        isSyncing = true
        syncedCount = 0
        syncError = nil

        do {
            let deviceContacts = try await ContactPickerService.shared.fetchLocalContacts()
            guard !deviceContacts.isEmpty else {
                isSyncing = false
                syncedDeviceContacts = []
                onSelect([])
                dismiss()
                return
            }

            totalCount = deviceContacts.count
            syncedDeviceContacts = deviceContacts

            _ = try await SupabaseService.shared.saveContactsBulk(deviceContacts) { upserted in
                Task { @MainActor in
                    syncedCount = upserted
                }
            }

            isSyncing = false
            // For full access, auto-dismiss. For limited, the alert handles dismissal.
            let status = await ContactPickerService.shared.authorizationStatus
            if status == .authorized {
                onSelect(deviceContacts)
                dismiss()
            }
        } catch {
            isSyncing = false
            syncError = error.localizedDescription
        }
    }
}

// MARK: - Native CNContactPickerViewController wrapper
private struct NativeContactPicker: UIViewControllerRepresentable {
    let onSelect: ([UserContact]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Enable multi-select: tapping a contact checks it instead of dismissing.
        // The predicate is always false so individual taps toggle selection;
        // the user hits "Done" to confirm, which fires didSelect contacts:[].
        picker.predicateForSelectionOfContact = NSPredicate(value: false)
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: ([UserContact]) -> Void

        init(onSelect: @escaping ([UserContact]) -> Void) {
            self.onSelect = onSelect
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            map(contacts)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onSelect([])
        }

        private func map(_ contacts: [CNContact]) {
            let userContacts = contacts.compactMap { contact -> UserContact? in
                guard let phone = contact.phoneNumbers.first?.value.stringValue else { return nil }
                let name = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                guard !name.isEmpty else { return nil }
                return UserContact(
                    id: UUID(),
                    name: name,
                    phoneNumber: PhoneNumberFormatter.normalizeToE164(phone),
                    avatarUrl: nil,
                    isAppUser: false,
                    source: .phonebook
                )
            }
            onSelect(userContacts)
        }
    }
}
