import SwiftUI
import Contacts

// MARK: - Reusable Contact Row (shared by all contact sheets)
struct ContactRow: View {
    let contact: UserContact
    let isSelected: Bool
    let onTap: () -> Void

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
                                    .foregroundColor(.white)
                            )
                    }
                }

                AvatarView(url: contact.avatarUrl, size: 40, placeholder: "person.fill")

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(contact.phoneNumber)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                Spacer()

                if contact.isAppUser {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.success)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.sm + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device Contact Picker (reads phone contacts)
struct ContactPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var contacts: [UserContact] = []
    @State private var searchText = ""
    @State private var selectedIds = Set<UUID>()
    @State private var isLoading = true
    @State private var permissionDenied = false
    @State private var isLimited = false
    @State private var error: String?

    let onSelect: ([UserContact]) -> Void

    private var filteredContacts: [UserContact] {
        if searchText.isEmpty { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phoneNumber.contains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Privacy banner
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.accent)

                    Text("Only contacts you select are shared. We never upload your full address book.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(Theme.Colors.accent.opacity(0.08))

                if permissionDenied {
                    permissionDeniedView
                } else if isLoading {
                    LoadingView(message: "Reading contacts locally...")
                } else {
                    // Limited access banner
                    if isLimited {
                        Button {
                            // Re-trigger the limited contacts picker
                            Task { await requestMoreAccess() }
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 14))
                                Text("Share more contacts with Game Night")
                                    .font(Theme.Typography.calloutMedium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(Theme.Colors.primary)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.primary.opacity(0.08))
                        }
                    }

                    SearchBar(text: $searchText, placeholder: "Search contacts...")
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.md)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredContacts) { contact in
                                ContactRow(
                                    contact: contact,
                                    isSelected: selectedIds.contains(contact.id)
                                ) {
                                    if selectedIds.contains(contact.id) {
                                        selectedIds.remove(contact.id)
                                    } else {
                                        selectedIds.insert(contact.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Phone Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add (\(selectedIds.count))") {
                        let selected = contacts.filter { selectedIds.contains($0.id) }
                        onSelect(selected)
                        dismiss()
                    }
                    .font(Theme.Typography.bodySemibold)
                    .foregroundColor(selectedIds.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.primary)
                    .disabled(selectedIds.isEmpty)
                }
            }
        }
        .task {
            await loadContacts()
        }
    }

    private var permissionDeniedView: some View {
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
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.jumbo)

            Spacer()
        }
    }

    private func loadContacts() async {
        let picker = ContactPickerService.shared
        let status = await picker.authorizationStatus

        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = (try? await picker.requestAccess()) ?? false
            if !granted {
                permissionDenied = true
                isLoading = false
                return
            }
            // Check if we got limited after requesting
            if #available(iOS 18, *) {
                let newStatus = await picker.authorizationStatus
                isLimited = (newStatus == .limited)
            }
        default:
            if #available(iOS 18, *), status == .limited {
                isLimited = true
            } else {
                permissionDenied = true
                isLoading = false
                return
            }
        }

        do {
            contacts = try await picker.fetchLocalContacts()
        } catch {
            self.error = "Couldn't read contacts"
        }
        isLoading = false
    }

    private func requestMoreAccess() async {
        let picker = ContactPickerService.shared
        // On iOS 18+, calling requestAccess when limited re-shows the system picker
        _ = try? await picker.requestAccess()
        // Reload contacts after user potentially added more
        do {
            contacts = try await picker.fetchLocalContacts()
        } catch {
            // ignore
        }
    }
}
