import SwiftUI

/// Sheet shown when tapping a group invite card. Displays members + their top 3 games
/// in a limited preview (no history, no pending invites — just who's in the group).
struct GroupInvitePreviewSheet: View {
    let groupId: UUID
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var preview: GroupInvitePreview?
    @State private var isLoading = true
    @State private var isResponding = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if isLoading {
                    loadingState
                } else if let preview {
                    contentView(preview)
                } else {
                    errorState
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }
        }
        .task {
            do {
                preview = try await SupabaseService.shared.fetchGroupInvitePreview(groupId: groupId)
            } catch {
                // Preview failed but card still works
            }
            isLoading = false
        }
    }

    // MARK: - Content

    private func contentView(_ preview: GroupInvitePreview) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                // Group header
                groupHeader(preview)

                // Members list
                membersSection(preview)

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
    }

    // MARK: - Group Header

    private func groupHeader(_ preview: GroupInvitePreview) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Gradients.primary)
                    .frame(width: 72, height: 72)
                Text(preview.group.emoji)
                    .font(.system(size: 36))
            }

            Text(preview.group.name)
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            if let desc = preview.group.description, !desc.isEmpty {
                Text(desc)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                Text("\(preview.totalMemberCount) member\(preview.totalMemberCount == 1 ? "" : "s")")
                    .font(Theme.Typography.callout)
            }
            .foregroundColor(Theme.Colors.textTertiary)
        }
    }

    // MARK: - Members Section

    private func membersSection(_ preview: GroupInvitePreview) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Members")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(0.4)
                .padding(.leading, Theme.Spacing.xs)

            VStack(spacing: 0) {
                // Owner first (always)
                memberRow(preview.owner, isOwner: true)

                // Then accepted members
                ForEach(Array(preview.members.enumerated()), id: \.element.id) { index, member in
                    Divider()
                        .overlay(Theme.Colors.divider)
                        .padding(.leading, 52 + Theme.Spacing.md)

                    memberRow(member, isOwner: false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .stroke(Theme.Colors.border.opacity(0.5), lineWidth: 0.5)
            )
        }
    }

    private func memberRow(_ member: GroupMemberPreview, isOwner: Bool) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            AvatarView(url: member.avatarUrl, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(member.displayName)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    if isOwner {
                        Text("Admin")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Theme.Colors.primarySubtle)
                            )
                    }
                }

                if !member.topGames.isEmpty {
                    topGamesRow(member.topGames)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }

    private func topGamesRow(_ games: [GamePreviewInfo]) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            // Game thumbnails
            HStack(spacing: -4) {
                ForEach(Array(games.prefix(3).enumerated()), id: \.offset) { index, game in
                    if let url = game.thumbnailUrl, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.fieldBackground)
                        }
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.Colors.cardBackground, lineWidth: 1.5)
                        )
                        .zIndex(Double(3 - index))
                    }
                }
            }

            Text(games.prefix(3).map(\.name).joined(separator: ", "))
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textTertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button {
                guard !isResponding else { return }
                isResponding = true
                onDecline()
                dismiss()
            } label: {
                Text("Decline")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.fieldBackground)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isResponding)

            Button {
                guard !isResponding else { return }
                isResponding = true
                onAccept()
                dismiss()
            } label: {
                Text("Join Group")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.primary)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isResponding)
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            // Shimmer header
            VStack(spacing: Theme.Spacing.md) {
                Circle()
                    .fill(Theme.Colors.shimmer)
                    .frame(width: 72, height: 72)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.shimmer)
                    .frame(width: 140, height: 20)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.shimmer)
                    .frame(width: 80, height: 14)
            }

            // Shimmer member rows
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    if i > 0 {
                        Divider().overlay(Theme.Colors.divider)
                            .padding(.leading, 52 + Theme.Spacing.md)
                    }
                    HStack(spacing: Theme.Spacing.md) {
                        Circle()
                            .fill(Theme.Colors.shimmer)
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.Colors.shimmer)
                                .frame(width: CGFloat.random(in: 80...140), height: 14)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.Colors.shimmer)
                                .frame(width: CGFloat.random(in: 100...180), height: 10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .fill(Theme.Colors.cardBackground)
            )
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.top, Theme.Spacing.xxl)
    }

    // MARK: - Error

    private var errorState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("Couldn't load group preview")
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}
