import SwiftUI

struct EventDetailView: View {
    let eventId: UUID
    @StateObject private var viewModel = EventViewModel()
    @State private var selectedTimeIds = Set<UUID>()
    @State private var pollVotes: [UUID: TimeOptionVoteType] = [:]
    @State private var showTimeSuggestion = false
    @State private var showInviteList = false

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                LoadingView()
            } else if let event = viewModel.event {
                VStack(spacing: 0) {
                    // Hero Header
                    EventHeroHeader(event: event)

                    VStack(spacing: Theme.Spacing.xxl) {
                        // Games Section
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            SectionHeader(title: "Games")

                            ForEach(event.games) { eventGame in
                                if let game = eventGame.game {
                                    CompactGameCard(game: game, isPrimary: eventGame.isPrimary)
                                }
                            }
                        }
                        .cardStyle()

                        // Schedule Section
                        if event.scheduleMode == .fixed || event.timeOptions.count <= 1 {
                            // Fixed mode: show date prominently
                            if let timeOption = event.timeOptions.first {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 20))
                                        .foregroundColor(Theme.Colors.primary)
                                    Text("\(timeOption.displayDate) \u{00B7} \(timeOption.displayTime)")
                                        .font(Theme.Typography.headlineMedium)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardStyle()
                            }
                        } else {
                            // Poll mode
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                SectionHeader(title: "Schedule Poll")

                                if let myInvite = viewModel.myInvite, myInvite.status == .pending {
                                    Text("Vote on the times that work for you:")
                                        .font(Theme.Typography.callout)
                                        .foregroundColor(Theme.Colors.textSecondary)

                                    PollVotingView(
                                        timeOptions: event.timeOptions,
                                        votes: $pollVotes
                                    )

                                    if event.allowTimeSuggestions {
                                        Button {
                                            showTimeSuggestion = true
                                        } label: {
                                            HStack {
                                                Image(systemName: "plus.circle")
                                                Text("Suggest another time")
                                            }
                                            .font(Theme.Typography.calloutMedium)
                                            .foregroundColor(Theme.Colors.accent)
                                        }
                                    }
                                } else {
                                    // Show poll results
                                    TimeOptionPicker(
                                        timeOptions: event.timeOptions,
                                        selectedIds: $selectedTimeIds,
                                        allowMultiple: false,
                                        showVoteCounts: true
                                    )
                                }
                            }
                            .cardStyle()
                        }

                        // RSVP Section (if I'm invited and pending)
                        if let myInvite = viewModel.myInvite, myInvite.status == .pending {
                            RSVPSection(
                                onAccept: {
                                    let votes = buildTimeVotes(for: event)
                                    await viewModel.respondToInvite(
                                        status: .accepted,
                                        timeVotes: votes,
                                        suggestedTimes: nil
                                    )
                                },
                                onDecline: {
                                    await viewModel.respondToInvite(
                                        status: .declined,
                                        timeVotes: [],
                                        suggestedTimes: nil
                                    )
                                },
                                onMaybe: {
                                    let votes = buildTimeVotes(for: event)
                                    await viewModel.respondToInvite(
                                        status: .maybe,
                                        timeVotes: votes,
                                        suggestedTimes: nil
                                    )
                                },
                                isSending: viewModel.isSending
                            )
                        } else if let myInvite = viewModel.myInvite {
                            // Show current status
                            HStack {
                                Image(systemName: myInvite.status.icon)
                                Text("You're \(myInvite.status.displayLabel.lowercased())")
                                    .font(Theme.Typography.bodyMedium)
                            }
                            .foregroundColor(statusColor(myInvite.status))
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .fill(statusColor(myInvite.status).opacity(0.1))
                            )
                        }

                        // Guest List Section
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Button {
                                showInviteList = true
                            } label: {
                                HStack {
                                    SectionHeader(title: "Guest List")

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                            }

                            let summary = viewModel.inviteSummary
                            HStack(spacing: Theme.Spacing.lg) {
                                GuestCountBadge(count: summary.accepted, label: "Going", color: Theme.Colors.success)
                                GuestCountBadge(count: summary.pending, label: "Pending", color: Theme.Colors.warning)
                                GuestCountBadge(count: summary.maybe, label: "Maybe", color: Theme.Colors.accent)
                                GuestCountBadge(count: summary.declined, label: "Can't", color: Theme.Colors.error)
                            }

                            // Avatar row of accepted guests
                            if !summary.acceptedUsers.isEmpty {
                                AvatarStack(
                                    urls: summary.acceptedUsers.map(\.avatarUrl),
                                    size: 36
                                )
                            }
                        }
                        .cardStyle()

                        // Location
                        if let location = event.location {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                SectionHeader(title: "Location")

                                HStack(spacing: Theme.Spacing.md) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                            .fill(Theme.Colors.secondary.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Theme.Colors.secondary)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(location)
                                            .font(Theme.Typography.bodyMedium)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        if let address = event.locationAddress {
                                            Text(address)
                                                .font(Theme.Typography.caption)
                                                .foregroundColor(Theme.Colors.textTertiary)
                                        }
                                    }
                                }
                            }
                            .cardStyle()
                        }

                        // Description
                        if let desc = event.description, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                SectionHeader(title: "Details")
                                Text(desc)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .cardStyle()
                        }
                    }
                    .padding(Theme.Spacing.xl)
                }
                .padding(.bottom, 100)
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTimeSuggestion) {
            TimeSuggestionSheet { option in
                // Handle time suggestion
            }
        }
        .sheet(isPresented: $showInviteList) {
            InviteListSheet(invites: viewModel.invites, summary: viewModel.inviteSummary)
        }
        .task {
            await viewModel.loadEvent(id: eventId)
        }
    }

    private func buildTimeVotes(for event: GameEvent) -> [TimeOptionVote] {
        if event.scheduleMode == .poll && event.timeOptions.count > 1 {
            // Use poll votes
            return pollVotes.map { TimeOptionVote(timeOptionId: $0.key, voteType: $0.value) }
        } else {
            // Fixed mode: auto-vote yes for all time options
            return selectedTimeIds.map { TimeOptionVote(timeOptionId: $0, voteType: .yes) }
        }
    }

    private func statusColor(_ status: InviteStatus) -> Color {
        switch status {
        case .accepted: return Theme.Colors.success
        case .declined: return Theme.Colors.error
        case .maybe: return Theme.Colors.warning
        case .pending: return Theme.Colors.textTertiary
        case .expired: return Theme.Colors.textTertiary
        case .waitlisted: return Theme.Colors.accent
        }
    }
}

