import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedEvent: GameEvent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Game Night")
                                .font(Theme.Typography.displayLarge)
                                .foregroundColor(Theme.Colors.textPrimary)

                            Text("Your upcoming sessions")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                        Spacer()

                        Button {
                            appState.showCreateEvent = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.Gradients.primary)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.lg)

                    if viewModel.isLoading {
                        // Skeleton loading
                        VStack(spacing: Theme.Spacing.lg) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                    .fill(Theme.Colors.cardBackground)
                                    .frame(height: 280)
                                    .shimmer()
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    } else if viewModel.upcomingEvents.isEmpty {
                        EmptyStateView(
                            icon: "dice.fill",
                            title: "No Game Nights Yet",
                            message: "Create your first game night and invite friends to play!",
                            actionLabel: "Create Game Night"
                        ) {
                            appState.showCreateEvent = true
                        }
                        .frame(minHeight: 400)
                    } else {
                        // My Invites Section
                        let pendingInvites = viewModel.myInvites.filter { $0.status == .pending }
                        if !pendingInvites.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                SectionHeader(title: "Pending Invites")
                                    .padding(.horizontal, Theme.Spacing.xl)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Spacing.md) {
                                        ForEach(pendingInvites) { invite in
                                            PendingInviteCard(invite: invite)
                                                .frame(width: 280)
                                        }
                                    }
                                    .padding(.horizontal, Theme.Spacing.xl)
                                }
                            }
                        }

                        // Upcoming Events
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            SectionHeader(title: "Upcoming")
                                .padding(.horizontal, Theme.Spacing.xl)

                            LazyVStack(spacing: Theme.Spacing.lg) {
                                ForEach(viewModel.upcomingEvents) { event in
                                    EventCard(
                                        event: event,
                                        myInvite: viewModel.invite(for: event.id)
                                    ) {
                                        selectedEvent = event
                                    }
                                    .fadeIn(delay: Double(viewModel.upcomingEvents.firstIndex(where: { $0.id == event.id }) ?? 0) * 0.1)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.xl)
                        }
                    }
                }
                .padding(.bottom, 100) // Tab bar clearance
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .refreshable {
                await viewModel.loadData()
            }
            .navigationDestination(item: $selectedEvent) { event in
                EventDetailView(eventId: event.id)
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Pending Invite Card
struct PendingInviteCard: View {
    let invite: Invite

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(Theme.Gradients.primary)

                Spacer()

                Text("RSVP")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.primary)
            }

            Text(invite.displayName ?? "Game Night")
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)

            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                Text("Respond soon")
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(Theme.Colors.warning)
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Theme.Colors.primary.opacity(0.3), lineWidth: 1)
        )
    }
}

// Make GameEvent Hashable for navigation
extension GameEvent: Hashable {
    static func == (lhs: GameEvent, rhs: GameEvent) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
