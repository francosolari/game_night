import SwiftUI

struct InviteClaimView: View {
    let inviteToken: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var isLoading = true
    @State private var eventTitle: String?
    @State private var hostName: String?
    @State private var coverImageUrl: String?
    @State private var eventId: UUID?
    @State private var error: String?
    @State private var toast: ToastItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.pageBackground
                    .ignoresSafeArea()

                if isLoading {
                    loadingState
                } else if let error = error {
                    errorState(error)
                } else {
                    inviteContent
                }
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .toast($toast)
        }
        .task {
            await fetchInviteDetails()
        }
    }

    // MARK: - Invite Content

    private var inviteContent: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            // Cover image
            if let urlString = coverImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(Theme.Colors.primarySubtle)
                        .overlay(
                            Image(systemName: "dice.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.Colors.primary.opacity(0.4))
                        )
                }
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            }

            VStack(spacing: Theme.Spacing.md) {
                Text("You're Invited!")
                    .font(Theme.Typography.displayLarge)
                    .foregroundColor(Theme.Colors.textPrimary)

                if let eventTitle = eventTitle {
                    Text(eventTitle)
                        .font(Theme.Typography.headlineMedium)
                        .foregroundColor(Theme.Colors.primary)
                }

                if let hostName = hostName {
                    Text("Hosted by \(hostName)")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()

            Button {
                viewEvent()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "eye.fill")
                    Text("View Event")
                }
                .font(Theme.Typography.bodyMedium)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }

    // MARK: - Loading / Error

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
                .tint(Theme.Colors.primary)
            Text("Loading invite...")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.warning)

            Text("Invite Not Found")
                .font(Theme.Typography.headlineMedium)
                .foregroundColor(Theme.Colors.textPrimary)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            Button("Close") { dismiss() }
                .font(Theme.Typography.calloutMedium)
                .foregroundColor(Theme.Colors.primary)
        }
    }

    // MARK: - Actions

    private func fetchInviteDetails() async {
        isLoading = true
        do {
            // Use the get-public-invite edge function
            struct PublicInviteResponse: Decodable {
                let event: EventInfo?

                struct EventInfo: Decodable {
                    let id: UUID
                    let title: String
                    let cover_image_url: String?
                    let host_name: String?
                }
            }

            let decoded: PublicInviteResponse = try await SupabaseService.shared.client
                .functions
                .invoke(
                    "get-public-invite",
                    options: .init(body: ["invite_token": inviteToken])
                )
            eventTitle = decoded.event?.title
            hostName = decoded.event?.host_name
            coverImageUrl = decoded.event?.cover_image_url
            eventId = decoded.event?.id
        } catch {
            self.error = "This invite may have expired or been cancelled."
        }
        isLoading = false
    }

    private func viewEvent() {
        guard let eventId = eventId else { return }
        dismiss()
        // Navigate to event via deep link
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.deepLinkEventId = eventId.uuidString
        }
    }
}
