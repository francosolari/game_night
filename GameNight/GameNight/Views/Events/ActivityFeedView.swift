import SwiftUI

struct ActivityFeedView: View {
    @ObservedObject var viewModel: EventViewModel
    let isHost: Bool
    @State private var isAnnouncement = false
    @State private var replyingTo: UUID?
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Activity")

            if !viewModel.canSeeActivityFeed {
                // Locked state
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text("RSVP to see comments & updates")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.xxl)
            } else {
                // Feed items
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.activityFeed) { item in
                        switch item.type {
                        case .rsvpUpdate:
                            RSVPUpdateRow(item: item)
                        case .comment, .announcement:
                            CommentRow(
                                item: item,
                                isHost: isHost,
                                replyingTo: $replyingTo,
                                onPin: { isPinned in
                                    Task { await viewModel.togglePin(itemId: item.id, isPinned: isPinned) }
                                }
                            )
                        }
                    }
                }

                // Comment input
                CommentInputBar(
                    text: $viewModel.newCommentText,
                    isAnnouncement: $isAnnouncement,
                    isPosting: viewModel.isPostingComment,
                    isHost: isHost,
                    isFocused: $isCommentFocused,
                    onSend: {
                        let content = viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !content.isEmpty else { return }
                        viewModel.newCommentText = ""
                        if isAnnouncement && isHost {
                            await viewModel.postAnnouncement(content: content)
                            isAnnouncement = false
                        } else {
                            await viewModel.postComment(content: content, parentId: replyingTo)
                            replyingTo = nil
                        }
                    }
                )
            }
        }
        .cardStyle()
    }
}

// MARK: - RSVP Update Row
private struct RSVPUpdateRow: View {
    let item: ActivityFeedItem

    private var statusText: String {
        switch item.content {
        case "accepted": return "is going"
        case "maybe": return "changed to maybe"
        case "declined": return "can't go"
        default: return "updated RSVP"
        }
    }

    private var dotColor: Color {
        switch item.content {
        case "accepted": return Theme.Colors.success
        case "maybe": return Theme.Colors.warning
        case "declined": return Theme.Colors.error
        default: return Theme.Colors.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            AvatarView(url: item.user?.avatarUrl, size: 18)

            Text(item.user?.displayName ?? "Someone")
                .font(Theme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.textSecondary)
            +
            Text(" \(statusText)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)

            Spacer()

            Text(item.createdAt.relativeDisplay)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textTertiary.opacity(0.7))
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 6)
    }
}

// MARK: - Comment Row
private struct CommentRow: View {
    let item: ActivityFeedItem
    let isHost: Bool
    @Binding var replyingTo: UUID?
    let onPin: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main comment
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                AvatarView(url: item.user?.avatarUrl, size: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.user?.displayName ?? "Unknown")
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)

                        if item.type == .announcement {
                            Text("HOST")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.Colors.primary)
                        }

                        Text(item.createdAt.relativeDisplay)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }

                    if let content = item.content {
                        Text(content)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineSpacing(2)
                    }

                    // Reply button
                    HStack(spacing: Theme.Spacing.md) {
                        Button {
                            replyingTo = item.id
                        } label: {
                            Text("Reply")
                                .font(Theme.Typography.caption2)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)

                        if let replies = item.replies, !replies.isEmpty {
                            Text("\(replies.count) \(replies.count == 1 ? "reply" : "replies")")
                                .font(Theme.Typography.caption2)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                item.type == .announcement ?
                    Theme.Colors.primary.opacity(0.06) : Color.clear
            )
            .contextMenu {
                if isHost {
                    Button {
                        onPin(!item.isPinned)
                    } label: {
                        Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                    }
                }
            }

            // Pinned badge
            if item.isPinned {
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                    Text("PINNED")
                        .font(.system(size: 9, weight: .bold, design: .default))
                        .tracking(0.5)
                }
                .foregroundColor(Theme.Colors.primary)
                .padding(.leading, Theme.Spacing.lg + 32)
                .padding(.bottom, 4)
            }

            // Replies
            if let replies = item.replies {
                ForEach(replies) { reply in
                    HStack(alignment: .top, spacing: 6) {
                        AvatarView(url: reply.user?.avatarUrl, size: 18)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(reply.user?.displayName ?? "Unknown")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text(reply.createdAt.relativeDisplay)
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                            if let content = reply.content {
                                Text(content)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }
                    }
                    .padding(.leading, Theme.Spacing.lg + 32)
                    .padding(.trailing, Theme.Spacing.lg)
                    .padding(.vertical, 4)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.Colors.primary.opacity(0.15))
                            .frame(width: 2)
                            .padding(.leading, Theme.Spacing.lg + 20)
                    }
                }
            }
        }
    }
}

// MARK: - Comment Input Bar
private struct CommentInputBar: View {
    @Binding var text: String
    @Binding var isAnnouncement: Bool
    let isPosting: Bool
    let isHost: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () async -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if isHost {
                HStack {
                    Button {
                        isAnnouncement.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isAnnouncement ? "megaphone.fill" : "megaphone")
                                .font(.system(size: 10))
                            Text(isAnnouncement ? "Announcement" : "Comment")
                                .font(Theme.Typography.caption2)
                        }
                        .foregroundColor(isAnnouncement ? Theme.Colors.primary : Theme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            HStack(spacing: 6) {
                TextField("Add a comment...", text: $text)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .focused(isFocused)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.fieldBackground)
                            .overlay(
                                Capsule()
                                    .stroke(Theme.Colors.divider, lineWidth: 1)
                            )
                    )

                if isPosting {
                    ProgressView()
                        .tint(Theme.Colors.primary)
                        .frame(width: 30, height: 30)
                } else {
                    Button {
                        Task { await onSend() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                Theme.Colors.textTertiary : Theme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
}

// MARK: - Date Relative Display
extension Date {
    var relativeDisplay: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}
