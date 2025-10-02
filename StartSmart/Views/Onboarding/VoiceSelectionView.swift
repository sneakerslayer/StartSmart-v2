//
//  VoiceSelectionView.swift
//  StartSmart
//
//  Voice Selection with Audio Previews
//  ElevenLabs integration for voice persona selection
//

import SwiftUI
import AVFoundation

/// Voice persona selection with audio previews
struct VoiceSelectionView: View {
    @ObservedObject var onboardingState: OnboardingState
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    let onVoiceSelected: ((VoicePersona) -> Void)?
    @State private var animateElements = false
    @State private var showVoices = false
    
    init(onboardingState: OnboardingState, onboardingViewModel: OnboardingViewModel, onVoiceSelected: ((VoicePersona) -> Void)? = nil) {
        self.onboardingState = onboardingState
        self.onboardingViewModel = onboardingViewModel
        self.onVoiceSelected = onVoiceSelected
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) { // Reduced spacing from 32 to 24
                    // Header section
                    headerSection
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : -20)
                    
                    // Voice selection list
                    voiceSelectionList
                        .opacity(showVoices ? 1 : 0)
                        .offset(y: showVoices ? 0 : 30)
                    
                    Spacer(minLength: 20) // Reduced to minimize dead space
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20) // Reduced bottom padding to minimize dead space
                .frame(minHeight: geometry.size.height) // Ensure content takes at least full screen height
            }
            .scrollContentBackground(.hidden) // Hide default background for better bounce effect
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) { // Standardized spacing
            // Voice icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50) // Standardized size
                
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 24, weight: .medium)) // Standardized size
                    .foregroundColor(.white)
            }
            
            // Main question
            Text("Choose your morning guide")
                .font(.system(size: 28, weight: .bold, design: .rounded)) // Standardized size
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .tracking(-1) // Standardized tracking
            
            // Subtitle
            Text("Each voice has its own personality. Tap to hear a preview.")
                .font(.system(size: 14, weight: .medium)) // Standardized size
                .foregroundColor(.white.opacity(0.85)) // Standardized opacity
                .multilineTextAlignment(.center)
                .lineSpacing(2) // Standardized line spacing
                .padding(.horizontal, 10) // Standardized padding
        }
        .padding(.top, 10) // Standardized top padding
    }
    
    // MARK: - Voice Selection List
    
    private var voiceSelectionList: some View {
        VStack(spacing: 16) {
            ForEach(Array(VoicePersona.allPersonas.enumerated()), id: \.element.id) { index, voice in
                VoicePersonaCard(
                    voice: voice,
                    isSelected: onboardingState.selectedVoice?.id == voice.id,
                    isPlaying: onboardingViewModel.isAudioPlaying,
                    onTap: {
                        handleVoiceSelection(voice)
                    },
                    onPlayPreview: {
                        playVoicePreview(voice)
                    }
                )
                .animation(
                    .easeOut(duration: 0.6).delay(Double(index) * 0.15),
                    value: showVoices
                )
            }
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateElements = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            showVoices = true
        }
    }
    
    // MARK: - Voice Handlers
    
    private func handleVoiceSelection(_ voice: VoicePersona) {
        print("🎯 handleVoiceSelection called with: \(voice.name)")
        
        // Call the callback if provided
        onVoiceSelected?(voice)
        
        // Also update the onboarding state for backward compatibility
        onboardingState.selectVoice(voice)
    }
    
    private func playVoicePreview(_ voice: VoicePersona) {
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Play the voice preview
        onboardingViewModel.playVoicePreview(for: voice)
    }
}

// MARK: - Voice Persona Card

struct VoicePersonaCard: View {
    let voice: VoicePersona
    let isSelected: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    let onPlayPreview: () -> Void
    
    @State private var isPressed = false
    @State private var showContent = false
    @State private var playButtonScale: CGFloat = 1.0
    @State private var isThisCardPlaying = false
    @State private var synthesizer: AVSpeechSynthesizer?
    
