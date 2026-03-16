import SwiftUI

struct GroupsView: View {
    @StateObject private var viewModel = GroupsViewModel()
    @State private var showCreateGroup = false
    @State private var selectedGroup: GameGroup?
    @State private var toast: ToastItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Header
                    HStack {
                        Text("Groups")
                            .font(Theme.Typography.displayLarge)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Spacer()

                        Button {
                            showCreateGroup = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.Gradients.primary)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.lg)

                    if viewModel.isLoading {
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                    .fill(Theme.Colors.cardBackground)
                                    .frame(height: 100)
                                    .shimmer()
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    } else if viewModel.groups.isEmpty {
                        EmptyStateView(
                            icon: "person.3.fill",
                            title: "No Groups Yet",
                            message: "Create groups of friends to quickly invite them to game nights.",
                            actionLabel: "Create a Group"
                        ) {
                            showCreateGroup = true
                        }
                        .frame(minHeight: 400)
                    } else {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(viewModel.groups) { group in
                                GroupCard(group: group) {
                                    selectedGroup = group
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupSheet(viewModel: viewModel, onResult: { resultToast in
                    toast = resultToast
                })
            }
            .sheet(item: $selectedGroup) { group in
                GroupDetailSheet(group: group, viewModel: viewModel, onResult: { resultToast in
                    toast = resultToast
                })
            }
            .toast($toast)
        }
        .task {
            await viewModel.loadGroups()
        }
    }
}