// MARK: - Event Hero Header
struct EventHeroHeader: View {
    let event: GameEvent

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "1E1B4B"),
                    Color(hex: "312E81"),
                    Theme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // Status pill
                Text(event.status.rawValue.capitalized)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.primaryLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.Colors.primary.opacity(0.2)))

                Text(event.title)
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                if let host = event.host {
                    HStack(spacing: 8) {
                        AvatarView(url: host.avatarUrl, size: 24)
                        Text("Hosted by \(host.displayName)")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }
}

// MARK: - RSVP Section
struct RSVPSection: View {
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    let onMaybe: () async -> Void
    var isSending: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Are you in?")
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)

            if isSending {
                ProgressView()
                    .tint(Theme.Colors.primary)
            } else {
                Button("I'm Going!") {
                    Task { await onAccept() }
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack(spacing: Theme.Spacing.md) {
                    Button("Maybe") {
                        Task { await onMaybe() }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Can't Go") {
                        Task { await onDecline() }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Guest Count Badge
struct GuestCountBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(Theme.Typography.headlineLarge)
                .foregroundColor(color)
            Text(label)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Invite List Sheet
struct InviteListSheet: View {
    let invites: [Invite]
    let summary: InviteSummary
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    if !summary.acceptedUsers.isEmpty {
                        InviteSection(title: "Going", users: summary.acceptedUsers, color: Theme.Colors.success)
                    }
                    if !summary.pendingUsers.isEmpty {
                        InviteSection(title: "Pending", users: summary.pendingUsers, color: Theme.Colors.warning)
                    }
                    if !summary.waitlistedUsers.isEmpty {
                        InviteSection(title: "Waitlist", users: summary.waitlistedUsers, color: Theme.Colors.accent)
                    }
                    if !summary.declinedUsers.isEmpty {
                        InviteSection(title: "Can't Go", users: summary.declinedUsers, color: Theme.Colors.error)
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Guest List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }
}

struct InviteSection: View {
    let title: String
    let users: [InviteSummary.InviteUser]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text("\(title) (\(users.count))")
                    .font(Theme.Typography.headlineMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            ForEach(users) { user in
                HStack(spacing: Theme.Spacing.md) {
                    AvatarView(url: user.avatarUrl, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        if user.tier > 1 {
                            Text("Tier \(user.tier)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }
                    }
                    Spacer()
                    InviteStatusBadge(status: user.status)
                }
            }
        }
    }
}
