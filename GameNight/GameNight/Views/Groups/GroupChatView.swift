import SwiftUI

struct GroupChatView: View {
    @ObservedObject var viewModel: GroupDetailViewModel
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingMessages && viewModel.messages.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.cardBackground)
                            .frame(height: 48)
                            .shimmer()
                    }
                }
            } else if viewModel.messages.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text("No messages yet")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text("Start a conversation with your group!")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.xxl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages) { message in
                        VStack(alignment: .leading, spacing: 0) {
                            // Main message
                            chatMessageRow(message)

                            // Replies
                            if let replies = message.replies {
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
                                            Text(reply.content)
                                                .font(Theme.Typography.callout)
                                                .foregroundColor(Theme.Colors.textSecondary)
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

                            Divider()
                                .background(Theme.Colors.divider.opacity(0.5))
                                .padding(.leading, Theme.Spacing.lg + 40)
                        }
                    }
                }
            }

            // Input bar
            chatInputBar
        }
        .cardStyle()
    }

    private func chatMessageRow(_ message: GroupMessage) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            AvatarView(url: message.user?.avatarUrl, size: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.user?.displayName ?? "Unknown")
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text(message.createdAt.relativeDisplay)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textTertiary)
                }

                Text(message.content)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineSpacing(2)

                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        viewModel.replyingTo = message
                    } label: {
                        Text("Reply")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)

                    if let replies = message.replies, !replies.isEmpty {
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

    private var chatInputBar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            // Replying-to chip
            if let replyTarget = viewModel.replyingTo {
                HStack(spacing: Theme.Spacing.xs) {
                    Text("Replying to \(replyTarget.user?.displayName ?? "Unknown")")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.primary)

                    Button {
                        viewModel.replyingTo = nil
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

            HStack(spacing: 6) {
                TextField("Message...", text: $viewModel.newMessageText)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .focused($isCommentFocused)
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

                if viewModel.isPostingMessage {
                    ProgressView()
                        .tint(Theme.Colors.primary)
                        .frame(width: 30, height: 30)
                } else {
                    Button {
                        Task { await viewModel.postMessage() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                Theme.Colors.textTertiary : Theme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
}
