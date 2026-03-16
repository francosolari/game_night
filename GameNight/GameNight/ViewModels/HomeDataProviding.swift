import Foundation

protocol HomeDataProviding {
    func fetchUpcomingEvents() async throws -> [GameEvent]
    func fetchMyInvites() async throws -> [Invite]
    func fetchDrafts() async throws -> [GameEvent]
}
