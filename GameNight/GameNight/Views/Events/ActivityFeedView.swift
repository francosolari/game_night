import SwiftUI

struct ActivityFeedView: View {
    @ObservedObject var viewModel: EventViewModel
    let isHost: Bool
    @State private var isAnnouncement = false
    @State private var replyingTo: ActivityFeedItem?
    @FocusState private var isCommentFocused: Bool

    private var visibleFeedItems: [ActivityFeedItem] {
        viewModel.activityFeed.filter { item in
            guard item.type == .rsvpUpdate else { return true }
            return item.content == "accepted" || item.content == "maybe"
        }
    }

    /// Group consecutive RSVP updates of the same status together.
    private var groupedFeedItems: [FeedDisplayItem] {
        var result: [FeedDisplayItem] = []
        var rsvpBuffer: [ActivityFeedItem] = []
        var currentRSVPStatus: String?

        func flushRSVPBuffer() {
            guard !rsvpBuffer.isEmpty else { return }
            if rsvpBuffer.count >= 3 {
                result.append(.groupedRSVP(items: rsvpBuffer, status: currentRSVPStatus ?? "accepted"))
            } else {
                for item in rsvpBuffer {
                    result.append(.single(item))
                }
            }
            rsvpBuffer = []
            currentRSVPStatus = nil
        }

        // Pinned items first
        let pinned = visibleFeedItems.filter { $0.isPinned }
        let unpinned = visibleFeedItems.filter { !$0.isPinned }

        for item in pinned {
            result.append(.pinned(item))
        }

        for item in unpinned {
            if item.type == .rsvpUpdate {
                if currentRSVPStatus == item.content {
                    rsvpBuffer.append(item)
                } else {
                    flushRSVPBuffer()
                    currentRSVPStatus = item.content
                    rsvpBuffer.append(item)
                }
            } else {
                flushRSVPBuffer()
                result.append(.single(item))
            }
        }
        flushRSVPBuffer()
        return result
    }

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
                    ForEach(Array(groupedFeedItems.enumerated()), id: \.offset) { _, displayItem in
                        switch displayItem {
                        case .pinned(let item):
                            PinnedItemRow(item: item, isHost: isHost) { isPinned in
                                Task { await viewModel.togglePin(itemId: item.id, isPinned: isPinned) }
                            }

                        case .single(let item):
                            if item.type == .rsvpUpdate {
                                RSVPUpdateRow(item: item)
                            } else if item.type == .dateConfirmed || item.type == .gameConfirmed {
                                SystemEventRow(item: item)
                            } else {
                                CommentRow(
                                    item: item,
                                    isHost: isHost,
                                    onReply: { replyingTo = item },
                                    onPin: { isPinned in
                                        Task { await viewModel.togglePin(itemId: item.id, isPinned: isPinned) }
                                    }
                                )
                            }

                        case .groupedRSVP(let items, let status):
                            GroupedRSVPRow(items: items, status: status)
                        }
                    }
                }

                // Comment input
                CommentInputBar(
                    text: $viewModel.newCommentText,
                    isAnnouncement: $isAnnouncement,
                    replyingTo: $replyingTo,
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
                            await viewModel.postComment(content: content, parentId: replyingTo?.id)
                            replyingTo = nil
                        }
                    }
                )
            }
        }
        .cardStyle()
    }
}

// MARK: - Feed Display Item

private enum FeedDisplayItem {
    case pinned(ActivityFeedItem)
    case single(ActivityFeedItem)
    case groupedRSVP(items: [ActivityFeedItem], status: String)
}

// MARK: - Pinned Item Row

private struct PinnedItemRow: View {
    let item: ActivityFeedItem
    let isHost: Bool
    let onPin: (Bool) -> Void

    var body: some View {
        AccentBorderCard(accentColor: Theme.Colors.primary, backgroundColor: Theme.Colors.primary.opacity(0.08)) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Pin badge
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                    Text("PINNED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(Theme.Colors.primary)
                .padding(.top, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)

                // Content
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    AvatarView(url: item.user?.avatarUrl, size: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.user?.displayName ?? "Unknown")
                                .font(Theme.Typography.calloutMedium)
                                .foregroundColor(Theme.Colors.textPrimary)

                            if item.type == .announcement {
                                hostBadge
                            }

                            Text(item.createdAt.relativeDisplay)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textTertiary)
                        }

                        if let content = item.content {
                            Text(content)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineSpacing(2)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            if isHost {
                Button {
                    onPin(false)
                } label: {
                    Label("Unpin", systemImage: "pin.slash")
                }
            }
        }
    }

    private var hostBadge: some View {
        Text("HOST")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(Theme.Colors.primary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                Capsule().fill(Theme.Colors.primary.opacity(0.12))
            )
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
            AvatarView(url: item.user?.avatarUrl, size: 20)

            Text(item.user?.displayName ?? "Someone")
                .font(Theme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.textSecondary)
            +
            Text(" \(statusText)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)

            StatusDot(color: dotColor, size: 6)

            Spacer()

            Text(item.createdAt.relativeDisplay)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textTertiary.opacity(0.7))
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 6)
    }
}

