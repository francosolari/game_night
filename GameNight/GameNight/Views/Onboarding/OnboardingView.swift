import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showAuth = false
    @State private var showBetaAuth = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    // Page 1: Hero
                    OnboardingPage(
                        icon: "dice.fill",
                        gradient: Theme.Gradients.primary,
                        title: "Game Night,\nSorted.",
                        subtitle: "The easiest way to get your crew together for board games. No more group chat scheduling chaos."
                    )
                    .tag(0)

                    // Page 2: Smart invites
                    OnboardingPage(
                        icon: "person.3.sequence.fill",
                        gradient: Theme.Gradients.secondary,
                        title: "Smart Invites\nThat Fill Seats",
                        subtitle: "Set your player count. Invites go out in tiers — if someone can't make it, the next person is automatically invited."
                    )
                    .tag(1)

                    // Page 3: Privacy promise (inspired by Partiful)
                    PrivacyPromisePage(showBetaAuth: $showBetaAuth)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom
                VStack(spacing: Theme.Spacing.xxl) {
                    // Page dots
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Theme.Colors.primary : Theme.Colors.textTertiary.opacity(0.4))
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(Theme.Animation.snappy, value: currentPage)
                        }
                    }

                    Button("Get Started") {
                        showAuth = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Theme.Spacing.xxxl)

                    Text("By continuing you agree to our Terms & Privacy Policy")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xxxl)
                }
                .padding(.bottom, Theme.Spacing.jumbo)
            }
        }
        .fullScreenCover(isPresented: $showAuth) {
            AuthFlowView()
        }
        .fullScreenCover(isPresented: $showBetaAuth) {
            BetaAuthFlowView()
        }
    }
}

// MARK: - Privacy Promise Page (Partiful-inspired)
struct PrivacyPromisePage: View {
    @State private var tapCount = 0
    @Binding var showBetaAuth: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.Gradients.accent.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.Gradients.accent)
            }
            .onTapGesture {
                tapCount += 1
                if tapCount >= 3 {
                    tapCount = 0
                    showBetaAuth = true
                }
            }

            VStack(spacing: Theme.Spacing.lg) {
                Text("Your Privacy\nIs Sacred")
                    .font(Theme.Typography.displayLarge)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                PrivacyBullet(
                    icon: "person.text.rectangle",
                    text: "No full name required — use any display name you want"
                )
                PrivacyBullet(
                    icon: "person.crop.circle.badge.xmark",
                    text: "We only store contacts you choose to invite, never your whole address book"
                )
                PrivacyBullet(
                    icon: "eye.slash.fill",
                    text: "Your phone number is hidden from other users by default"
                )
                PrivacyBullet(
                    icon: "hand.raised.fill",
                    text: "Block anyone, anytime — they'll never know"
                )
                PrivacyBullet(
                    icon: "megaphone.fill",
                    text: "Zero marketing spam — we never add you to a mailing list"
                )
                PrivacyBullet(
                    icon: "dollarsign.circle",
                    text: "We never sell your personal data. Period."
                )
            }
            .padding(.horizontal, Theme.Spacing.xxxl)

            Spacer()
            Spacer()
        }
    }
}

struct PrivacyBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.accent)
                .frame(width: 24, height: 24)

            Text(text)
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Onboarding Page (reusable)
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

