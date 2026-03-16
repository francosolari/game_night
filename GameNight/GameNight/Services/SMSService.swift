import Foundation

/// SMS service that delegates to Supabase Edge Functions (which use Twilio)
actor SMSService {
    static let shared = SMSService()

    @MainActor private var supabase: SupabaseService { SupabaseService.shared }

    /// Send an event invite via SMS
    func sendInviteSMS(
        to phoneNumber: String,
        eventTitle: String,
        hostName: String,
        games: [String],
        inviteLink: String
    ) async throws {
        let gameList = games.prefix(3).joined(separator: ", ")
        let message = """
        \(hostName) invited you to \(eventTitle)! \
        Games: \(gameList). \
        RSVP here: \(inviteLink)
        """

        try await supabase.invokeAuthenticatedFunction(
            "send-sms",
            body: [
                "to": phoneNumber,
                "message": message
            ]
        )
    }

    /// Send a reminder SMS
    func sendReminderSMS(
        to phoneNumber: String,
        eventTitle: String,
        dateTime: String,
        location: String
    ) async throws {
        let message = """
        Reminder: \(eventTitle) is coming up! \
        \(dateTime) at \(location). See you there!
        """

        try await supabase.invokeAuthenticatedFunction(
            "send-sms",
            body: [
                "to": phoneNumber,
                "message": message
            ]
        )
    }

    /// Send waitlist promotion notification
    func sendWaitlistPromotionSMS(
        to phoneNumber: String,
        eventTitle: String,
        inviteLink: String
    ) async throws {
        let message = """
        A spot opened up for \(eventTitle)! \
        RSVP now: \(inviteLink)
        """

        try await supabase.invokeAuthenticatedFunction(
            "send-sms",
            body: [
                "to": phoneNumber,
                "message": message
            ]
        )
    }
}
