import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @Binding var navigationPath: NavigationPath
    @State private var draftToResume: GameEvent?
    @State private var eventsNeedingPlayLog: [GameEvent] = []
    @State private var dismissedPlayLogIds: Set<UUID> = HomeView.loadDismissedPlayLogIds()
    @State private var playLogEvent: GameEvent?
    @State private var refreshHandlerToken: UUID?
    private static let dismissedPlayLogEventIdsKeyPrefix = "dismissedPlayLogEventIds"

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
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            HStack(alignment: .center, spacing: 6) {
                                Text("CardboardWithMe")
                                    .font(Theme.Typography.displayLarge)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .minimumScaleFactor(0.75)
                                    .lineLimit(1)

                                Image("MeepleLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .opacity(0.6)
                            }

                            Text("Your upcoming sessions")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 8) {
                            // Notifications
                            Button {
                                navigationPath.append(HomeDestination.notifications)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Theme.Colors.textSecondary)

                                    if appState.unreadNotificationCount > 0 {
                                        Circle()
                                            .fill(Theme.Colors.error)
                                            .frame(width: 6, height: 6)
                                            .offset(x: 2, y: -1)
                                    }
                                }
                                .frame(width: 24, height: 24)
                            }

                            // Messages
                            Button {
                                navigationPath.append(HomeDestination.inbox)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bubble.left.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Theme.Colors.textSecondary)

                                    if appState.unreadMessageCount > 0 {
                                        Circle()
                                            .fill(Theme.Colors.error)
                                            .frame(width: 6, height: 6)
                                            .offset(x: 2, y: -1)
                                    }
                                }
                                .frame(width: 24, height: 24)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.lg)

                    if let error = viewModel.error {
                        HomeErrorCard(error: error) {
                            Task { await viewModel.loadData() }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }

                    // Log Your Plays banner
                    let visiblePlayLogEvents = eventsNeedingPlayLog.filter {
                        $0.deletedAt == nil && !dismissedPlayLogIds.contains($0.id)
                    }
                    if !visiblePlayLogEvents.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            SectionHeader(title: "Log Your Plays")
                                .padding(.horizontal, Theme.Spacing.xl)

                            ForEach(visiblePlayLogEvents) { event in
                                HStack(spacing: Theme.Spacing.md) {
                                    // Game thumbnail
                                    if let imageUrl = event.preferredCoverImageURLString, let url = URL(string: imageUrl) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                                .fill(Theme.Colors.primary.opacity(0.1))
                                        }
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                                .fill(Theme.Colors.primary.opacity(0.1))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "trophy")
                                                .font(.system(size: 16))
                                                .foregroundColor(Theme.Colors.primary)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title)
                                            .font(Theme.Typography.bodyMedium)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                            .lineLimit(1)
                                        Text("What did you play?")
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textTertiary)
                                    }

                                    Spacer()

                                    Button {
                                        playLogEvent = event
                                    } label: {
                                        Text("Log")
                                            .font(Theme.Typography.calloutMedium)
                                            .foregroundColor(Theme.Colors.primary)
                                            .padding(.horizontal, Theme.Spacing.md)
                                            .padding(.vertical, Theme.Spacing.sm)
                                            .background(Capsule().fill(Theme.Colors.primary.opacity(0.1)))
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        dismissPlayLogPrompt(for: event.id)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.Colors.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(Theme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                        .fill(Theme.Colors.cardBackground)
                                )
                            }
                            .padding(.horizontal, Theme.Spacing.xl)
                        }
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

                    // Compute future events once for empty state check and display
                    let startOfToday = Calendar.current.startOfDay(for: Date())
                    let futureEvents = viewModel.upcomingEvents.filter { event in
                        event.effectiveStartDate >= startOfToday
                    }
                    let awaitingResponseItems = viewModel.awaitingResponseEvents
                    let pendingGroupInvites = viewModel.pendingGroupInvites
                    let hasVisibleContent = !futureEvents.isEmpty
                        || !awaitingResponseItems.isEmpty
                        || !pendingGroupInvites.isEmpty
                        || !viewModel.drafts.isEmpty

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
                    } else if !hasVisibleContent {
                        VStack(spacing: Theme.Spacing.xxl) {
                            Spacer()
                                .frame(height: 60)

                            Image(systemName: "dice.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(Theme.Gradients.primary)

                            VStack(spacing: Theme.Spacing.sm) {
                                Text("No Game Nights Yet")
                                    .font(Theme.Typography.headlineLarge)
                                    .foregroundColor(Theme.Colors.textPrimary)

                                Text("Get the crew together — pick a game,\nset the date, and send out invites.")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }

                            Button {
                                appState.showCreateEvent = true
                            } label: {
                                Text("Plan a Game Night")
                                    .font(Theme.Typography.bodySemibold)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal, Theme.Spacing.jumbo)

                            Button("View All Events") {
                                navigationPath.append(CalendarDestination())
                            }
                            .font(Theme.Typography.bodySemibold)
                            .foregroundColor(Theme.Colors.primaryAction)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Theme.Spacing.xl)
                    } else {
                        if !awaitingResponseItems.isEmpty || !pendingGroupInvites.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                SectionHeader(title: "Awaiting Response")
                                    .padding(.horizontal, Theme.Spacing.xl)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Spacing.md) {
                                        // Group invites (shown first — more time-sensitive)
                                        ForEach(pendingGroupInvites, id: \.member.id) { entry in
                                            GroupInviteCard(
                                                group: entry.group,
                                                member: entry.member,
                                                onAccept: {
                                                    Task { await viewModel.respondToGroupInvite(memberId: entry.member.id, accept: true) }
                                                },
                                                onDecline: {
                                                    Task { await viewModel.respondToGroupInvite(memberId: entry.member.id, accept: false) }
                                                }
                                            )
                                            .frame(width: carouselCardWidth)
                                        }

                                        // Event invites
                                        ForEach(awaitingResponseItems, id: \.event.id) { entry in
                                            VerticalEventCard(
                                                event: entry.event,
                                                myInvite: entry.invite,
                                                confirmedCount: viewModel.confirmedCount(for: entry.event.id),
                                                size: .compact
                                            ) {
                                                navigationPath.append(entry.event)
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

                        if !futureEvents.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                SectionHeader(title: "Next Up", action: "View all") {
                                    navigationPath.append(CalendarDestination())
                                }
                                .padding(.horizontal, Theme.Spacing.xl)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Spacing.md) {
                                        ForEach(futureEvents) { event in
                                            VerticalEventCard(
                                                event: event,
                                                myInvite: viewModel.invite(for: event.id),
                                                confirmedCount: viewModel.confirmedCount(for: event.id),
                                                size: .compact
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
                                            VerticalEventCard(
                                                event: event,
                                                myInvite: viewModel.invite(for: event.id),
                                                confirmedCount: viewModel.confirmedCount(for: event.id),
                                                size: .compact
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
            .scrollIndicators(.hidden)
            .refreshable {
                await viewModel.loadData()
            }
        .task {
            let preloaded = appState.preloadedHomeSnapshot
            appState.preloadedHomeSnapshot = nil
            await viewModel.loadData(preloadedSnapshot: preloaded)
            await loadEventsNeedingPlayLog()
            if refreshHandlerToken == nil {
                refreshHandlerToken = appState.registerRefreshHandler(for: .home) {
                    await viewModel.loadData()
                }
            }
        }
        .sheet(item: $draftToResume) { draft in
            CreateEventView(eventToEdit: draft) { _ in }
        }
        .sheet(item: $playLogEvent) { event in
            PlayLoggingSheet(event: event)
        }
        .onChange(of: playLogEvent) { _, newValue in
            if newValue == nil {
                Task { await loadEventsNeedingPlayLog() }
            }
        }
    }

    private func loadEventsNeedingPlayLog() async {
        guard let userId = SupabaseService.shared.client.auth.currentSession?.user.id else { return }
        eventsNeedingPlayLog = (try? await SupabaseService.shared.fetchCompletedEventsNeedingPlayLog(userId: userId)) ?? []
    }

    private func dismissPlayLogPrompt(for eventId: UUID) {
        dismissedPlayLogIds.insert(eventId)
        persistDismissedPlayLogIds()
    }

    private func persistDismissedPlayLogIds() {
        let values = dismissedPlayLogIds.map(\.uuidString)
        let userId = SupabaseService.shared.client.auth.currentSession?.user.id
        UserDefaults.standard.set(values, forKey: Self.dismissedPlayLogEventIdsKey(for: userId))
    }

    private static func loadDismissedPlayLogIds() -> Set<UUID> {
        let userId = SupabaseService.shared.client.auth.currentSession?.user.id
        let values = UserDefaults.standard.array(
            forKey: dismissedPlayLogEventIdsKey(for: userId)
        ) as? [String] ?? []
        let ids = values.compactMap(UUID.init(uuidString:))
        return Set(ids)
    }

    private static func dismissedPlayLogEventIdsKey(for userId: UUID?) -> String {
        guard let userId else { return dismissedPlayLogEventIdsKeyPrefix }
        return "\(dismissedPlayLogEventIdsKeyPrefix).\(userId.uuidString)"
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
struct CalendarDestination: Hashable {
    var startInListMode: Bool = false
}

// MARK: - Home Navigation Destinations
enum HomeDestination: Hashable {
    case notifications
    case inbox
    case eventDetail(UUID)
    case groupDetail(UUID)
}