// MARK: - Auth Flow (Partiful-style minimal friction)
struct AuthFlowView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var step: AuthStep = .phone
    @State private var phoneNumber = ""
    @State private var countryCode = "+1"
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var otpFullCode: String = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var otpTimer = 0
    @State private var timerTask: Task<Void, Never>?
    @FocusState private var otpFieldFocused: Bool
    @FocusState private var phoneFieldFocused: Bool
    @FocusState private var nameFieldFocused: Bool

    enum AuthStep {
        case phone, otp, name
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress bar
                    GeometryReader { geo in
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(stepIndex >= i ? Theme.Colors.primary : Theme.Colors.divider)
                                    .frame(height: 3)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                    .frame(height: 3)
                    .padding(.top, Theme.Spacing.md)

                    ScrollView {
                        VStack(spacing: Theme.Spacing.xxl) {
                            Spacer().frame(height: Theme.Spacing.jumbo)

                            // Step content
                            Group {
                                switch step {
                                case .phone: phoneStep
                                case .otp: otpStep
                                case .name: nameStep
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step != .phone {
                        Button {
                            withAnimation(Theme.Animation.snappy) {
                                switch step {
                                case .otp: step = .phone
                                case .name: step = .otp
                                case .phone: break
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
    }

    private var stepIndex: Int {
        switch step {
        case .phone: return 0
        case .otp: return 1
        case .name: return 2
        }
    }

    // MARK: - Phone Step
    private var phoneStep: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            VStack(spacing: Theme.Spacing.md) {
                Text("What's your number?")
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("We'll text you a code to sign in.\nNo passwords, no hassle.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Phone input
            HStack(spacing: Theme.Spacing.sm) {
                // Country code
                Menu {
                    Button("+1 US") { countryCode = "+1" }
                    Button("+44 UK") { countryCode = "+44" }
                    Button("+61 AU") { countryCode = "+61" }
                    Button("+49 DE") { countryCode = "+49" }
                    Button("+33 FR") { countryCode = "+33" }
                    Button("+81 JP") { countryCode = "+81" }
                } label: {
                    HStack(spacing: 4) {
                        Text(countryCode)
                            .font(Theme.Typography.headlineLarge)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.backgroundElevated)
                    )
                }

                TextField("(555) 123-4567", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(Theme.Typography.headlineLarge)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .focused($phoneFieldFocused)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.fieldBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .stroke(phoneFieldFocused ? Theme.Colors.primary.opacity(0.5) : .clear, lineWidth: 1.5)
                            )
                    )
            }

            if let error {
                Text(error)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.error)
                    .transition(.opacity)
            }

            Button("Send Code") {
                Task { await sendCode() }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: isPhoneValid && !isLoading))
            .disabled(!isPhoneValid || isLoading)

            if isLoading {
                ProgressView()
                    .tint(Theme.Colors.primary)
            }

            // Privacy assurance
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.accent)
                Text("Your number is never shared with other users")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(.top, Theme.Spacing.md)
        }
        .onAppear { phoneFieldFocused = true }
    }

    // MARK: - OTP Step
    private var otpStep: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            VStack(spacing: Theme.Spacing.md) {
                Text("Enter the code")
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Sent to \(countryCode) \(phoneNumber)")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Hidden TextField for autocomplete
            ZStack {
                // Visual OTP boxes
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(0..<6, id: \.self) { index in
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.fieldBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .stroke(
                                        otpFieldFocused ? Theme.Colors.primary : (otpDigits[index].isEmpty ? Theme.Colors.divider : Theme.Colors.primary.opacity(0.3)),
                                        lineWidth: otpFieldFocused ? 2 : 1
                                    )
                            )
                            .frame(width: 48, height: 56)
                            .overlay(
                                Text(otpDigits[index])
                                    .font(Theme.Typography.displaySmall)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            )
                    }
                }
                
                // Hidden TextField captures full OTP from autocomplete
                TextField("", text: $otpFullCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($otpFieldFocused)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .opacity(0.01)
                    .onChange(of: otpFullCode) { _, newValue in
                        let filtered = String(newValue.filter(\.isNumber).prefix(6))
                        // Distribute digits to visual boxes
                        for i in 0..<6 {
                            if i < filtered.count {
                                let idx = filtered.index(filtered.startIndex, offsetBy: i)
                                otpDigits[i] = String(filtered[idx])
                            } else {
                                otpDigits[i] = ""
                            }
                        }
                        // Clamp to 6 digits without re-triggering onChange loop
                        if newValue != filtered {
                            otpFullCode = filtered
                        }
                        // Auto-submit when all 6 filled
                        if filtered.count == 6 {
                            Task { await verifyCode() }
                        }
                    }
            }

            if let error {
                Text(error)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.error)
                    .transition(.opacity)
            }

            if isLoading {
                ProgressView()
                    .tint(Theme.Colors.primary)
            }

            // Resend
            VStack(spacing: Theme.Spacing.sm) {
                if otpTimer > 0 {
                    Text("Resend code in \(otpTimer)s")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.textTertiary)
                } else {
                    Button("Resend Code") {
                        Task { await resendCode() }
                    }
                    .font(Theme.Typography.calloutMedium)
                    .foregroundColor(Theme.Colors.primary)
                }

                Button("Wrong number? Go back") {
                    withAnimation(Theme.Animation.snappy) { step = .phone }
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .onAppear {
            otpFieldFocused = true
            startResendTimer()
        }
    }

    // MARK: - Name Step
    private var nameStep: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            VStack(spacing: Theme.Spacing.md) {
                Text("What should we\ncall you?")
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Pick any name, nickname, or alias.\nThis is what friends see on invites.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            TextField("e.g. Alex, GameMaster, A.", text: $displayName)
                .font(Theme.Typography.headlineLarge)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .focused($nameFieldFocused)
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .fill(Theme.Colors.fieldBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .stroke(nameFieldFocused ? Theme.Colors.primary.opacity(0.5) : .clear, lineWidth: 1.5)
                        )
                )

            if let error {
                Text(error)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.error)
            }

            Button("Let's Play!") {
                Task { await createProfile() }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: !displayName.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading))
            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

            if isLoading {
                ProgressView()
                    .tint(Theme.Colors.primary)
            }

            // No real name required
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.primaryLight)
                Text("No real name required — use whatever you like")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .onAppear { nameFieldFocused = true }
    }

    // MARK: - Validation

    private var isPhoneValid: Bool {
        let digits = phoneNumber.filter(\.isNumber)
        return digits.count >= 7
    }

    private var fullPhoneNumber: String {
        let digits = phoneNumber.filter(\.isNumber)
        return "\(countryCode)\(digits)"
    }

    private var otpCode: String {
        otpFullCode.isEmpty ? otpDigits.joined() : otpFullCode
    }

    // MARK: - Actions

    private func sendCode() async {
        isLoading = true
        error = nil
        print("📱 [sendCode] Attempting OTP for: \(fullPhoneNumber)")
        do {
            try await SupabaseService.shared.signInWithOTP(phoneNumber: fullPhoneNumber)
            print("✅ [sendCode] OTP sent successfully")
            withAnimation(Theme.Animation.snappy) { step = .otp }
        } catch let err {
            print("❌ [sendCode] Error: \(String(describing: err))")
            print("❌ [sendCode] Localized: \(err.localizedDescription)")
            self.error = "Couldn't send code. Check your number and try again."
        }
        isLoading = false
    }

    private func verifyCode() async {
        isLoading = true
        error = nil
        do {
            try await SupabaseService.shared.verifyOTP(phoneNumber: fullPhoneNumber, code: otpCode)
            // Check if returning user
            if let existingUser = try? await SupabaseService.shared.fetchCurrentUser() {
                appState.currentUser = existingUser
                appState.isAuthenticated = true
                dismiss()
            } else {
                withAnimation(Theme.Animation.snappy) { step = .name }
            }
        } catch let err {
            print("❌ [verifyCode] \(err)")
            self.error = "Invalid code. Please try again."
            otpDigits = Array(repeating: "", count: 6)
            otpFullCode = ""
            otpFieldFocused = true
        }
        isLoading = false
    }

    private func createProfile() async {
        isLoading = true
        error = nil
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let user = User(
                id: session.user.id,
                phoneNumber: fullPhoneNumber,
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                phoneVisible: false,
                discoverableByPhone: true,
                marketingOptIn: false,
                contactsSynced: false,
                phoneVerified: true,
                privacyAcceptedAt: Date()
            )
            try await SupabaseService.shared.updateUser(user)
            appState.currentUser = user
            appState.isAuthenticated = true
            dismiss()
        } catch let err {
            print("❌ [createProfile] \(err)")
            self.error = "Something went wrong. Please try again."
        }
        isLoading = false
    }

    private func resendCode() async {
        error = nil
        do {
            try await SupabaseService.shared.signInWithOTP(phoneNumber: fullPhoneNumber)
            startResendTimer()
        } catch let err {
            print("❌ [resendCode] \(err)")
            self.error = "Couldn't resend code."
        }
    }

    private func startResendTimer() {
        otpTimer = 30
        timerTask?.cancel()
        timerTask = Task {
            while otpTimer > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                otpTimer -= 1
            }
        }
    }
}