    var body: some View {
        HStack(spacing: 16) {
            // Voice avatar/icon
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(voiceColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected ? voiceColor.opacity(0.8) : voiceColor.opacity(0.4),
                                    lineWidth: isSelected ? 3 : 2
                                )
                        )
                    
                    Image(systemName: voice.tone.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(voiceColor)
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
                
                // Play button
                Button(action: {
                    if isThisCardPlaying {
                        // Stop playback
                        stopAudio()
                    } else {
                        // Start playback
                        playSampleAudio()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: isThisCardPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .offset(x: isThisCardPlaying ? 0 : 1) // Offset play icon slightly for better visual balance
                    }
                    .scaleEffect(playButtonScale)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .onLongPressGesture(
                    minimumDuration: 0,
                    maximumDistance: .infinity,
                    pressing: { pressing in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            playButtonScale = pressing ? 0.9 : 1.0
                        }
                    },
                    perform: {}
                )
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
            }
            
            // Voice information
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(voice.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Sample text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\"\(voice.sampleText)\"")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .italic()
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(x: showContent ? 0 : 20)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                VStack {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .scaleEffect(isSelected ? 1.0 : 0.5)
                    .opacity(isSelected ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    isSelected ?
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isSelected ?
                            Color.white.opacity(0.5) :
                            Color.white.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: isSelected ?
                    voiceColor.opacity(0.3) :
                    Color.black.opacity(0.1),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Audio Playback Functions
    
    private func playSampleAudio() {
        // Stop any currently playing audio
        stopAudio()
        
        // Use text-to-speech to play the sample text
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: voice.sampleText)
        
        // Configure voice based on the persona
        switch voice.tone {
        case .gentle:
            utterance.rate = 0.4
            utterance.pitchMultiplier = 1.1
        case .energetic:
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.2
        case .toughLove:
            utterance.rate = 0.6
            utterance.pitchMultiplier = 0.9
        case .storyteller:
            utterance.rate = 0.4
            utterance.pitchMultiplier = 1.0
        }
        
        utterance.volume = 0.8
        
        // Start playing
        isThisCardPlaying = true
        synthesizer.speak(utterance)
        
        // Store synthesizer to prevent deallocation
        self.synthesizer = synthesizer
        
        // Simulate completion after a reasonable duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.isThisCardPlaying = false
        }
    }
    
    private func stopAudio() {
        // Stop any currently playing audio
        synthesizer?.stopSpeaking(at: .immediate)
        isThisCardPlaying = false
        synthesizer = nil
    }
    
    private var voiceColor: Color {
        switch voice.tone {
        case .gentle: return .mint
        case .energetic: return .orange
        case .toughLove: return .red
        case .storyteller: return .purple
        }
    }
}

// MARK: - Audio Waveform Animation

struct AudioWaveformView: View {
    let isPlaying: Bool
    @State private var animateBars = false
    
    private let barCount = 5
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 2)
                    .frame(height: barHeight(for: index))
                    .animation(
                        isPlaying ?
                        .easeInOut(duration: 0.5 + Double(index) * 0.1)
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
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 16
        
        if isPlaying && animateBars {
            return CGFloat.random(in: baseHeight...maxHeight)
        } else {
            return baseHeight
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VoiceSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VoiceSelectionView(
                onboardingState: OnboardingState(),
                onboardingViewModel: OnboardingViewModel()
            )
            .background(
                LinearGradient(
                    colors: [.green.opacity(0.7), .teal.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .preferredColorScheme(.dark)
            
            // Single card preview
            VoicePersonaCard(
                voice: VoicePersona.allPersonas[0],
                isSelected: false,
                isPlaying: false,
                onTap: { print("Voice selected") },
                onPlayPreview: { print("Preview played") }
            )
            .padding()
            .background(Color.black)
        }
    }
}
#endif
