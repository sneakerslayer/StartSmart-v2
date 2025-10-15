import SwiftUI
import AVFoundation
import Combine

// MARK: - Alarm Phase
enum AlarmPhase {
    case traditionalAlarm      // Phase 1: Traditional alarm sound
    case aiScriptPlayback     // Phase 2: AI-generated content
    case dismissed            // User dismissed
}

// MARK: - Alarm View
struct AlarmView: View {
    let alarm: Alarm
    @StateObject private var viewModel: AlarmViewModel
    @StateObject private var speechService: SpeechRecognitionService
    @StateObject private var audioPlaybackService: AudioPlaybackService
    
    @Environment(\.presentationMode) var presentationMode
    @State private var currentTime = Date()
    @State private var isListeningForSpeech = false
    @State private var showingSnoozeOptions = false
    @State private var audioWaveformData: [Float] = Array(repeating: 0.0, count: 50)
    @State private var waveformTimer: Timer?
    @State private var dismissalAttempts = 0
    @State private var showingVoiceInstructions = false
    
    // Two-phase alarm flow
    @State private var alarmPhase: AlarmPhase = .traditionalAlarm
    @State private var traditionalAlarmTimer: Timer?
    @State private var traditionalAlarmPlayer: AVAudioPlayer?
    
    // Animation states
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    @State private var waveformOffset: CGFloat = 0
    
    private let maxDismissalAttempts = 3
    
    // MARK: - Initialization
    init(alarm: Alarm) {
        self.alarm = alarm
        self._viewModel = StateObject(wrappedValue: AlarmViewModel())
        self._speechService = StateObject(wrappedValue: SpeechRecognitionService())
        self._audioPlaybackService = StateObject(wrappedValue: AudioPlaybackService())
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                backgroundGradient
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Time display
                    timeDisplaySection
                    
                    // Alarm label
                    alarmLabelSection
                    
                    // Waveform visualization
                    waveformSection
                        .frame(height: 120)
                    
                    // Speech recognition status
                    speechStatusSection
                    
                    Spacer()
                    
                    // Action buttons
                    actionButtonsSection
                    
                    Spacer()
                }
                .padding(.horizontal, 30)
                
