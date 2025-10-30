import SwiftUI
import AVFoundation
import Combine
import os.log

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
    @State private var audioPlaybackError: String?
    @State private var isAttemptingAudioLoad = false
    
    // Two-phase alarm flow
    @State private var alarmPhase: AlarmPhase = .traditionalAlarm
    @State private var traditionalAlarmTimer: Timer?
    @State private var traditionalAlarmPlayer: AVAudioPlayer?
    
    // Animation states
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    @State private var waveformOffset: CGFloat = 0
    
    private let maxDismissalAttempts = 3
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "AlarmView")
    private let maxAudioLoadRetries = 3
    private let audioLoadRetryDelay: TimeInterval = 1.0
    
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
            if let error = audioPlaybackError {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio Error")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.3))
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                        )
                )
            } else if isAttemptingAudioLoad {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading audio...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )
            } else if isListeningForSpeech {
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
        logger.info("🎬 ========== SETUP ALARM EXPERIENCE STARTED ==========")
        logger.info("📋 Alarm ID: \(self.alarm.id.uuidString)")
        logger.info("🏷️ Alarm Label: \(self.alarm.label)")
        logger.info("🔊 Has Custom Audio: \(self.alarm.hasCustomAudio)")
        logger.info("📁 Generated Content: \(self.alarm.generatedContent != nil ? "YES" : "NO")")
        
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
        
        // IMPORTANT: iOS Notification Limitations
        // FIXED APPROACH: Always play AI script directly (reliable)
        // iOS notifications cannot reliably play loud alarm sounds
        // Play AI script in app for better user experience
        
        // Check for audio file URL with detailed logging
        logger.info("🔍 Checking for audio file URL...")
        
        if let audioURL = alarm.audioFileURL {
            logger.info("✅ Audio file URL found: \(audioURL.path)")
            logger.info("📂 File path exists check: \(FileManager.default.fileExists(atPath: audioURL.path))")
            
            // Verify file exists before attempting playback
            if FileManager.default.fileExists(atPath: audioURL.path) {
                logger.info("✅ File exists at path, starting AI script playback")
                alarmPhase = .aiScriptPlayback
                startAIScriptPhase(audioURL: audioURL, retryCount: 0)
            } else {
                logger.error("❌ Audio file does not exist at path: \(audioURL.path)")
                logger.info("🔄 Attempting fallback lookup...")
                
                // Try fallback lookup
                Task {
                    await attemptFallbackAudioLookup(for: alarm, originalURL: audioURL)
                }
            }
        } else {
            logger.warning("⚠️ No audio file URL found for alarm")
            logger.info("📋 Alarm details:")
            logger.info("   - Custom Audio Path: \(self.alarm.customAudioPath ?? "nil")")
            if let generated = self.alarm.generatedContent {
                logger.info("   - Generated Content Audio Path: \(generated.audioFilePath)")
            } else {
                logger.info("   - Generated Content: nil")
            }
            alarmPhase = .dismissed
        }
        
        logger.info("🎬 ========== SETUP ALARM EXPERIENCE COMPLETED ==========")
    }
    
    
    private func startAIScriptPhase(audioURL: URL, retryCount: Int = 0) {
        logger.info("🎵 ========== START AI SCRIPT PHASE ==========")
        logger.info("📁 Audio URL: \(audioURL.path)")
        logger.info("🔄 Retry Count: \(retryCount)")
        
        // Stop traditional alarm player
        traditionalAlarmPlayer?.stop()
        traditionalAlarmPlayer = nil
        
        // Stop traditional alarm timer
        traditionalAlarmTimer?.invalidate()
        traditionalAlarmTimer = nil
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            logger.error("❌ Audio file does not exist at path: \(audioURL.path)")
            
            // Track error
            Task {
                await AlarmErrorTrackingService.shared.trackAudioFileResolution(
                    alarmId: alarm.id.uuidString,
                    found: false,
                    path: audioURL.path,
                    fallbackUsed: false,
                    context: [
                        "retryCount": retryCount,
                        "phase": "startAIScriptPhase"
                    ]
                )
            }
            
            // Retry mechanism
            if retryCount < maxAudioLoadRetries {
                logger.info("🔄 Retrying audio load in \(audioLoadRetryDelay) seconds... (attempt \(retryCount + 1)/\(maxAudioLoadRetries))")
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(audioLoadRetryDelay * 1_000_000_000))
                    await MainActor.run {
                        startAIScriptPhase(audioURL: audioURL, retryCount: retryCount + 1)
                    }
                }
            } else {
                logger.error("❌ Max retries reached. Audio file not found.")
                
                // Track final failure
                Task {
                    await AlarmErrorTrackingService.shared.trackPlaybackError(
                        alarmId: alarm.id.uuidString,
                        error: NSError(domain: "AlarmView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio file not found after \(maxAudioLoadRetries) retries"]),
                        errorType: .fileNotFound,
                        context: [
                            "retryCount": retryCount,
                            "filePath": audioURL.path
                        ]
                    )
                }
                
                await MainActor.run {
                    audioPlaybackError = "Audio file not found. Please regenerate your alarm content."
                    alarmPhase = .dismissed
                }
            }
            return
        }
        
        // Get file size and attributes for debugging
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            if let fileSize = attributes[.size] as? UInt64 {
                let fileSizeMB = Double(fileSize) / (1024 * 1024)
                logger.info("📊 File size: \(String(format: "%.2f", fileSizeMB)) MB")
            }
            if let modificationDate = attributes[.modificationDate] as? Date {
                logger.info("📅 File last modified: \(modificationDate)")
            }
        } catch {
            logger.warning("⚠️ Could not read file attributes: \(error.localizedDescription)")
        }
        
        // Track successful file resolution
        Task {
            await AlarmErrorTrackingService.shared.trackAudioFileResolution(
                alarmId: alarm.id.uuidString,
                found: true,
                path: audioURL.path,
                fallbackUsed: retryCount > 0,
                context: [
                    "retryCount": retryCount,
                    "fileSizeMB": (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? UInt64) ?? 0
                ]
            )
        }
        
        // Configure audio session for ALARM playback (bypasses silent mode)
        audioPlaybackService.configureForAlarm()
        logger.info("🔊 Audio session configured for alarm playback")
        
        // Start AI script playback
        isAttemptingAudioLoad = true
        Task {
            do {
                logger.info("▶️ Starting audio playback...")
                try await audioPlaybackService.play(from: audioURL)
                logger.info("✅ Audio playback started successfully")
                
                await MainActor.run {
                    isAttemptingAudioLoad = false
                    audioPlaybackError = nil
                }
                
                // Track successful playback
                await AlarmErrorTrackingService.shared.trackDismissalSuccess(
                    alarmId: alarm.id.uuidString,
                    method: "audio_playback",
                    audioPlayed: true,
                    context: [
                        "retryCount": retryCount,
                        "audioURL": audioURL.path
                    ]
                )
                
            } catch {
                logger.error("❌ Audio playback failed: \(error.localizedDescription)")
                logger.error("❌ Error details: \(String(describing: error))")
                
                // Determine error type
                let errorType: PlaybackErrorType
                if let audioError = error as? AudioPlaybackError {
                    switch audioError {
                    case .fileLoadError:
                        errorType = .fileLoadError
                    case .dataPlaybackError:
                        errorType = .playbackFailed
                    case .audioSessionConfigurationFailed:
                        errorType = .audioSessionError
                    case .playerInitializationFailed:
                        errorType = .fileLoadError
                    case .playbackStartFailed:
                        errorType = .playbackFailed
                    case .fileNotFound:
                        errorType = .fileNotFound
                    case .invalidAudioFormat:
                        errorType = .fileLoadError
                    }
                } else {
                    errorType = .unknown
                }
                
                // Track error
                await AlarmErrorTrackingService.shared.trackPlaybackError(
                    alarmId: alarm.id.uuidString,
                    error: error,
                    errorType: errorType,
                    context: [
                        "retryCount": retryCount,
                        "audioURL": audioURL.path,
                        "errorDescription": String(describing: error)
                    ]
                )
                
                // Retry if we haven't exceeded max retries
                if retryCount < maxAudioLoadRetries {
                    logger.info("🔄 Retrying audio playback in \(audioLoadRetryDelay) seconds... (attempt \(retryCount + 1)/\(maxAudioLoadRetries))")
                    
                    try? await Task.sleep(nanoseconds: UInt64(audioLoadRetryDelay * 1_000_000_000))
                    
                    await MainActor.run {
                        startAIScriptPhase(audioURL: audioURL, retryCount: retryCount + 1)
                    }
                } else {
                    logger.error("❌ Max playback retries reached")
                    
                    await MainActor.run {
                        isAttemptingAudioLoad = false
                        audioPlaybackError = "Failed to play audio after \(maxAudioLoadRetries) attempts. Please try again."
                        alarmPhase = .dismissed
                    }
                }
            }
        }
    }
    
    private func attemptFallbackAudioLookup(for alarm: Alarm, originalURL: URL) async {
        logger.info("🔍 ========== ATTEMPTING FALLBACK AUDIO LOOKUP ==========")
        logger.info("📋 Alarm ID: \(alarm.id.uuidString)")
        logger.info("📁 Original URL: \(originalURL.path)")
        
        // Try to find audio file by alarm ID or intent ID
        if let generatedContent = alarm.generatedContent {
            logger.info("📦 Generated content found, checking cache...")
            
            // Try to get from AudioCacheService using alarm/intent ID lookup
            do {
                let audioCacheService = try AudioCacheService()
                let intentId = generatedContent.intentId
                let voiceId = generatedContent.voiceId
                
                logger.info("🔑 Looking up by Alarm ID: \(alarm.id.uuidString)")
                logger.info("🔑 Intent ID: \(intentId ?? "nil")")
                logger.info("🔑 Voice ID: \(voiceId)")
                
                if let cachedResult = try await audioCacheService.findAudioByAlarmOrIntentId(
                    alarmId: alarm.id.uuidString,
                    intentId: intentId,
                    voiceId: voiceId
                ) {
                    logger.info("✅ Found audio in cache: \(cachedResult.filePath)")
                    
                    let fallbackURL = URL(fileURLWithPath: cachedResult.filePath)
                    if FileManager.default.fileExists(atPath: fallbackURL.path) {
                        logger.info("✅ Fallback file exists, using it")
                        
                        // Track successful fallback
                        await AlarmErrorTrackingService.shared.trackAudioFileResolution(
                            alarmId: alarm.id.uuidString,
                            found: true,
                            path: fallbackURL.path,
                            fallbackUsed: true,
                            context: [
                                "originalPath": originalURL.path,
                                "fallbackPath": fallbackURL.path,
                                "intentId": intentId ?? "nil"
                            ]
                        )
                        
                        await MainActor.run {
                            alarmPhase = .aiScriptPlayback
                            startAIScriptPhase(audioURL: fallbackURL, retryCount: 0)
                        }
                        return
                    } else {
                        logger.warning("⚠️ Fallback file does not exist: \(fallbackURL.path)")
                        
                        // Track fallback failure
                        await AlarmErrorTrackingService.shared.trackAudioFileResolution(
                            alarmId: alarm.id.uuidString,
                            found: false,
                            path: fallbackURL.path,
                            fallbackUsed: true,
                            context: [
                                "originalPath": originalURL.path,
                                "fallbackPath": fallbackURL.path
                            ]
                        )
                    }
                } else {
                    logger.info("ℹ️ No cached audio found for alarm/intent ID")
                }
            } catch {
                logger.error("❌ Error accessing audio cache: \(error.localizedDescription)")
                
                // Track cache access error
                await AlarmErrorTrackingService.shared.trackPlaybackError(
                    alarmId: alarm.id.uuidString,
                    error: error,
                    errorType: .fileLoadError,
                    context: [
                        "phase": "fallback_lookup",
                        "originalPath": originalURL.path
                    ]
                )
            }
        }
        
        // Last resort: search cache directory for files matching alarm ID
        logger.info("🔍 Searching cache directory for matching files...")
        let cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioCache")
        
        if FileManager.default.fileExists(atPath: cacheDirectory.path) {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
                logger.info("📁 Found \(files.count) files in cache directory")
                
                // Look for files that might match this alarm
                let alarmIdString = alarm.id.uuidString
                for file in files {
                    if file.lastPathComponent.contains(alarmIdString) {
                        logger.info("✅ Found potentially matching file: \(file.path)")
                        if FileManager.default.fileExists(atPath: file.path) {
                            logger.info("✅ File exists, using as fallback")
                            
                            // Track successful file system fallback
                            await AlarmErrorTrackingService.shared.trackAudioFileResolution(
                                alarmId: alarm.id.uuidString,
                                found: true,
                                path: file.path,
                                fallbackUsed: true,
                                context: [
                                    "originalPath": originalURL.path,
                                    "fallbackMethod": "filesystem_search"
                                ]
                            )
                            
                            await MainActor.run {
                                alarmPhase = .aiScriptPlayback
                                startAIScriptPhase(audioURL: file, retryCount: 0)
                            }
                            return
                        }
                    }
                }
            } catch {
                logger.error("❌ Error searching cache directory: \(error.localizedDescription)")
                
                // Track filesystem search error
                await AlarmErrorTrackingService.shared.trackPlaybackError(
                    alarmId: alarm.id.uuidString,
                    error: error,
                    errorType: .fileLoadError,
                    context: [
                        "phase": "filesystem_search",
                        "cacheDirectory": cacheDirectory.path
                    ]
                )
            }
        }
        
        logger.error("❌ No fallback audio file found")
        
        // Track final failure
        await AlarmErrorTrackingService.shared.trackPlaybackError(
            alarmId: alarm.id.uuidString,
            error: NSError(domain: "AlarmView", code: -2, userInfo: [NSLocalizedDescriptionKey: "All fallback lookup methods failed"]),
            errorType: .fileNotFound,
            context: [
                "originalPath": originalURL.path,
                "fallbackMethods": ["cache_lookup", "filesystem_search"]
            ]
        )
        
        await MainActor.run {
            self.audioPlaybackError = "Audio file not found. Please regenerate your alarm content."
            self.alarmPhase = .dismissed
        }
    }
    
    private func userInteracted() {
        // User tapped or interacted with the alarm
        // Track dismissal success
        Task {
            await AlarmErrorTrackingService.shared.trackDismissalSuccess(
                alarmId: alarm.id.uuidString,
                method: "button",
                audioPlayed: audioPlaybackService.isPlaying,
                context: [
                    "alarmPhase": "\(alarmPhase)",
                    "hasError": audioPlaybackError != nil
                ]
            )
        }
        
        viewModel.dismissAlarm(alarm.id, method: .button)
        presentationMode.wrappedValue.dismiss()
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
