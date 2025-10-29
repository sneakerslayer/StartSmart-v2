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
    
    // State for WakeUpIntent-triggered alarm dismissal
    @State private var shouldShowWakeUpSheet = false
    @State private var wakeUpAlarmId: String?
    @State private var wakeUpUserGoal: String?
    
    // Create AlarmViewModel lazily - it will use the repository from DependencyContainer once initialized
    @StateObject private var alarmViewModel: AlarmViewModel = {
        // Create with AlarmKit-based repository
        let alarmRepository = AlarmRepository()  // AlarmKit handles scheduling
        return AlarmViewModel(alarmRepository: alarmRepository)
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

                DeferredView { AnalyticsDashboardView() }
                    .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
                    .tag(3)

                DeferredView { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(4)
            }
            .onChange(of: appState.selectedTab) { newValue in
                logger.info("Tab changed -> \(newValue)")
            }
            .accentColor(.blue)
            .environmentObject(appState)
            .onReceive(NotificationCenter.default.publisher(for: .showAlarmView)) { notification in
                logger.info("🎯 WakeUpIntent notification received in MainAppView")
                if let userInfo = notification.userInfo,
                   let alarmID = userInfo["alarmID"] as? String,
                   let userGoal = userInfo["userGoal"] as? String {
                    wakeUpAlarmId = alarmID
                    wakeUpUserGoal = userGoal
                    shouldShowWakeUpSheet = true
                    logger.info("🎯 Showing WakeUpIntent sheet for alarm: \(alarmID)")
                }
            }
            .sheet(isPresented: $alarmCoordinator.shouldShowDismissalSheet) {
                if let alarmId = alarmCoordinator.pendingAlarmId {
                    // Ensure alarms are loaded
                    if alarmViewModel.alarms.isEmpty {
                        ProgressView("Loading alarm...")
                            .onAppear {
                                logger.info("📢 ========== ALARM SHEET TRIGGERED ==========")
                                logger.info("📋 Pending Alarm ID: \(alarmId)")
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
                        AlarmView(alarm: alarm)
                            .onAppear {
                                logger.info("📢 ========== ALARM SHEET TRIGGERED ==========")
                                logger.info("✅ Found alarm: '\(alarm.label)'")
                                logger.info("🔧 Alarm Settings:")
                                logger.info("   - ID: \(alarm.id.uuidString)")
                                logger.info("   - hasCustomAudio: \(alarm.hasCustomAudio)")
                                logger.info("🎬 AlarmView appeared for alarm: \(alarm.label)")
                            }
                            .onDisappear {
                                logger.info("👋 AlarmView disappeared")
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
            .sheet(isPresented: $shouldShowWakeUpSheet) {
                if let alarmId = wakeUpAlarmId,
                   let alarm = alarmViewModel.alarms.first(where: { $0.id.uuidString == alarmId }) {
                    // TODO: Fix AlarmDismissalView not found in project
                    // AlarmDismissalView(alarm: alarm) {
                    //     shouldShowWakeUpSheet = false
                    //     wakeUpAlarmId = nil
                    //     wakeUpUserGoal = nil
                    //     logger.info("🎯 WakeUpIntent sheet dismissed")
                    // }
                    // .onAppear {
                    Text("Alarm Dismissal View - Temporarily Disabled")
                    // }
                } else {
                    // Fallback if alarm not found
                    VStack(spacing: 20) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Wake Up!")
                            .font(.title.bold())
                        
                        Text("Ready to start your day?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Dismiss") {
                            shouldShowWakeUpSheet = false
                            wakeUpAlarmId = nil
                            wakeUpUserGoal = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .onAppear {
                        logger.error("❌ Could not find alarm with ID: \(wakeUpAlarmId ?? "nil")")
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
    @StateObject private var usageService = UsageTrackingService.shared
    @StateObject private var container = DependencyContainer.shared
    @State private var enhancedStats = EnhancedUserStats()
    @State private var nextAlarm: Alarm?
    @State private var showPaywall = false
    @State private var isPremium = false
    
    // Voice preview state
    @State private var currentlyPlayingVoice: String?
    @State private var voiceAudioPlayer: AVAudioPlayer?
    @State private var isLoadingVoicePreview = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Good Morning!")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.top, 20)

                // Upgrade Banner for Free Users
                if !isPremium {
                    upgradeBanner
                }

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

                    // Analytics
                    Button {
                        logger.info("Tap Analytics (state)")
                        appState.selectedTab = 3
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Analytics")
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

                    // Settings
                    Button {
                        logger.info("Tap Settings (state)")
                        appState.selectedTab = 4
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "gear")
                                .foregroundColor(.purple)
                                .font(.title2)
                            Text("Settings")
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
                
                // AI Voice Library Section (simplified for Home)
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Voice Library")
                        .font(.headline)
                        .padding(.top, 8)

                    Text("Choose your AI voice for personalized wake-up content")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Voice Cards (with play buttons)
                    VStack(spacing: 8) {
                        SimpleVoiceCard(
                            name: "Girl Bestie",
                            subtitle: "Supportive and encouraging",
                            isPremium: false,
                            isPlaying: currentlyPlayingVoice == "Girl Bestie",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Girl Bestie",
                            onPlay: { playVoicePreview("Girl Bestie") }
                        )
                        SimpleVoiceCard(
                            name: "Motivational Mike",
                            subtitle: "High-energy motivation",
                            isPremium: false,
                            isPlaying: currentlyPlayingVoice == "Motivational Mike",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Motivational Mike",
                            onPlay: { playVoicePreview("Motivational Mike") }
                        )
                        SimpleVoiceCard(
                            name: "Drill Sergeant Drew",
                            subtitle: "Military-style discipline",
                            isPremium: true,
                            isPlaying: currentlyPlayingVoice == "Drill Sergeant Drew",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Drill Sergeant Drew",
                            onPlay: { playVoicePreview("Drill Sergeant Drew") }
                        )
                        SimpleVoiceCard(
                            name: "Mrs. Walker",
                            subtitle: "Warm Southern encouragement",
                            isPremium: true,
                            isPlaying: currentlyPlayingVoice == "Mrs. Walker",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Mrs. Walker",
                            onPlay: { playVoicePreview("Mrs. Walker") }
                        )
                        SimpleVoiceCard(
                            name: "Calm Kyle",
                            subtitle: "Peaceful zen guidance",
                            isPremium: true,
                            isPlaying: currentlyPlayingVoice == "Calm Kyle",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Calm Kyle",
                            onPlay: { playVoicePreview("Calm Kyle") }
                        )
                        SimpleVoiceCard(
                            name: "Angry Allen",
                            subtitle: "Intense wake-up calls",
                            isPremium: true,
                            isPlaying: currentlyPlayingVoice == "Angry Allen",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Angry Allen",
                            onPlay: { playVoicePreview("Angry Allen") }
                        )
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Upgrade Banner
    
    private var upgradeBanner: some View {
        let usageInfo = usageService.getUsageInfo(isPremium: isPremium)
        let remaining = usageService.getRemainingAlarmCredits(isPremium: isPremium) ?? 0
        
        return Button(action: {
            showPaywall = true
        }) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Upgrade to Premium")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    
                    if let total = usageInfo.total {
                        Text("\(remaining) of \(total) free alarms remaining")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
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
    
    // MARK: - Voice Preview Functions
    
    private func playVoicePreview(_ voiceName: String) {
        // Check if services are ready
        guard container.isFullyInitialized else {
            logger.info("AI services not ready yet")
            return
        }
        
        // Stop any currently playing voice
        stopVoicePreview()
        
        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("Audio session error: \(error)")
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
                // Use safe async resolution
                guard let elevenLabsService: ElevenLabsServiceProtocol = await container.resolveSafe() else {
                    logger.error("ElevenLabs service not available")
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
                        self.logger.error("Audio playback error: \(error)")
                        self.currentlyPlayingVoice = nil
                        self.isLoadingVoicePreview = false
                    }
                }
            } catch {
                logger.error("Voice preview generation failed: \(error)")
                await MainActor.run {
                    self.currentlyPlayingVoice = nil
                    self.isLoadingVoicePreview = false
                }
            }
        }
    }
    
    private func stopVoicePreview() {
        voiceAudioPlayer?.stop()
        voiceAudioPlayer = nil
        currentlyPlayingVoice = nil
        isLoadingVoicePreview = false
    }
}

// ✅ FIXED: VoicesView with proper service loading handling
struct VoicesView: View {
    @StateObject private var container = DependencyContainer.shared
    
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

                        // FREE VOICES (First 2)
                        VoiceCard(
                            name: "Girl Bestie",
                            subtitle: "Supportive and encouraging like your best friend",
                            accent: "Friendly",
                            isSelected: true,
                            isPlaying: currentlyPlayingVoice == "Girl Bestie",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Girl Bestie",
                            onPlay: { playVoicePreview("Girl Bestie") }
                        )
                        VoiceCard(
                            name: "Motivational Mike",
                            subtitle: "High-energy speaker who gets you pumped up",
                            accent: "Energetic",
                            isPlaying: currentlyPlayingVoice == "Motivational Mike",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Motivational Mike",
                            onPlay: { playVoicePreview("Motivational Mike") }
                        )
                        
                        // PREMIUM VOICES
                        VoiceCard(
                            name: "Drill Sergeant Drew",
                            subtitle: "Tough, commanding military-style motivation",
                            accent: "Military",
                            isPremium: true,
                            isPlaying: currentlyPlayingVoice == "Drill Sergeant Drew",
                            isLoading: isLoadingVoicePreview && currentlyPlayingVoice == "Drill Sergeant Drew",
                            onPlay: { playVoicePreview("Drill Sergeant Drew") }
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
            }
            .padding(.horizontal, 16)
        }
        .onDisappear {
            stopVoicePreview()
        }
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

// MARK: - Simple Voice Card (for HomeView)
struct SimpleVoiceCard: View {
    let name: String
    let subtitle: String
    let isPremium: Bool
    var isPlaying: Bool = false
    var isLoading: Bool = false
    var onPlay: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 12) {
            // Voice Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isPremium ? [.purple.opacity(0.3), .blue.opacity(0.3)] : [.green.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isPremium ? .purple : .green)
            }
            
            // Voice Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isPremium {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Play/Stop Button
            Button(action: onPlay) {
                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isPremium ? .purple : .blue)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    MainAppView()
}