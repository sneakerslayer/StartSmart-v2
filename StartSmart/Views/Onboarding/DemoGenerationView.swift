//
//  DemoGenerationView.swift
//  StartSmart
//
//  Magic Moment Demo Screen
//  Engaging animation with AI-generated audio playback
//

import SwiftUI
import AVFoundation

/// Magic moment demo screen with engaging animations and audio playback
struct DemoGenerationView: View {
    @ObservedObject var onboardingState: OnboardingState
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    
    @State private var animateElements = false
    @State private var showGenerationAnimation = false
    @State private var showContent = false
    @State private var showPlaybackControls = false
    @State private var currentAnimationStep = 0
    
    // Demo service
    @State private var demoService: OnboardingDemoService?
    
    var body: some View {
        VStack(spacing: 32) {
            // Header section
            headerSection
                .opacity(animateElements ? 1 : 0)
                .offset(y: animateElements ? 0 : -20)
            
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
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .onAppear {
            startDemoGeneration()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Magic wand icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse.byLayer, options: .repeating, value: animateElements)
            }
            
            // Title
            Text("Creating Your First Wake-Up...")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .tracking(-1)
            
            // Subtitle with personalization details
            VStack(spacing: 8) {
                if let motivation = onboardingState.selectedMotivation,
                   let voice = onboardingState.selectedVoice {
                    Text("Crafting a \(onboardingState.computedTone.displayName.lowercased()) message about \(motivation.displayName.lowercased()) in \(voice.name)'s voice")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                } else {
                    Text("Personalizing your perfect wake-up experience")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Main Animation Area
    
    private var mainAnimationArea: some View {
        VStack(spacing: 24) {
            if onboardingState.isGeneratingDemo {
                generationAnimationView
            } else if onboardingState.generatedDemoContent != nil {
                successAnimationView
            } else if onboardingState.demoError != nil {
                errorAnimationView
            }
        }
        .frame(height: 200)
    }
    
    // MARK: - Generation Animation
    
    private var generationAnimationView: some View {
        VStack(spacing: 20) {
            // Neural network style animation
            NeuralNetworkAnimation(isAnimating: onboardingState.isGeneratingDemo)
                .frame(width: 120, height: 120)
            
            // Status text
            Text(generationStatusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
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
            // Success icon with celebration
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.6), lineWidth: 3)
                    )
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.green)
                    .symbolEffect(.bounce, value: showContent)
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
    }
    
    // MARK: - Error Animation
    
    private var errorAnimationView: some View {
        VStack(spacing: 20) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(Color.orange.opacity(0.6), lineWidth: 3)
                    )
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            // Error message
            Text("Using a sample message instead")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Generated Content Section
    
    private func generatedContentSection(_ content: GeneratedContent) -> some View {
        VStack(spacing: 20) {
            // Content preview card
            VStack(spacing: 16) {
                // Content text
                ScrollView {
                    Text(content.textContent)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 16)
                }
                .frame(maxHeight: 120)
                
                // Audio playback controls
                audioPlaybackControls(for: content)
                    .opacity(showPlaybackControls ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(0.5), value: showPlaybackControls)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Magic moment message
            VStack(spacing: 8) {
                Text("✨ This is just a preview")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("Every morning, you'll get a fresh, personalized message based on your goals")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 16)
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
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: onboardingViewModel.isAudioPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .offset(x: onboardingViewModel.isAudioPlaying ? 0 : 2)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .scaleEffect(onboardingViewModel.isAudioPlaying ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: onboardingViewModel.isAudioPlaying)
            
            // Audio visualization
            if onboardingViewModel.isAudioPlaying {
                AudioVisualizationView(isPlaying: onboardingViewModel.isAudioPlaying)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tap to hear your message")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Delivered by \(onboardingState.selectedVoice?.name ?? "your chosen voice")")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 16) {
            Text("Don't worry - here's a sample!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            // Retry button (if needed)
            Button(action: {
                retryDemoGeneration()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("Try Again")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.2))
                )
            }
        }
    }
    
