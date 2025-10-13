import SwiftUI
import os
import Combine
import RevenueCat
import AVFoundation
import AudioToolbox

// MARK: - Shared App State
class AppState: ObservableObject {
    @Published var selectedTab: Int = 0
}

// MARK: - DeferredView for lazy loading
struct DeferredView<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
    }
}

struct MainAppView: View {
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "UI")
    @StateObject private var appState = AppState()
    @StateObject private var container = DependencyContainer.shared
    @StateObject private var alarmCoordinator = AlarmNotificationCoordinator.shared
    
    // Create AlarmViewModel lazily - it will use the repository from DependencyContainer once initialized
    @StateObject private var alarmViewModel: AlarmViewModel = {
        // Create with a repository that has NotificationService
        let notificationService = NotificationService()
        let repository = AlarmRepository(notificationService: notificationService)
        return AlarmViewModel(alarmRepository: repository)
    }()

    var body: some View {
        ZStack {
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                DeferredView { 
                    AlarmFormView { alarm in
                        // Save alarm using shared AlarmViewModel
                        alarmViewModel.addAlarm(alarm)
                    }
                }
                .tabItem { Label("Create", systemImage: "plus.circle.fill") }
                .tag(1)

                DeferredView { AlarmListView() }
                    .environmentObject(alarmViewModel)
                    .tabItem { Label("Alarms", systemImage: "alarm.fill") }
                    .tag(2)

                DeferredView { VoicesView() }
                    .tabItem { Label("Voices", systemImage: "waveform.circle.fill") }
                    .tag(3)

                DeferredView { AnalyticsDashboardView() }
                    .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                    .tag(4)
            }
            .onChange(of: appState.selectedTab) { newValue in
                logger.info("Tab changed -> \(newValue)")
            }
            .accentColor(.blue)
            .environmentObject(appState)
            .sheet(isPresented: $alarmCoordinator.shouldShowDismissalSheet) {
                if let alarmId = alarmCoordinator.pendingAlarmId {
                    // Ensure alarms are loaded
                    if alarmViewModel.alarms.isEmpty {
                        ProgressView("Loading alarm...")
                            .onAppear {
                                logger.info("⏳ Alarms not loaded, loading now...")
                                alarmViewModel.loadAlarms()
                                // Give it a moment to load
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    // Force refresh of sheet if still empty
                                    if alarmViewModel.alarms.isEmpty {
                                        logger.error("❌ Alarms still empty after loading")
                                    }
                                }
                            }
                    } else if let alarm = alarmViewModel.alarms.first(where: { $0.id.uuidString == alarmId }) {
                        AlarmDismissalView(alarm: alarm) {
                            alarmCoordinator.clearPendingAlarm()
                        }
                    } else {
                        // Fallback if alarm not found
                        VStack(spacing: 20) {
                            Image(systemName: "alarm.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Alarm Triggered!")
                                .font(.title.bold())
                            
                            Text("Could not find alarm details")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Dismiss") {
                                alarmCoordinator.clearPendingAlarm()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .onAppear {
                            logger.error("❌ Could not find alarm with ID: \(alarmId)")
                            logger.info("Available alarms: \(alarmViewModel.alarms.map { $0.id.uuidString })")
                        }
                    }
                }
            }
            
            // ✅ Show subtle loading indicator if heavy services still loading
            if !container.isFullyInitialized {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading AI features...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
                    .padding(.bottom, 100) // Above tab bar
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: container.isFullyInitialized)
            }
        }
    }
}

