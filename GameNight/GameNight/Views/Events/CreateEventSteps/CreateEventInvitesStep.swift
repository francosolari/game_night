import SwiftUI
import UniformTypeIdentifiers

struct CreateEventInvitesStep: View {
    @ObservedObject var viewModel: CreateEventViewModel
    @ObservedObject var groupsViewModel: GroupsViewModel
    @Binding var showGroupPicker: Bool
    @Binding var showContactList: Bool
    @Binding var showContactPicker: Bool
    @State private var draggingInviteeId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Who's playing?")
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)

            // Quick-add: suggested contacts (top 3 frequent)
            if !viewModel.topSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Suggested")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textTertiary)

                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.topSuggestions) { contact in
                            Button {
                                viewModel.addFrequentContact(contact)
                            } label: {
                                HStack(spacing: 6) {
                                    AvatarView(url: contact.contactAvatarUrl, size: 24)
                                    Text(contact.contactName.components(separatedBy: " ").first ?? contact.contactName)
                                        .font(Theme.Typography.calloutMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .lineLimit(1)
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Theme.Colors.primary)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(
                                    Capsule()
                                        .fill(Theme.Colors.backgroundElevated)
                                        .overlay(
                                            Capsule()
                                                .stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }
            }

            // Add people row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    if !groupsViewModel.groups.isEmpty {
                        addPeopleButton(icon: "person.3.fill", label: "Groups") {
                            showGroupPicker = true
                        }
                    }

                    addPeopleButton(icon: "person.2.fill", label: "All Contacts") {
                        showContactList = true
                    }

                    addPeopleButton(icon: "person.badge.plus", label: "Phone") {
                        showContactPicker = true
                    }

                    // Share link — available in edit mode when event has a share token
                    if let shareToken = viewModel.eventToEdit?.shareToken,
                       let url = URL(string: "https://cardboardwithme.com/event/\(shareToken)") {
                        ShareLink(
                            item: url,
                            message: Text("Join me for \(viewModel.title.isEmpty ? "Game Night" : viewModel.title)!")
                        ) {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "link")
                                    .font(.system(size: 14))
                                Text("Link")
                                    .font(Theme.Typography.calloutMedium)
                            }
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .fill(Theme.Colors.primary.opacity(0.1))
                            )
                        }
                    }
                }
            }

            // Manual entry
            AddInviteeField { name, phone in
                viewModel.addInvitee(name: name, phoneNumber: phone, tier: 1)
            }

            // Unified invite list
            if viewModel.invitees.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text("Add people to invite")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xxl)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    // Playing section (Tier 1)
                    HStack {
                        Image(systemName: "person.fill.checkmark")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.success)
                        Text("Playing (\(viewModel.tier1Invitees.count))")
                            .font(Theme.Typography.headlineMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text("Drag to reorder")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }

                    tierInviteeList(tier: 1, benchTier: 2)

                    // Bench section (Tier 2 / Waitlist)
                    HStack {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.accent)
                        Text("Bench (\(viewModel.tier2Invitees.count))")
                            .font(Theme.Typography.headlineMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(.top, Theme.Spacing.md)

                    if viewModel.tier2Invitees.isEmpty {
                        Text("Move people here to waitlist them. They get invited in order when someone declines.")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                    .foregroundColor(Theme.Colors.divider)
                            )
                    } else {
                        tierInviteeList(tier: 2, benchTier: 1)
                    }

                    // Auto-promote toggle
                    Toggle(isOn: $viewModel.inviteStrategy.autoPromote) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-invite from bench")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Next on bench gets invited when someone declines")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    .tint(Theme.Colors.primary)
                    .padding(.top, Theme.Spacing.md)
                }
            }
        }
        .task {
            await viewModel.loadSuggestedContacts()
            await groupsViewModel.loadGroups()
        }
        .sheet(isPresented: $showGroupPicker) {
            GroupPickerSheet(groups: groupsViewModel.groups) { group in
                viewModel.loadGroupMembers(group)
            }
        }
    }

    private func addPeopleButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(Theme.Typography.calloutMedium)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(AddPeopleButtonStyle())
    }

    private func collapseKey(groupId: UUID, tier: Int) -> String {
        "\(groupId.uuidString)-\(tier)"
    }

    @ViewBuilder
    private func tierInviteeList(tier: Int, benchTier: Int) -> some View {
        let grouped = viewModel.groupedInvitees(forTier: tier)

        // Grouped invitees
        ForEach(grouped.groups, id: \.id) { group in
            let key = collapseKey(groupId: group.id, tier: tier)
            let isCollapsed = viewModel.collapsedGroups.contains(key)

            GroupInviteeHeader(
                emoji: group.emoji,
                groupName: group.name,
                groupId: group.id,
                memberCount: group.entries.count,
                isCollapsed: isCollapsed,
                onToggle: {
                    withAnimation(Theme.Animation.snappy) {
                        viewModel.toggleGroupCollapse(key)
                    }
                }
            )

            if !isCollapsed {
                ForEach(group.entries) { invitee in
                    draggableInviteeRow(invitee: invitee, groupEmoji: invitee.groupEmoji, benchTier: benchTier)
                }
            }
        }

        // Ungrouped invitees
        ForEach(grouped.ungrouped) { invitee in
            draggableInviteeRow(invitee: invitee, groupEmoji: nil, benchTier: benchTier)
        }
    }

    private func draggableInviteeRow(invitee: InviteeEntry, groupEmoji: String?, benchTier: Int) -> some View {
        InviteeRow(
            invitee: invitee,
            groupEmoji: groupEmoji,
            onBench: {
                viewModel.setInviteeTier(invitee.id, tier: benchTier)
            },
            onRemove: {
                if let idx = viewModel.invitees.firstIndex(where: { $0.id == invitee.id }) {
                    viewModel.removeInvitee(at: idx)
                }
            }
        )
        .opacity(draggingInviteeId == invitee.id ? 0.5 : 1.0)
        .onDrag {
            draggingInviteeId = invitee.id
            return NSItemProvider(object: invitee.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: InviteeDropDelegate(
            targetId: invitee.id,
            viewModel: viewModel,
            draggingId: $draggingInviteeId
        ))
    }
}

struct InviteeDropDelegate: DropDelegate {
    let targetId: UUID
    let viewModel: CreateEventViewModel
    @Binding var draggingId: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let sourceId = draggingId, sourceId != targetId else { return }
        guard let sourceIndex = viewModel.invitees.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = viewModel.invitees.firstIndex(where: { $0.id == targetId }) else { return }
        // Only reorder within same tier
        guard viewModel.invitees[sourceIndex].tier == viewModel.invitees[targetIndex].tier else { return }
        withAnimation(Theme.Animation.snappy) {
            viewModel.invitees.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