// MARK: - Beta Auth Flow (Password Bypass)
struct BetaAuthFlowView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var step: BetaStep = .password
    @State private var betaPassword = ""
    @State private var phoneNumber = ""
    @State private var countryCode = "+1"
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var error: String?
    @FocusState private var passwordFieldFocused: Bool
    @FocusState private var phoneFieldFocused: Bool
    @FocusState private var nameFieldFocused: Bool

    private let correctPassword = "francosfriend"

    enum BetaStep {
        case password, phone, name
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress bar
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(stepIndex >= i ? Theme.Colors.accent : Theme.Colors.divider)
                                .frame(height: 3)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.md)

                    ScrollView {
                        VStack(spacing: Theme.Spacing.xxl) {
                            Spacer().frame(height: Theme.Spacing.jumbo)

                            Group {
                                switch step {
                                case .password: passwordStep
                                case .phone: betaPhoneStep
                                case .name: betaNameStep
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step != .password {
                        Button {
                            withAnimation(Theme.Animation.snappy) {
                                switch step {
                                case .phone: step = .password
                                case .name: step = .phone
                                case .password: break
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.Typography.calloutMedium)
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
    }

    private var stepIndex: Int {
        switch step {
        case .password: return 0
        case .phone: return 1
        case .name: return 2
        }
    }

    // MARK: - Password Gate Step
    private var passwordStep: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Gradients.accent)

                Text("Beta Access")
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Enter the password Franco gave you.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SecureField("Password", text: $betaPassword)
                .font(Theme.Typography.headlineLarge)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .focused($passwordFieldFocused)
                .padding(Theme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .fill(Theme.Colors.fieldBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .stroke(passwordFieldFocused ? Theme.Colors.accent.opacity(0.5) : .clear, lineWidth: 1.5)
                        )
                )
                .submitLabel(.go)
                .onSubmit { checkPassword() }

            if let error {
                Text(error)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.error)
                    .transition(.opacity)
            }

            Button("Continue") {
                checkPassword()
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: !betaPassword.isEmpty))
            .disabled(betaPassword.isEmpty)
        }
        .onAppear { passwordFieldFocused = true }
    }

    // MARK: - Phone Step (no OTP)
    private var betaPhoneStep: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            VStack(spacing: Theme.Spacing.md) {
                Text("What's your number?")
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("We'll use this to identify your account.\nNo verification code needed.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: Theme.Spacing.sm) {
                Menu {
                    Button("+1 US") { countryCode = "+1" }
                    Button("+44 UK") { countryCode = "+44" }
                    Button("+61 AU") { countryCode = "+61" }
                    Button("+49 DE") { countryCode = "+49" }
                    Button("+33 FR") { countryCode = "+33" }
                    Button("+81 JP") { countryCode = "+81" }
                } label: {
                    HStack(spacing: 4) {
                        Text(countryCode)
                            .font(Theme.Typography.headlineLarge)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.backgroundElevated)
                    )
                }

                TextField("(555) 123-4567", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(Theme.Typography.headlineLarge)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .focused($phoneFieldFocused)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Theme.Colors.fieldBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .stroke(phoneFieldFocused ? Theme.Colors.accent.opacity(0.5) : .clear, lineWidth: 1.5)
                            )
                    )
            }

            if let error {
                Text(error)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.error)
                    .transition(.opacity)
            }

            Button("Continue") {
                Task { await signUpOrIn() }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: isPhoneValid && !isLoading))
            .disabled(!isPhoneValid || isLoading)

            if isLoading {
                ProgressView()
                    .tint(Theme.Colors.accent)
            }
        }
        .onAppear { phoneFieldFocused = true }
    }

    // MARK: - Name Step
    private var betaNameStep: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            VStack(spacing: Theme.Spacing.md) {
                Text("What should we\ncall you?")
                    .font(Theme.Typography.displayMedium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Pick any name, nickname, or alias.\nThis is what friends see on invites.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            TextField("e.g. Alex, GameMaster, A.", text: $displayName)
                .font(Theme.Typography.headlineLarge)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .focused($nameFieldFocused)
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .fill(Theme.Colors.fieldBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .stroke(nameFieldFocused ? Theme.Colors.accent.opacity(0.5) : .clear, lineWidth: 1.5)
                        )
                )

            if let error {
                Text(error)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.error)
            }

            Button("Let's Play!") {
                Task { await createProfile() }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: !displayName.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading))
            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

            if isLoading {
                ProgressView()
                    .tint(Theme.Colors.accent)
            }

            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.primaryLight)
                Text("No real name required — use whatever you like")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
        .onAppear { nameFieldFocused = true }
    }

    // MARK: - Validation

    private var isPhoneValid: Bool {
        let digits = phoneNumber.filter(\.isNumber)
        return digits.count >= 7
    }

    private var fullPhoneNumber: String {
        let digits = phoneNumber.filter(\.isNumber)
        return "\(countryCode)\(digits)"
    }

    // MARK: - Actions

    private func checkPassword() {
        if betaPassword == correctPassword {
            error = nil
            withAnimation(Theme.Animation.snappy) { step = .phone }
        } else {
            error = "Wrong password."
            betaPassword = ""
        }
    }

    private func signUpOrIn() async {
        isLoading = true
        error = nil

        do {
            try await SupabaseService.shared.ensureBetaUser(
                phoneNumber: fullPhoneNumber,
                password: correctPassword
            )
            try await SupabaseService.shared.signInWithPassword(
                phoneNumber: fullPhoneNumber,
                password: correctPassword
            )

            if let existingUser = try? await SupabaseService.shared.fetchCurrentUser() {
                appState.currentUser = existingUser
                appState.isAuthenticated = true
                dismiss()
                isLoading = false
                return
            } else {
                withAnimation(Theme.Animation.snappy) { step = .name }
            }
        } catch let signInError {
            print("❌ [betaAuth] ensure/sign-in error: \(signInError)")
            self.error = "Something went wrong. Please try again."
        }

        isLoading = false
    }

    private func createProfile() async {
        isLoading = true
        error = nil
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let user = User(
                id: session.user.id,
                phoneNumber: fullPhoneNumber,
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                phoneVisible: false,
                discoverableByPhone: true,
                marketingOptIn: false,
                contactsSynced: false,
                phoneVerified: false,
                privacyAcceptedAt: Date()
            )
            try await SupabaseService.shared.updateUser(user)
            appState.currentUser = user
            appState.isAuthenticated = true
            dismiss()
        } catch let err {
            print("❌ [betaCreateProfile] \(err)")
            self.error = "Something went wrong. Please try again."
        }
        isLoading = false
    }
}

// MARK: - OTP Digit Box
struct OTPDigitBox: View {
    @Binding var digit: String
    let isFocused: Bool
    let onType: (String) -> Void
    let onBackspace: () -> Void

    @State private var fieldText: String = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(
                            isFocused ? Theme.Colors.primary : (digit.isEmpty ? Theme.Colors.divider : Theme.Colors.primary.opacity(0.3)),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .frame(width: 48, height: 56)

            TextField("", text: $fieldText)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(Theme.Typography.displaySmall)
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(width: 48, height: 56)
                .onChange(of: fieldText) { _, newValue in
                    if newValue.isEmpty {
                        onBackspace()
                    } else {
                        let filtered = String(newValue.filter(\.isNumber).prefix(1))
                        fieldText = filtered
                        onType(filtered)
                    }
                }
                .onAppear { fieldText = digit }
                .onChange(of: digit) { _, newValue in
                    if fieldText != newValue {
                        fieldText = newValue
                    }
                }
        }
    }
}
