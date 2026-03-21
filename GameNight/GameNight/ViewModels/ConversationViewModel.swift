import SwiftUI
import Supabase

@MainActor
final class ConversationViewModel: ObservableObject {
    @Published var messages: [DirectMessage] = []
    @Published var newMessageText = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: String?

    let conversationId: UUID
    let otherUser: ConversationOtherUser

    private let supabase = SupabaseService.shared
    private var channel: RealtimeChannelV2?

    struct ConversationOtherUser {
        let id: UUID
        let displayName: String
        let avatarUrl: String?
    }

    init(conversationId: UUID, otherUser: ConversationOtherUser) {
        self.conversationId = conversationId
        self.otherUser = otherUser
    }

    func loadMessages() async {
        isLoading = true
        do {
            messages = try await supabase.fetchMessages(conversationId: conversationId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func sendMessage() async {
        let content = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        isSending = true
        newMessageText = ""

        do {
            try await supabase.sendDirectMessage(conversationId: conversationId, content: content)
            await loadMessages()
        } catch {
            self.error = error.localizedDescription
        }
        isSending = false
    }

    func markAsRead() async {
        do {
            try await supabase.markConversationRead(conversationId: conversationId)
        } catch {
            print("Failed to mark conversation read: \(error)")
        }
    }

    func subscribe() {
        channel = supabase.subscribeToDirectMessages(conversationId: conversationId) { [weak self] in
            Task { @MainActor in
                await self?.loadMessages()
            }
        }
    }

    func unsubscribe() {
        if let channel = channel {
            Task {
                await channel.unsubscribe()
            }
        }
        channel = nil
    }
}