// MARK: - Group Card
struct GroupCard: View {
    let group: GameGroup
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.lg) {
                // Emoji avatar
                ZStack {
                    Circle()
                        .fill(Theme.Gradients.primary)
                        .frame(width: 52, height: 52)

                    Text(group.emoji ?? "🎲")
                        .font(.system(size: 24))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(group.name)
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)

                    if let desc = group.description {
                        Text(desc)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                        Text("\(group.memberCount) members")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundColor(Theme.Colors.textTertiary)
                }

                Spacer()

                // Member tier indicators
                VStack(spacing: 2) {
                    let t1 = group.members.filter { $0.tier == 1 }.count
                    let t2 = group.members.filter { $0.tier == 2 }.count
                    if t1 > 0 {
                        Text("T1: \(t1)")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.primary)
                    }
                    if t2 > 0 {
                        Text("T2: \(t2)")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.accent)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Group Sheet
struct CreateGroupSheet: View {
    @ObservedObject var viewModel: GroupsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var emoji = "🎲"
    @State private var description = ""
    @State private var step = 1
    @State private var createdGroup: GameGroup?
    @State private var isCreating = false
    var onResult: ((ToastItem) -> Void)?

    private let emojiOptions = ["🎲", "🏜️", "🐉", "🧙", "⚔️", "🎯", "🃏", "♟️", "🎮", "🌌", "🏰", "🚀"]

    var body: some View {
        NavigationStack {
            if step == 1 {
                ScrollView {
                    VStack(spacing: Theme.Spacing.xxl) {
                        // Emoji picker
                        VStack(spacing: Theme.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Gradients.primary)
                                    .frame(width: 80, height: 80)
                                Text(emoji)
                                    .font(.system(size: 40))
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

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Group Name")
                                .font(Theme.Typography.label)
                                .foregroundColor(Theme.Colors.textSecondary)
                            TextField("e.g. Dune Crew", text: $name)
                                .font(Theme.Typography.body)
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                        .fill(Theme.Colors.backgroundElevated)
                                )
                        }

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Description (optional)")
                                .font(Theme.Typography.label)
                                .foregroundColor(Theme.Colors.textSecondary)
                            TextField("What does this group play?", text: $description)
                                .font(Theme.Typography.body)
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                        .fill(Theme.Colors.backgroundElevated)
                                )
                        }

                        if let errorMsg = viewModel.error {
                            Text(errorMsg)
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.error)
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                        .fill(Theme.Colors.error.opacity(0.1))
                                )
                        }

                        Button(isCreating ? "Creating..." : "Create Group") {
                            guard !isCreating else { return }
                            isCreating = true
                            viewModel.error = nil
                            Task {
                                if let group = await viewModel.createGroup(
                                    name: name,
                                    emoji: emoji,
                                    description: description.isEmpty ? nil : description
                                ) {
                                    createdGroup = group
                                    withAnimation { step = 2 }
                                } else {
                                    onResult?(ToastItem(style: .error, message: viewModel.error ?? "Couldn't create group"))
                                    dismiss()
                                }
                                isCreating = false
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: !name.isEmpty && !isCreating))
                        .disabled(name.isEmpty || isCreating)
                    }
                    .padding(Theme.Spacing.xl)
                }
                .background(Theme.Colors.background.ignoresSafeArea())
                .navigationTitle("New Group")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            } else if let group = createdGroup {
                ContactListSheet(
                    excludedPhones: Set<String>(),
                    onSelect: { contacts in
                        Task {
                            await viewModel.addMembers(to: group.id, contacts: contacts)
                            onResult?(ToastItem(style: .success, message: "\(group.emoji ?? "🎲") \(group.name) created with \(contacts.count) members"))
                        }
                        dismiss()
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Skip") {
                            onResult?(ToastItem(style: .success, message: "\(group.emoji ?? "🎲") \(group.name) created"))
                            dismiss()
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Group Detail Sheet
struct GroupDetailSheet: View {
    let group: GameGroup
    @ObservedObject var viewModel: GroupsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showAddMembers = false
    var onResult: ((ToastItem) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Header
                    VStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Theme.Gradients.primary)
                                .frame(width: 80, height: 80)
                            Text(group.emoji ?? "🎲")
                                .font(.system(size: 40))
                        }

                        Text(group.name)
                            .font(Theme.Typography.displaySmall)
                            .foregroundColor(Theme.Colors.textPrimary)

                        if let desc = group.description {
                            Text(desc)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    // Add members button
                    Button {
                        showAddMembers = true
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14))
                            Text("Add Members")
                                .font(Theme.Typography.calloutMedium)
                        }
                        .foregroundColor(Theme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.primary.opacity(0.1))
                        )
                    }

                    // Members list
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Members (\(group.memberCount))")
                            .font(Theme.Typography.headlineMedium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        // Tier 1
                        let tier1 = group.members.filter { $0.tier == 1 }
                        if !tier1.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Tier 1 — First Invite")
                                    .font(Theme.Typography.label)
                                    .foregroundColor(Theme.Colors.primary)

                                ForEach(tier1) { member in
                                    MemberRow(member: member, groupId: group.id, viewModel: viewModel)
                                }
                            }
                        }

                        // Tier 2
                        let tier2 = group.members.filter { $0.tier == 2 }
                        if !tier2.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Tier 2 — Waitlist")
                                    .font(Theme.Typography.label)
                                    .foregroundColor(Theme.Colors.accent)

                                ForEach(tier2) { member in
                                    MemberRow(member: member, groupId: group.id, viewModel: viewModel)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .sheet(isPresented: $showAddMembers) {
                ContactListSheet(
                    excludedPhones: Set(group.members.map(\.phoneNumber)),
                    onSelect: { contacts in
                        Task {
                            await viewModel.addMembers(to: group.id, contacts: contacts)
                            onResult?(ToastItem(style: .success, message: "Added \(contacts.count) member\(contacts.count == 1 ? "" : "s")"))
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    let member: GroupMember
    let groupId: UUID
    @ObservedObject var viewModel: GroupsViewModel

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            AvatarView(url: nil, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName ?? "Unknown")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(member.phoneNumber)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }

            Spacer()

            Menu {
                Button("Tier 1 (First Invite)") {
                    viewModel.updateMemberTier(memberId: member.id, groupId: groupId, tier: 1)
                }
                Button("Tier 2 (Waitlist)") {
                    viewModel.updateMemberTier(memberId: member.id, groupId: groupId, tier: 2)
                }
                Divider()
                Button("Remove", role: .destructive) {
                    Task { await viewModel.removeMember(id: member.id, from: groupId) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .padding(Theme.Spacing.sm)
    }
}
