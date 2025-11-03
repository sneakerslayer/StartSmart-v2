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
    @StateObject private var authService = SimpleAuthenticationService()
    @Environment(\.dismiss) private var dismiss
    
    let onComplete: (() -> Void)?
    
    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }
    
    // MARK: - State Management
    @State private var showingAuthAlert = false
    @State private var authAlertMessage = ""
    @State private var currentStep: OnboardingStep = .premiumLanding
    @State private var isSigningIn = false
    @State private var selectedMotivation: MotivationCategory? = nil
    @State private var selectedVoice: VoicePersona? = nil
    
    // Computed progress based on current step
    private var progress: Double {
        return Double(currentStep.rawValue) / Double(OnboardingStep.allCases.count - 1)
    }
    
    // Computed canProceed based on current step
    private var canProceed: Bool {
        let result: Bool
        switch currentStep {
        case .premiumLanding:
            result = true
        case .motivation:
            result = selectedMotivation != nil
        case .tone:
            result = true // Slider always has a value
        case .voice:
            result = selectedVoice != nil
        case .demo:
            result = true // Always allow proceeding from demo page
        case .permissions:
            result = true // Always allow proceeding from permissions page
        case .accountCreation:
            result = true // Always allow proceeding from account creation (implies completion)
        }
        
        print("🔍 canProceed check - step: \(currentStep), selectedMotivation: \(selectedMotivation?.rawValue ?? "nil"), selectedVoice: \(selectedVoice?.name ?? "nil"), result: \(result)")
        return result
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient that changes based on current step
                backgroundGradient
                    .ignoresSafeArea()
                
                // Main content area - fills entire screen
                Group {
                        switch currentStep {
                        case .premiumLanding:
                            PremiumLandingPageV2(onGetStarted: {
                                currentStep = .motivation
                            })
                        
                        case .motivation:
                            MotivationSelectionView(
                                onboardingState: onboardingViewModel.onboardingState,
                                onMotivationSelected: { motivation in
                                    print("🎯 Motivation selected in OnboardingFlowView: \(motivation.rawValue)")
                                    selectedMotivation = motivation
                                }
                            )
                            
                        case .tone:
                            ToneSelectionView(onboardingState: onboardingViewModel.onboardingState)
                            
                        case .voice:
                            VoiceSelectionView(
                                onboardingState: onboardingViewModel.onboardingState,
                                onboardingViewModel: onboardingViewModel,
                                onVoiceSelected: { voice in
                                    print("🎯 Voice selected in OnboardingFlowView: \(voice.name)")
                                    selectedVoice = voice
                                }
                            )
                            
                        case .demo:
                            DemoGenerationView(
                                onboardingState: onboardingViewModel.onboardingState,
                                onboardingViewModel: onboardingViewModel
                            )
                            
                        case .permissions:
                            PermissionPrimingView(onboardingState: onboardingViewModel.onboardingState)
                            
                        case .accountCreation:
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
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: onboardingViewModel.onboardingState.currentStep)
                
                // Floating navigation controls (positioned outside VStack to float over background)
                VStack {
                    Spacer()
                    if shouldShowNavigationControls {
                        navigationControls
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                }
                
                // Progress indicator overlayed at the top (hidden on premium landing screen)
                if currentStep != .premiumLanding {
                    VStack {
                        progressIndicator
                            .padding(.top, 8)
                            .padding(.horizontal, 20)
                        Spacer()
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
        .onChange(of: onboardingViewModel.onboardingState.selectedMotivation) { _ in
            // Force UI update when motivation selection changes
            print("🔄 selectedMotivation changed, forcing UI update")
        }
    }
    
    // MARK: - Background Gradient
    
    private var backgroundGradient: some View {
        // Unified dark gradient for all screens - matching the premium landing page
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.06, green: 0.06, blue: 0.12),
                Color(red: 0.10, green: 0.10, blue: 0.18)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var toneGradientColors: [Color] {
        let position = onboardingViewModel.toneSliderPositionProxy
        
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
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(
                            width: geometry.size.width * progress,
                            height: 12
                        )
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 12)
            
            // Step indicator
            HStack {
                Text("\(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.2))
                    )
                
                Spacer()
                
                Text(currentStep.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
    
    // MARK: - Navigation Controls
    
    private var shouldShowNavigationControls: Bool {
        switch currentStep {
        case .premiumLanding, .accountCreation:
            return false
        case .motivation, .tone, .voice, .demo, .permissions:
            return true
        }
    }
    
    private var navigationControls: some View {
        HStack {
            // Back button
            if currentStep.rawValue > 0 {
                Button(action: {
                    if let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                        currentStep = previousStep
                    }
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
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
            }
            
            Spacer()
            
            // Next button
            if canProceed {
                Button(action: {
                    handleNextButton()
                }) {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
            }
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleNextButton() {
        print("🔘 handleNextButton called")
        print("🔘 Current step: \(currentStep)")
        print("🔘 Can proceed: \(canProceed)")
        
        switch currentStep {
        case .tone:
            print("🔘 Proceeding from tone step")
            if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
            }
        case .permissions:
            print("🔘 Requesting notification permissions and proceeding")
            requestNotificationPermissions()
            // Proceed to next step regardless of permission result
            if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
            }
        default:
            print("🔘 Proceeding to next step")
            if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
            }
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
        
        // Call completion callback if provided, otherwise dismiss
        if let onComplete = onComplete {
            onComplete()
        } else {
            dismiss()
        }
    }
    
    private func setupOnboardingFlow() {
        // Any initial setup for the onboarding flow
        
        // Pre-load voice personas if needed
        _ = VoicePersona.allPersonas
        
        // Configure initial state
        onboardingViewModel.onboardingState.currentStep = .premiumLanding
        
        // Initialize any required services
        // This could include checking for existing partial onboarding data
    }
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

