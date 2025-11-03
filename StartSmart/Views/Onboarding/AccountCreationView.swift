//
//  AccountCreationView.swift
//  StartSmart
//
//  Onboarding Step 7: Account Creation
//  Updated to match PremiumLandingPageV2 theme
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth

/// Enhanced account creation with premium design focused on saving onboarding preferences
struct AccountCreationView: View {
    @ObservedObject var onboardingState: OnboardingState
    let authService: SimpleAuthenticationService
    @Binding var isSigningIn: Bool
    let onAuthError: (String) -> Void
    let onComplete: () -> Void
    
    @State private var animateElements = false
    @State private var showAuthOptions = false
    
    var body: some View {
        ZStack {
            // Background - matching landing page theme
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.10, green: 0.10, blue: 0.18)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Radial gradients for depth
            ZStack {
                RadialGradient(
                    gradient: Gradient(colors: [
                        DesignSystem.purple.opacity(0.15),
                        Color.clear
                    ]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 300
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        DesignSystem.indigo.opacity(0.15),
                        Color.clear
                    ]),
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 300
                )
            }
            .ignoresSafeArea()
            
            // Content
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignSystem.spacing3) {
                        // Header section
                        headerSection
                            .opacity(animateElements ? 1 : 0)
                            .offset(y: animateElements ? 0 : 20)
                        
                        // Preference summary
                        preferenceSummary
                            .opacity(showAuthOptions ? 1 : 0)
                            .offset(y: showAuthOptions ? 0 : 20)
                        
                        // Authentication options
                        authenticationSection
                            .opacity(showAuthOptions ? 1 : 0)
                            .offset(y: showAuthOptions ? 0 : 30)
                        
                        // Value proposition reminder
                        valueProposition
                            .opacity(showAuthOptions ? 1 : 0)
                            .offset(y: showAuthOptions ? 0 : 20)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, DesignSystem.spacing4)
                    .padding(.top, 0)
                    .padding(.bottom, DesignSystem.spacing3)
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.spacing3) {
            // Success checkmark with celebration
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                // Success ring effect
                Circle()
                    .stroke(DesignSystem.green.opacity(0.3), lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .scaleEffect(animateElements ? 1.2 : 1.0)
                    .opacity(animateElements ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false),
                        value: animateElements
                    )
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.green)
                    .scaleEffect(animateElements ? 1.0 : 0.95)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animateElements)
            }
            
            VStack(spacing: 12) {
                // Title
                Text("Save Your\nPreferences")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .tracking(-0.5)
                
                // Subtitle
                Text("Create an account to save your motivational profile and track your progress")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.top, 60)
    }
    
    // MARK: - Preference Summary
    
    private var preferenceSummary: some View {
        VStack(spacing: 12) {
            Text("Your Personalized Setup")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                // Motivation
                if let motivation = onboardingState.selectedMotivation {
                    PremiumPreferenceSummaryRow(
                        icon: motivation.iconName,
                        title: "Focus Area",
                        value: motivation.displayName,
                        color: motivation.iconColor
                    )
                }
                
                // Tone
                PremiumPreferenceSummaryRow(
                    icon: onboardingState.computedTone.iconName,
                    title: "Motivation Style",
                    value: onboardingState.computedTone.displayName,
                    color: toneColor
                )
                
                // Voice
                if let voice = onboardingState.selectedVoice {
                    PremiumPreferenceSummaryRow(
                        icon: "person.wave.2.fill",
                        title: "Voice Persona",
                        value: voice.name,
                        color: DesignSystem.purple
                    )
                }
                
                // Notifications
                PremiumPreferenceSummaryRow(
                    icon: onboardingState.notificationPermissionGranted == true ? "bell.fill" : "bell.slash.fill",
                    title: "Notifications",
                    value: onboardingState.notificationPermissionGranted == true ? "Enabled" : "Disabled",
                    color: onboardingState.notificationPermissionGranted == true ? DesignSystem.green : Color.orange
                )
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(16)
    }
    
    private var toneColor: Color {
        switch onboardingState.computedTone {
        case .gentle: return DesignSystem.green
        case .energetic: return Color(red: 1.0, green: 0.72, blue: 0.0)
        case .toughLove: return Color(red: 0.94, green: 0.27, blue: 0.27)
        case .storyteller: return DesignSystem.purple
        }
    }
    
    // MARK: - Authentication Section
    
    private var authenticationSection: some View {
        VStack(spacing: 12) {
            Text("Choose your sign-in method")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            VStack(spacing: 12) {
                // Sign in with Apple
                SignInWithAppleButton(.signUp) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleSignInResult(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(isSigningIn)
                .opacity(isSigningIn ? 0.6 : 1.0)
                
                // Sign in with Google
                Button(action: {
                    handleGoogleSignIn()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .medium))
                        
                        Text("Continue with Google")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .disabled(isSigningIn)
                .opacity(isSigningIn ? 0.6 : 1.0)
                
                // Continue as Guest button
                Button(action: {
                    handleContinueAsGuest()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 18, weight: .medium))
                        
                        Text("Continue as Guest")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
                    .cornerRadius(14)
                }
                .disabled(isSigningIn)
                .opacity(isSigningIn ? 0.6 : 1.0)
                
                // Loading state
                if isSigningIn {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Creating your account...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 8)
                }
            }
            
            // Guest mode disclaimer
            Text("Guest mode: Basic alarm features only")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }
    
    // MARK: - Value Proposition
    
    private var valueProposition: some View {
        VStack(spacing: 12) {
            Text("Why create an account?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                PremiumValuePropositionRow(
                    icon: "icloud.fill",
                    text: "Sync your preferences across devices"
                )
                
                PremiumValuePropositionRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Track your morning motivation progress"
                )
                
                PremiumValuePropositionRow(
                    icon: "sparkles",
                    text: "Get personalized content improvements"
                )
            }
            
            // Terms and privacy
            VStack(spacing: 8) {
                Text("By creating an account, you agree to our")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 4) {
                    Button("Terms of Service") {
                        // Handle terms
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    
                    Text("and")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Button("Privacy Policy") {
                        // Handle privacy
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.top, 16)
        }
    }
    
    // MARK: - Authentication Handlers
    
    private func handleGoogleSignIn() {
        isSigningIn = true
        
        Task {
            let success = await authService.signInWithGoogle()
            
            await MainActor.run {
                isSigningIn = false
                
                if success {
                    saveOnboardingData()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                } else {
                    onAuthError(authService.errorMessage ?? "Google Sign In failed")
                }
            }
        }
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        isSigningIn = true
        
        Task {
            var success = false
            var errorMsg: String? = nil
            
            switch result {
            case .success(let authorization):
                guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    errorMsg = "Invalid Apple ID credential"
                    break
                }
                
                guard let appleIDToken = appleIDCredential.identityToken,
                      let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    errorMsg = "Unable to fetch identity token"
                    break
                }
                
                let nonce = randomNonceString()
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                do {
                    _ = try await Auth.auth().signIn(with: credential)
                    success = true
                } catch {
                    errorMsg = "Firebase authentication failed: \(error.localizedDescription)"
                }
                
            case .failure(let error):
                errorMsg = "Apple Sign In failed: \(error.localizedDescription)"
            }
            
            await MainActor.run {
                isSigningIn = false
                
                if success {
                    saveOnboardingData()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                } else {
                    onAuthError(errorMsg ?? "Apple Sign In failed")
                }
            }
        }
    }
    
    private func handleContinueAsGuest() {
        print("⏭️ Continue as Guest tapped")
        print("⏭️ Entering guest mode - skipping authentication")
        
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        UserDefaults.standard.set(true, forKey: "is_guest_user")
        
        print("✅ Guest mode flag set in UserDefaults")
        
        saveOnboardingDataLocally()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
        
        print("⏭️ Navigating to MainAppView as guest user")
    }
    
    private func saveOnboardingData() {
        let preferences = onboardingState.createUserPreferences()
        
        let onboardingData = OnboardingCompletionData(
            motivation: onboardingState.selectedMotivation,
            tonePosition: onboardingState.toneSliderPosition,
            selectedVoice: onboardingState.selectedVoice,
            preferences: preferences,
            completedAt: Date()
        )
        
        if let encoded = try? JSONEncoder().encode(onboardingData) {
            UserDefaults.standard.set(encoded, forKey: "onboarding_completion_data")
        }
        
        print("✅ Onboarding preferences saved successfully")
    }
    
    private func saveOnboardingDataLocally() {
        let preferences = onboardingState.createUserPreferences()
        
        let onboardingData = OnboardingCompletionData(
            motivation: onboardingState.selectedMotivation,
            tonePosition: onboardingState.toneSliderPosition,
            selectedVoice: onboardingState.selectedVoice,
            preferences: preferences,
            completedAt: Date()
        )
        
        if let encoded = try? JSONEncoder().encode(onboardingData) {
            UserDefaults.standard.set(encoded, forKey: "onboarding_completion_data")
            UserDefaults.standard.set(true, forKey: "is_guest_user")
        }
        
        print("✅ Guest user preferences saved locally (no cloud sync)")
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateElements = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            showAuthOptions = true
        }
    }
    
    // MARK: - Apple Sign In Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
}

// MARK: - Premium Preference Summary Row

struct PremiumPreferenceSummaryRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Content
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Premium Value Proposition Row

struct PremiumValuePropositionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AccountCreationView_Previews: PreviewProvider {
    static var previews: some View {
        AccountCreationView(
            onboardingState: {
                let state = OnboardingState()
                state.selectedMotivation = .fitness
                state.selectedVoice = VoicePersona.allPersonas[0]
                state.toneSliderPosition = 0.7
                state.notificationPermissionGranted = true
                return state
            }(),
            authService: SimpleAuthenticationService(),
            isSigningIn: .constant(false),
            onAuthError: { message in
                print("Auth error: \(message)")
            },
            onComplete: {
                print("Account creation completed")
            }
        )
        .preferredColorScheme(.dark)
    }
}
#endif
