import SwiftUI

struct ProfileEventHistoryView: View {
    @StateObject private var viewModel = ProfileEventHistoryViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.pastEvents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(viewModel.groupedByMonth, id: \.month) { group in
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text(group.month)
                                    .font(Theme.Typography.label)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .padding(.horizontal, Theme.Spacing.xl)
                                    .padding(.top, Theme.Spacing.md)

                                ForEach(group.events) { event in
                                    NavigationLink(value: event) {
                                        ListEventCard(
                                            event: event,
                                            myInvite: viewModel.invitesByEventId[event.id],
                                            confirmedCount: viewModel.confirmedCounts[event.id] ?? 0
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, Theme.Spacing.xl)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Event History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.textTertiary)

            Text("No past events")
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Events you've hosted or attended will appear here.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Month Group

struct EventMonthGroup {
    let month: String
    let events: [GameEvent]
}

// MARK: - View Model

@MainActor
class ProfileEventHistoryViewModel: ObservableObject {
    @Published var pastEvents: [GameEvent] = []
    @Published var invitesByEventId: [UUID: Invite] = [:]
    @Published var confirmedCounts: [UUID: Int] = [:]
    @Published var isLoading = false

    var groupedByMonth: [EventMonthGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: pastEvents) { event in
            formatter.string(from: event.effectiveStartDate)
        }

        return grouped.map { EventMonthGroup(month: $0.key, events: $0.value) }
            .sorted { a, b in
                guard let aDate = a.events.first?.effectiveStartDate,
                      let bDate = b.events.first?.effectiveStartDate else { return false }
                return aDate > bDate
            }
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let invites = try await SupabaseService.shared.fetchMyInvites()
            let hostedEvents = try await SupabaseService.shared.fetchMyEvents()

            let acceptedInvites = invites.filter { $0.status == .accepted }
            let invitedEventIds = Set(acceptedInvites.map(\.eventId))

            let invitedEvents: [GameEvent]
            if !invitedEventIds.isEmpty {
                invitedEvents = try await SupabaseService.shared.fetchEvents(ids: Array(invitedEventIds))
            } else {
                invitedEvents = []
            }

            // Merge and dedup
            var eventMap: [UUID: GameEvent] = [:]
            for event in hostedEvents { eventMap[event.id] = event }
            for event in invitedEvents { eventMap[event.id] = event }

            // Build invite lookup
            var inviteMap: [UUID: Invite] = [:]
            for invite in acceptedInvites {
                inviteMap[invite.eventId] = invite
            }

            let now = Date()
            let past = eventMap.values
                .filter { $0.effectiveStartDate < now }
                .sorted { $0.effectiveStartDate > $1.effectiveStartDate }

            pastEvents = past
            invitesByEventId = inviteMap

            if !past.isEmpty {
                confirmedCounts = try await SupabaseService.shared.fetchAcceptedInviteCounts(
                    eventIds: past.map(\.id)
                )
            }
        } catch {
            print("⚠️ [EventHistoryVM] Failed to load: \(error)")
        }
    }
}
