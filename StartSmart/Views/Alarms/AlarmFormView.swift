import SwiftUI
import Foundation

// MARK: - Alarm Form View with Step-by-Step Restoration
struct AlarmFormView: View {
    @State private var formViewModel: AlarmFormViewModel? = nil
    @State private var tomorrowsMission: String = ""
    @State private var selectedVoice: String = "Motivational Mike"
    @State private var toneStyle: Double = 0.5 // 0.0 = Gentle, 1.0 = Tough Love
    @State private var showTimePicker = false
    @State private var generatedScript: String = ""
    @State private var generatedAudioURL: URL? = nil
    @State private var isPlayingAudio = false
    @State private var audioPlaybackService: AudioPlaybackService? = nil
    
    // Usage tracking for freemium
    @StateObject private var usageService = UsageTrackingService.shared
    @State private var showUpgradePrompt = false
    @State private var showPaywall = false
    @State private var isPremium = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let onSave: (Alarm) -> Void
    private let editingAlarm: Alarm?
    
    // MARK: - Initialization
    init(alarm: Alarm? = nil, onSave: @escaping (Alarm) -> Void) {
        self.editingAlarm = alarm
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if formViewModel != nil {
                        headerSection
                        missionSection
                        alarmSettingsSection

                        generateScriptButton
                        

                        scriptPreviewSection
                        
                        if !generatedScript.isEmpty {
                            createAlarmButton
                        }
                        
                    } else {
                        loadingSection
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        appState.selectedTab = 0
                    }
                }
            }
            .onAppear {
                // Lazy initialization of AlarmFormViewModel
                if formViewModel == nil {
                    if let alarm = editingAlarm {
                        formViewModel = AlarmFormViewModel(alarm: alarm)
                    } else {
                        formViewModel = AlarmFormViewModel()
                    }
                    print("AlarmFormViewModel initialized successfully")
                }
                
                // Check premium status
                checkPremiumStatus()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .overlay {
                if showUpgradePrompt {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showUpgradePrompt = false
                            }
                        
                        UpgradePromptView(
                            title: "You've Reached Your Limit",
                            message: "You've used all 15 free AI alarms this month. Upgrade to Premium for unlimited personalized wake-ups!",
                            featureIcon: "alarm.fill",
                            onUpgrade: {
                                showUpgradePrompt = false
                                showPaywall = true
                            },
                            onDismiss: {
                                showUpgradePrompt = false
                            }
                        )
                        .padding(20)
                    }
                }
            }
            .alert(
                "Generation Error",
                isPresented: Binding(
                    get: { generationErrorMessage != nil },
                    set: { _ in generationErrorMessage = nil }
                )
            ) {
                Button("OK") { generationErrorMessage = nil }
                if !generatedScript.isEmpty && generatedAudioURL == nil {
                    Button("Retry Audio") { 
                        generationErrorMessage = nil
                        Task {
                            await retryAudioGeneration()
                        }
                    }
                }
        } message: {
                Text(generationErrorMessage ?? "")
            }
            .sheet(isPresented: $showTimePicker) {
                timePickerSheet
            }
            .onAppear {
                // Services will be resolved lazily when needed
            }
        }
    }
    
    // MARK: - View Components
    
    private var generateScriptButton: some View {
        Button {
            Task { await generateScriptAndAudio() }
        } label: {
            HStack(spacing: 12) {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(isGenerating ? "Generating..." : "Generate AI Script")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .disabled(isGenerating)
        .scaleEffect(isGenerating ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isGenerating)
        .padding(.horizontal, 20)
    }
    
    private var scriptPreviewSection: some View {
        Group {
            if !generatedScript.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Generated Script Preview")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Your personalized morning motivation")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    Text(generatedScript)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 16) {
                        Button {
                            previewVoice()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isPlayingAudio ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Preview Voice")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .disabled(generatedAudioURL == nil)
                        .opacity(generatedAudioURL == nil ? 0.6 : 1.0)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private var createAlarmButton: some View {
        VStack(spacing: 12) {
            Button {
                handleAlarmCreation()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Create Smart Alarm")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(Color.blue)
                .cornerRadius(16)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(false)
            .scaleEffect(isGenerating ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isGenerating)
            
            // Usage info for free users
            if !isPremium {
                let remaining = usageService.getRemainingAlarmCredits(isPremium: isPremium) ?? 0
                Text("\(remaining) free alarms remaining this month")
                    .font(.system(size: 13))
                    .foregroundColor(remaining <= 3 ? .orange : .secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Your personalized morning experience awaits")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private func handleAlarmCreation() {
        // Check if user can create alarm (usage limits for free users)
        guard usageService.canCreateAlarm(isPremium: isPremium) else {
            print("⚠️ Free tier limit reached - showing upgrade prompt")
            showUpgradePrompt = true
            return
        }
        
        // Proceed with alarm creation
        saveAlarm()
        
        // Increment usage for free users
        if !isPremium {
            usageService.incrementAlarmUsage()
        }
    }
    
    private var loadingSection: some View {
        VStack {
            ProgressView()
            Text("Loading...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var timePickerSheet: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Alarm Time",
                    selection: Binding(
                        get: { formViewModel?.time ?? Date() },
                        set: { formViewModel?.time = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                
                Spacer()
            }
            .navigationTitle("Set Alarm Time")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    showTimePicker = false
                },
                trailing: Button("Done") {
                    showTimePicker = false
                }
            )
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Helper Methods
    private func checkPremiumStatus() {
        // Check if user is premium (from subscription service or UserDefaults)
        // For now, default to free unless they have a subscription
        let isGuestUser = UserDefaults.standard.bool(forKey: "is_guest_user")
        isPremium = false // Will be updated when subscription service is integrated
        
        print("📊 Premium status: \(isPremium ? "Premium" : "Free"), Guest: \(isGuestUser)")
    }
    
    private func saveAlarm() {
        guard let formViewModel = formViewModel else { return }
        
        if formViewModel.validate() {
            var alarm = formViewModel.createAlarm()
            
            // Attach generated content if present
            if !generatedScript.isEmpty, let fileURL = lastGeneratedAudioURL, let voice = lastVoiceIdUsed {
                let content = AlarmGeneratedContent(
                    textContent: generatedScript,
                    audioFilePath: fileURL.path,
                    voiceId: voice,
                    generatedAt: Date(),
                    duration: nil,
                    intentId: nil
                )
                alarm.setGeneratedContent(content)
            }
            
            // Create alarm using AlarmRepository (supports both StartSmart and AlarmKit)
            Task { @MainActor in
                do {
                    let alarmRepository = AlarmRepository()
                    
                    if let editingAlarm = editingAlarm {
                        // Update existing alarm using AlarmRepository
                        try await alarmRepository.updateAlarm(alarm)
                        print("✅ Alarm updated successfully using AlarmRepository")
                    } else {
                        // Create new alarm using AlarmRepository
                        try await alarmRepository.saveAlarm(alarm)
                        print("✅ Alarm created successfully using AlarmRepository")
                    }
                    
                    // Call the onSave callback to update UI
                    onSave(alarm)
                    
                } catch {
                    print("❌ AlarmRepository save failed: \(error)")
                    // Fallback to old system if AlarmRepository fails
                    do {
                        let storage = StorageManager()
                        var all = try storage.loadAlarms()
                        if let editingAlarm = editingAlarm {
                            // Update existing alarm
                            if let index = all.firstIndex(where: { $0.id == editingAlarm.id }) {
                                all[index] = alarm
                            }
                        } else {
                            // Add new alarm
                            all.append(alarm)
                        }
                        try storage.saveAlarms(all)
                        print("✅ Fallback to StorageManager successful")
                        onSave(alarm)
                    } catch {
                        print("❌ Fallback save failed: \(error)")
                    }
                }
                
                // Navigate to alarms tab after successful save
                appState.selectedTab = 2
            }
        }
    }

    // MARK: - AI/Audio Integration
    @State private var isGenerating = false
    @State private var lastGeneratedAudioURL: URL?
    @State private var lastVoiceIdUsed: String?
    @State private var generationErrorMessage: String?
    
    // Dependencies
    @State private var elevenLabsService: ElevenLabsServiceProtocol?
    @State private var grok4Service: Grok4ServiceProtocol?

    private func personaForSelectedVoice() -> PersonaManager.Persona {
        switch selectedVoice {
        case "Coach Marcus": return .motivationalMike
        case "Wise Sarah": return .mrsWalker
        case "Gentle Grace": return .calmKyle
        case "Motivator Mike": return .motivationalMike
        default: return .motivationalMike
        }
    }

    private func generateScriptAndAudio() async {
        guard !isGenerating else { return }
        guard !tomorrowsMission.isEmpty else {
            await MainActor.run {
                generationErrorMessage = "Please enter your mission for tomorrow."
            }
            return
        }
        
        isGenerating = true
        defer {
            isGenerating = false
        }
        
        do {
            // Resolve services lazily without blocking
            let grokService: Grok4ServiceProtocol = try await DependencyContainer.shared.resolveAsync()
            
            let elevenLabsService: ElevenLabsServiceProtocol = try await DependencyContainer.shared.resolveAsync()
            
            // Convert tone slider to tone string
            let toneString: String = {
                switch PersonaManager.ToneLevel.fromSliderValue(toneStyle) {
                case .gentle: return "gentle"
                case .balanced: return "energetic"
                case .toughLove: return "tough_love"
                }
            }()
            
            // Generate script using Grok4
            let script = try await grokService.generateMotivationalScript(
                userIntent: tomorrowsMission,
                tone: toneString,
                context: ["timeOfDay": "morning", "dayOfWeek": ""]
            )
            
            await MainActor.run { 
                self.generatedScript = script
            }
            
            // Get voice ID for selected voice
            let voiceId = getVoiceIdForSelectedVoice()
            
            // Try to generate audio with multiple attempts and fallback
            var audioGenerated = false
            var lastError: Error?
            
            // Try up to 3 times with progressive backoff (reduced from 5)
            for attempt in 1...3 {
                do {
                    
                    let audioData = try await elevenLabsService.generateSpeech(
                        text: script,
                        voiceId: voiceId
                    )
                    
                    
                    
                    // Save audio to documents
                    let fileURL = try await writeAudioData(audioData)
                    
                    await MainActor.run {
                        self.lastGeneratedAudioURL = fileURL
                        self.generatedAudioURL = fileURL
                        self.lastVoiceIdUsed = voiceId
                    }
                    
                    audioGenerated = true
                    break // Success, exit retry loop
                    
                } catch {
                    lastError = error
                    
                    // Check if this is a retryable error
                    let shouldRetry = shouldRetryAudioError(error)
                    if !shouldRetry {
                        break
                    }
                    
                    // If this isn't the last attempt, wait with progressive backoff
                    if attempt < 3 {
                        let delay = min(pow(2.0, Double(attempt - 1)) * 1.0, 8.0) // Max 8 seconds
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            }
            
            // If all attempts failed, automatically fall back to traditional sound
            if !audioGenerated {
                await MainActor.run {
                    if let error = lastError {
                        let nsError = error as NSError
                        switch nsError.code {
                        case -1005: // Network connection lost
                            generationErrorMessage = "Script generated successfully! Audio generation failed due to network issues. Switched to traditional alarm sound."
                        case -1009: // No internet connection
                            generationErrorMessage = "Script generated successfully! Audio generation failed - no internet connection. Switched to traditional alarm sound."
                        case -1017: // Cannot parse response
                            generationErrorMessage = "Script generated successfully! ElevenLabs API is currently experiencing issues. Switched to traditional alarm sound."
                        default:
                            generationErrorMessage = "Script generated successfully! Audio generation failed. Switched to traditional alarm sound."
                        }
                    } else {
                        generationErrorMessage = "Script generated successfully! Audio generation failed. Switched to traditional alarm sound."
                    }
                }
            }
            
        } catch {
            await MainActor.run { 
                generationErrorMessage = "Failed to generate script: \(error.localizedDescription)"
            }
        }
    }
    private func getVoiceIdForSelectedVoice() -> String {
        // Map UI voice names to ElevenLabs voice IDs - using the specific voice IDs provided by the user
        switch selectedVoice {
        case "Drill Sergeant Drew":
            return "DGzg6RaUqxGRTHSBjfgF"
        case "Girl Bestie":
            return "uYXf8XasLslADfZ2MB4u"
        case "Mrs. Walker - Warm & Caring Southern Mom":
            return "DLsHlh26Ugcm6ELvS0qi"
        case "Motivational Mike":
            return "84Fal4DSXWfp7nJ8emqQ"
        case "Calm Kyle":
            return "MpZY6e8MW2zHVi4Vtxrn"
        case "Angry Allen":
            return "KLZOWyG48RjZkAAjuM89"
        default:
            return "84Fal4DSXWfp7nJ8emqQ" // Default to Motivational Mike
        }
    }

    private func writeAudioData(_ data: Data) async throws -> URL {
        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = docs.appendingPathComponent("AlarmAudio", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let filename = UUID().uuidString + ".mp3"
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }
    
    // Helper function to add timeout to async operations
    
    // MARK: - ElevenLabs API Test Function
    
    // MARK: - Error Handling Helper
    
    private func shouldRetryAudioError(_ error: Error) -> Bool {
        // Check for specific network errors that should be retried
        if let nsError = error as NSError? {
            switch nsError.code {
            case -1001, -1005, -1009, -1017, -1018, -1019, -1020, -1021, -1022, -1023, -1024, -1025, -1026, -1027, -1028, -1029, -1030, -1031, -1032, -1033, -1034, -1035, -1036, -1037, -1038, -1039, -1040, -1041, -1042, -1043, -1044, -1045, -1046, -1047, -1048, -1049, -1050:
                return true
            default:
                break
            }
        }
        
        // Check for ElevenLabs specific errors that should be retried
        let errorString = error.localizedDescription.lowercased()
        if !errorString.isEmpty {
            if errorString.contains("cannot parse response") ||
               errorString.contains("network connection") ||
               errorString.contains("timeout") ||
               errorString.contains("connection lost") ||
               errorString.contains("server error") {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Audio Retry Function
    private func retryAudioGeneration() async {
        guard !generatedScript.isEmpty else {
            await MainActor.run {
                generationErrorMessage = "No script available to generate audio for."
            }
            return
        }
        
        
        // Get voice ID for selected voice
        let voiceId = getVoiceIdForSelectedVoice()
        
        // Try to generate audio with multiple attempts
        var audioGenerated = false
        var lastError: Error?
        
            // Try up to 5 times with progressive backoff
            for attempt in 1...5 {
                do {
                    
                    let elevenLabsService: ElevenLabsServiceProtocol = DependencyContainer.shared.resolve()
                    let audioData = try await elevenLabsService.generateSpeech(
                        text: generatedScript,
                        voiceId: voiceId
                    )
                    
                    
                    // Save audio to documents
                    let fileURL = try await writeAudioData(audioData)
                    
                    await MainActor.run {
                        self.lastGeneratedAudioURL = fileURL
                        self.generatedAudioURL = fileURL
                        self.lastVoiceIdUsed = voiceId
                    }
                    
                    audioGenerated = true
                    break // Success, exit retry loop
                    
                } catch {
                    lastError = error
                    
                    // Check if this is a retryable error
                    let shouldRetry = shouldRetryAudioError(error)
                    if !shouldRetry {
                        break
                    }
                    
                    // If this isn't the last attempt, wait with progressive backoff
                    if attempt < 5 {
                        let delay = min(pow(2.0, Double(attempt - 1)) * 1.0, 8.0) // Max 8 seconds
                        do {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        } catch {
                            // Ignore sleep errors
                        }
                    }
                }
            }
        
        // If all attempts failed, show a helpful message
        if !audioGenerated {
            await MainActor.run {
                if let error = lastError {
                    let nsError = error as NSError
                    switch nsError.code {
                    case -1005: // Network connection lost
                        generationErrorMessage = "Audio generation failed due to network issues. Please check your internet connection and try again."
                    case -1009: // No internet connection
                        generationErrorMessage = "Audio generation failed - no internet connection. Please check your network settings and try again."
                    case -1017: // Cannot parse response
                        generationErrorMessage = "ElevenLabs API is currently experiencing issues. Please try again later."
                    default:
                        generationErrorMessage = "Audio generation failed: \(error.localizedDescription). Please try again later."
                    }
                } else {
                    generationErrorMessage = "Audio generation failed after multiple attempts. Please try again later."
                }
            }
        }
    }
    
    // MARK: - Audio Playback Functions
    private func previewVoice() {
        
        guard let audioURL = generatedAudioURL else { 
            Task { @MainActor in
                generationErrorMessage = "No audio available to preview. Please generate audio first."
            }
            return 
        }
        
        
        // Check if file exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: audioURL.path) {
            Task { @MainActor in
                generationErrorMessage = "Audio file not found. Please regenerate audio."
            }
            return
        }
        
        // Check file size
        do {
            let attributes = try fileManager.attributesOfItem(atPath: audioURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize == 0 {
                Task { @MainActor in
                    generationErrorMessage = "Audio file is empty. Please regenerate audio."
                }
                return
            }
        } catch {
        }
        
        if isPlayingAudio {
            // Stop current playback
            audioPlaybackService?.stop()
            audioPlaybackService = nil
            isPlayingAudio = false
        } else {
            // Start playback
            audioPlaybackService = AudioPlaybackService()
            audioPlaybackService?.configureForPreview() // Ensure proper audio session
            Task {
                do {
                    try await audioPlaybackService?.play(from: audioURL)
                    await MainActor.run {
                        isPlayingAudio = true
                    }
                } catch {
                    await MainActor.run {
                        isPlayingAudio = false
                        generationErrorMessage = "Audio playback failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        EmptyView()
    }
    
    private var missionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tomorrow's Mission")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Tell me what you want to accomplish tomorrow")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            TextEditor(text: $tomorrowsMission)
                .frame(minHeight: 120)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .font(.system(size: 16))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var alarmSettingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Alarm Settings")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            // Wake-up Time Row
            HStack {
                Text("Wake-up Time")
                    .font(.system(size: 17, weight: .regular))
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut) { showTimePicker.toggle() }
                }) {
                    Text(formViewModel?.timeDisplayString ?? "12:00 AM")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                }
            }
            .padding(.horizontal, 20)
            
            // Voice Style Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Voice Style")
                    .font(.system(size: 17, weight: .regular))
                    .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(["Drill Sergeant Drew", "Girl Bestie", "Mrs. Walker - Warm & Caring Southern Mom", "Motivational Mike", "Calm Kyle", "Angry Allen"], id: \.self) { voice in
                            Button(action: {
                                selectedVoice = voice
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "waveform")
                                        .foregroundColor(selectedVoice == voice ? .white : .blue)
                                    
                                    Text(voice)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(selectedVoice == voice ? .white : .primary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedVoice == voice ? Color.blue : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedVoice == voice ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Tone Style Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Tone Style")
                    .font(.system(size: 17, weight: .regular))
                    .padding(.horizontal, 20)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Gentle & Nurturing")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Tough Love & Direct")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    Slider(value: $toneStyle, in: 0...1)
                        .padding(.horizontal, 20)
                        .tint(.blue)
                }
            }
        }
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
}


#Preview {
    AlarmFormView(onSave: { _ in })
}