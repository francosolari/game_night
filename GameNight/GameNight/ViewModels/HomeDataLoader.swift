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
    private static let maxRetryAttempts = 2

    static func load(
        fetchUpcomingEvents: @escaping @Sendable () async throws -> [GameEvent],
        fetchMyInvites: @escaping @Sendable () async throws -> [Invite],
        fetchDrafts: @escaping @Sendable () async throws -> [GameEvent]
    ) async -> HomeDataLoadSnapshot {
        // Keep startup pressure bounded: these are heavy RLS-backed queries.
        let events = await capture("Upcoming Events", operation: fetchUpcomingEvents)
        let invites = await capture("Invites", operation: fetchMyInvites)
        let drafts = await capture("Drafts", operation: fetchDrafts)

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
        var attempt = 0
        while attempt <= maxRetryAttempts {
            do {
                return CapturedResult(value: try await operation(), errorDescription: nil)
            } catch is CancellationError {
                // Task cancelled (e.g. SwiftUI .refreshable releasing) — not a real failure
                return CapturedResult(value: nil, errorDescription: nil)
            } catch let error as URLError where error.code == .cancelled {
                // URLSession cancellation (NSURLErrorCancelled / -999) is expected under refresh overlap.
                return CapturedResult(value: nil, errorDescription: nil)
            } catch {
                if shouldRetryAfter(error), attempt < maxRetryAttempts {
                    attempt += 1
                    do {
                        try await Task.sleep(nanoseconds: transientRetryDelayNanoseconds * UInt64(attempt))
                        continue
                    } catch {
                        return CapturedResult(value: nil, errorDescription: buildErrorDescription(label: label, error: error))
                    }
                }
                return CapturedResult(value: nil, errorDescription: buildErrorDescription(label: label, error: error))
            }
        }

        // Defensive fallback; loop always returns.
        return CapturedResult(value: nil, errorDescription: "\(label): Unknown loading failure")
    }

    private static func shouldRetryAfter(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            if urlError.code == .cancelled {
                return false
            }
            return true
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            if nsError.code == NSURLErrorCancelled {
                return false
            }
            return true
        }

        let message = (error.localizedDescription + " " + String(describing: error)).lowercased()
        return message.contains("status code 500")
            || message.contains("status code 502")
            || message.contains("status code 503")
            || message.contains("status code 504")
            || message.contains("statement timeout")
            || message.contains("canceling statement due to statement timeout")
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
