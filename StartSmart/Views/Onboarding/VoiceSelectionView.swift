//
//  VoiceSelectionView.swift
//  StartSmart
//
//  Onboarding Step 4: Voice Selection
//  Updated to match PremiumLandingPageV2 theme
//

import SwiftUI
import AVFoundation

/// Voice persona selection with audio previews and premium design
struct VoiceSelectionView: View {
    @ObservedObject var onboardingState: OnboardingState
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    let onVoiceSelected: ((VoicePersona) -> Void)?
    @State private var animateElements = false
    @State private var showVoices = false
    @State private var showPaywall = false
    @State private var showUpgradePrompt = false
    @State private var selectedPremiumVoice: VoicePersona?
    @State private var isPremium = false
    @State private var playingVoiceId: String?
    
    init(onboardingState: OnboardingState, onboardingViewModel: OnboardingViewModel, onVoiceSelected: ((VoicePersona) -> Void)? = nil) {
        self.onboardingState = onboardingState
        self.onboardingViewModel = onboardingViewModel
        self.onVoiceSelected = onVoiceSelected
    }
    
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
                        
                        // Voice selection list
                        voiceSelectionList
                            .opacity(showVoices ? 1 : 0)
                            .offset(y: showVoices ? 0 : 30)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, DesignSystem.spacing4)
                    .padding(.bottom, 20)
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .onAppear {
            startAnimations()
            checkPremiumStatus()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .overlay {
            if showUpgradePrompt, let voice = selectedPremiumVoice {
                upgradePromptOverlay(for: voice)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.spacing3) {
            // Voice icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.purple)
            }
            
            VStack(spacing: 12) {
                Text("Choose your\nmorning guide")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .tracking(-0.5)
                
                Text("Each voice has its own personality. Tap to hear a preview.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.top, 60)
    }
    
    // MARK: - Voice Selection List
    
    private var voiceSelectionList: some View {
        VStack(spacing: 16) {
            ForEach(Array(VoicePersona.allPersonas.enumerated()), id: \.element.id) { index, voice in
                PremiumVoicePersonaCard(
                    voice: voice,
                    isSelected: onboardingState.selectedVoice?.id == voice.id,
                    isLocked: voice.isPremium && !isPremium,
                    playingVoiceId: $playingVoiceId,
                    onTap: {
                        handleVoiceSelection(voice)
                    }
                )
                .animation(
                    .easeOut(duration: 0.6).delay(Double(index) * 0.15),
                    value: showVoices
                )
            }
        }
    }
    
    // MARK: - Upgrade Prompt Overlay
    
    private func upgradePromptOverlay(for voice: VoicePersona) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showUpgradePrompt = false
                    selectedPremiumVoice = nil
                }
            
            UpgradePromptView(
                title: "Premium Voice",
                message: "\(voice.name) is a premium voice. Upgrade to unlock all voice styles and unlimited AI alarms!",
                featureIcon: "waveform",
                onUpgrade: {
                    showUpgradePrompt = false
                    selectedPremiumVoice = nil
                    showPaywall = true
                },
                onDismiss: {
                    showUpgradePrompt = false
                    selectedPremiumVoice = nil
                }
            )
            .padding(20)
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
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // All voices are now available - no premium check needed
        // Call the callback if provided
        onVoiceSelected?(voice)
        
        // Also update the onboarding state for backward compatibility
        onboardingState.selectVoice(voice)
    }
    
    private func checkPremiumStatus() {
        // Check if user is premium
        // During onboarding, user hasn't created account yet, so default to false
        // Premium status will be checked after account creation
        isPremium = false
    }
}

// MARK: - Premium Voice Persona Card

struct PremiumVoicePersonaCard: View {
    let voice: VoicePersona
    let isSelected: Bool
    let isLocked: Bool
    @Binding var playingVoiceId: String?
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var showContent = false
    @State private var playButtonScale: CGFloat = 1.0
    @State private var audioPlayer: AVAudioPlayer?
    
    private var isThisCardPlaying: Bool {
        playingVoiceId == voice.id
    }
    
    private var voiceColor: Color {
        switch voice.tone {
        case .gentle:
            return DesignSystem.green
        case .energetic:
            return Color(red: 1.0, green: 0.72, blue: 0.0) // Gold/yellow
        case .toughLove:
            return Color(red: 0.94, green: 0.27, blue: 0.27) // Red
        case .storyteller:
            return DesignSystem.purple
        }
    }
    
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
                                    isSelected ? voiceColor : voiceColor.opacity(0.4),
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
                        stopAudio()
                    } else {
                        playSampleAudio()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: isThisCardPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.black)
                            .offset(x: isThisCardPlaying ? 0 : 1)
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
            }
            
            // Voice information
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(voice.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(voice.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Sample text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("\"\(voice.sampleText)\"")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .italic()
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                VStack {
                    ZStack {
                        Circle()
                            .fill(voiceColor)
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
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
            ZStack {
                Color.white.opacity(isSelected ? 0.06 : 0.04)
                if isSelected {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            voiceColor.opacity(0.1),
                            voiceColor.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelected ? voiceColor.opacity(0.5) : Color.white.opacity(0.08),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .cornerRadius(20)
        .shadow(
            color: isSelected ? voiceColor.opacity(0.3) : Color.black.opacity(0.1),
            radius: isSelected ? 8 : 4,
            x: 0,
            y: isSelected ? 4 : 2
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
        
        // Update playingVoiceId to mark this card as playing
        playingVoiceId = voice.id
        
        // Generate audio using ElevenLabs API
        Task {
            do {
                // Get ElevenLabs service from dependency container
                guard let elevenLabsService: ElevenLabsServiceProtocol = await DependencyContainer.shared.resolveSafe() else {
                    print("❌ ElevenLabs service not available")
                    playingVoiceId = nil
                    return
                }
                
                // Generate speech using the voice ID from VoicePersona
                let audioData = try await elevenLabsService.generateSpeech(
                    text: voice.sampleText,
                    voiceId: voice.voiceId
                )
                
                // Save audio data to temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("voice_preview_\(voice.id).mp3")
                try audioData.write(to: tempURL)
                
                // Play the audio
                await MainActor.run {
                    self.playAudioFile(at: tempURL)
                }
            } catch {
                print("❌ Failed to generate voice preview: \(error.localizedDescription)")
                playingVoiceId = nil
            }
        }
    }
    
    private func playAudioFile(at url: URL) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = nil
            audioPlayer?.play()
            
            // Estimate duration based on typical speech rate and text length
            // Average speech is about 150 words per minute = 2.5 words per second
            let wordCount = voice.sampleText.split(separator: " ").count
            let estimatedDuration = Double(wordCount) / 2.5
            
            // Schedule the playingVoiceId reset
            DispatchQueue.main.asyncAfter(deadline: .now() + estimatedDuration + 0.5) {
                if self.playingVoiceId == self.voice.id {
                    self.playingVoiceId = nil
                }
            }
        } catch {
            print("❌ Failed to play audio: \(error.localizedDescription)")
            playingVoiceId = nil
        }
    }
    
    private func stopAudio() {
        // Stop any currently playing audio
        audioPlayer?.stop()
        playingVoiceId = nil
        audioPlayer = nil
    }
}

// MARK: - Preview

#if DEBUG
struct VoiceSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceSelectionView(
            onboardingState: OnboardingState(),
            onboardingViewModel: OnboardingViewModel()
        )
        .preferredColorScheme(.dark)
    }
}
#endif
