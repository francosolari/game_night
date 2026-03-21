import SwiftUI

/// Shows shareable invite links for contacts invited via the app (not SMS).
/// Presented after inviting app-connection contacts who receive push-only delivery.
struct InviteLinkSheet: View {
    @Environment(\.dismiss) var dismiss
    let invites: [Invite]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.primary)

                    Text("Share Invite Links")
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("These guests were notified in-app. You can also share their personal invite links below.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                }
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.lg)

                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(invites) { invite in
                            if let token = invite.inviteToken {
                                let url = URL(string: "https://cardboardwithme.com/invite/\(token)")!
                                HStack(spacing: Theme.Spacing.md) {
                                    AvatarView(url: nil, size: 40)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(invite.displayName ?? "Guest")
                                            .font(Theme.Typography.bodyMedium)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Text("via Game Night")
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textTertiary.opacity(0.6))
                                    }

                                    Spacer()

                                    ShareLink(item: url) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 16))
                                            .foregroundColor(Theme.Colors.primary)
                                            .padding(8)
                                            .background(
                                                Circle().fill(Theme.Colors.primary.opacity(0.1))
                                            )
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.xl)
                                .padding(.vertical, Theme.Spacing.sm)
                            }
                        }
                    }
                }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.Typography.bodySemibold)
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }
}
