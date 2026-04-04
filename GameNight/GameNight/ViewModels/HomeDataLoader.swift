import Foundation

struct HomeDataLoadSnapshot {
    let upcomingEvents: [GameEvent]
    let myInvites: [Invite]
    let drafts: [GameEvent]
    let awaitingResponseEvents: [(event: GameEvent, invite: Invite)]
    let pendingGroupInvites: [(group: GameGroup, member: GroupMember)]
    let inviteCounts: [UUID: Int]
    let isHydratedForHome: Bool
    let errorMessage: String?
}

enum HomeDataLoader {
    private static let transientRetryDelayNanoseconds: UInt64 = 250_000_000

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
            awaitingResponseEvents: [],
            pendingGroupInvites: [],
            inviteCounts: [:],
            isHydratedForHome: false,
            errorMessage: failures.isEmpty ? nil : failures.joined(separator: "\n")
        )
    }

    private static func capture<Value>(
        _ label: String,
        operation: @escaping @Sendable () async throws -> Value
    ) async -> CapturedResult<Value> {
        do {
            return CapturedResult(value: try await operation(), errorDescription: nil)
        } catch is CancellationError {
            // Task cancelled (e.g. SwiftUI .refreshable releasing) — not a real failure
            return CapturedResult(value: nil, errorDescription: nil)
        } catch {
            if shouldRetryAfter(error) {
                do {
                    try await Task.sleep(nanoseconds: transientRetryDelayNanoseconds)
                    return CapturedResult(value: try await operation(), errorDescription: nil)
                } catch is CancellationError {
                    return CapturedResult(value: nil, errorDescription: nil)
                } catch {
                    return CapturedResult(value: nil, errorDescription: buildErrorDescription(label: label, error: error))
                }
            }
            return CapturedResult(value: nil, errorDescription: buildErrorDescription(label: label, error: error))
        }
    }

    private static func shouldRetryAfter(_ error: Error) -> Bool {
        if error is URLError {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    private static func buildErrorDescription(label: String, error: Error) -> String {
        let detail = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
        return "\(label): \(detail)"
    }
}

private struct CapturedResult<Value> {
    let value: Value?
    let errorDescription: String?
}
