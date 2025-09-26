//
//  OnboardingFlowView.swift
//  StartSmart
//
//  Enhanced Onboarding Navigation Framework
//  Manages the complete onboarding flow with step-by-step navigation
//

import SwiftUI
import AuthenticationServices

/// Main onboarding flow coordinator that manages all onboarding steps
struct OnboardingFlowView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var authService = AuthenticationService()
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Management
    @State private var showingAuthAlert = false
    @State private var authAlertMessage = ""
    @State private var isSigningIn = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient that changes based on current step
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator (hidden on welcome screen)
                    if onboardingViewModel.onboardingState.currentStep != .welcome {
                        progressIndicator
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                    }
                    
                    // Main content area
                    TabView(selection: $onboardingViewModel.onboardingState.currentStep) {
                        // Step 1: Welcome
                        EnhancedWelcomeView(
                            onPrimaryAction: {
                                onboardingViewModel.onboardingState.proceedToNext()
                            },
                            onSecondaryAction: {
                                // Handle "Already have account" flow
                                showSignInFlow()
                            }
                        )
                        .tag(OnboardingStep.welcome)
                        
                        // Step 2: Motivation Selection
                        MotivationSelectionView(onboardingState: onboardingViewModel.onboardingState)
                            .tag(OnboardingStep.motivation)
                        
                        // Step 3: Tone Selection
                        ToneSelectionView(onboardingState: onboardingViewModel.onboardingState)
                            .tag(OnboardingStep.tone)
                        
                        // Step 4: Voice Selection
                        VoiceSelectionView(
                            onboardingState: onboardingViewModel.onboardingState,
                            onboardingViewModel: onboardingViewModel
                        )
                        .tag(OnboardingStep.voice)
                        
                        // Step 5: Demo Generation
                        DemoGenerationView(
                            onboardingState: onboardingViewModel.onboardingState,
                            onboardingViewModel: onboardingViewModel
                        )
                        .tag(OnboardingStep.demo)
                        
                        // Step 6: Permission Priming
                        PermissionPrimingView(onboardingState: onboardingViewModel.onboardingState)
                            .tag(OnboardingStep.permissions)
                        
                        // Step 7: Account Creation
                        AccountCreationView(
                            onboardingState: onboardingViewModel.onboardingState,
                            authService: authService,
                            isSigningIn: $isSigningIn,
                            onAuthError: { message in
                                authAlertMessage = message
                                showingAuthAlert = true
                            },
                            onComplete: {
                                handleOnboardingCompletion()
                            }
                        )
                        .tag(OnboardingStep.accountCreation)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: onboardingViewModel.onboardingState.currentStep)
                    
                    // Navigation controls (hidden on certain steps)
                    if shouldShowNavigationControls {
                        navigationControls
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Authentication Error", isPresented: $showingAuthAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authAlertMessage)
        }
        .onAppear {
            setupOnboardingFlow()
        }
    }
    
    // MARK: - Background Gradient
    
    private var backgroundGradient: some View {
        Group {
            switch onboardingViewModel.onboardingState.currentStep {
            case .welcome:
                LinearGradient(
                    colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .motivation:
                LinearGradient(
                    colors: [.orange.opacity(0.7), .pink.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .tone:
                LinearGradient(
                    colors: toneGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .voice:
                LinearGradient(
                    colors: [.green.opacity(0.7), .teal.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .demo:
                LinearGradient(
                    colors: [.purple.opacity(0.8), .indigo.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .permissions:
                LinearGradient(
                    colors: [.blue.opacity(0.7), .cyan.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .accountCreation:
                LinearGradient(
                    colors: [.green.opacity(0.8), .mint.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    private var toneGradientColors: [Color] {
        let position = onboardingViewModel.onboardingState.toneSliderPosition
        
        switch position {
        case 0.0..<0.25:
            return [.mint.opacity(0.7), .green.opacity(0.5)]
        case 0.25..<0.5:
            return [.purple.opacity(0.7), .blue.opacity(0.5)]
        case 0.5..<0.75:
            return [.orange.opacity(0.7), .red.opacity(0.5)]
        default:
            return [.red.opacity(0.8), .black.opacity(0.6)]
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(
                            width: geometry.size.width * onboardingViewModel.onboardingState.progress,
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.3), value: onboardingViewModel.onboardingState.progress)
                }
            }
            .frame(height: 8)
            
            // Step indicator
            HStack {
                Text("\(onboardingViewModel.onboardingState.currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text(onboardingViewModel.onboardingState.currentStep.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Navigation Controls
    
    private var shouldShowNavigationControls: Bool {
        switch onboardingViewModel.onboardingState.currentStep {
        case .welcome, .demo, .accountCreation:
            return false
        case .motivation, .tone, .voice, .permissions:
            return true
        }
    }
    
    private var navigationControls: some View {
        HStack {
            // Back button
            if onboardingViewModel.onboardingState.currentStep.rawValue > 0 {
                Button(action: {
                    onboardingViewModel.onboardingState.goBack()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.white.opacity(0.2))
                    )
                }
            }
            
            Spacer()
            
            // Skip button (if applicable)
            if onboardingViewModel.onboardingState.currentStep.canSkip {
                Button(action: {
                    onboardingViewModel.onboardingState.skipCurrentStep()
                }) {
                    Text("Skip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
            }
            
            // Next button
            if onboardingViewModel.onboardingState.canProceed {
                Button(action: {
                    handleNextButton()
                }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
                    .foregroundColor(.primary)
                }
            }
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleNextButton() {
        let currentStep = onboardingViewModel.onboardingState.currentStep
        
        switch currentStep {
        case .tone:
            onboardingViewModel.onboardingState.proceedToNext()
        case .permissions:
            requestNotificationPermissions()
        default:
            onboardingViewModel.onboardingState.proceedToNext()
        }
    }
    
    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                    onboardingViewModel.onboardingState.setNotificationPermission(false)
                } else {
                    print("✅ Notification permission granted: \(granted)")
                    onboardingViewModel.onboardingState.setNotificationPermission(granted)
                }
            }
        }
    }
    
    private func showSignInFlow() {
        // Handle existing users - could show a simplified auth flow
        print("🔄 Showing sign-in flow for existing users")
        // For now, just start the regular auth flow
        onboardingViewModel.onboardingState.currentStep = .accountCreation
    }
    
    private func handleOnboardingCompletion() {
        // Convert onboarding state to user preferences
        let preferences = onboardingViewModel.onboardingState.createUserPreferences()
        
        // Store onboarding data in user defaults for immediate use
        let onboardingData = OnboardingCompletionData(
            motivation: onboardingViewModel.onboardingState.selectedMotivation,
            tonePosition: onboardingViewModel.onboardingState.toneSliderPosition,
            selectedVoice: onboardingViewModel.onboardingState.selectedVoice,
            preferences: preferences,
            completedAt: Date()
        )
        
        // Save to user defaults
        if let encoded = try? JSONEncoder().encode(onboardingData) {
            UserDefaults.standard.set(encoded, forKey: "onboarding_completion_data")
        }
        
        // Mark onboarding as completed
        onboardingViewModel.onboardingState.completeOnboarding()
        
        // Dismiss the onboarding flow
        dismiss()
        
        print("🎉 Onboarding completed successfully!")
    }
    
    private func setupOnboardingFlow() {
        // Any initial setup for the onboarding flow
        print("🚀 Starting enhanced onboarding flow")
        
        // Pre-load voice personas if needed
        _ = VoicePersona.allPersonas
        
        // Initialize any required services
        // This could include checking for existing partial onboarding data
    }
}

// MARK: - Onboarding Completion Data

struct OnboardingCompletionData: Codable {
    let motivation: MotivationCategory?
    let tonePosition: Double
    let selectedVoice: VoicePersona?
    let preferences: UserPreferences
    let completedAt: Date
}

// MARK: - Preview Support

#if DEBUG
struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowView()
            .preferredColorScheme(.dark)
    }
}
#endif
