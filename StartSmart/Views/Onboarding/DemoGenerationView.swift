//
//  DemoGenerationView.swift
//  StartSmart
//
//  Onboarding Step 5: Demo Generation
//  Updated to match PremiumLandingPageV2 theme
//

import SwiftUI
import AVFoundation

/// Magic moment demo screen with premium design and engaging animations
struct DemoGenerationView: View {
    @ObservedObject var onboardingState: OnboardingState
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showGenerationAnimation = false
    @State private var showContent = false
    @State private var showPlaybackControls = false
    @State private var currentAnimationStep = 0
    @State private var demoService: OnboardingDemoService?
    
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
                            .opacity(showGenerationAnimation ? 1 : 0)
                            .offset(y: showGenerationAnimation ? 0 : 20)
                        
                        // Main animation area
                        mainAnimationArea
                            .opacity(showGenerationAnimation ? 1 : 0)
                            .offset(y: showGenerationAnimation ? 0 : 30)
                        
                        // Generated content display
                        if let content = onboardingState.generatedDemoContent {
                            generatedContentSection(content)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                        }
                        
                        // Error handling
                        if let error = onboardingState.demoError {
                            errorSection(error)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                        }
                        
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
            demoService = OnboardingDemoService()
            startDemoGeneration()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.spacing3) {
            // Magic wand icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.purple)
                    .modifier(PulseAnimationModifier(animate: true))
            }
            
            VStack(spacing: 12) {
                // Title
                Text("Creating Your First\nWake-Up...")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .tracking(-0.5)
                
                // Subtitle with personalization details
                if let motivation = onboardingState.selectedMotivation,
                   let voice = onboardingState.selectedVoice {
                    Text("Crafting a \(onboardingState.computedTone.displayName.lowercased()) message about \(motivation.displayName.lowercased()) in \(voice.name)'s voice")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                } else {
                    Text("Personalizing your perfect wake-up experience")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
        }
        .padding(.top, 60)
    }
    
    // MARK: - Main Animation Area
    
    private var mainAnimationArea: some View {
        VStack(spacing: DesignSystem.spacing3) {
            if onboardingState.isGeneratingDemo {
                loadingAnimationView
            } else if onboardingState.generatedDemoContent != nil {
                successAnimationView
            }
        }
    }
    
    // MARK: - Loading Animation
    
    private var loadingAnimationView: some View {
        VStack(spacing: 20) {
            // Loading spinner with premium gradient
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [DesignSystem.purple, DesignSystem.indigo]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(Angle(degrees: onboardingState.isGeneratingDemo ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: onboardingState.isGeneratingDemo
                    )
            }
            
            Text(generationStatusText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.5), value: currentAnimationStep)
        }
        .onAppear {
            startGenerationStatusAnimation()
        }
    }
    
    private var generationStatusText: String {
        let statusMessages = [
            "Analyzing your preferences...",
            "Crafting personalized content...",
            "Optimizing for your tone...",
            "Adding motivational elements...",
            "Finalizing your wake-up message..."
        ]
        
        return statusMessages[min(currentAnimationStep, statusMessages.count - 1)]
    }
    
    // MARK: - Success Animation
    
    private var successAnimationView: some View {
        VStack(spacing: 20) {
            // Success icon
            ZStack {
                Circle()
                    .fill(DesignSystem.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.green.opacity(0.5), lineWidth: 3)
                    )
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(DesignSystem.green)
                    .scaleEffect(showContent ? 1.0 : 0.95)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showContent)
            }
            .scaleEffect(showContent ? 1.0 : 0.5)
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showContent)
            
            // Success message
            Text("Your wake-up message is ready!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .opacity(showContent ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).delay(0.3), value: showContent)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Generated Content Section
    
    private func generatedContentSection(_ content: GeneratedContent) -> some View {
        VStack(spacing: DesignSystem.spacing2) {
            // Content preview card
            VStack(spacing: DesignSystem.spacing2) {
                // Content text
                ScrollView {
                    Text(content.textContent)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 16)
                }
                .frame(maxHeight: 180)
                
                // Audio playback controls
                audioPlaybackControls(for: content)
                    .opacity(showPlaybackControls ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(0.5), value: showPlaybackControls)
            }
            .padding(20)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .cornerRadius(20)
            
            // Magic moment message
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text("✨")
                        .font(.system(size: 16))
                    Text("This is just a preview")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.purple)
                }
                
                Text("Every morning, you'll get a fresh, personalized message based on your goals")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.purple.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DesignSystem.purple.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Audio Playback Controls
    
    private func audioPlaybackControls(for content: GeneratedContent) -> some View {
        HStack(spacing: 16) {
            // Play/pause button
            Button(action: {
                if onboardingViewModel.isAudioPlaying {
                    onboardingViewModel.stopAudio()
                } else {
                    onboardingViewModel.playDemoContent()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [DesignSystem.purple, DesignSystem.indigo]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: onboardingViewModel.isAudioPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: onboardingViewModel.isAudioPlaying ? 0 : 2)
                }
                .shadow(color: DesignSystem.purple.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(onboardingViewModel.isAudioPlaying ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: onboardingViewModel.isAudioPlaying)
            
            // Audio visualization or label
            if onboardingViewModel.isAudioPlaying {
                PremiumAudioVisualizationView(isPlaying: onboardingViewModel.isAudioPlaying)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tap to hear your message")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Delivered by \(onboardingState.selectedVoice?.name ?? "your chosen voice")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Color.orange)
            
            Text("Oops! Something went wrong")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button(action: startDemoGeneration) {
                Text("Try Again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [DesignSystem.purple, DesignSystem.indigo]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(20)
    }
    
    // MARK: - Helper Functions
    
    private func startDemoGeneration() {
        withAnimation(.easeOut(duration: 0.6)) {
            showGenerationAnimation = true
        }
        
        // Use fallback content instead of dependency-heavy demo service
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            generateFallbackContent()
        }
    }
    
    private func generateFallbackContent() {
        guard let motivation = onboardingState.selectedMotivation,
              let voice = onboardingState.selectedVoice else {
            print("⚠️ Missing required onboarding selections")
            onboardingState.isGeneratingDemo = false
            return
        }
        
        // Create fallback content without depending on external services
        let fallbackContent = GeneratedContent(
            textContent: getFallbackText(for: motivation),
            audioURL: nil,
            audioData: nil,
            voiceId: voice.name,
            metadata: ContentMetadata(
                textContent: getFallbackText(for: motivation),
                tone: onboardingState.computedTone,
                aiModel: "fallback",
                ttsModel: nil,
                generationTime: 0
            )
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onboardingState.isGeneratingDemo = false
            onboardingState.generatedDemoContent = fallbackContent
            
            withAnimation(.easeInOut(duration: 0.6)) {
                showContent = true
                showPlaybackControls = true
            }
        }
    }
    
    private func getFallbackText(for motivation: MotivationCategory) -> String {
        switch motivation {
        case .fitness:
            return "Good morning, champion! Today is the day you push your body to new limits. Every rep, every step, every breath is building the strongest version of yourself. Let's make it count!"
        case .career:
            return "Rise and shine, future leader! Today's challenges are tomorrow's success stories. Your dreams are calling – time to answer with action and determination!"
        case .studies:
            return "Good morning, brilliant mind! Knowledge is calling your name today. Every page you read, every concept you master brings you closer to your goals. Let's learn something amazing!"
        case .mindfulness:
            return "Good morning, peaceful soul. Take a deep breath and feel the calm energy of a new day. Today is your opportunity to find balance and inner peace. Let's embrace the present moment."
        case .personalProject:
            return "Good morning, creator! Your vision is waiting to come to life today. Every small step forward is progress toward something amazing. Let's build something incredible!"
        case .other:
            return "Good morning! Today is a fresh start full of endless possibilities. Whatever you're working toward, believe in yourself and take that first step. You've got this!"
        }
    }
    
    private func startGenerationStatusAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            if onboardingState.isGeneratingDemo {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentAnimationStep = (currentAnimationStep + 1) % 5
                }
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Pulse Animation Modifier

struct PulseAnimationModifier: ViewModifier {
    let animate: Bool
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                if animate {
                    withAnimation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                    ) {
                        scale = 1.15
                    }
                }
            }
    }
}

// MARK: - Premium Audio Visualization View

struct PremiumAudioVisualizationView: View {
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [DesignSystem.purple, DesignSystem.indigo]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: isPlaying ? CGFloat.random(in: 10...24) : 10)
                    .animation(
                        isPlaying ?
                        Animation.easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1) :
                        .default,
                        value: isPlaying
                    )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DemoGenerationView_Previews: PreviewProvider {
    static var previews: some View {
        DemoGenerationView(
            onboardingState: {
                let state = OnboardingState()
                state.selectedMotivation = .fitness
                state.selectedVoice = VoicePersona.allPersonas[0]
                state.toneSliderPosition = 0.7
                return state
            }(),
            onboardingViewModel: OnboardingViewModel()
        )
        .preferredColorScheme(.dark)
    }
}
#endif
