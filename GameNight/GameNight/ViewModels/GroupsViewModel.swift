import SwiftUI

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published var groups: [GameGroup] = []
    @Published var isLoading = true
    @Published var error: String?
    @Published var showCreateGroup = false

    private let supabase = SupabaseService.shared

    func loadGroups() async {
        isLoading = true
        do {
            groups = try await supabase.fetchGroups()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createGroup(name: String, emoji: String?, description: String?) async -> GameGroup? {
        let session = try? await supabase.client.auth.session
        guard let userId = session?.user.id else { return nil }

        let group = GameGroup(
            id: UUID(),
            ownerId: userId,
            name: name,
            emoji: emoji,
            description: description,
            members: [],
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            let created = try await supabase.createGroup(group)
            groups.insert(created, at: 0)
            return created
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func deleteGroup(id: UUID) async {
        do {
            try await supabase.deleteGroup(id: id)
            groups.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addMember(to groupId: UUID, name: String, phoneNumber: String, tier: Int = 1) async {
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else { return }

        let member = GroupMember(
            id: UUID(),
            groupId: groupId,
            userId: nil,
            phoneNumber: phoneNumber,
            displayName: name,
            tier: tier,
            sortOrder: groups[idx].members.count,
            addedAt: Date()
        )

        do {
            try await supabase.addGroupMember(member)
            groups[idx].members.append(member)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addMembers(to groupId: UUID, contacts: [UserContact]) async {
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else { return }
        let existingPhones = Set(groups[idx].members.map(\.phoneNumber))

        for contact in contacts {
            let normalized = ContactPickerService.normalizePhone(contact.phoneNumber)
            guard !existingPhones.contains(normalized) else { continue }

            let member = GroupMember(
                id: UUID(),
                groupId: groupId,
                userId: nil,
                phoneNumber: normalized,
                displayName: contact.name,
                tier: 1,
                sortOrder: groups[idx].members.count,
                addedAt: Date()
            )

            do {
                try await supabase.addGroupMember(member)
                groups[idx].members.append(member)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func removeMember(id: UUID, from groupId: UUID) async {
        guard let groupIdx = groups.firstIndex(where: { $0.id == groupId }) else { return }

        do {
            try await supabase.removeGroupMember(id: id)
            groups[groupIdx].members.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateMemberTier(memberId: UUID, groupId: UUID, tier: Int) {
        guard let groupIdx = groups.firstIndex(where: { $0.id == groupId }),
              let memberIdx = groups[groupIdx].members.firstIndex(where: { $0.id == memberId }) else { return }
        groups[groupIdx].members[memberIdx].tier = tier
    }
}
