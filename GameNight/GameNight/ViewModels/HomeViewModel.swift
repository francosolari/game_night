import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var upcomingEvents: [GameEvent] = []
    @Published var myInvites: [Invite] = []
    @Published var drafts: [GameEvent] = []
    @Published var isLoading = true
    @Published var error: String?

    private let supabase: any HomeDataProviding

    init(supabase: any HomeDataProviding) {
        self.supabase = supabase
    }

    convenience init() {
        self.init(supabase: SupabaseService.shared)
    }

    func loadData() async {
        isLoading = true
        error = nil

        let snapshot = await HomeDataLoader.load(
            fetchUpcomingEvents: { [supabase] in
                try await supabase.fetchUpcomingEvents()
            },
            fetchMyInvites: { [supabase] in
                try await supabase.fetchMyInvites()
            },
            fetchDrafts: { [supabase] in
                try await supabase.fetchDrafts()
            }
        )

        self.upcomingEvents = snapshot.upcomingEvents
        self.myInvites = snapshot.myInvites
        self.drafts = snapshot.drafts
        self.error = snapshot.errorMessage

        if let error = snapshot.errorMessage {
            print("🏠 [HomeViewModel] \(error)")
        }

        isLoading = false
    }

    func invite(for eventId: UUID) -> Invite? {
        myInvites.first { $0.eventId == eventId }
    }
}
