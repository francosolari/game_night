import SwiftUI

/// Wrapper that fetches a group by ID then shows GroupDetailView.
/// Used for deep-link / notification navigation where only the group ID is known.
struct GroupDetailLoadingView: View {
    let groupId: UUID
    @State private var group: GameGroup?
    @State private var error: String?

    var body: some View {
        Group {
            if let group {
                GroupDetailView(group: group)
            } else if let error {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.textTertiary)
                    Text(error)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            } else {
                ProgressView()
                    .tint(Theme.Colors.primary)
            }
        }
        .task {
            do {
                group = try await SupabaseService.shared.fetchGroupById(groupId)
            } catch {
                self.error = "Couldn't load group"
            }
        }
    }
}
