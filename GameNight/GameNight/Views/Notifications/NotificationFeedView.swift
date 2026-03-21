import SwiftUI

struct NotificationFeedView: View {
    @Binding var navigationPath: NavigationPath
    @StateObject private var viewModel = NotificationViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            Theme.Colors.pageBackground
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.notifications.isEmpty {
                loadingState
            } else if viewModel.notifications.isEmpty {
                emptyState
            } else {
                feedList
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                markAllReadButton
            }
        }
        .onAppear {
            Task { await viewModel.loadNotifications() }
            viewModel.subscribe()
        }
        .onDisappear {
            viewModel.unsubscribe()
        }
    }

    // MARK: - Feed List

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.notifications) { notification in
                    Button {
                        Task { await viewModel.markAsRead(notification) }
                        if let eventId = notification.eventId {
                            navigationPath.append(HomeDestination.eventDetail(eventId))
                        }
                    } label: {
                        NotificationRow(notification: notification)
                    }
                    .buttonStyle(.plain)

                    if notification.id != viewModel.notifications.last?.id {
                        Divider()
                            .overlay(Theme.Colors.divider)
                            .padding(.leading, Theme.Spacing.lg + 40 + Theme.Spacing.md)
                    }
                }
            }
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(themeManager.isDark ? 0.3 : 0.06),
                radius: 8, x: 0, y: 4
            )
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .refreshable {
            await viewModel.loadNotifications()
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { index in
                    ShimmerNotificationRow()

                    if index < 7 {
                        Divider()
                            .overlay(Theme.Colors.divider)
                            .padding(.leading, Theme.Spacing.lg + 40 + Theme.Spacing.md)
                    }
                }
            }
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.Colors.primarySubtle)
                    .frame(width: 80, height: 80)

                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Theme.Colors.primary)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("No Notifications")
                    .font(Theme.Typography.headlineMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("You're all caught up. Invite friends to a game night to get started.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxxl)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar Button

    private var markAllReadButton: some View {
        let hasUnread = viewModel.notifications.contains { !$0.isRead }

        return Button {
            Task { await viewModel.markAllAsRead() }
        } label: {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(hasUnread ? Theme.Colors.primary : Theme.Colors.textTertiary)
        }
        .disabled(!hasUnread)
    }
}

// MARK: - Shimmer Placeholder Row

private struct ShimmerNotificationRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Icon circle placeholder
            Circle()
                .fill(Theme.Colors.backgroundElevated)
                .frame(width: 40, height: 40)
                .shimmer()

            // Content placeholder
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.backgroundElevated)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                    .shimmer()

                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.backgroundElevated)
                    .frame(height: 12)
                    .frame(maxWidth: 200)
                    .shimmer()

                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .fill(Theme.Colors.backgroundElevated)
                    .frame(height: 10)
                    .frame(maxWidth: 60)
                    .shimmer()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }
}
