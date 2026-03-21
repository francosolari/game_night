import SwiftUI

struct ConversationView: View {
    @StateObject var viewModel: ConversationViewModel
    @EnvironmentObject var appState: AppState
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @State private var toast: ToastItem?
    @State private var navigateToEventId: String?

    var body: some View {
        VStack(spacing: 0) {
            messageArea
            Divider()
                .background(Theme.Colors.divider)
            inputBar
        }
        .background(Theme.Colors.pageBackground.ignoresSafeArea())
        .navigationTitle(viewModel.otherUser.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .task {
            await viewModel.loadMessages()
            viewModel.subscribe()
            await viewModel.markAsRead()
        }
        .onDisappear {
            viewModel.unsubscribe()
        }
        .onChange(of: viewModel.error) { _, newError in
            if let msg = newError {
                toast = ToastItem(style: .error, message: msg)
            }
        }
    }

    // MARK: - Message Area

    private var messageArea: some View {
        Group {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                loadingState
            } else if viewModel.messages.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.xs) {
                            ForEach(viewModel.messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }
                            // Invisible anchor for auto-scroll
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(Theme.Animation.smooth) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ message: DirectMessage) -> some View {
        let isSent = message.senderId == appState.currentUser?.id

        switch message.messageType {
        case .system:
            systemMessage(message)

        case .invite:
            inviteBubble(message, isSent: isSent)

        case .text:
            textBubble(message, isSent: isSent)
        }
    }

    private func textBubble(_ message: DirectMessage, isSent: Bool) -> some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            if isSent { Spacer(minLength: 48) }

            if !isSent {
                AvatarView(url: viewModel.otherUser.avatarUrl, size: 28)
                    .padding(.bottom, 2)
            }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 2) {
                Text(message.content ?? "")
                    .font(Theme.Typography.body)
                    .foregroundColor(isSent ? Theme.Colors.primaryActionText : Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isSent ? Theme.Colors.primary : Theme.Colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        isSent ? Color.clear : Theme.Colors.divider,
                                        lineWidth: 1
                                    )
                            )
                    )

                Text(message.createdAt.relativeDisplay)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .padding(.horizontal, Theme.Spacing.xs)
            }

            if isSent {
                AvatarView(url: appState.currentUser?.avatarUrl, size: 28)
                    .padding(.bottom, 2)
            } else {
                Spacer(minLength: 48)
            }
        }
    }

    private func inviteBubble(_ message: DirectMessage, isSent: Bool) -> some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            if isSent { Spacer(minLength: 32) }

            if !isSent {
                AvatarView(url: viewModel.otherUser.avatarUrl, size: 28)
                    .padding(.bottom, 2)
            }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 4) {
                if let metadata = message.metadata {
                    InviteMessageCard(metadata: metadata) {
                        if let eventIdString = metadata.eventId {
                            appState.deepLinkEventId = eventIdString
                        }
                    }
                    .frame(maxWidth: 280)
                }

                Text(message.createdAt.relativeDisplay)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.textTertiary)
                    .padding(.horizontal, Theme.Spacing.xs)
            }

            if isSent {
                AvatarView(url: appState.currentUser?.avatarUrl, size: 28)
                    .padding(.bottom, 2)
            } else {
                Spacer(minLength: 32)
            }
        }
    }

    private func systemMessage(_ message: DirectMessage) -> some View {
        HStack {
            Spacer()
            Text(message.content ?? "")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.xs)
            Spacer()
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Message...", text: $viewModel.newMessageText, axis: .vertical)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    Capsule()
                        .fill(Theme.Colors.fieldBackground)
                        .overlay(
                            Capsule()
                                .stroke(
                                    isInputFocused ? Theme.Colors.primary : Theme.Colors.divider,
                                    lineWidth: 1
                                )
                        )
                )
                .animation(Theme.Animation.snappy, value: isInputFocused)

            if viewModel.isSending {
                ProgressView()
                    .tint(Theme.Colors.primary)
                    .frame(width: 34, height: 34)
            } else {
                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(
                            viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Theme.Colors.textTertiary
                                : Theme.Colors.primary
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .animation(Theme.Animation.snappy, value: viewModel.newMessageText.isEmpty)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.cardBackground.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Placeholder States

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            ForEach(0..<4, id: \.self) { i in
                HStack {
                    if i % 2 == 0 { Spacer(minLength: 60) }
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.Colors.cardBackground)
                        .frame(width: CGFloat.random(in: 120...220), height: 40)
                        .shimmer()
                    if i % 2 != 0 { Spacer(minLength: 60) }
                }
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: "bubble.left")
                .font(.system(size: 36))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("Say hello!")
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Start the conversation with \(viewModel.otherUser.displayName).")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
            Spacer()
        }
    }
}
