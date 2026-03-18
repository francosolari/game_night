import Foundation

protocol HomeDataProviding {
    func fetchUpcomingEvents() async throws -> [GameEvent]
    func fetchEvents(ids: [UUID]) async throws -> [GameEvent]
    func fetchMyInvites() async throws -> [Invite]
    func fetchDrafts() async throws -> [GameEvent]
    func fetchAcceptedInviteCounts(eventIds: [UUID]) async throws -> [UUID: Int]
}
