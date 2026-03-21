import SwiftUI
import Supabase

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var conversations: [ConversationSummary] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseService.shared

    func loadConversations() async {
        isLoading = true
        do {
            conversations = try await supabase.fetchConversations()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func startNewDM(withUserId userId: UUID) async throws -> UUID {
        try await supabase.getOrCreateDM(otherUserId: userId)
    }

    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }
}
