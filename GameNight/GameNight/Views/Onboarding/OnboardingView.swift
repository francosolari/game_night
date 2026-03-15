import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showAuth = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Pages
                TabView(selection: $currentPage) {
                    OnboardingPage(
                        icon: "dice.fill",
                        gradient: Theme.Gradients.primary,
                        title: "Plan Game Nights\nEffortlessly",
                        subtitle: "Create events, invite friends, and coordinate schedules for the perfect game night."
                    )
                    .tag(0)

                    OnboardingPage(
                        icon: "list.star",
                        gradient: Theme.Gradients.secondary,
                        title: "Build Your\nGame Library",
                        subtitle: "Search BoardGameGeek to add games with player counts, complexity, and play times."
                    )
                    .tag(1)

                    OnboardingPage(
                        icon: "person.3.fill",
                        gradient: Theme.Gradients.accent,
                        title: "Smart Invites\nThat Fill Seats",
                        subtitle: "Tiered invites automatically fill spots as people decline. No more empty chairs."
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom section
                VStack(spacing: Theme.Spacing.xxl) {
                    // Page dots
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Theme.Colors.primary : Theme.Colors.textTertiary)
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(Theme.Animation.snappy, value: currentPage)
                        }
                    }

                    Button("Get Started") {
                        showAuth = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Theme.Spacing.xxxl)
                }
                .padding(.bottom, Theme.Spacing.jumbo)
            }
        }
        .sheet(isPresented: $showAuth) {
            AuthView()
        }
    }
}

// MARK: - Onboarding Page
struct OnboardingPage: View {
    let icon: String
    let gradient: LinearGradient
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(gradient.opacity(0.15))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(gradient.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundStyle(gradient)
            }

            VStack(spacing: Theme.Spacing.lg) {
                Text(title)
                    .font(Theme.Typography.displayLarge)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxxl)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Auth View (Phone Number OTP)
struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var step: AuthStep = .phone
    @State private var isLoading = false
    @State private var error: String?

    enum AuthStep {
        case phone
        case otp
        case profile
    }

    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xxl) {
                // Header
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: step == .phone ? "phone.fill" : step == .otp ? "lock.shield.fill" : "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.Gradients.primary)

                    Text(step == .phone ? "Enter your number" : step == .otp ? "Verify your number" : "Set up your profile")
                        .font(Theme.Typography.displaySmall)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text(step == .phone
                         ? "We'll send you a code to verify your number."
                         : step == .otp
                         ? "Enter the 6-digit code sent to \(phoneNumber)"
                         : "Choose a display name for your friends to see.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Input
                Group {
                    switch step {
                    case .phone:
                        TextField("+1 (555) 123-4567", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .font(Theme.Typography.displaySmall)
                            .multilineTextAlignment(.center)

                    case .otp:
                        TextField("000000", text: $otpCode)
                            .keyboardType(.numberPad)
                            .font(Theme.Typography.displaySmall)
                            .multilineTextAlignment(.center)

                    case .profile:
                        TextField("Your name", text: $displayName)
                            .font(Theme.Typography.displaySmall)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .fill(Theme.Colors.backgroundElevated)
                )

                if let error {
                    Text(error)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.error)
                }

                Button(step == .profile ? "Let's Go!" : "Continue") {
                    Task { await handleAction() }
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: isValid && !isLoading))
                .disabled(!isValid || isLoading)

                if isLoading {
                    ProgressView()
                        .tint(Theme.Colors.primary)
                }

                Spacer()
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private var isValid: Bool {
        switch step {
        case .phone: return phoneNumber.count >= 10
        case .otp: return otpCode.count == 6
        case .profile: return !displayName.isEmpty
        }
    }

    private func handleAction() async {
        isLoading = true
        error = nil

        do {
            switch step {
            case .phone:
                try await SupabaseService.shared.signInWithOTP(phoneNumber: phoneNumber)
                withAnimation { step = .otp }

            case .otp:
                try await SupabaseService.shared.verifyOTP(phoneNumber: phoneNumber, code: otpCode)
                // Check if user exists
                if let _ = try? await SupabaseService.shared.fetchCurrentUser() {
                    appState.currentUser = try await SupabaseService.shared.fetchCurrentUser()
                    appState.isAuthenticated = true
                    dismiss()
                } else {
                    withAnimation { step = .profile }
                }

            case .profile:
                let session = try await SupabaseService.shared.client.auth.session
                let user = User(
                    id: session.user.id,
                    phoneNumber: phoneNumber,
                    displayName: displayName,
                    avatarUrl: nil,
                    bio: nil,
                    bggUsername: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try await SupabaseService.shared.updateUser(user)
                appState.currentUser = user
                appState.isAuthenticated = true
                dismiss()
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
