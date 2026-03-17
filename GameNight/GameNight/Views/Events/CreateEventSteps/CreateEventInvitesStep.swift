import SwiftUI

struct CreateEventInvitesStep: View {
    @ObservedObject var viewModel: CreateEventViewModel
    @ObservedObject var groupsViewModel: GroupsViewModel
    @Binding var showGroupPicker: Bool
    @Binding var showContactList: Bool
    @Binding var showContactPicker: Bool

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
                        Button {
                            showGroupPicker = true
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 14))
                                Text("Groups")
                                    .font(Theme.Typography.calloutMedium)
                            }
                            .foregroundColor(Theme.Colors.secondary)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.secondary.opacity(0.1))
                            )
                        }
                    }

                    Button {
                        showContactList = true
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 14))
                            Text("All Contacts")
                                .font(Theme.Typography.calloutMedium)
                        }
                        .foregroundColor(Theme.Colors.primary)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.primary.opacity(0.1))
                        )
                    }

                    Button {
                        showContactPicker = true
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14))
                            Text("Phone")
                                .font(Theme.Typography.calloutMedium)
                        }
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.accent.opacity(0.1))
                        )
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

    @ViewBuilder
    private func tierInviteeList(tier: Int, benchTier: Int) -> some View {
        let grouped = viewModel.groupedInvitees(forTier: tier)

        // Grouped invitees
        ForEach(grouped.groups, id: \.id) { group in
            let isCollapsed = viewModel.collapsedGroups.contains(group.id)

            GroupInviteeHeader(
                emoji: group.emoji,
                groupId: group.id,
                memberCount: group.entries.count,
                isCollapsed: isCollapsed,
                onToggle: {
                    withAnimation(Theme.Animation.snappy) {
                        viewModel.toggleGroupCollapse(group.id)
                    }
                }
            )

            if !isCollapsed {
                ForEach(group.entries) { invitee in
                    InviteeRow(
                        invitee: invitee,
                        groupEmoji: invitee.groupEmoji,
                        onBench: {
                            viewModel.setInviteeTier(invitee.id, tier: benchTier)
                        },
                        onRemove: {
                            if let idx = viewModel.invitees.firstIndex(where: { $0.id == invitee.id }) {
                                viewModel.removeInvitee(at: idx)
                            }
                        }
                    )
                }
            }
        }

        // Ungrouped invitees
        ForEach(grouped.ungrouped) { invitee in
            InviteeRow(
                invitee: invitee,
                onBench: {
                    viewModel.setInviteeTier(invitee.id, tier: benchTier)
                },
                onRemove: {
                    if let idx = viewModel.invitees.firstIndex(where: { $0.id == invitee.id }) {
                        viewModel.removeInvitee(at: idx)
                    }
                }
            )
        }
    }
}
