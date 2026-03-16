import Foundation

struct HomeDataLoadSnapshot {
    let upcomingEvents: [GameEvent]
    let myInvites: [Invite]
    let drafts: [GameEvent]
    let errorMessage: String?
}

enum HomeDataLoader {
    static func load(
        fetchUpcomingEvents: @escaping @Sendable () async throws -> [GameEvent],
        fetchMyInvites: @escaping @Sendable () async throws -> [Invite],
        fetchDrafts: @escaping @Sendable () async throws -> [GameEvent]
    ) async -> HomeDataLoadSnapshot {
        async let eventsResult = capture("Upcoming Events", operation: fetchUpcomingEvents)
        async let invitesResult = capture("Invites", operation: fetchMyInvites)
        async let draftsResult = capture("Drafts", operation: fetchDrafts)

        let events = await eventsResult
        let invites = await invitesResult
        let drafts = await draftsResult

        let failures = [events.errorDescription, invites.errorDescription, drafts.errorDescription]
            .compactMap { $0 }

        return HomeDataLoadSnapshot(
            upcomingEvents: events.value ?? [],
            myInvites: invites.value ?? [],
            drafts: drafts.value ?? [],
            errorMessage: failures.isEmpty ? nil : failures.joined(separator: "\n")
        )
    }

    private static func capture<Value>(
        _ label: String,
        operation: @escaping @Sendable () async throws -> Value
    ) async -> CapturedResult<Value> {
        do {
            return CapturedResult(value: try await operation(), errorDescription: nil)
        } catch {
            let detail = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
            return CapturedResult(value: nil, errorDescription: "\(label): \(detail)")
        }
    }
}

private struct CapturedResult<Value> {
    let value: Value?
    let errorDescription: String?
}
