import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @Binding var navigationPath: NavigationPath
    @State private var draftToResume: GameEvent?

    private var carouselCardWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let padding = Theme.Spacing.xl * 2
        let spacing = Theme.Spacing.md
        return (screenWidth - padding - spacing) / 2.15
    }

    var body: some View {
        ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                                Text("Game Night")
                                    .font(Theme.Typography.displayLarge)
                                    .foregroundColor(Theme.Colors.textPrimary)

                                Image("MeepleLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .opacity(0.6)
                            }

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

                    if let error = viewModel.error {
                        HomeErrorCard(error: error) {
                            Task { await viewModel.loadData() }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }

                    // Drafts section (always visible when drafts exist, even while loading)
                    if !viewModel.drafts.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            SectionHeader(title: "Drafts")
                                .padding(.horizontal, Theme.Spacing.xl)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.md) {
                                    ForEach(viewModel.drafts) { draft in
                                        DraftCard(draft: draft) {
                                            draftToResume = draft
                                        }
                                        .frame(width: 200)
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.xl)
                            }
                        }
                    }

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
                    } else if viewModel.upcomingEvents.isEmpty && viewModel.drafts.isEmpty {
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

                        // Next Up — horizontal carousel (future/today events only)
                        let futureEvents = viewModel.upcomingEvents.filter { event in
                            let eventDate = event.timeOptions.first?.date ?? event.createdAt
                            return eventDate >= Calendar.current.startOfDay(for: Date())
                        }

                        if !futureEvents.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                SectionHeader(title: "Next Up", action: "View all") {
                                    navigationPath.append(CalendarDestination())
                                }
                                .padding(.horizontal, Theme.Spacing.xl)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Spacing.md) {
                                        ForEach(futureEvents) { event in
                                            CompactEventCard(
                                                event: event,
                                                myInvite: viewModel.invite(for: event.id),
                                                confirmedCount: viewModel.confirmedCount(for: event.id)
                                            ) {
                                                navigationPath.append(event)
                                            }
                                            .frame(width: carouselCardWidth)
                                        }
                                    }
                                    .padding(.horizontal, Theme.Spacing.xl)
                                    .scrollTargetLayout()
                                }
                                .scrollTargetBehavior(.viewAligned)
                            }
                        }

                        // Hosting — events I'm hosting from upcoming
                        let currentUserId = SupabaseService.shared.client.auth.currentSession?.user.id
                        let hostingEvents = futureEvents.filter { $0.hostId == currentUserId }

                        if !hostingEvents.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                SectionHeader(title: "Hosting")
                                    .padding(.horizontal, Theme.Spacing.xl)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Spacing.md) {
                                        ForEach(hostingEvents) { event in
                                            CompactEventCard(
                                                event: event,
                                                myInvite: viewModel.invite(for: event.id),
                                                confirmedCount: viewModel.confirmedCount(for: event.id)
                                            ) {
                                                navigationPath.append(event)
                                            }
                                            .frame(width: carouselCardWidth)
                                        }
                                    }
                                    .padding(.horizontal, Theme.Spacing.xl)
                                    .scrollTargetLayout()
                                }
                                .scrollTargetBehavior(.viewAligned)
                            }
                        }
                    }
                }
                .padding(.bottom, 100) // Tab bar clearance
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .refreshable {
                await viewModel.loadData()
            }
        .task {
            await viewModel.loadData()
        }
        .sheet(item: $draftToResume) { draft in
            CreateEventView(eventToEdit: draft) { _ in
                Task { await viewModel.loadData() }
            }
        }
    }
}

// MARK: - Pending Invite Card
private struct HomeErrorCard: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Some home data couldn't load")
                .font(Theme.Typography.bodySemibold)
                .foregroundColor(Theme.Colors.error)

            Text(error)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Try Again", action: onRetry)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.primary)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.error.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(Theme.Colors.error.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct PendingInviteCard: View {
    let invite: Invite

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(Theme.Gradients.primary)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.Colors.highlight)
                        .frame(width: 8, height: 8)
                    Text("RSVP")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.primary)
                }
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
            .foregroundColor(Theme.Colors.dateAccent)
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Theme.Colors.primary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Draft Card
struct DraftCard: View {
    let draft: GameEvent
    let onResume: () -> Void

    var body: some View {
        Button(action: onResume) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(Theme.Colors.textTertiary)
                    Spacer()
                    Text("DRAFT")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Theme.Colors.accent.opacity(0.15))
                        )
                }

                Text(draft.title.isEmpty ? "Untitled" : draft.title)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.sm) {
                    if !draft.games.isEmpty {
                        Label("\(draft.games.count)", systemImage: "gamecontroller")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primary)
                    }
                    if let invitees = draft.draftInvitees, !invitees.isEmpty {
                        Label("\(invitees.count)", systemImage: "person.2")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.dateAccent)
                    }
                }

                Text(draft.updatedAt, style: .relative)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.textTertiary)

                Text("Continue")
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.primary)
            }
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .stroke(Theme.Colors.accent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

// MARK: - Calendar Navigation Destination
struct CalendarDestination: Hashable {}