    // MARK: - Demo Generation Logic
    
    private func startDemoGeneration() {
        startAnimations()
        
        // Initialize demo service
        demoService = OnboardingDemoService()
        
        // Start generation immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            generateDemoContent()
        }
    }
    
    private func generateDemoContent() {
        guard let motivation = onboardingState.selectedMotivation,
              let voice = onboardingState.selectedVoice else {
            onboardingState.demoError = "Missing required selection data"
            return
        }
        
        onboardingState.isGeneratingDemo = true
        onboardingState.demoError = nil
        onboardingState.generatedDemoContent = nil
        
        Task {
            do {
                let content = try await demoService?.generateDemoContent(
                    motivation: motivation,
                    tone: onboardingState.computedTone,
                    voicePersona: voice
                )
                
                await MainActor.run {
                    onboardingState.isGeneratingDemo = false
                    onboardingState.generatedDemoContent = content
                    
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showContent = true
                    }
                    
                    withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                        showPlaybackControls = true
                    }
                    
                    // Auto-advance after a moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        onboardingState.proceedToNext()
                    }
                }
                
            } catch {
                await MainActor.run {
                    onboardingState.isGeneratingDemo = false
                    onboardingState.demoError = error.localizedDescription
                    
                    // Still show demo content if we have fallback
                    if let fallbackContent = demoService?.getFallbackContent(
                        motivation: motivation,
                        tone: onboardingState.computedTone
                    ) {
                        onboardingState.generatedDemoContent = fallbackContent
                    }
                    
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showContent = true
                    }
                    
                    // Auto-advance after showing error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        onboardingState.proceedToNext()
                    }
                }
            }
        }
    }
    
    private func retryDemoGeneration() {
        // Reset state and try again
        onboardingState.demoError = nil
        onboardingState.generatedDemoContent = nil
        showContent = false
        showPlaybackControls = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            generateDemoContent()
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateElements = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            showGenerationAnimation = true
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

// MARK: - Neural Network Animation

struct NeuralNetworkAnimation: View {
    let isAnimating: Bool
    @State private var pulse = false
    @State private var rotate = false
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .frame(width: 120, height: 120)
            
            // Middle ring
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(
                    isAnimating ? .linear(duration: 4).repeatForever(autoreverses: false) : .default,
                    value: rotate
                )
            
            // Inner nodes
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 8, height: 8)
                    .offset(x: 30)
                    .rotationEffect(.degrees(Double(index) * 60 + (rotate ? 360 : 0)))
                    .scaleEffect(pulse ? 1.5 : 1.0)
                    .animation(
                        isAnimating ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(index) * 0.1) : .default,
                        value: pulse
                    )
            }
            
            // Center brain icon
            Image(systemName: "brain")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .animation(
                    isAnimating ? .easeInOut(duration: 2).repeatForever(autoreverses: true) : .default,
                    value: pulse
                )
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                pulse = true
                rotate = true
            } else {
                pulse = false
                rotate = false
            }
        }
    }
}

// MARK: - Audio Visualization

struct AudioVisualizationView: View {
    let isPlaying: Bool
    @State private var animateBars = false
    
    private let barCount = 8
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 3)
                    .frame(height: barHeight(for: index))
                    .animation(
                        isPlaying ?
                        .easeInOut(duration: 0.4 + Double(index) * 0.1)
                        .repeatForever(autoreverses: true) :
                        .easeOut(duration: 0.3),
                        value: animateBars
                    )
            }
        }
        .onChange(of: isPlaying) { newValue in
            animateBars = newValue
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 24
        
        if isPlaying && animateBars {
            return CGFloat.random(in: baseHeight...maxHeight)
        } else {
            return baseHeight
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
        .background(
            LinearGradient(
                colors: [.purple.opacity(0.8), .indigo.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .preferredColorScheme(.dark)
    }
}
#endif