                // Voice instructions overlay
                if showingVoiceInstructions {
                    voiceInstructionsOverlay
                }
            }
        }
        .onAppear {
            setupAlarmExperience()
        }
        .onDisappear {
            cleanupAlarmExperience()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Date()
        }
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        let colors = toneBasedGradientColors()
        
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            // Subtle animated pattern
            Circle()
                .fill(Color.white.opacity(glowOpacity * 0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .scaleEffect(pulseScale)
                .animation(
                    Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: pulseScale
                )
        )
    }
    
    // MARK: - Time Display Section
    private var timeDisplaySection: some View {
        VStack(spacing: 8) {
            Text(timeFormatter.string(from: currentTime))
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text(dateFormatter.string(from: currentTime))
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Alarm Label Section
    private var alarmLabelSection: some View {
        VStack(spacing: 12) {
            Text(alarm.label.isEmpty ? "Wake Up!" : alarm.label)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            if alarm.generatedContent != nil {
                Text("AI-Generated Motivation")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
            }
        }
    }
    
    // MARK: - Waveform Section
    private var waveformSection: some View {
        HStack(spacing: 3) {
            ForEach(0..<audioWaveformData.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 4, height: CGFloat(audioWaveformData[index]) * 80 + 10)
                    .animation(
                        Animation.easeInOut(duration: 0.3)
                            .delay(Double(index) * 0.02),
                        value: audioWaveformData[index]
                    )
            }
        }
        .offset(x: waveformOffset)
        .animation(
            Animation.linear(duration: 2.0).repeatForever(autoreverses: false),
            value: waveformOffset
        )
    }
    
    // MARK: - Speech Status Section
    private var speechStatusSection: some View {
        VStack(spacing: 16) {
            if isListeningForSpeech {
                HStack(spacing: 12) {
                    Image(systemName: "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .scaleEffect(pulseScale)
                    
                    Text("Say \"I'm awake\" to dismiss")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                )
            } else if dismissalAttempts > 0 {
                Text("Tap the microphone to try again")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            if !speechService.recognizedText.isEmpty {
                Text("\"\\(speechService.recognizedText)\"")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .italic()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                    )
            }
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 20) {
            // Voice dismiss button
            Button(action: handleVoiceDismiss) {
                HStack(spacing: 12) {
                    Image(systemName: isListeningForSpeech ? "mic.fill" : "mic")
                        .font(.title2)
                    
                    Text(isListeningForSpeech ? "Listening..." : "Voice Dismiss")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
            }
            .disabled(isListeningForSpeech)
            .scaleEffect(isListeningForSpeech ? 1.05 : 1.0)
            
            HStack(spacing: 20) {
                // Snooze button
                if alarm.canSnooze {
                    Button(action: handleSnooze) {
                        VStack(spacing: 6) {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.title2)
                            Text("Snooze")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }
                }
                
                // Stop button
                Button(action: handleStop) {
                    VStack(spacing: 6) {
                        Image(systemName: "stop.circle")
                            .font(.title2)
                        Text("Stop")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.red.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
    
    // MARK: - Voice Instructions Overlay
    private var voiceInstructionsOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 24) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Voice Commands")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(speechService.getDismissKeywords().prefix(6), id: \.self) { keyword in
                        HStack {
                            Image(systemName: "quote.bubble")
                                .foregroundColor(.blue.opacity(0.8))
                            Text("\"\\(keyword)\"")
                                .foregroundColor(.white)
                                .font(.body)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Button("Got it") {
                    showingVoiceInstructions = false
                }
                .foregroundColor(.black)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Private Methods
    private func setupAlarmExperience() {
        print("DEBUG: 🚀 ========== ALARM VIEW SETUP STARTED ==========")
        print("DEBUG: 📋 Alarm ID: \(alarm.id.uuidString)")
        print("DEBUG: 📋 Alarm Label: \(alarm.label)")
        print("DEBUG: 🔧 useTraditionalSound: \(alarm.useTraditionalSound)")
        print("DEBUG: 🔧 traditionalSound: \(alarm.traditionalSound.displayName)")
        print("DEBUG: 🔧 useAIScript: \(alarm.useAIScript)")
        print("DEBUG: 🔧 hasCustomAudio: \(alarm.hasCustomAudio)")
        print("DEBUG: 🔧 audioFileURL: \(alarm.audioFileURL?.path ?? "nil")")
        
        // IMPORTANT: iOS Notification Limitations
        print("DEBUG: ⚠️ iOS LIMITATION: Third-party apps cannot reliably play alarm sounds from lock screen")
        print("DEBUG: 💡 SOLUTION: Play traditional alarm sound FIRST in foreground, then AI script")
        
        // FIXED APPROACH: Always play traditional alarm first in foreground (reliable)
        // iOS notifications cannot reliably play loud alarm sounds
        // Play traditional alarm in app, then transition to AI script
        if alarm.useTraditionalSound {
            print("DEBUG: 🔊 Starting TRADITIONAL ALARM PHASE (foreground audio - reliable)")
            alarmPhase = .traditionalAlarm
            startTraditionalAlarmPhase()
            
            // Set up transition to AI script after user interaction
            if alarm.useAIScript {
                print("DEBUG: ⏳ Traditional sound playing, AI script will start after user interaction")
            }
        } else if alarm.useAIScript, let audioURL = alarm.audioFileURL {
            print("DEBUG: ✅ No traditional sound, going directly to AI Script")
            print("DEBUG: 📁 Audio file path: \(audioURL.path)")
            print("DEBUG: 📂 File exists: \(FileManager.default.fileExists(atPath: audioURL.path))")
            alarmPhase = .aiScriptPlayback
            startAIScriptPhase(audioURL: audioURL)
        } else {
            print("DEBUG: ⚠️ No alarm sound configured - showing dismissed state")
            alarmPhase = .dismissed
        }
        
        // Setup animations
        pulseScale = 1.1
        glowOpacity = 0.8
        waveformOffset = -200
        
        // Start waveform animation
        startWaveformAnimation()
        
        // Request speech permissions if needed
        if speechService.permissionStatus != .authorized {
            Task {
                await speechService.requestPermissions()
            }
        }
        
        print("DEBUG: 🏁 ========== ALARM VIEW SETUP COMPLETE ==========")
    }
    
    private func startTraditionalAlarmPhase() {
        // Configure audio session for alarm playback
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set category to playback with options to allow mixing and override silent mode
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true, options: [])
            print("DEBUG: ✅ Audio session activated successfully")
        } catch {
            print("DEBUG: ❌ Failed to activate audio session: \(error)")
        }
        
        // Load and play the traditional alarm sound with looping
        let fileName = alarm.traditionalSound.soundFileName.replacingOccurrences(of: ".caf", with: "")
        guard let soundURL = Bundle.main.url(forResource: fileName, withExtension: "caf") else {
            print("DEBUG: ❌ Could not find traditional alarm sound file: \(alarm.traditionalSound.soundFileName)")
            print("DEBUG: 🔍 Searched for: \(fileName).caf")
            print("DEBUG: 🔍 In bundle: \(Bundle.main.bundlePath)")
            return
        }
        
        print("DEBUG: 📁 Loading traditional alarm sound: \(fileName).caf from \(soundURL.path)")
        print("DEBUG: 🔧 Alarm settings - useTraditionalSound: \(alarm.useTraditionalSound), sound: \(alarm.traditionalSound.displayName)")
        
        do {
            traditionalAlarmPlayer = try AVAudioPlayer(contentsOf: soundURL)
            traditionalAlarmPlayer?.numberOfLoops = -1 // Loop indefinitely
            traditionalAlarmPlayer?.volume = 1.0 // Full volume for alarm
            
            // Prepare to play (preloads audio buffer)
            traditionalAlarmPlayer?.prepareToPlay()
            
            // Play the alarm
            let didPlay = traditionalAlarmPlayer?.play() ?? false
            
            print("DEBUG: 🔊 Traditional alarm playback started: \(didPlay)")
            print("DEBUG: 📊 Player state - isPlaying: \(traditionalAlarmPlayer?.isPlaying ?? false), volume: \(traditionalAlarmPlayer?.volume ?? 0), loops: \(traditionalAlarmPlayer?.numberOfLoops ?? 0)")
        } catch {
            print("DEBUG: ❌ Error creating/playing traditional alarm sound: \(error)")
        }
    }
    
    private func startAIScriptPhase(audioURL: URL) {
        // Stop traditional alarm player
        traditionalAlarmPlayer?.stop()
        traditionalAlarmPlayer = nil
        
        // Stop traditional alarm timer
        traditionalAlarmTimer?.invalidate()
        traditionalAlarmTimer = nil
        
        print("DEBUG: 🎬 ========== STARTING AI SCRIPT PHASE ==========")
        print("DEBUG: 📁 Audio URL: \(audioURL.path)")
        print("DEBUG: 📂 File exists: \(FileManager.default.fileExists(atPath: audioURL.path))")
        
        if FileManager.default.fileExists(atPath: audioURL.path) {
            // Get file size for debugging
            if let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
               let fileSize = attributes[.size] as? UInt64 {
                print("DEBUG: 📊 File size: \(fileSize) bytes")
            }
            
            print("DEBUG: ✅ Audio file found, starting playback...")
            
            // Configure audio session for ALARM playback (bypasses silent mode)
            print("DEBUG: 🔊 Configuring audio session for alarm playback...")
            audioPlaybackService.configureForAlarm()
            
            // Start AI script playback
            Task {
                do {
                    print("DEBUG: 🎵 Calling audioPlaybackService.play()...")
                    try await audioPlaybackService.play(from: audioURL)
                    print("DEBUG: ✅ Audio playback started successfully")
                    print("DEBUG: 🔊 Audio state: \(audioPlaybackService.isPlaying ? "PLAYING" : "NOT PLAYING")")
                    print("DEBUG: 🔊 Volume: \(audioPlaybackService.volume)")
                } catch {
                    print("DEBUG: ❌ Error playing audio: \(error)")
                }
            }
        } else {
            print("DEBUG: ❌ ERROR: Audio file does NOT exist at path!")
            print("DEBUG: ⚠️ Cannot play AI script - file missing")
        }
    }
    
    private func userInteracted() {
        // User tapped or interacted with the alarm
        // If we're in traditional alarm phase and have AI script, transition to AI script
        // But if we're already in AI script phase, just dismiss
        if alarmPhase == .traditionalAlarm && alarm.useAIScript {
            // Transition to AI script phase
            if let audioURL = alarm.audioFileURL {
                alarmPhase = .aiScriptPlayback
                startAIScriptPhase(audioURL: audioURL)
            } else {
                alarmPhase = .dismissed
            }
        } else {
            // Already in AI script phase or no AI script - just dismiss
            alarmPhase = .dismissed
        }
    }
    
    private func cleanupAlarmExperience() {
        audioPlaybackService.stop()
        speechService.stopListening()
        waveformTimer?.invalidate()
        waveformTimer = nil
        traditionalAlarmTimer?.invalidate()
        traditionalAlarmTimer = nil
        traditionalAlarmPlayer?.stop()
        traditionalAlarmPlayer = nil
    }
    
    private func startWaveformAnimation() {
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Generate realistic audio waveform data
            audioWaveformData = (0..<audioWaveformData.count).map { index in
                let baseAmplitude = Float.random(in: 0.2...0.8)
                let frequencyComponent = sin(Double(index) * 0.5 + Date().timeIntervalSince1970) * 0.3
                return baseAmplitude + Float(frequencyComponent)
            }
        }
    }
    
    private func handleVoiceDismiss() {
        guard speechService.permissionStatus == .authorized else {
            showingVoiceInstructions = true
            return
        }
        
        dismissalAttempts += 1
        isListeningForSpeech = true
        
        Task {
            let success = await speechService.startAlarmDismissListening()
            
            await MainActor.run {
                isListeningForSpeech = false
                
                if success {
                    handleSuccessfulDismiss()
                } else if dismissalAttempts >= maxDismissalAttempts {
                    // After max attempts, show instructions
                    showingVoiceInstructions = true
                }
            }
        }
    }
    
    private func handleSnooze() {
        userInteracted()
        viewModel.snoozeAlarm(alarm.id)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func handleStop() {
        userInteracted()
        viewModel.dismissAlarm(alarm.id, method: .button)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func handleSuccessfulDismiss() {
        userInteracted()
        // Add a brief success animation/feedback
        pulseScale = 1.2
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.dismissAlarm(alarm.id, method: .voice)
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func toneBasedGradientColors() -> [Color] {
        switch alarm.tone {
        case .gentle:
            return [
                Color(red: 0.8, green: 0.6, blue: 0.9),  // Soft purple
                Color(red: 0.6, green: 0.8, blue: 0.9),  // Soft blue
                Color(red: 0.9, green: 0.8, blue: 0.6)   // Soft yellow
            ]
        case .energetic:
            return [
                Color(red: 1.0, green: 0.4, blue: 0.4),  // Bright red
                Color(red: 1.0, green: 0.6, blue: 0.0),  // Orange
                Color(red: 1.0, green: 0.8, blue: 0.0)   // Yellow
            ]
        case .toughLove:
            return [
                Color(red: 0.2, green: 0.2, blue: 0.2),  // Dark gray
                Color(red: 0.4, green: 0.0, blue: 0.0),  // Dark red
                Color(red: 0.0, green: 0.0, blue: 0.4)   // Dark blue
            ]
        case .storyteller:
            return [
                Color(red: 0.4, green: 0.2, blue: 0.6),  // Purple
                Color(red: 0.0, green: 0.4, blue: 0.6),  // Teal
                Color(red: 0.2, green: 0.6, blue: 0.4)   // Green
            ]
        }
    }
    
    // MARK: - Formatters
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
}

// MARK: - Preview
struct AlarmView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Gentle tone
            AlarmView(alarm: Alarm(
                time: Date(),
                label: "Good morning workout",
                tone: .gentle
            ))
            .previewDisplayName("Gentle Tone")
            
            // Energetic tone
            AlarmView(alarm: Alarm(
                time: Date(),
                label: "Time to conquer the day!",
                tone: .energetic
            ))
            .previewDisplayName("Energetic Tone")
            
            // Tough love tone
            AlarmView(alarm: Alarm(
                time: Date(),
                label: "Get up now!",
                tone: .toughLove
            ))
            .previewDisplayName("Tough Love Tone")
        }
    }
}
