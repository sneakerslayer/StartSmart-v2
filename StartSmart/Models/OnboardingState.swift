//
//  OnboardingState.swift
//  StartSmart
//
//  Enhanced Onboarding Data Models
//  Supports the new interactive onboarding flow
//

import Foundation
import SwiftUI
import Combine

// MARK: - Motivation Categories
enum MotivationCategory: String, CaseIterable, Codable {
    case fitness = "fitness"
    case career = "career_growth"
    case studies = "studies"
    case mindfulness = "mindfulness"
    case personalProject = "personal_project"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .fitness: return "Fitness"
        case .career: return "Career Growth"
        case .studies: return "My Studies"
        case .mindfulness: return "Mindfulness"
        case .personalProject: return "A Personal Project"
        case .other: return "Other"
        }
    }
    
    var description: String {
        switch self {
        case .fitness: return "Health, workouts, and physical well-being"
        case .career: return "Professional growth and advancement"
        case .studies: return "Learning, education, and skill development"
        case .mindfulness: return "Mental health, meditation, and balance"
        case .personalProject: return "Creative projects and personal goals"
        case .other: return "Something else that drives you"
        }
    }
    
    var iconName: String {
        switch self {
        case .fitness: return "figure.strengthtraining.functional"
        case .career: return "briefcase.fill"
        case .studies: return "graduationcap.fill"
        case .mindfulness: return "leaf.fill"
        case .personalProject: return "lightbulb.fill"
        case .other: return "star.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .fitness: return .red
        case .career: return .blue
        case .studies: return .orange
        case .mindfulness: return .green
        case .personalProject: return .purple
        case .other: return .pink
        }
    }
}

// MARK: - Voice Persona
struct VoicePersona: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let tone: AlarmTone
    let sampleText: String
    let voiceId: String // ElevenLabs voice ID
    let isPremium: Bool // Premium feature flag
    
    static let allPersonas: [VoicePersona] = [
        VoicePersona(
            id: "gentle_mentor",
            name: "The Mentor",
            description: "Warm, encouraging guidance like a caring coach",
            tone: .gentle,
            sampleText: "Good morning. You've got this. Take a deep breath and gently begin your day with purpose.",
            voiceId: "gentle",
            isPremium: false // Free voice
        ),
        VoicePersona(
            id: "energetic_coach",
            name: "The Coach",
            description: "High-energy motivation to get you moving",
            tone: .energetic,
            sampleText: "Rise and shine! Today is your day to absolutely crush those goals. Let's go make it happen!",
            voiceId: "energetic",
            isPremium: false // Free voice
        ),
        VoicePersona(
            id: "tough_challenger",
            name: "The Challenger",
            description: "Direct, no-nonsense motivation that pushes you",
            tone: .toughLove,
            sampleText: "Time to get up. No excuses today. That goal isn't going to crush itself. Move!",
            voiceId: "tough_love",
            isPremium: true // Premium voice
        ),
        VoicePersona(
            id: "wise_storyteller",
            name: "The Storyteller",
            description: "Inspiring through metaphors and vivid imagery",
            tone: .storyteller,
            sampleText: "Like the sunrise breaking through the darkness, your potential awakens. Rise and embrace your journey.",
            voiceId: "storyteller",
            isPremium: true // Premium voice
        )
    ]
    
    static func persona(for tone: AlarmTone) -> VoicePersona? {
        return allPersonas.first { $0.tone == tone }
    }
}

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case premiumLanding = 0
    case motivation = 1
    case tone = 2
    case voice = 3
    case demo = 4
    case permissions = 5
    case accountCreation = 6
    
    var title: String {
        switch self {
        case .premiumLanding: return "StartSmart"
        case .motivation: return "What drives you?"
        case .tone: return "How do you like your motivation?"
        case .voice: return "Choose your morning guide"
        case .demo: return "Creating your first wake-up..."
        case .permissions: return "Enable notifications"
        case .accountCreation: return "Save your preferences"
        }
    }
    
    var isInteractive: Bool {
        switch self {
        case .premiumLanding, .demo, .permissions, .accountCreation:
            return false
        case .motivation, .tone, .voice:
            return true
        }
    }
    
    var canSkip: Bool {
        switch self {
        case .premiumLanding, .demo, .permissions, .accountCreation:
            return false
        case .motivation, .tone, .voice:
            return true
        }
    }
}