// MARK: - Grouped RSVP Row

private struct GroupedRSVPRow: View {
    let items: [ActivityFeedItem]
    let status: String

    private var statusText: String {
        switch status {
        case "accepted": return "are going"
        case "maybe": return "changed to maybe"
        default: return "updated RSVP"
        }
    }

    private var dotColor: Color {
        switch status {
        case "accepted": return Theme.Colors.success
        case "maybe": return Theme.Colors.warning
        default: return Theme.Colors.textTertiary
        }
    }

    private var displayNames: String {
        let names = items.compactMap { $0.user?.displayName }
        if names.count <= 2 {
            return names.joined(separator: " and ")
        }
        let first = names.prefix(2).joined(separator: ", ")
        return "\(first), and \(names.count - 2) other\(names.count - 2 == 1 ? "" : "s")"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            AvatarStack(
                urls: items.prefix(3).map { $0.user?.avatarUrl },
                size: 20,
                maxDisplay: 3
            )

            Text(displayNames)
                .font(Theme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.textSecondary)
            +
            Text(" \(statusText)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)

            StatusDot(color: dotColor, size: 6)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 6)
    }
}

// MARK: - System Event Row (date_confirmed / game_confirmed)

private struct SystemEventRow: View {
    let item: ActivityFeedItem

    private var icon: String {
        item.type == .dateConfirmed ? "calendar.badge.checkmark" : "gamecontroller.fill"
    }

    private var label: String {
        if item.type == .dateConfirmed {
            if let iso = item.content, let date = ISO8601DateFormatter().date(from: iso) {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
                return "Date confirmed: \(formatter.string(from: date))"
            }
            return "Date confirmed"
        } else {
            let name = item.content ?? "a game"
            return "\(name) selected for the night"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 20)

            Text(label)
                .font(Theme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.textSecondary)

            Spacer()

            Text(item.createdAt.relativeDisplay)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textTertiary.opacity(0.7))
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 8)
        .background(Theme.Colors.primary.opacity(0.05))
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let item: ActivityFeedItem
    let isHost: Bool
    let onReply: () -> Void
    let onPin: (Bool) -> Void

    private var isAnnouncement: Bool { item.type == .announcement }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main comment
            let commentContent = VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    AvatarView(url: item.user?.avatarUrl, size: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.user?.displayName ?? "Unknown")
                                .font(Theme.Typography.calloutMedium)
                                .foregroundColor(Theme.Colors.textPrimary)

                            if isAnnouncement {
                                HStack(spacing: 2) {
                                    Image(systemName: "megaphone.fill")
                                        .font(.system(size: 8))
                                    Text("HOST")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(Theme.Colors.primary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Theme.Colors.primary.opacity(0.12))
                                )
                            }

                            Text(item.createdAt.relativeDisplay)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textTertiary)
                        }

                        if let content = item.content {
                            Text(content)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineSpacing(2)
                        }

                        // Reply button + reply count
                        HStack(spacing: Theme.Spacing.md) {
                            Button(action: onReply) {
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
                .padding(.vertical, Theme.Spacing.md)
            }

            if isAnnouncement {
                AccentBorderCard(
                    accentColor: Theme.Colors.primary,
                    backgroundColor: Theme.Colors.primary.opacity(0.08)
                ) {
                    commentContent
                }
            } else {
                commentContent
            }

            // Replies with connector line
            if let replies = item.replies {
                ForEach(replies) { reply in
                    HStack(alignment: .top, spacing: 6) {
                        AvatarView(url: reply.user?.avatarUrl, size: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(reply.user?.displayName ?? "Unknown")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text(reply.createdAt.relativeDisplay)
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                            if let content = reply.content {
                                Text(content)
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.leading, Theme.Spacing.lg + 40)
                    .padding(.trailing, Theme.Spacing.lg)
                    .padding(.vertical, 4)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.Colors.primary.opacity(0.15))
                            .frame(width: 2)
                            .padding(.leading, Theme.Spacing.lg + 26)
                    }
                }
            }

            // Subtle divider between comments
            if !isAnnouncement {
                Divider()
                    .background(Theme.Colors.divider.opacity(0.5))
                    .padding(.leading, Theme.Spacing.lg + 40)
            }
        }
        .contextMenu {
            if isHost {
                Button {
                    onPin(!item.isPinned)
                } label: {
                    Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                }
            }
        }
    }
}

// MARK: - Comment Input Bar

private struct CommentInputBar: View {
    @Binding var text: String
    @Binding var isAnnouncement: Bool
    @Binding var replyingTo: ActivityFeedItem?
    let isPosting: Bool
    let isHost: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () async -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            // "Replying to" chip
            if let replyTarget = replyingTo {
                HStack(spacing: Theme.Spacing.xs) {
                    Text("Replying to \(replyTarget.user?.displayName ?? "Unknown")")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.primary)

                    Button {
                        replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                .padding(.horizontal, Theme.Spacing.lg)
            }

            // Announcement toggle
            if isHost && replyingTo == nil {
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
