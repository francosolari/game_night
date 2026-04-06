import XCTest
@testable import GameNight

final class SupabaseServiceTests: XCTestCase {
    @MainActor
    func testEventSelectContainsRequiredRelations() {
        let select = SupabaseService.eventSelect

        XCTAssertTrue(select.contains("host:users(*)"), "eventSelect must include host relation")
        XCTAssertTrue(select.contains("games:event_games(*, game:games(*))"), "eventSelect must include nested games relation")
        XCTAssertTrue(select.contains("time_options!event_id(*)"), "eventSelect must include time_options relation")
    }

    func testMergeOwnedAndAcceptedGroupsIncludesAcceptedNonOwnedGroups() {
        let owned = makeGroup(name: "Owned", createdAt: Date(timeIntervalSince1970: 100))
        let acceptedNonOwned = makeGroup(name: "Accepted", createdAt: Date(timeIntervalSince1970: 200))

        let merged = SupabaseService.mergeOwnedAndAcceptedGroups(
            ownedGroups: [owned],
            acceptedMembershipGroupIds: [acceptedNonOwned.id],
            memberGroups: [acceptedNonOwned]
        )

        XCTAssertEqual(Set(merged.map(\.id)), Set([owned.id, acceptedNonOwned.id]))
    }

    func testMergeOwnedAndAcceptedGroupsDoesNotDuplicateWhenOwnedAlsoAccepted() {
        let group = makeGroup(name: "Same Group", createdAt: Date(timeIntervalSince1970: 100))

        let merged = SupabaseService.mergeOwnedAndAcceptedGroups(
            ownedGroups: [group],
            acceptedMembershipGroupIds: [group.id],
            memberGroups: [group]
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.id, group.id)
    }

    func testMergeOwnedAndAcceptedGroupsSortsByNewestCreatedAt() {
        let older = makeGroup(name: "Older", createdAt: Date(timeIntervalSince1970: 100))
        let newer = makeGroup(name: "Newer", createdAt: Date(timeIntervalSince1970: 200))

        let merged = SupabaseService.mergeOwnedAndAcceptedGroups(
            ownedGroups: [older],
            acceptedMembershipGroupIds: [newer.id],
            memberGroups: [newer]
        )

        XCTAssertEqual(merged.map(\.id), [newer.id, older.id])
    }

    private func makeGroup(name: String, createdAt: Date) -> GameGroup {
        GameGroup(
            id: UUID(),
            ownerId: UUID(),
            name: name,
            emoji: "🎲",
            description: nil,
            members: [],
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}