// MARK: - Onboarding State
class OnboardingState: ObservableObject {
    @Published var currentStep: OnboardingStep = .premiumLanding {
        didSet {
            print("🔄 OnboardingState.currentStep changed from \(oldValue) to \(currentStep)")
        }
    }
    @Published var selectedMotivation: MotivationCategory?
    @Published var toneSliderPosition: Double = 0.5 // 0.0 (gentle) to 1.0 (tough)
    @Published var selectedVoice: VoicePersona?
    @Published var isGeneratingDemo: Bool = false
    @Published var generatedDemoContent: GeneratedContent?
    @Published var demoError: String?
    @Published var notificationPermissionGranted: Bool? = nil
    @Published var isCompletingOnboarding: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    
    // MARK: - Progress Tracking
    var progress: Double {
        Double(currentStep.rawValue) / Double(OnboardingStep.allCases.count - 1)
    }
    
    var canProceed: Bool {
        switch currentStep {
        case .premiumLanding:
            return true
        case .motivation:
            return selectedMotivation != nil
        case .tone:
            return true // Slider always has a value
        case .voice:
            return selectedVoice != nil
        case .demo:
            return generatedDemoContent != nil || demoError != nil
        case .permissions:
            return notificationPermissionGranted != nil
        case .accountCreation:
            return true
        }
    }
    
    // MARK: - Computed Properties
    var computedTone: AlarmTone {
        switch toneSliderPosition {
        case 0.0..<0.25:
            return .gentle
        case 0.25..<0.5:
            return .storyteller
        case 0.5..<0.75:
            return .energetic
        default:
            return .toughLove
        }
    }
    
    var toneDisplayText: String {
        switch toneSliderPosition {
        case 0.0..<0.2:
            return "You've got this. Take a deep breath and gently begin your day."
        case 0.2..<0.4:
            return "Rise with purpose and embrace the possibilities ahead of you."
        case 0.4..<0.6:
            return "Time to wake up and show the world what you're made of!"
        case 0.6..<0.8:
            return "Let's go! Today is your day to absolutely crush those goals."
        default:
            return "Get up! No excuses today. That goal isn't going to crush itself."
        }
    }
    
