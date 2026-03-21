import SwiftUI

// MARK: - Navigation Destination

/// Lightweight Hashable wrapper used for NavigationStack push navigation.
struct DMNavDestination: Hashable {
    let conversationId: UUID
    let otherUserId: UUID
    let otherDisplayName: String
    let otherAvatarUrl: String?

    init(summary: ConversationSummary) {
        self.conversationId = summary.conversationId
        self.otherUserId = summary.otherUserId
        self.otherDisplayName = summary.otherDisplayName
        self.otherAvatarUrl = summary.otherAvatarUrl
    }

    init(conversationId: UUID, otherUser: ConversationViewModel.ConversationOtherUser) {
        self.conversationId = conversationId
        self.otherUserId = otherUser.id
        self.otherDisplayName = otherUser.displayName
        self.otherAvatarUrl = otherUser.avatarUrl
    }
}

// MARK: - InboxView

struct InboxView: View {
    @StateObject private var viewModel = InboxViewModel()
    @EnvironmentObject var appState: AppState
    @Binding var navigationPath: NavigationPath
    @State private var showNewMessage = false
    @State private var toast: ToastItem?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                loadingState
            } else if viewModel.conversations.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .background(Theme.Colors.pageBackground.ignoresSafeArea())
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewMessage = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageSheet { conversationId, otherUser in
                showNewMessage = false
                Task {
                    await viewModel.loadConversations()
                    let dest = DMNavDestination(conversationId: conversationId, otherUser: otherUser)
                    navigationPath.append(dest)
                }
            }
        }
        .toast($toast)
        .task {
            await viewModel.loadConversations()
        }
        .refreshable {
            await viewModel.loadConversations()
        }
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.conversations) { summary in
                    let dest = DMNavDestination(summary: summary)
                    NavigationLink(value: dest) {
                        ConversationRow(summary: summary, currentUserId: appState.currentUser?.id)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(Theme.Colors.divider.opacity(0.5))
                        .padding(.leading, Theme.Spacing.xl + 48 + Theme.Spacing.md)
                }
            }
            .padding(.top, Theme.Spacing.xs)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { _ in
                    ConversationRowSkeleton()
                    Divider()
                        .background(Theme.Colors.divider.opacity(0.5))
                        .padding(.leading, Theme.Spacing.xl + 48 + Theme.Spacing.md)
                }
            }
            .padding(.top, Theme.Spacing.xs)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Gradients.primary)

            Text("No messages yet")
                .font(Theme.Typography.headlineLarge)
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Start a conversation with friends\nto plan your next game night.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)

            Button {
                showNewMessage = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "square.and.pencil")
                    Text("New Message")
                }
                .font(Theme.Typography.bodyMedium)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.jumbo)

            Spacer()
        }
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let summary: ConversationSummary
    let currentUserId: UUID?

    private var isUnread: Bool { summary.unreadCount > 0 }

    private var messagePreview: String {
        guard let content = summary.lastMessageContent else { return "No messages yet" }
        if summary.lastMessageType == "invite" {
            return "✉️ \(content)"
        }
        return content
    }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            // Avatar with gradient ring for unread conversations
            ZStack {
                if isUnread {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.primary, Theme.Colors.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                }
                AvatarView(url: summary.otherAvatarUrl, size: isUnread ? 44 : 48)
            }

            // Text content
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.otherDisplayName)
                        .font(isUnread ? Theme.Typography.bodyMedium : Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if let date = summary.lastMessageCreatedAt {
                        Text(date.relativeDisplay)
                            .font(Theme.Typography.caption2)
                            .foregroundColor(isUnread ? Theme.Colors.primary : Theme.Colors.textTertiary)
                    }
                }

                HStack(alignment: .center) {
                    Text(messagePreview)
                        .font(isUnread ? Theme.Typography.calloutMedium : Theme.Typography.callout)
                        .foregroundColor(isUnread ? Theme.Colors.textSecondary : Theme.Colors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    if isUnread {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.primary)
                                .frame(width: 20, height: 20)
                            Text(summary.unreadCount > 9 ? "9+" : "\(summary.unreadCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            isUnread
                ? Theme.Colors.primary.opacity(0.04)
                : Color.clear
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Skeleton Row

private struct ConversationRowSkeleton: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Theme.Colors.cardBackground)
                .frame(width: 48, height: 48)
                .shimmer()

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.cardBackground)
                    .frame(width: 120, height: 14)
                    .shimmer()
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.cardBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 12)
                    .shimmer()
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
    }
}
