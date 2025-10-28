//
//  AccountCreationView.swift
//  StartSmart
//
//  Enhanced Account Creation Flow
//  Focused on saving preferences with social authentication
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth

/// Enhanced account creation focused on saving onboarding preferences
struct AccountCreationView: View {
    @ObservedObject var onboardingState: OnboardingState
    let authService: SimpleAuthenticationService
    @Binding var isSigningIn: Bool
    let onAuthError: (String) -> Void
    let onComplete: () -> Void
    
    @State private var animateElements = false
    @State private var showAuthOptions = true // Set to true immediately for testing
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    // Header section
                    headerSection
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : -20)
                    
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
                    
                    // Add space for navigation buttons
                    Spacer(minLength: 20) // Reduced to minimize dead space
                }
                .padding(.horizontal, 24)
                .padding(.top, 10) // Reduced top padding to prevent cutoff
                .padding(.bottom, 20) // Reduced bottom padding to minimize dead space
                .frame(minHeight: geometry.size.height)
            }
            .scrollContentBackground(.hidden) // Hide default background for better bounce effect
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Success checkmark with celebration
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.6), lineWidth: 3)
                    )
                    .scaleEffect(animateElements ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: animateElements)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.green)
                    .scaleEffect(animateElements ? 1.0 : 0.95)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animateElements)
            }
            
            // Title
            Text("Save Your Preferences")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .tracking(-1)
            
            // Subtitle
            Text("Create an account to save your motivational profile and track your progress")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
        }
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
                    PreferenceSummaryRow(
                        icon: motivation.iconName,
                        title: "Focus Area",
                        value: motivation.displayName,
                        color: motivation.iconColor
                    )
                }
                
                // Tone
                PreferenceSummaryRow(
                    icon: onboardingState.computedTone.iconName,
                    title: "Motivation Style",
                    value: onboardingState.computedTone.displayName,
                    color: toneColor
                )
                
                // Voice
                if let voice = onboardingState.selectedVoice {
                    PreferenceSummaryRow(
                        icon: "person.wave.2.fill",
                        title: "Voice Persona",
                        value: voice.name,
                        color: .purple
                    )
                }
                
                // Notifications
                PreferenceSummaryRow(
                    icon: onboardingState.notificationPermissionGranted == true ? "bell.fill" : "bell.slash.fill",
                    title: "Notifications",
                    value: onboardingState.notificationPermissionGranted == true ? "Enabled" : "Disabled",
                    color: onboardingState.notificationPermissionGranted == true ? .green : .orange
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var toneColor: Color {
        switch onboardingState.computedTone {
        case .gentle: return .mint
        case .energetic: return .orange
        case .toughLove: return .red
        case .storyteller: return .purple
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
                    // Configure request
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleSignInResult(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .disabled(isSigningIn)
                
                // Sign in with Google
                Button(action: {
                    handleGoogleSignIn()
                }) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.title2)
                        
                        Text("Continue with Google")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1.5)
                    )
                }
                .disabled(isSigningIn)
                
                // Continue as Guest button
                Button(action: {
                    handleContinueAsGuest()
                }) {
                    HStack {
                        Image(systemName: "person.fill.questionmark")
                            .font(.title2)
                        
                        Text("Continue as Guest")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                            )
                    )
                }
                .disabled(isSigningIn)
                
                // Loading state
                if isSigningIn {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Creating your account...")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 8)
                }
            }
            
            // Guest mode disclaimer
            Text("Guest mode: Basic alarm features only")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
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
                HStack {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 16)
                    
                    Text("Sync your preferences across devices")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 16)
                    
                    Text("Track your morning motivation progress")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 16)
                    
                    Text("Get personalized content improvements")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                }
            }
            
            // Terms and privacy
            VStack(spacing: 8) {
                Text("By creating an account, you agree to our")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 4) {
                    Button("Terms of Service") {
                        // Handle terms
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    
                    Text("and")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Button("Privacy Policy") {
                        // Handle privacy
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 16)
            .padding(.bottom, 20) // Reduced bottom padding to minimize dead space
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
                    // Save onboarding preferences
                    saveOnboardingData()
                    
                    // Add a small delay to ensure UI updates properly
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
                // Process the authorization from SignInWithAppleButton
                guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    errorMsg = "Invalid Apple ID credential"
                    break
                }
                
                guard let appleIDToken = appleIDCredential.identityToken,
                      let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    errorMsg = "Unable to fetch identity token"
                    break
                }
                
                // Generate nonce for Firebase
                let nonce = randomNonceString()
                
                // Create Firebase credential
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                do {
                    // Sign in with Firebase
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
                    // Save onboarding preferences
                    saveOnboardingData()
                    
                    // Add a small delay to ensure UI updates properly
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

        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")

        // Set guest mode flag (AuthenticationService will check this when initialized)
        UserDefaults.standard.set(true, forKey: "is_guest_user")
        
        print("✅ Guest mode flag set in UserDefaults")

        // Save onboarding preferences locally (not to Firestore since no user account)
        saveOnboardingDataLocally()

        // Navigate to main app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }

        print("⏭️ Navigating to MainAppView as guest user")
    }
    
    private func saveOnboardingData() {
        // Create user preferences from onboarding state
        let preferences = onboardingState.createUserPreferences()
        
        // Save additional onboarding metadata
        let onboardingData = OnboardingCompletionData(
            motivation: onboardingState.selectedMotivation,
            tonePosition: onboardingState.toneSliderPosition,
            selectedVoice: onboardingState.selectedVoice,
            preferences: preferences,
            completedAt: Date()
        )
        
        // Save to user defaults for immediate use
        if let encoded = try? JSONEncoder().encode(onboardingData) {
            UserDefaults.standard.set(encoded, forKey: "onboarding_completion_data")
        }
        
        print("✅ Onboarding preferences saved successfully")
    }
    
    private func saveOnboardingDataLocally() {
        // Save onboarding preferences locally for guest users (no Firestore)
        let preferences = onboardingState.createUserPreferences()
        
        let onboardingData = OnboardingCompletionData(
            motivation: onboardingState.selectedMotivation,
            tonePosition: onboardingState.toneSliderPosition,
            selectedVoice: onboardingState.selectedVoice,
            preferences: preferences,
            completedAt: Date()
        )
        
        // Save to UserDefaults only (guest mode - no cloud sync)
        if let encoded = try? JSONEncoder().encode(onboardingData) {
            UserDefaults.standard.set(encoded, forKey: "onboarding_completion_data")
            UserDefaults.standard.set(true, forKey: "is_guest_user")
        }
        
        print("✅ Guest user preferences saved locally (no cloud sync)")
    }
    
    private func updateUserWithOnboardingData(_ user: User) {
        // Convert onboarding state to user preferences
        var updatedUser = user
        let preferences = onboardingState.createUserPreferences()
        updatedUser.updatePreferences(preferences)
        
        // Save additional onboarding metadata
        let onboardingData = OnboardingCompletionData(
            motivation: onboardingState.selectedMotivation,
            tonePosition: onboardingState.toneSliderPosition,
            selectedVoice: onboardingState.selectedVoice,
            preferences: preferences,
            completedAt: Date()
        )
        
        // Save to user defaults for immediate use
        if let encoded = try? JSONEncoder().encode(onboardingData) {
            UserDefaults.standard.set(encoded, forKey: "onboarding_completion_data")
        }
        
        print("✅ User updated with onboarding preferences")
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateElements = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
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
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Preference Summary Row

struct PreferenceSummaryRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            
            // Content
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Value Proposition Row

struct ValuePropositionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 12))
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
        .background(
            LinearGradient(
                colors: [.green.opacity(0.8), .mint.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .preferredColorScheme(.dark)
    }
}

#endif
