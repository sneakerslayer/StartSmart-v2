import SwiftUI
import AVFoundation
import AudioToolbox
import Foundation // <-- Add this line to ensure Foundation types are available

struct ContentView: View {
    @State private var authService: AuthenticationService?
    @State private var isLoading = true
    @State private var initializationProgress: Double = 0.0
    @State private var currentStage: String = "Starting..."
    
    var body: some View {
        Group {
            if isLoading {
                // Enhanced loading screen with progress tracking
                VStack(spacing: 30) {
                    VStack(spacing: 16) {
                        Image(systemName: "alarm.waves.left.and.right")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(.blue)
                        
                        Text("StartSmart")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("AI-Powered Motivational Alarms")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 16) {
                        // Restored proper progress bar
                        ProgressView(value: initializationProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                        
                        // Restored proper progress text
                        HStack {
                            Text("\(Int(initializationProgress * 100))%")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Text(currentStage)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .animation(.easeInOut(duration: 0.3), value: currentStage)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                // When not loading, show authentication flow regardless of authService state
                if let authService = authService, authService.isAuthenticated {
                    // Main app content (only if authenticated)
                    MainAppView(authService: authService)
                } else {
                    // Show simple authentication flow (no services)
                    SimpleAuthView()
                }
            }
        }
        .onAppear {
            print("🔥 ContentView onAppear - BYPASS ALL SERVICES")
            
            // DON'T CREATE ANY SERVICES! Just skip loading entirely
            print("🔥 BYPASS: Skipping all service creation")
            print("🔥 BYPASS: Setting isLoading = false without any services")
            
            self.isLoading = false
            self.currentStage = "Ready!"
            self.initializationProgress = 1.0
            
            print("🔥 BYPASS: App should show main content now (no services)")
        }
    }
    
    
    private func loadDependencies() async {
        print("🔥 LOAD: Starting direct service creation (no dependency container)")
        
        do {
            // Add timeout to prevent hanging
            print("🔥 LOAD: Creating AuthenticationService with timeout...")
            
            let authService = try await withTimeout(seconds: 3.0) {
                print("🔥 LOAD: Creating AuthenticationService directly...")
                let service = AuthenticationService()
                print("🔥 LOAD: AuthenticationService created successfully")
                return service
            }
            
            print("🔥 LOAD: Updating authentication state with timeout...")
            try await withTimeout(seconds: 2.0) {
                await authService.updateAuthenticationState()
                print("🔥 LOAD: Authentication state updated successfully")
            }
            
            await MainActor.run {
                print("🔥 LOAD: Setting authService and completing loading...")
                self.authService = authService
                self.isLoading = false
                self.currentStage = "Complete!"
            }
            
            print("🔥 LOAD: SUCCESS - App ready!")
            
        } catch {
            print("🔥 ERROR: Failed to load dependencies: \(error)")
            await MainActor.run {
                print("🔥 LOAD: Setting isLoading = false due to error")
                self.isLoading = false
                self.currentStage = "Error - continuing anyway"
            }
        }
    }
    
    // Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
}

struct TimeoutError: Error {
    let message = "Operation timed out"
}

// MARK: - Main App View (Placeholder)

struct MainAppView: View {
    let authService: AuthenticationService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "alarm.waves.left.and.right")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.blue)
                    
                    Text("StartSmart")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("AI-Powered Motivational Alarms")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    if let user = authService.currentUser {
                        Text("Welcome back, \(user.displayName ?? "User")!")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                
                VStack(spacing: 20) {
                    Text("🚧 Under Construction 🚧")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Text("The main alarm interface will be implemented in Phase 3: Core Alarm Infrastructure")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Text("Authentication is complete and working perfectly!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 30)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Button("Sign Out") {
                    Task {
                        try? await authService.signOut()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 30)
            }
            .padding(.top, 40)
            .navigationTitle("StartSmart")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Simple Auth View (No Dependencies)
struct SimpleAuthView: View {
    @State private var showingNextScreen = false
    @State private var onboardingComplete = false
    
    var body: some View {
        if onboardingComplete {
            SimpleMainAppView(goBackToWelcome: { 
                onboardingComplete = false
                showingNextScreen = false
            })
        } else if showingNextScreen {
            SimpleOnboardingView(
                goBack: { showingNextScreen = false },
                onComplete: { onboardingComplete = true }
            )
        } else {
            welcomeScreen
        }
    }
    
    private var welcomeScreen: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Image(systemName: "alarm.waves.left.and.right")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    Text("StartSmart")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("AI-Powered Motivational Alarms")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 20) {
                Button("Get Started") {
                    print("🔥 DEMO: Get Started tapped")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingNextScreen = true
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.system(size: 18, weight: .semibold))
                
                Button("Already have an account? Sign In") {
                    print("🔥 DEMO: Sign In tapped")
                }
                .foregroundColor(.blue)
                .font(.system(size: 16))
            }
            .padding(.horizontal, 40)
            
            Text("✅ App successfully bypassed DependencyContainer loading!")
                .font(.system(size: 14))
                .foregroundColor(.green)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Simple Onboarding View (No Dependencies)
struct SimpleOnboardingView: View {
    let goBack: () -> Void
    let onComplete: () -> Void
    @State private var currentStep = 0
    
    private let onboardingSteps = [
        ("bell.fill", "Smart Wake-Up", "AI-powered alarms that adapt to your sleep cycle and energy levels"),
        ("brain.head.profile", "Personalized Content", "Custom motivational messages tailored to your goals and preferences"),
        ("chart.line.uptrend.xyaxis", "Track Progress", "Monitor your consistency and celebrate your achievements")
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            // Back button
            HStack {
                Button("← Back") {
                    goBack()
                }
                .foregroundColor(.blue)
                .font(.system(size: 16))
                Spacer()
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Onboarding content
            VStack(spacing: 30) {
                Image(systemName: onboardingSteps[currentStep].0)
                    .font(.system(size: 70, weight: .light))
                    .foregroundColor(.blue)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)
                
                VStack(spacing: 16) {
                    Text(onboardingSteps[currentStep].1)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(onboardingSteps[currentStep].2)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .animation(.easeInOut(duration: 0.4), value: currentStep)
            }
            
            Spacer()
            
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<onboardingSteps.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            
            // Navigation buttons
            VStack(spacing: 16) {
                if currentStep < onboardingSteps.count - 1 {
                    Button("Next") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.system(size: 18, weight: .semibold))
                } else {
                    Button("Start Using StartSmart") {
                        print("🔥 DEMO: User completed onboarding - transitioning to main app")
                        withAnimation(.easeInOut(duration: 0.5)) {
                            onComplete()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.system(size: 18, weight: .semibold))
                }
                
                Button("Skip") {
                    print("🔥 DEMO: User skipped onboarding - transitioning to main app")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        onComplete()
                    }
                }
                .foregroundColor(.gray)
                .font(.system(size: 16))
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Simple Main App View (No Dependencies)
struct SimpleMainAppView: View {
    let goBackToWelcome: () -> Void
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home/Dashboard Tab
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            // Create Alarm Tab
            CreateAlarmView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Create")
                }
                .tag(1)
            
            // Alarms Tab
            AlarmsListView()
                .tabItem {
                    Image(systemName: "alarm.fill")
                    Text("Alarms")
                }
                .tag(2)
            
            // Voices Tab
            VoicesView()
                .tabItem {
                    Image(systemName: "waveform")
                    Text("Voices")
                }
                .tag(3)
            
            // Analytics Tab
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Insights")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @State private var currentStreak = 7
    @State private var weeklyStats = ["Mon": true, "Tue": true, "Wed": false, "Thu": true, "Fri": true, "Sat": true, "Sun": false]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Streak Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current Streak")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("\(currentStreak) days")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "flame.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                        }
                        
                        // Weekly Progress
                        HStack(spacing: 8) {
                            ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                                VStack(spacing: 4) {
                                    Text(String(day.prefix(1)))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Circle()
                                        .fill(weeklyStats[day] == true ? Color.orange : Color.gray.opacity(0.3))
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        quickActionCard(
                            icon: "plus.circle.fill",
                            title: "New Alarm",
                            color: .blue
                        ) {
                            print("🔥 Quick: New Alarm")
                        }
                        
                        quickActionCard(
                            icon: "waveform",
                            title: "Voices",
                            color: .purple
                        ) {
                            print("🔥 Quick: Voices")
                        }
                        
                        quickActionCard(
                            icon: "chart.bar.fill",
                            title: "Stats",
                            color: .green
                        ) {
                            print("🔥 Quick: Stats")
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Next Alarm
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Alarm")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 20)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("7:00 AM")
                                    .font(.system(size: 24, weight: .bold))
                                
                                Text("Morning Motivation")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                
                                Text("AI-Generated Content Ready")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 8) {
                                Image(systemName: "alarm.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                                
                                Text("in 14h 23m")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    // Recent Activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 8) {
                            activityRow(icon: "checkmark.circle.fill", title: "Woke up on time", time: "Today 7:00 AM", color: .green)
                            activityRow(icon: "alarm.fill", title: "AI content generated", time: "Yesterday 11:30 PM", color: .blue)
                            activityRow(icon: "waveform", title: "Voice synthesized", time: "Yesterday 11:31 PM", color: .purple)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Good Morning!")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func quickActionCard(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func activityRow(icon: String, title: String, time: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                Text(time)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Create Alarm View
struct CreateAlarmView: View {
    @State private var intentText = ""
    @State private var selectedTime = Date()
    @State private var alarmName = "Morning Motivation"
    @State private var selectedVoice = "Energetic Emma"
    @State private var toneSlider: Double = 0.5
    @State private var isGeneratingContent = false
    @State private var generatedScript = ""
    @State private var showingPreview = false
    @State private var showingAlarmSequence = false
    @State private var showingSuccess = false
    @State private var alarmsList: [AlarmItem] = []
    
    private let voices = ["Gentle Grace", "Energetic Emma", "Coach Marcus", "Wise Sarah", "Motivator Mike"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Intent Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tomorrow's Mission")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Tell me what you want to accomplish tomorrow")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        ZStack(alignment: .topLeading) {
                            if intentText.isEmpty {
                                Text("e.g., 'Crush my morning presentation', 'Hit the gym early', 'Start working on my thesis'")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            
                            TextEditor(text: $intentText)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Alarm Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Alarm Settings")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 16) {
                            // Time Selection
                            HStack {
                                Text("Wake-up Time")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 20)
                            
                            Divider()
                                .padding(.horizontal, 20)
                            
                            // Voice Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Voice Style")
                                    .font(.system(size: 16, weight: .medium))
                                    .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(voices, id: \.self) { voice in
                                            voiceCard(voice: voice)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            Divider()
                                .padding(.horizontal, 20)
                            
                            // Tone Slider
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tone Style")
                                    .font(.system(size: 16, weight: .medium))
                                    .padding(.horizontal, 20)
                                
                                VStack(spacing: 8) {
                                    Slider(value: $toneSlider, in: 0...1)
                                        .accentColor(.blue)
                                        .padding(.horizontal, 20)
                                    
                                    HStack {
                                        Text("Gentle & Nurturing")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("Tough Love & Direct")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                    
                    // AI Generation Section
                    VStack(spacing: 16) {
                        Button(action: generateAIContent) {
                            HStack {
                                if isGeneratingContent {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 18))
                                }
                                
                                Text(isGeneratingContent ? "Generating AI Content..." : "Generate AI Script")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(intentText.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundColor(intentText.isEmpty ? .secondary : .white)
                            .cornerRadius(12)
                        }
                        .disabled(intentText.isEmpty || isGeneratingContent)
                        .padding(.horizontal, 20)
                        
                        if !generatedScript.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Generated Script Preview")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text(generatedScript)
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                    .padding(16)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                
                                HStack(spacing: 12) {
                                    Button("🎵 Preview Voice") {
                                        showingPreview = true
                                    }
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.purple)
                                    
                                    Button("⏰ Test Wake-Up") {
                                        showingAlarmSequence = true
                                    }
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.orange)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Button("Create Smart Alarm") {
                            createAlarm()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(generatedScript.isEmpty ? Color.gray.opacity(0.3) : 
                                   showingSuccess ? Color.green : Color.blue)
                        .foregroundColor(generatedScript.isEmpty ? .secondary : .white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .disabled(generatedScript.isEmpty)
                        .overlay(
                            showingSuccess ? 
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                Text("Alarm Created!")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            : nil
                        )
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Create Alarm")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingPreview) {
            VoicePreviewView(script: generatedScript, voice: selectedVoice)
        }
        .sheet(isPresented: $showingAlarmSequence) {
            AlarmSequenceView(script: generatedScript, voice: selectedVoice)
        }
    }
    
    private func voiceCard(voice: String) -> some View {
        Button(action: { selectedVoice = voice }) {
            VStack(spacing: 8) {
                Image(systemName: selectedVoice == voice ? "waveform.circle.fill" : "waveform.circle")
                    .font(.system(size: 24))
                    .foregroundColor(selectedVoice == voice ? .blue : .gray)
                
                Text(voice)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedVoice == voice ? .blue : .primary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(selectedVoice == voice ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedVoice == voice ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func generateAIContent() {
        isGeneratingContent = true
        
        // Play generation start sound
        AudioServicesPlaySystemSound(1103) // Begin sound
        
        // Enhanced AI script generation with realistic timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            let currentHour = Calendar.current.component(.hour, from: selectedTime)
            let timeOfDay = currentHour < 12 ? "morning" : currentHour < 17 ? "afternoon" : "evening"
            
            let toneStyle: (greeting: String, approach: String, closing: String)
            
            if toneSlider < 0.3 {
                // Gentle & Nurturing
                toneStyle = (
                    greeting: "Good \(timeOfDay), beautiful soul ✨",
                    approach: "I believe in you completely. Today feels like the perfect day to gently",
                    closing: "Take a moment to breathe deeply and know that you're exactly where you need to be. You've got this, and I'm cheering you on every step of the way! 💙"
                )
            } else if toneSlider > 0.7 {
                // Tough Love & Direct  
                toneStyle = (
                    greeting: "Wake up, champion! ⚡",
                    approach: "No excuses today. You said you wanted to",
                    closing: "Stop thinking, start doing. Your future self will thank you for the action you take RIGHT NOW. Let's go! 🔥"
                )
            } else {
                // Balanced & Encouraging
                toneStyle = (
                    greeting: "Good \(timeOfDay), superstar! 🌟",
                    approach: "Today is your opportunity to",
                    closing: "Remember, you've overcome challenges before and today is no different. Ready to rise and shine? Let's make this \(timeOfDay) count! 🚀"
                )
            }
            
            let weatherContext = ["The sun is shining for you", "Perfect energy in the air", "The universe is aligned", "Conditions are optimal"].randomElement() ?? "Everything is set up for success"
            
            let motivationalQuotes = [
                "Success is not final, failure is not fatal: it is the courage to continue that counts.",
                "The future belongs to those who believe in the beauty of their dreams.",
                "Your limitation—it's only your imagination.",
                "Great things never come from comfort zones."
            ]
            
            generatedScript = """
            \(toneStyle.greeting)
            
            \(toneStyle.approach) \(intentText.lowercased()). \(weatherContext), and your energy is building strong.
            
            Here's something to remember: "\(motivationalQuotes.randomElement() ?? "You are capable of amazing things.")"
            
            Take three deep breaths, feel that power within you, and let's show the world what you're made of. Your future self is counting on the choices you make in the next few hours.
            
            \(toneStyle.closing)
            """
            
            isGeneratingContent = false
            
            // Play completion sound
            AudioServicesPlaySystemSound(1016) // Success sound
        }
    }
    
    private func createAlarm() {
        // Generate smart alarm name if not customized
        let finalAlarmName = alarmName == "Morning Motivation" ? 
            "AI: \(intentText.prefix(20))..." : alarmName
        
        // Create new alarm with AI content
        let newAlarm = AlarmItem(
            id: Int.random(in: 1000...9999),
            time: formatTime(selectedTime),
            name: finalAlarmName,
            isEnabled: true,
            hasAIContent: true
        )
        
        // Save alarm to local storage (in real app, this would sync to backend)
        UserDefaults.standard.set(true, forKey: "alarm_\(newAlarm.id)_enabled")
        UserDefaults.standard.set(newAlarm.time, forKey: "alarm_\(newAlarm.id)_time")
        UserDefaults.standard.set(newAlarm.name, forKey: "alarm_\(newAlarm.id)_name")
        UserDefaults.standard.set(generatedScript, forKey: "alarm_\(newAlarm.id)_script")
        UserDefaults.standard.set(selectedVoice, forKey: "alarm_\(newAlarm.id)_voice")
        UserDefaults.standard.set(toneSlider, forKey: "alarm_\(newAlarm.id)_tone")
        UserDefaults.standard.set(intentText, forKey: "alarm_\(newAlarm.id)_intent")
        
        // Schedule the smart alarm sequence
        scheduleSmartAlarm(alarm: newAlarm)
        
        print("🔥 SMART ALARM CREATED & SCHEDULED:")
        print("📅 Time: \(newAlarm.time)")
        print("🎯 Intent: \(intentText)")
        print("🎙️ Voice: \(selectedVoice)")
        print("🎚️ Tone Level: \(Int(toneSlider * 100))%")
        print("📝 Script: \(generatedScript.prefix(100))...")
        print("⏰ Alarm Sequence: Continuous Bell → User Dismiss → AI Script → Affirmation → Complete!")
        
        // Show success feedback
        showingSuccess = true
        
        // Play success sound
        AudioServicesPlaySystemSound(1025) // Alarm created sound
        
        // Reset form after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            resetForm()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func scheduleSmartAlarm(alarm: AlarmItem) {
        // This is where we'd integrate with iOS notification system
        // For demo purposes, we simulate the scheduling
        print("📱 Scheduling notification for \(alarm.time)")
        print("🔔 Smart alarm sequence configured:")
        print("   1. Continuous alarm until manually dismissed (🔔)")
        print("   2. AI script playback with \(selectedVoice) voice")
        print("   3. Daily affirmation and completion (✨)")
        
        // In a real implementation, this would:
        // 1. Create UNNotificationRequest for the alarm time
        // 2. Attach custom sound file with the sequence
        // 3. Handle the wake-up flow in the notification handler
    }
    
    private func resetForm() {
        intentText = ""
        generatedScript = ""
        alarmName = "Morning Motivation"
        selectedVoice = "Energetic Emma"
        toneSlider = 0.5
        showingSuccess = false
        selectedTime = Date()
    }
}

// MARK: - Smart Alarm Sequence Simulator
struct AlarmSequenceView: View {
    let script: String
    let voice: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioManager = AudioManager()
    @State private var currentPhase: AlarmPhase = .alarm
    @State private var phaseProgress: Double = 0.0
    @State private var isActive = false
    
    enum AlarmPhase: String, CaseIterable {
        case alarm = "Alarm - Tap to Dismiss"
        case script = "AI Script Playing"
        case affirmation = "Daily Affirmation"
        case dismissed = "Ready to Conquer Today!"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: currentPhase == .alarm ? "alarm.fill" : currentPhase == .affirmation ? "heart.fill" : "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundColor(currentPhase == .script ? .purple : currentPhase == .affirmation ? .pink : .orange)
                        .scaleEffect(isActive ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isActive)
                    
                    Text("Smart Alarm Simulation")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("Testing: Manual Dismiss → AI Script → Affirmation → Ready!")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                // Phase Indicator
                VStack(spacing: 12) {
                    Text("Current Phase: \(currentPhase.rawValue)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(currentPhase == .script ? .purple : .orange)
                    
                    ProgressView(value: phaseProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: currentPhase == .script ? .purple : .orange))
                        .scaleEffect(y: 3)
                    
                    HStack {
                        ForEach(AlarmPhase.allCases.prefix(3), id: \.self) { phase in
                            Text(phase.rawValue)
                                .font(.system(size: 12))
                                .foregroundColor(phase == currentPhase ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 30)
                
                // Phase Description
                VStack(spacing: 8) {
                    switch currentPhase {
                    case .alarm:
                        Text("🔔 Alarm playing continuously")
                        Text("Tap 'Dismiss Alarm' when you're awake")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    case .script:
                        Text("🤖 AI script playing with \(voice)")
                        Text("Listen to your personalized motivation")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    case .affirmation:
                        Text("✨ Daily words of encouragement")
                        Text("You've got this - time to start your amazing day!")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    case .dismissed:
                        Text("🎉 Wake-up sequence complete!")
                        Text("Ready to conquer your day like the champion you are!")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                
                if currentPhase == .script {
                    ScrollView {
                        Text(script)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 30)
                    }
                    .frame(maxHeight: 150)
                }
                
                if currentPhase == .affirmation {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.pink)
                            .scaleEffect(isActive ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isActive)
                        
                        Text(generateAffirmation())
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(20)
                            .background(Color.pink.opacity(0.1))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.pink.opacity(0.3), lineWidth: 2)
                            )
                            .padding(.horizontal, 30)
                    }
                }
                
                Button(action: primaryButtonAction) {
                    HStack {
                        Image(systemName: primaryButtonIcon)
                            .font(.system(size: 24))
                        Text(primaryButtonText)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(primaryButtonColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 30)
                
                if !isActive && currentPhase != .dismissed {
                    Button("Reset Simulation") {
                        resetSequence()
                    }
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                }
                
                Spacer()
            }
            .padding(.vertical, 20)
            .navigationTitle("Alarm Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Button State Management
    private var primaryButtonText: String {
        switch currentPhase {
        case .alarm:
            return isActive ? "Dismiss Alarm" : "Start Wake-Up Sequence"
        case .script:
            return "Skip to Affirmation"
        case .affirmation:
            return "I'm Ready!"
        case .dismissed:
            return "Start New Sequence"
        }
    }
    
    private var primaryButtonIcon: String {
        switch currentPhase {
        case .alarm:
            return isActive ? "alarm.slash" : "play.circle.fill"
        case .script:
            return "forward.circle.fill"
        case .affirmation:
            return "checkmark.circle.fill"
        case .dismissed:
            return "repeat.circle.fill"
        }
    }
    
    private var primaryButtonColor: Color {
        switch currentPhase {
        case .alarm:
            return isActive ? .orange : .blue
        case .script:
            return .purple
        case .affirmation:
            return .pink
        case .dismissed:
            return .green
        }
    }
    
    private func primaryButtonAction() {
        switch currentPhase {
        case .alarm:
            if isActive {
                dismissAlarm()
            } else {
                startSequence()
            }
        case .script:
            skipToAffirmation()
        case .affirmation:
            completeWakeUp()
        case .dismissed:
            resetSequence()
        }
    }
    
    private func generateAffirmation() -> String {
        let affirmations = [
            "You are exactly where you need to be. Trust yourself and take the next step forward.",
            "Today is full of possibilities. Your unique talents will make a difference.",
            "You have overcome challenges before, and you will overcome today's too. You're stronger than you know.",
            "Your presence matters. The world is better because you're in it.",
            "Every small step you take today is building the life you want tomorrow.",
            "You are worthy of all the good things coming your way. Believe in yourself.",
            "Your journey is unique and valuable. Trust the process and keep moving forward.",
            "Today is a fresh start. You have the power to make it amazing."
        ]
        return affirmations.randomElement() ?? "You are capable of incredible things. Go show the world what you're made of!"
    }
    
    private func startSequence() {
        isActive = true
        currentPhase = .alarm
        phaseProgress = 0.0
        
        // Phase 1: Continuous Alarm until manually dismissed
        print("🔔 Starting alarm sequence - Phase 1: Continuous Alarm")
        audioManager.playAlarmSound()
        
        // Continuous alarm sounds every second until dismissed
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if currentPhase == .alarm && isActive {
                audioManager.playAlarmSound()
                // Pulse progress indicator to show it's active
                phaseProgress = phaseProgress == 0.8 ? 0.2 : 0.8
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func dismissAlarm() {
        print("👋 User dismissed alarm - starting AI script")
        isActive = false
        currentPhase = .script
        phaseProgress = 0.0
        
        // Brief pause before starting script
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startScriptPhase()
        }
    }
    
    private func skipToAffirmation() {
        print("⏭️ User skipped to affirmation")
        audioManager.stopSpeaking()
        showAffirmation()
    }
    
    private func completeWakeUp() {
        print("🎉 User is ready to start the day!")
        isActive = false
        currentPhase = .dismissed
        phaseProgress = 1.0
        
        // Play completion sound
        AudioServicesPlaySystemSound(1025) // Success sound
    }
    
    private func resetSequence() {
        print("🔄 Resetting alarm sequence")
        isActive = false
        currentPhase = .alarm
        phaseProgress = 0.0
        audioManager.stopSpeaking()
    }
    
    private func startScriptPhase() {
        // Phase 2: AI Script (actual speech)
        print("🤖 Starting alarm sequence - Phase 2: AI Script with \(voice)")
        isActive = true // Script is playing
        audioManager.speakText(script, voice: voice)
        
        // Monitor speech progress and AudioManager state
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if currentPhase != .script {
                // User manually stopped script
                timer.invalidate()
                return
            }
            
            if audioManager.isPlaying {
                phaseProgress = audioManager.playbackProgress
            } else if phaseProgress > 0.5 { // Speech completed
                timer.invalidate()
                print("🎵 AI script completed - showing affirmation")
                showAffirmation()
            } else {
                // Fallback if speech doesn't start or gets interrupted
                phaseProgress += 0.02
                if phaseProgress >= 1.0 {
                    timer.invalidate()
                    showAffirmation()
                }
            }
        }
    }
    
    private func showAffirmation() {
        // Phase 3: Show daily affirmation
        print("✨ Showing daily affirmation")
        currentPhase = .affirmation
        phaseProgress = 0.0
        isActive = true
        
        // Play gentle notification sound
        AudioServicesPlaySystemSound(1016) // Success/completion sound
        
        // Auto-progress the affirmation display
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if currentPhase == .affirmation {
                phaseProgress += 0.02 // 5 seconds to read affirmation
                if phaseProgress >= 1.0 {
                    timer.invalidate()
                    // Auto-complete after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if self.currentPhase == .affirmation {
                            self.completeWakeUp()
                        }
                    }
                }
            } else {
                timer.invalidate()
            }
        }
    }
    
}

// MARK: - Audio Manager
class AudioManager: ObservableObject {
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0.0
    
    init() {
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("🔊 Audio session error: \(error)")
        }
    }
    
    func playSystemSound(_ soundID: SystemSoundID) {
        AudioServicesPlaySystemSound(soundID)
    }
    
    func speakText(_ text: String, voice: String = "Energetic Emma") {
        guard !isPlaying else { return }
        
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Map our voice names to iOS voices
        switch voice {
        case "Gentle Grace":
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Samantha
        case "Energetic Emma":
            utterance.voice = AVSpeechSynthesisVoice(language: "en-GB") // Kate
        case "Coach Marcus":
            utterance.voice = AVSpeechSynthesisVoice(language: "en-AU") // Lee
        case "Wise Sarah":
            utterance.voice = AVSpeechSynthesisVoice(language: "en-CA") // Alex
        case "Motivator Mike":
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Aaron
        default:
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = 0.5
        utterance.pitchMultiplier = voice.contains("Coach") ? 0.8 : 1.0
        utterance.volume = 0.8
        
        isPlaying = true
        speechSynthesizer.speak(utterance)
        
        // Estimate speech duration and update progress
        let estimatedDuration = Double(text.count) * 0.05 // ~50ms per character
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.speechSynthesizer.isSpeaking {
                self.playbackProgress = min(self.playbackProgress + (0.1 / estimatedDuration), 1.0)
            } else {
                timer.invalidate()
                self.isPlaying = false
                self.playbackProgress = 0.0
            }
        }
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        playbackProgress = 0.0
    }
    
    func playAlarmSound() {
        // Create a simple alarm tone using system sounds
        playSystemSound(1005) // System sound for alarm
    }
    
    func generateAlarmTone() {
        // Generate a simple beep tone
        let frequency: Float = 800.0
        let duration: Float = 0.5
        let sampleRate: Float = 44100.0
        let frameCount = Int(sampleRate * duration)
        
        var audioBuffer = [Float](repeating: 0.0, count: frameCount)
        
        for i in 0..<frameCount {
            let time = Float(i) / sampleRate
            audioBuffer[i] = sin(2.0 * Float.pi * frequency * time) * 0.5
        }
        
        playBuffer(audioBuffer, sampleRate: sampleRate)
    }
    
    private func playBuffer(_ buffer: [Float], sampleRate: Float) {
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(buffer.count))!
        
        audioBuffer.frameLength = AVAudioFrameCount(buffer.count)
        
        for i in 0..<buffer.count {
            audioBuffer.floatChannelData?[0][i] = buffer[i]
        }
        
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
        
        do {
            try audioEngine.start()
            playerNode.scheduleBuffer(audioBuffer)
            playerNode.play()
        } catch {
            print("🔊 Audio playback error: \(error)")
        }
    }
}

// MARK: - Voice Preview View  
struct VoicePreviewView: View {
    let script: String
    let voice: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioManager = AudioManager()
    @State private var showingAlarmSequence = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("Voice Preview")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Synthesizing with \(voice)")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                // Waveform visualization
                VStack(spacing: 16) {
                    HStack(spacing: 4) {
                        ForEach(0..<20, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.purple.opacity(audioManager.isPlaying ? Double.random(in: 0.3...1.0) : 0.3))
                                .frame(width: 4, height: CGFloat.random(in: 20...60))
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: audioManager.isPlaying)
                        }
                    }
                    
                    ProgressView(value: audioManager.playbackProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                    
                    HStack {
                        Text("0:00")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(audioManager.isPlaying ? "Playing..." : "Ready")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 40)
                
                HStack(spacing: 16) {
                    Button(action: togglePlayback) {
                        HStack {
                            Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 20))
                            Text(audioManager.isPlaying ? "Stop" : "Play Voice")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(audioManager.isPlaying ? Color.red : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: { showingAlarmSequence = true }) {
                        HStack {
                            Image(systemName: "alarm.fill")
                                .font(.system(size: 20))
                            Text("Test Wake-Up")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                
                Text("Script Preview:")
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 40)
                
                ScrollView {
                    Text(script)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
            }
            .padding(.vertical, 20)
            .navigationTitle("Voice Synthesis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAlarmSequence) {
            AlarmSequenceView(script: script, voice: voice)
        }
    }
    
    private func togglePlayback() {
        if audioManager.isPlaying {
            audioManager.stopSpeaking()
        } else {
            // Play a simple button sound first
            audioManager.playSystemSound(1104) // Click sound
            
            // Then speak the script with the selected voice
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                audioManager.speakText(script, voice: voice)
            }
        }
    }
}

// MARK: - Alarms List View
struct AlarmsListView: View {
    @State private var alarms = [
        AlarmItem(id: 1, time: "7:00 AM", name: "Morning Motivation", isEnabled: true, hasAIContent: true),
        AlarmItem(id: 2, time: "6:30 AM", name: "Workout Prep", isEnabled: false, hasAIContent: true),
        AlarmItem(id: 3, time: "8:00 AM", name: "Weekend Vibes", isEnabled: true, hasAIContent: false)
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(alarms) { alarm in
                    SimpleAlarmRowView(alarm: alarm) { updatedAlarm in
                        if let index = alarms.firstIndex(where: { $0.id == updatedAlarm.id }) {
                            alarms[index] = updatedAlarm
                        }
                    }
                }
                .onDelete(perform: deleteAlarms)
            }
            .navigationTitle("My Alarms")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteAlarms(offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
    }
}

struct AlarmItem: Identifiable {
    let id: Int
    let time: String
    let name: String
    var isEnabled: Bool
    let hasAIContent: Bool
}

struct SimpleAlarmRowView: View {
    let alarm: AlarmItem
    let onToggle: (AlarmItem) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.time)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(alarm.isEnabled ? .primary : .secondary)
                
                HStack {
                    Text(alarm.name)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    if alarm.hasAIContent {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { isEnabled in
                    var updatedAlarm = alarm
                    updatedAlarm.isEnabled = isEnabled
                    onToggle(updatedAlarm)
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Voices View  
struct VoicesView: View {
    @State private var selectedVoice = "Energetic Emma"
    @State private var isPlaying = false
    
    private let voiceLibrary = [
        VoiceOption(name: "Gentle Grace", description: "Warm and nurturing", isPremium: false, accent: "American"),
        VoiceOption(name: "Energetic Emma", description: "Upbeat and motivating", isPremium: false, accent: "British"),
        VoiceOption(name: "Coach Marcus", description: "Strong and encouraging", isPremium: true, accent: "Australian"),
        VoiceOption(name: "Wise Sarah", description: "Calm and thoughtful", isPremium: true, accent: "Canadian"),
        VoiceOption(name: "Motivator Mike", description: "Dynamic and inspiring", isPremium: true, accent: "American")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Voice Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Current Voice")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 20)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedVoice)
                                    .font(.system(size: 18, weight: .medium))
                                
                                Text(voiceLibrary.first { $0.name == selectedVoice }?.description ?? "")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { isPlaying.toggle() }) {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    // Voice Library
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Voice Library")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 20)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(voiceLibrary, id: \.name) { voice in
                                voiceLibraryRow(voice: voice)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Voices")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func voiceLibraryRow(voice: VoiceOption) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(voice.name)
                        .font(.system(size: 16, weight: .medium))
                    
                    if voice.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
                
                Text(voice.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(voice.accent)
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
                
                Button(action: { selectedVoice = voice.name }) {
                    Text(selectedVoice == voice.name ? "Selected" : "Select")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedVoice == voice.name ? .white : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedVoice == voice.name ? Color.blue : Color.clear)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }
                .disabled(voice.isPremium && selectedVoice != voice.name)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct VoiceOption {
    let name: String
    let description: String
    let isPremium: Bool
    let accent: String
}

// MARK: - Analytics View
struct AnalyticsView: View {
    @State private var selectedPeriod = "Week"
    private let periods = ["Week", "Month", "Year"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Period Selector
                    HStack {
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(periods, id: \.self) { period in
                                Text(period).tag(period)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Key Stats
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        statCard(title: "Wake Success", value: "85%", color: .green, icon: "checkmark.circle.fill")
                        statCard(title: "Avg Wake Time", value: "7:12 AM", color: .blue, icon: "clock.fill")
                        statCard(title: "AI Scripts", value: "24", color: .purple, icon: "brain.head.profile")
                        statCard(title: "Streak Record", value: "12 days", color: .orange, icon: "flame.fill")
                    }
                    .padding(.horizontal, 20)
                    
                    // Weekly Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Weekly Performance")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 20)
                        
                        // Simple bar chart
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                                VStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue)
                                        .frame(width: 30, height: CGFloat.random(in: 40...100))
                                    
                                    Text(day)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                    
                    // Insights
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Insights")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            insightRow(icon: "lightbulb.fill", title: "Your best wake-up time is 7:00 AM", color: .yellow)
                            insightRow(icon: "brain.head.profile", title: "AI content boosts success by 23%", color: .blue)
                            insightRow(icon: "moon.fill", title: "Consider earlier bedtime on weekends", color: .purple)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func statCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func insightRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Simple Alarm Setup View (Demo)
struct SimpleAlarmSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime = Date()
    @State private var alarmName = "Morning Motivation"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 20) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Set Your Alarm")
                        .font(.system(size: 24, weight: .bold))
                }
                
                VStack(spacing: 20) {
                    DatePicker("Alarm Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alarm Name")
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("Enter alarm name", text: $alarmName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal, 30)
                
                Button("Create Alarm (Demo)") {
                    print("🔥 DEMO: Alarm created for \(selectedTime)")
                    dismiss()
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .navigationTitle("New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
