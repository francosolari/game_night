import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var upcomingEvents: [GameEvent] = []
    @Published var myInvites: [Invite] = []
    @Published var drafts: [GameEvent] = []
    @Published var isLoading = true
    @Published var error: String?

    private let supabase = SupabaseService.shared

    func loadData() async {
        isLoading = true
        error = nil

        do {
            async let events = supabase.fetchUpcomingEvents()
            async let invites = supabase.fetchMyInvites()
            async let draftEvents = supabase.fetchDrafts()

            self.upcomingEvents = try await events
            self.myInvites = try await invites
            self.drafts = try await draftEvents
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func invite(for eventId: UUID) -> Invite? {
        myInvites.first { $0.eventId == eventId }
    }
}