    // MARK: - Navigation Methods
    func proceedToNext() {
        print("🔄 proceedToNext() called - current step: \(currentStep), canProceed: \(canProceed)")
        guard canProceed else { 
            print("❌ Cannot proceed from current step")
            return 
        }
        
        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            print("✅ Moving to next step: \(nextStep)")
            
            // Force state update on main thread
            DispatchQueue.main.async {
                self.currentStep = nextStep
                print("✅ State updated to: \(self.currentStep)")
            }
        } else {
            print("❌ No next step available")
        }
    }
    
    func goBack() {
        if let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            DispatchQueue.main.async {
                self.currentStep = previousStep
            }
        }
    }
    
    func skipCurrentStep() {
        guard currentStep.canSkip else { return }
        proceedToNext()
    }
    
    // MARK: - Selection Methods
    func selectMotivation(_ motivation: MotivationCategory) {
        print("🎯 selectMotivation called with: \(motivation.rawValue)")
        withAnimation(.easeOut(duration: 0.2)) {
            selectedMotivation = motivation
        }
        print("🎯 selectedMotivation set to: \(selectedMotivation?.rawValue ?? "nil")")
        
        // Don't auto-advance - let user manually tap Next button
        // This ensures proper state synchronization with OnboardingFlowView
    }
    
    func selectVoice(_ voice: VoicePersona) {
        withAnimation(.easeOut(duration: 0.2)) {
            selectedVoice = voice
        }
        
        // Don't auto-advance - let user manually tap Next button
        // This ensures proper state synchronization with OnboardingFlowView
    }
    
    func updateTonePosition(_ position: Double) {
        withAnimation(.easeOut(duration: 0.1)) {
            toneSliderPosition = max(0.0, min(1.0, position))
        }
    }
    
    // MARK: - Demo Generation
    func startDemoGeneration() {
        guard !isGeneratingDemo else { return }
        
        isGeneratingDemo = true
        demoError = nil
        generatedDemoContent = nil
        
        // This will be implemented when we create the OnboardingDemoService
        print("🚀 Demo generation started for: \(selectedMotivation?.displayName ?? "Unknown"), tone: \(computedTone.displayName)")
        
        // Simulate demo generation for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.isGeneratingDemo = false
            
            // Create mock generated content
            let mockContent = GeneratedContent(
                textContent: self.createMockDemoText(),
                voiceId: self.selectedVoice?.voiceId ?? "energetic",
                metadata: ContentMetadata(
                    textContent: self.createMockDemoText(),
                    tone: self.computedTone
                )
            )
            
            self.generatedDemoContent = mockContent
            
            // Auto-advance after successful generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.proceedToNext()
            }
        }
    }
    
    private func createMockDemoText() -> String {
        guard let motivation = selectedMotivation else {
            return "Wake up and make today count!"
        }
        
        let tone = computedTone
        
        switch (motivation, tone) {
        case (.fitness, .gentle):
            return "Good morning, champion. Your body is ready to move, and your spirit is ready to soar. Let's start this day with gentle strength and purpose."
        case (.fitness, .energetic):
            return "Rise and shine, athlete! Time to fuel that incredible machine you call your body. Let's crush this workout and show the world what you're made of!"
        case (.fitness, .toughLove):
            return "Get up, warrior. That gym isn't going to conquer itself. Stop making excuses and start making gains. Your future self is counting on you."
        case (.career, .gentle):
            return "Good morning, professional. Today brings new opportunities to grow and shine. Take a breath, center yourself, and step confidently into your potential."
        case (.career, .energetic):
            return "Rise up, future leader! Today is your stage to showcase your talents. That presentation, that meeting, that goal - you're ready to dominate!"
        case (.career, .toughLove):
            return "Time to get up and get serious. Your career won't build itself. Stop dreaming and start doing. Success demands action, not intentions."
        default:
            return "Wake up with purpose. Today is your canvas - paint it with intention, effort, and unwavering determination."
        }
    }
    
    // MARK: - Permission Handling
    func setNotificationPermission(_ granted: Bool) {
        withAnimation(.easeOut(duration: 0.2)) {
            notificationPermissionGranted = granted
        }
        
        // Auto-advance after permission handling
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.proceedToNext()
        }
    }
    
    // MARK: - Completion
    func completeOnboarding() {
        isCompletingOnboarding = true
        
        // Convert onboarding data to user preferences
        let preferences = createUserPreferences()
        
        // This will be handled by the parent view/service
        print("🎉 Onboarding completed with preferences: \(preferences)")
        
        // Mark as completed
        withAnimation(.easeOut(duration: 0.3)) {
            hasCompletedOnboarding = true
            isCompletingOnboarding = false
        }
    }
    
    func createUserPreferences() -> UserPreferences {
        return UserPreferences(
            defaultAlarmTone: selectedVoice?.tone ?? computedTone,
            notificationsEnabled: notificationPermissionGranted ?? false,
            toneSliderPosition: toneSliderPosition
        )
    }
    
    // MARK: - Reset
    func reset() {
        currentStep = .premiumLanding
        selectedMotivation = nil
        toneSliderPosition = 0.5
        selectedVoice = nil
        isGeneratingDemo = false
        generatedDemoContent = nil
        demoError = nil
        notificationPermissionGranted = nil
        isCompletingOnboarding = false
        hasCompletedOnboarding = false
    }
}

// MARK: - Onboarding Progress View Model
@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var onboardingState = OnboardingState()
    @Published var isAudioPlaying = false
    @Published var audioError: String?
    // Proxy published value so parent views react to slider changes
    @Published var toneSliderPositionProxy: Double = 0.5
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        // Bridge nested object changes to this view model so views observing
        // the view model update when the slider moves
        onboardingState.$toneSliderPosition
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.toneSliderPositionProxy = value
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation Methods
    func proceedToNext() {
        onboardingState.proceedToNext()
    }
    
    func goBack() {
        onboardingState.goBack()
    }
    
    // MARK: - Audio Preview
    func playVoicePreview(for voice: VoicePersona) {
        guard !isAudioPlaying else { return }
        
        isAudioPlaying = true
        audioError = nil
        
        // This will be implemented when we integrate with audio services
        print("🔊 Playing voice preview for: \(voice.name)")
        
        // Simulate audio playback
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.isAudioPlaying = false
        }
    }
    
    func playDemoContent() {
        guard let content = onboardingState.generatedDemoContent,
              !isAudioPlaying else { return }
        
        isAudioPlaying = true
        audioError = nil
        
        print("🔊 Playing demo content: \(content.textContent.prefix(50))...")
        
        // Simulate audio playback
        DispatchQueue.main.asyncAfter(deadline: .now() + content.estimatedDuration) {
            self.isAudioPlaying = false
        }
    }
    
    func stopAudio() {
        isAudioPlaying = false
        audioError = nil
    }
}