struct HomeView: View {
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "UI")
    @EnvironmentObject var appState: AppState
    @StateObject private var alarmViewModel = AlarmViewModel()
    @StateObject private var streakService = StreakTrackingService()
    @State private var enhancedStats = EnhancedUserStats()
    @State private var nextAlarm: Alarm?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Good Morning!")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.top, 20)

                // Streak Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Streak")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                    }

                    HStack {
                        Text("\(enhancedStats.currentStreak) days")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.orange)

                        Spacer()

                       HStack(spacing: 4) {
                           ForEach(["Su", "M", "Tu", "W", "Th", "F", "Sa"], id: \.self) { day in
                                Text(day)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(.orange))
                                    .opacity(isDayCompleted(day) ? 1.0 : 0.3)
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )

                // Quick Action Buttons
                HStack(spacing: 12) {
                    // New Alarm
                    Button {
                        logger.info("Tap New Alarm (state)")
                        appState.selectedTab = 1
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Text("New Alarm")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .allowsHitTesting(true)

                    // Voices
                    Button {
                        logger.info("Tap Voices (state)")
                        appState.selectedTab = 3
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "waveform")
                                .foregroundColor(.purple)
                                .font(.title2)
                            Text("Voices")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .allowsHitTesting(true)

                    // Stats
                    Button {
                        logger.info("Tap Stats (state)")
                        appState.selectedTab = 4
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Stats")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .allowsHitTesting(true)
                }

                // Next Alarm Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next Alarm")
                        .font(.headline)

                    if let alarm = nextAlarm {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(formatTime(alarm.time))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(alarm.label)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(alarm.hasCustomAudio ? "AI-Generated Content Ready" : "Traditional Alarm")
                                    .font(.caption)
                                    .foregroundColor(alarm.hasCustomAudio ? .green : .blue)
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Image(systemName: "alarm")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                Text(timeUntilAlarm(alarm))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("No alarms set")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Text("Create your first alarm to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Create Alarm") {
                                appState.selectedTab = 1
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )

                // Recent Activity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Activity")
                        .font(.headline)

                    if enhancedStats.recentEvents.isEmpty {
                        ActivityItem(icon: "clock", color: .gray, title: "No recent activity", subtitle: "Start using alarms to see your progress")
                    } else {
                        ForEach(Array(enhancedStats.recentEvents.prefix(3)), id: \.timestamp) { event in
                            ActivityItem(
                                icon: iconForEvent(event),
                                color: colorForEvent(event),
                                title: titleForEvent(event),
                                subtitle: formatEventTime(event.timestamp)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear { 
            logger.info("HomeView appeared")
            loadData()
        }
        .onReceive(streakService.enhancedStats) { stats in
            enhancedStats = stats
        }
        .onReceive(alarmViewModel.$alarms) { _ in
            nextAlarm = alarmViewModel.nextAlarm
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadData() {
        Task {
            await streakService.loadStats()
            nextAlarm = alarmViewModel.nextAlarm
        }
    }
    
    private func isDayCompleted(_ day: String) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        // Map day letters to weekday numbers (Sunday = 1)
        let dayMap = ["Su": 1, "M": 2, "Tu": 3, "W": 4, "Th": 5, "F": 6, "Sa": 7]
        guard let targetDay = dayMap[day] else { return false }
        
        // Check if this day has been completed in the current week
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let daysSinceWeekStart = calendar.dateComponents([.day], from: weekStart, to: today).day ?? 0
        
        return daysSinceWeekStart >= (targetDay - 1)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func timeUntilAlarm(_ alarm: Alarm) -> String {
        guard let nextTrigger = alarm.nextTriggerDate else {
            return "Not scheduled"
        }
        
        let now = Date()
        let timeInterval = nextTrigger.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            return "Overdue"
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
    
    private func iconForEvent(_ event: StreakEvent) -> String {
        switch event {
        case .alarmDismissed(_, let method, _):
            switch method {
            case .voice: return "mic.fill"
            case .button: return "hand.tap.fill"
            case .notification: return "bell.fill"
            }
        case .alarmSnoozed: return "clock.arrow.circlepath"
        case .alarmMissed: return "exclamationmark.triangle.fill"
        }
    }
    
    private func colorForEvent(_ event: StreakEvent) -> Color {
        switch event {
        case .alarmDismissed: return .green
        case .alarmSnoozed: return .orange
        case .alarmMissed: return .red
        }
    }
    
    private func titleForEvent(_ event: StreakEvent) -> String {
        switch event {
        case .alarmDismissed(_, let method, _):
            switch method {
            case .voice: return "Woke up with voice"
            case .button: return "Woke up on time"
            case .notification: return "Alarm dismissed"
            }
        case .alarmSnoozed(_, let count, _):
            return "Snoozed \(count) time\(count == 1 ? "" : "s")"
        case .alarmMissed:
            return "Missed alarm"
        }
    }
    
    private func formatEventTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// ✅ FIXED: VoicesView with proper service loading handling
struct VoicesView: View {
    @StateObject private var container = DependencyContainer.shared
    @State private var currentlyPlayingSound: TraditionalAlarmSound? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil
    
    // Voice preview state
    @State private var currentlyPlayingVoice: String?
    @State private var voiceAudioPlayer: AVAudioPlayer?
    @State private var isLoadingVoicePreview = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voices")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Choose your morning guide")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // ✅ Show loading state if AI services not ready
                if !container.isFullyInitialized {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading AI voices...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("This will only take a moment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // AI Voice Library Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Voice Library")
                            .font(.headline)

                        Text("Choose your AI voice for personalized content")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VoiceCard(
                            name: "Drill Sergeant Drew",
                            subtitle: "Tough, commanding military-style motivation",
                            accent: "Military",
                            isSelected: true,
                            isPlaying: currentlyPlayingVoice == "Drill Sergeant Drew",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Drill Sergeant Drew",
                            onPlay: { playVoicePreview("Drill Sergeant Drew") }
                        )
                        VoiceCard(
                            name: "Girl Bestie",
                            subtitle: "Supportive and encouraging like your best friend",
                            accent: "Friendly",
                            isPlaying: currentlyPlayingVoice == "Girl Bestie",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Girl Bestie",
                            onPlay: { playVoicePreview("Girl Bestie") }
                        )
                        VoiceCard(
                            name: "Mrs. Walker",
                            subtitle: "Warm & caring Southern mom who believes in you",
                            accent: "Southern",
                            isPremium: true,
                            isPlaying: currentlyPlayingVoice == "Mrs. Walker",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Mrs. Walker",
                            onPlay: { playVoicePreview("Mrs. Walker") }
                        )
                        VoiceCard(
                            name: "Motivational Mike",
                            subtitle: "High-energy speaker who gets you pumped up",
                            accent: "Energetic",
                            isPremium: true,
                            isPlaying: currentlyPlayingVoice == "Motivational Mike",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Motivational Mike",
                            onPlay: { playVoicePreview("Motivational Mike") }
                        )
                        VoiceCard(
                            name: "Calm Kyle",
                            subtitle: "Peaceful, zen-like guidance for mindful mornings",
                            accent: "Calm",
                            isPremium: true,
                            isPlaying: currentlyPlayingVoice == "Calm Kyle",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Calm Kyle",
                            onPlay: { playVoicePreview("Calm Kyle") }
                        )
                        VoiceCard(
                            name: "Angry Allen",
                            subtitle: "Intense, no-nonsense wake-up calls",
                            accent: "Intense",
                            isPremium: true,
                            isPlaying: currentlyPlayingVoice == "Angry Allen",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Angry Allen",
                            onPlay: { playVoicePreview("Angry Allen") }
                        )
                    }
                }

                // Wake-up Sounds Section (doesn't need AI services)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Wake-up Sounds")
                        .font(.headline)

                    Text("Preview traditional alarm sounds")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(TraditionalAlarmSound.allCases, id: \.self) { sound in
                            WakeUpSoundCard(
                                sound: sound,
                                isPlaying: currentlyPlayingSound == sound,
                                onPlay: { playSound(sound) },
                                onStop: { stopSound() }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .onDisappear {
            stopSound()
            stopVoicePreview()
        }
    }
    
    private func playSound(_ sound: TraditionalAlarmSound) {
        // Stop any currently playing sound
        stopSound()
        
        // Load and play the custom MP3 file
        let fileName = sound.soundFileName.replacingOccurrences(of: ".mp3", with: "")
        guard let soundURL = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.7 // Set volume for preview
            audioPlayer?.play()
            currentlyPlayingSound = sound
            
            // Auto-stop after 3 seconds for preview
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if currentlyPlayingSound == sound {
                    currentlyPlayingSound = nil
                    audioPlayer?.stop()
                    audioPlayer = nil
                }
            }
        } catch {
            // Handle error silently in production
        }
    }
    
    private func stopSound() {
        currentlyPlayingSound = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // MARK: - ✅ FIXED: Voice Preview Functions with Service Check
    
    private func playVoicePreview(_ voiceName: String) {
        // ✅ Check if services are ready
        guard container.isFullyInitialized else {
            print("AI services not ready yet")
            return
        }
        
        // Stop any currently playing voice
        stopVoicePreview()
        
        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
            return
        }
        
        // Generate a random phrase for the voice to read
        let phrases = [
            "Good morning! Time to conquer your day!",
            "Rise and shine! Your goals are waiting!",
            "Wake up! Today is full of possibilities!",
            "Morning! Let's make today amazing!",
            "Time to wake up and chase your dreams!"
        ]
        
        let randomPhrase = phrases.randomElement() ?? "Good morning! Time to start your day!"
        
        currentlyPlayingVoice = voiceName
        isLoadingVoicePreview = true
        
        // Generate actual audio using ElevenLabs
        Task {
            do {
                // ✅ Use safe async resolution
                guard let elevenLabsService: ElevenLabsServiceProtocol = await container.resolveSafe() else {
                    print("ElevenLabs service not available")
                    await MainActor.run {
                        self.currentlyPlayingVoice = nil
                        self.isLoadingVoicePreview = false
                    }
                    return
                }
                
                let audioData = try await elevenLabsService.generateVoicePreview(text: randomPhrase, voiceName: voiceName)
                
                // Validate audio data
                guard !audioData.isEmpty else {
                    await MainActor.run {
                        self.currentlyPlayingVoice = nil
                        self.isLoadingVoicePreview = false
                    }
                    return
                }
                
                // Save audio data to temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("voice_preview_\(voiceName.replacingOccurrences(of: " ", with: "_")).mp3")
                try audioData.write(to: tempURL)
                
                // Play the audio
                await MainActor.run {
                    do {
                        self.voiceAudioPlayer = try AVAudioPlayer(contentsOf: tempURL)
                        self.voiceAudioPlayer?.volume = 0.8
                        self.isLoadingVoicePreview = false
                        
                        _ = self.voiceAudioPlayer?.play()
                        
                        // Auto-stop after audio finishes
                        let duration = self.voiceAudioPlayer?.duration ?? 3.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            if self.currentlyPlayingVoice == voiceName {
                                self.stopVoicePreview()
                            }
                        }
                    } catch {
                        print("Audio playback error: \(error)")
                        self.currentlyPlayingVoice = nil
                        self.isLoadingVoicePreview = false
                    }
                }
            } catch {
                print("Voice preview error: \(error)")
                await MainActor.run {
                    self.currentlyPlayingVoice = nil
                    self.isLoadingVoicePreview = false
                }
            }
        }
    }
    
    private func stopVoicePreview() {
        currentlyPlayingVoice = nil
        isLoadingVoicePreview = false
        voiceAudioPlayer?.stop()
        voiceAudioPlayer = nil
    }
}

struct ActivityItem: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct WakeUpSoundCard: View {
    let sound: TraditionalAlarmSound
    let isPlaying: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: sound.iconName)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            // Name
            Text(sound.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Play button
            Button(action: isPlaying ? onStop : onPlay) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isPlaying ? .red : .blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPlaying ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
    }
}

// ✅ FIXED: VoiceCard with loading state
struct VoiceCard: View {
    let name: String
    let subtitle: String
    let accent: String?
    let isSelected: Bool
    let isPremium: Bool
    let isPlaying: Bool
    let isLoading: Bool
    let onPlay: () -> Void

    init(name: String, subtitle: String, accent: String? = nil, isSelected: Bool = false, isPremium: Bool = false, isPlaying: Bool = false, isLoading: Bool = false, onPlay: @escaping () -> Void = {}) {
        self.name = name
        self.subtitle = subtitle
        self.accent = accent
        self.isSelected = isSelected
        self.isPremium = isPremium
        self.isPlaying = isPlaying
        self.isLoading = isLoading
        self.onPlay = onPlay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if isPremium {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let accent = accent {
                        Text(accent)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                Button(action: {
                    onPlay()
                }) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                        }
                    }
                    .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    MainAppView()
}