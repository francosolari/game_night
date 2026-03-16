import SwiftUI

struct CreateGroupFromAttendeesSheet: View {
    let invites: [Invite]
    var onResult: ((ToastItem) -> Void)?
    @Environment(\.dismiss) var dismiss
    @StateObject private var groupsViewModel = GroupsViewModel()
    @State private var name = ""
    @State private var emoji = "🎲"
    @State private var selectedInviteIds = Set<UUID>()
    @State private var isSaving = false

    private let emojiOptions = ["🎲", "🏜️", "🐉", "🧙", "⚔️", "🎯", "🃏", "♟️", "🎮", "🌌", "🏰", "🚀"]

    private var eligibleInvites: [Invite] {
        invites.filter { [.accepted, .pending, .maybe].contains($0.status) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Emoji picker
                    VStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Theme.Gradients.primary)
                                .frame(width: 64, height: 64)
                            Text(emoji)
                                .font(.system(size: 32))
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(emojiOptions, id: \.self) { e in
                                    Button { emoji = e } label: {
                                        Text(e)
                                            .font(.system(size: 28))
                                            .padding(Theme.Spacing.sm)
                                            .background(
                                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                                    .fill(emoji == e ? Theme.Colors.primary.opacity(0.2) : .clear)
                                            )
                                    }
                                }
                            }
                        }
                    }

                    // Group name
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Group Name")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.textSecondary)
                        TextField("e.g. Friday Night Crew", text: $name)
                            .font(Theme.Typography.body)
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.backgroundElevated)
                            )
                    }

                    // Attendee selection
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            Text("Select Guests")
                                .font(Theme.Typography.headlineMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Button(selectedInviteIds.count == eligibleInvites.count ? "Deselect All" : "Select All") {
                                if selectedInviteIds.count == eligibleInvites.count {
                                    selectedInviteIds.removeAll()
                                } else {
                                    selectedInviteIds = Set(eligibleInvites.map(\.id))
                                }
                            }
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primary)
                        }

                        ForEach(eligibleInvites) { invite in
                            Button {
                                if selectedInviteIds.contains(invite.id) {
                                    selectedInviteIds.remove(invite.id)
                                } else {
                                    selectedInviteIds.insert(invite.id)
                                }
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: selectedInviteIds.contains(invite.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(selectedInviteIds.contains(invite.id) ? Theme.Colors.primary : Theme.Colors.textTertiary)

                                    AvatarView(url: nil, size: 36)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(invite.displayName ?? "Unknown")
                                            .font(Theme.Typography.bodyMedium)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Text(invite.phoneNumber)
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textTertiary)
                                    }

                                    Spacer()

                                    InviteStatusBadge(status: invite.status)
                                }
                                .padding(.vertical, Theme.Spacing.xs)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(isSaving ? "Creating..." : "Create Group") {
                        guard !isSaving else { return }
                        isSaving = true
                        Task {
                            if let group = await groupsViewModel.createGroup(
                                name: name,
                                emoji: emoji,
                                description: nil
                            ) {
                                let selectedInvites = eligibleInvites.filter { selectedInviteIds.contains($0.id) }
                                let contacts = selectedInvites.map { invite in
                                    UserContact(
                                        id: UUID(),
                                        name: invite.displayName ?? "Unknown",
                                        phoneNumber: invite.phoneNumber,
                                        avatarUrl: nil,
                                        isAppUser: invite.userId != nil
                                    )
                                }
                                await groupsViewModel.addMembers(to: group.id, contacts: contacts)
                                onResult?(ToastItem(style: .success, message: "\(emoji) \(name) created with \(contacts.count) guests"))
                            } else {
                                onResult?(ToastItem(style: .error, message: groupsViewModel.error ?? "Couldn't create group"))
                            }
                            isSaving = false
                            dismiss()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: !name.isEmpty && !selectedInviteIds.isEmpty && !isSaving))
                    .disabled(name.isEmpty || selectedInviteIds.isEmpty || isSaving)
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Create Group from Guests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
    }
}
