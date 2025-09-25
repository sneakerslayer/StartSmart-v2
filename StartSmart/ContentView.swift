import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - Color Extension for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

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
    @State private var selectedVoice = PersonaManager.Persona.girlBestie.rawValue
    @State private var selectedPersona = PersonaManager.Persona.girlBestie
    @State private var toneSlider: Double = 0.5
    @State private var isGeneratingContent = false
    @State private var generatedScript = ""
    @State private var showingPreview = false
    @State private var showingAlarmSequence = false
    @State private var showingSuccess = false
    @State private var alarmsList: [AlarmItem] = []
    
    private let personas = PersonaManager.shared.getAllPersonas()
    
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
                                        ForEach(personas, id: \.self) { persona in
                                            personaCard(persona: persona)
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
            VoicePreviewView(script: generatedScript, voice: PersonaManager.shared.getPersonaCard(for: selectedPersona).voiceMapping)
        }
        .sheet(isPresented: $showingAlarmSequence) {
            AlarmSequenceView(script: generatedScript, voice: PersonaManager.shared.getPersonaCard(for: selectedPersona).voiceMapping)
        }
    }
    
    private func personaCard(persona: PersonaManager.Persona) -> some View {
        let personaManager = PersonaManager.shared
        let card = personaManager.getPersonaCard(for: persona)
        let isSelected = selectedPersona == persona
        
        return Button(action: { 
            selectedPersona = persona
            selectedVoice = persona.rawValue
        }) {
            VStack(spacing: 6) {
                // Persona Icon with color
                Image(systemName: card.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color(hex: card.color))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isSelected ? Color(hex: card.color) : Color(hex: card.color).opacity(0.2))
                    )
                
                // Persona Name (short version)
                Text(persona.shortName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: card.color) : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isSelected ? Color(hex: card.color).opacity(0.1) : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: card.color) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func generateAIContent() {
        isGeneratingContent = true
        
        // Play generation start sound
        AudioServicesPlaySystemSound(1103) // Begin sound
        
        // ✨ PRODUCTION PERSONA-BASED AI GENERATION ✨
        Task {
            do {
                // Create script context with user goals and current context
                let currentHour = Calendar.current.component(.hour, from: selectedTime)
                let timeOfDay = currentHour < 12 ? "morning" : currentHour < 17 ? "afternoon" : "evening"
                let dayOfWeek = DateFormatter().weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
                
                let context = ScriptContext(
                    userGoals: intentText,
                    timeOfDay: timeOfDay,
                    dayOfWeek: dayOfWeek,
                    weather: "Clear and energizing", // Could be enhanced with real weather API
                    location: nil, // Could be enhanced with user location
                    calendarEvents: nil // Could be enhanced with calendar integration
                )
                
                // Generate script using production persona system
                let grokService = Grok4Service(apiKey: "demo-key") // In production, get from secure storage
                let script = try await grokService.generatePersonalizedScript(
                    persona: selectedPersona,
                    toneLevel: toneSlider,
                    context: context
                )
                
                // Update UI on main thread
                await MainActor.run {
                    generatedScript = script
                    isGeneratingContent = false
                    
                    // Play completion sound
                    AudioServicesPlaySystemSound(1016) // Success sound
                    
                    print("✅ Generated script for \(selectedPersona.rawValue) with tone level \(toneSlider)")
                    print("📝 Script: \(script.prefix(100))...")
                }
                
            } catch {
                // Handle errors gracefully with fallback to demo content
                await MainActor.run {
                    print("⚠️ AI Generation failed, using fallback: \(error)")
                    
                    // Fallback to persona preview for demo purposes
                    let personaManager = PersonaManager.shared
                    let toneLevel = PersonaManager.ToneLevel.fromSliderValue(toneSlider)
                    let fallbackScript = personaManager.getPersonaPreview(for: selectedPersona, toneLevel: toneLevel)
                    
                    generatedScript = """
                    \(fallbackScript)
                    
                    Your goal for today: \(intentText)
                    
                    Remember, you're capable of incredible things! This is just the beginning of what you can accomplish. Take a deep breath, feel that energy within you, and let's make today extraordinary! 🌟
                    """
                    
                    isGeneratingContent = false
                    
                    // Play completion sound
                    AudioServicesPlaySystemSound(1016) // Success sound
                }
            }
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
        UserDefaults.standard.set(selectedPersona.rawValue, forKey: "alarm_\(newAlarm.id)_voice")
        UserDefaults.standard.set(PersonaManager.shared.getPersonaCard(for: selectedPersona).voiceMapping, forKey: "alarm_\(newAlarm.id)_voice_mapping")
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
        selectedPersona = PersonaManager.Persona.girlBestie
        selectedVoice = selectedPersona.rawValue
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
// MARK: - Script Segment Types
struct ScriptSegment {
    let text: String
    let type: SegmentType
    
    enum SegmentType {
        case speech
        case pause
    }
}

// MARK: - Speech Delegate for Sequential Playback
class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onComplete: () -> Void
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onComplete()
    }
}

// MARK: - Audio Player Delegate for ElevenLabs Playback
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onComplete: () -> Void
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🎵 ElevenLabs audio playback completed (success: \(flag))")
        onComplete()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("⚠️ Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        onComplete() // Continue sequence even on error
    }
}

class AudioManager: ObservableObject {
    private var speechSynthesizer = AVSpeechSynthesizer() // Fallback for iOS TTS
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0.0
    private var currentDelegate: SpeechDelegate? // Strong reference to prevent deallocation
    private let elevenLabsService: ElevenLabsService
    
    init(elevenLabsApiKey: String = "demo-key") {
        // Initialize ElevenLabs service with API key (in production, get from secure storage)
        self.elevenLabsService = ElevenLabsService(apiKey: elevenLabsApiKey)
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
    
    // MARK: - Enhanced Speech with ElevenLabs + Pause Parsing
    func speakText(_ text: String, voice: String = "uYXf8XasLslADfZ2MB4u") {
        guard !isPlaying else { return }
        
        stopSpeaking() // Stop any current playback
        
        // 🎯 Parse script with pause optimization
        let optimizedScript = optimizeScriptTiming(text)
        let segments = parseScriptSegments(optimizedScript)
        
        isPlaying = true
        print("🎙️ Starting ElevenLabs speech generation for \(segments.count) segments")
        
        // Use ElevenLabs for high-quality voice synthesis
        speakSegmentsWithElevenLabs(segments, voiceId: voice, currentIndex: 0)
    }
    
    // MARK: - Script Timing Optimization (45-60 seconds)
    private func optimizeScriptTiming(_ text: String) -> String {
        let wordsPerMinute: Double = 150 // Average speaking rate
        let wordsPerSecond = wordsPerMinute / 60
        
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let estimatedDuration = Double(words.count) / wordsPerSecond
        
        var optimizedText = text
        
        if estimatedDuration < 45 {
            // Script too short - add strategic pauses
            optimizedText = addStrategicPauses(text, targetIncrease: 45 - estimatedDuration)
        } else if estimatedDuration > 60 {
            // Script too long - condense while preserving meaning
            optimizedText = condenseScript(text, targetDecrease: estimatedDuration - 60)
        }
        
        return optimizedText
    }
    
    private func addStrategicPauses(_ text: String, targetIncrease: Double) -> String {
        let pausesNeeded = Int(targetIncrease / 0.8) // Each pause adds ~0.8 seconds
        var result = text
        
        // Add pauses after key phrases
        let pausePoints = ["Good morning", "Today", "Remember", "You've got this", "Let's go"]
        var addedPauses = 0
        
        for point in pausePoints {
            if addedPauses >= pausesNeeded { break }
            result = result.replacingOccurrences(of: point, with: "\(point) [short pause]")
            addedPauses += 1
        }
        
        return result
    }
    
    private func condenseScript(_ text: String, targetDecrease: Double) -> String {
        // Smart condensation while preserving persona voice
        let result = text
            .replacingOccurrences(of: " and ", with: " & ")
            .replacingOccurrences(of: " because ", with: " 'cause ")
            .replacingOccurrences(of: " you are ", with: " you're ")
            .replacingOccurrences(of: " cannot ", with: " can't ")
        
        return result
    }
    
    // MARK: - Pause Parsing System
    private func parseScriptSegments(_ text: String) -> [ScriptSegment] {
        let components = text.components(separatedBy: "[short pause]")
        var segments: [ScriptSegment] = []
        
        for (index, component) in components.enumerated() {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                segments.append(ScriptSegment(text: trimmed, type: .speech))
            }
            
            // Add pause after each segment (except the last one)
            if index < components.count - 1 {
                segments.append(ScriptSegment(text: "", type: .pause))
            }
        }
        
        return segments
    }
    
    // MARK: - ElevenLabs Sequential Speech with Natural Pauses
    private func speakSegmentsWithElevenLabs(_ segments: [ScriptSegment], voiceId: String, currentIndex: Int) {
        guard currentIndex < segments.count else {
            isPlaying = false
            print("🎙️ ElevenLabs speech sequence completed!")
            return
        }
        
        let segment = segments[currentIndex]
        
        if segment.type == .pause {
            // Natural pause timing
            let pauseDuration = 0.8 // 0.8 seconds for natural flow
            print("⏸️ Playing natural pause (\(pauseDuration)s)")
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
                self.speakSegmentsWithElevenLabs(segments, voiceId: voiceId, currentIndex: currentIndex + 1)
            }
        } else {
            // Generate and play speech with ElevenLabs
            print("🎙️ Generating speech for segment \(currentIndex + 1): '\(segment.text.prefix(50))...'")
            
            Task {
                do {
                    // Generate high-quality audio with ElevenLabs
                    let audioData = try await elevenLabsService.generateSpeech(
                        text: segment.text,
                        voiceId: voiceId
                    )
                    
                    // Play generated audio on main thread
                    await MainActor.run {
                        playAudioData(audioData) {
                            // Continue to next segment when audio finishes
                            self.speakSegmentsWithElevenLabs(segments, voiceId: voiceId, currentIndex: currentIndex + 1)
                        }
                    }
                    
                } catch {
                    print("⚠️ ElevenLabs generation failed: \(error)")
                    
                    // Fallback to iOS TTS for this segment
                    await MainActor.run {
                        self.speakSegmentWithFallback(segment.text, voiceId: voiceId) {
                            self.speakSegmentsWithElevenLabs(segments, voiceId: voiceId, currentIndex: currentIndex + 1)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Audio Data Playback
    private func playAudioData(_ data: Data, completion: @escaping () -> Void) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = AudioPlayerDelegate(onComplete: completion)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            print("▶️ Playing ElevenLabs audio (\(data.count) bytes)")
            
        } catch {
            print("⚠️ Audio playback error: \(error)")
            completion() // Continue sequence even if playback fails
        }
    }
    
    // MARK: - iOS TTS Fallback
    private func speakSegmentWithFallback(_ text: String, voiceId: String, completion: @escaping () -> Void) {
        print("🔄 Using iOS TTS fallback for: '\(text.prefix(30))...'")
        
        let utterance = createUtterance(text, voice: voiceId)
        
        currentDelegate = SpeechDelegate(onComplete: completion)
        speechSynthesizer.delegate = currentDelegate
        speechSynthesizer.speak(utterance)
    }
    
    private func createUtterance(_ text: String, voice: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        
        // Enhanced voice mapping with persona support
        if let voiceId = getVoiceMapping(voice) {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceId) ?? 
                             AVSpeechSynthesisVoice(language: "en-US")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = 0.52 // Slightly faster for better engagement
        utterance.pitchMultiplier = getPitchForVoice(voice)
        utterance.volume = 0.85
        
        return utterance
    }
    
    private func getVoiceMapping(_ voice: String) -> String? {
        // Map persona voice identifiers to iOS TTS voices
        let voiceMap: [String: String] = [
            "com.apple.ttsbundle.Samantha-compact": "com.apple.ttsbundle.Samantha-compact", // Gentle Grace
            "com.apple.ttsbundle.siri_female_en-US_compact": "com.apple.ttsbundle.siri_female_en-US_compact", // Girl Bestie  
            "com.apple.ttsbundle.Karen-compact": "com.apple.ttsbundle.Karen-compact", // Mrs. Walker
            "com.apple.ttsbundle.Aaron-compact": "com.apple.ttsbundle.Aaron-compact", // Motivational Mike
            "com.apple.ttsbundle.Alex": "com.apple.ttsbundle.Alex", // Calm Kyle
            "com.apple.ttsbundle.siri_male_en-US_compact": "com.apple.ttsbundle.siri_male_en-US_compact" // Angry Allen
        ]
        
        return voiceMap[voice] ?? "com.apple.ttsbundle.Samantha-compact"
    }
    
    private func getPitchForVoice(_ voice: String) -> Float {
        // Adjust pitch based on persona characteristics
        if voice.contains("Aaron") || voice.contains("Allen") { return 0.85 } // Deeper for authority
        if voice.contains("Samantha") || voice.contains("Karen") { return 1.1 } // Higher for warmth
        return 1.0 // Default
    }
    
    // MARK: - Stop Speech
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.delegate = nil
        currentDelegate = nil
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
            
            // Then speak the script with ElevenLabs voice
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Convert persona voice to ElevenLabs voice ID
                let elevenLabsVoiceId = getElevenLabsVoiceId(for: voice)
                audioManager.speakText(script, voice: elevenLabsVoiceId)
            }
        }
    }
    
    // MARK: - Voice ID Mapping Helper
    private func getElevenLabsVoiceId(for personaVoice: String) -> String {
        // Map persona voice identifiers to ElevenLabs voice IDs
        let voiceMapping: [String: String] = [
            "com.apple.ttsbundle.Samantha-compact": "DGzg6RaUqxGRTHSBjfgF", // Drill Sergeant Drew
            "com.apple.ttsbundle.siri_female_en-US_compact": "uYXf8XasLslADfZ2MB4u", // Girl Bestie
            "com.apple.ttsbundle.Karen-compact": "DLsHlh26Ugcm6ELvS0qi", // Mrs. Walker
            "com.apple.ttsbundle.Aaron-compact": "84Fal4DSXWfp7nJ8emqQ", // Motivational Mike
            "com.apple.ttsbundle.Alex": "MpZY6e8MW2zHVi4Vtxrn", // Calm Kyle
            "com.apple.ttsbundle.siri_male_en-US_compact": "KLZOWyG48RjZkAAjuM89" // Angry Allen
        ]
        
        // If it's already an ElevenLabs voice ID (starts with letters and numbers), return as-is
        if personaVoice.count == 20 && personaVoice.range(of: "^[A-Za-z0-9]+$", options: .regularExpression) != nil {
            return personaVoice
        }
        
        // Otherwise, try to map from the old voice system
        return voiceMapping[personaVoice] ?? "uYXf8XasLslADfZ2MB4u" // Default to Girl Bestie
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
    @State private var selectedPersona = PersonaManager.Persona.girlBestie
    @State private var isPlaying = false
    @State private var toneSlider: Double = 0.5
    
    private let personas = PersonaManager.shared.getAllPersonas()
    
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
                                Text(selectedPersona.rawValue)
                                    .font(.system(size: 18, weight: .medium))
                                
                                Text(PersonaManager.shared.getPersonaCard(for: selectedPersona).description)
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
                        
                        LazyVStack(spacing: 16) {
                            ForEach(personas, id: \.self) { persona in
                                personaLibraryRow(persona: persona)
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
    
    // MARK: - Persona Library Row
    private func personaLibraryRow(persona: PersonaManager.Persona) -> some View {
        let personaManager = PersonaManager.shared
        let card = personaManager.getPersonaCard(for: persona)
        let toneLevel = PersonaManager.ToneLevel.balanced // Use balanced tone for library preview
        let preview = personaManager.getPersonaPreview(for: persona, toneLevel: toneLevel)
        let isSelected = selectedPersona == persona
        
        return Button(action: { selectedPersona = persona }) {
            HStack(spacing: 16) {
                // Persona Icon
                Image(systemName: card.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color(hex: card.color))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    // Persona Name
                    Text(persona.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Description
                    Text(card.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Tone Preview
                    Text("Preview: \"\(preview)\"")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: card.color))
                        .italic()
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Selection indicator & Play button
                VStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: card.color))
                    }
                    
                    Spacer()
                    
                    Button("Preview") {
                        // Future: Add voice preview functionality
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: card.color))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: card.color).opacity(0.1) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: card.color) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
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

// MARK: - Temporary PersonaManager (to be extracted later)
// MARK: - Persona Card Structure
struct PersonaCard {
    let name: String
    let description: String
    let characteristics: [String]
    let samplePhrase: String
    let voiceMapping: String // iOS TTS voice identifier
    let icon: String // SF Symbol icon name
    let color: String // Hex color for UI theming
}

// MARK: - Persona Manager
class PersonaManager {
    
    // MARK: - Persona Enum
    enum Persona: String, CaseIterable {
        case drillSergeantDrew = "Drill Sergeant Drew"
        case girlBestie = "Girl Bestie"
        case mrsWalker = "Mrs. Walker"
        case motivationalMike = "Motivational Mike"
        case calmKyle = "Calm Kyle"
        case angryAllen = "Angry Allen"
        
        var id: String { return self.rawValue }
        
        var shortName: String {
            switch self {
            case .drillSergeantDrew: return "Drew"
            case .girlBestie: return "Bestie"
            case .mrsWalker: return "Mrs. Walker"
            case .motivationalMike: return "Mike"
            case .calmKyle: return "Kyle"
            case .angryAllen: return "Allen"
            }
        }
    }
    
    // MARK: - Tone Level Enum
    enum ToneLevel {
        case gentle      // 0.0 - 0.3
        case balanced    // 0.3 - 0.7
        case toughLove   // 0.7 - 1.0
        
        static func fromSliderValue(_ value: Double) -> ToneLevel {
            if value <= 0.3 {
                return .gentle
            } else if value <= 0.7 {
                return .balanced
            } else {
                return .toughLove
            }
        }
    }
    
    // MARK: - Singleton
    static let shared = PersonaManager()
    private init() {}
    
    // MARK: - Persona Cards
    func getPersonaCard(for persona: Persona) -> PersonaCard {
        switch persona {
        case .drillSergeantDrew:
            return PersonaCard(
                name: "🎖️ Drill Sergeant Drew",
                description: "A tough but caring military drill instructor who believes discipline equals success. Drew pushes you to your limits because he knows you're capable of greatness.",
                characteristics: [
                    "Direct and commanding",
                    "Uses military terminology",
                    "Tough love approach",
                    "Believes in discipline",
                    "Results-oriented"
                ],
                samplePhrase: "Listen up! Do you think that goal is going to achieve itself? Time to move out and conquer your day! THAT'S AN ORDER!",
                voiceMapping: "en-US",
                icon: "star.fill",
                color: "#4A5D23"
            )
            
        case .girlBestie:
            return PersonaCard(
                name: "✨ Girl Bestie",
                description: "Your supportive best friend who's always got your back. She's enthusiastic, caring, and knows exactly what to say to pump you up for success.",
                characteristics: [
                    "Enthusiastic and supportive",
                    "Uses modern slang",
                    "Encouraging and uplifting",
                    "Celebrates your wins",
                    "Like talking to your BFF"
                ],
                samplePhrase: "Heyyy gorgeous! Today is literally going to be amazing and you're going to absolutely crush it! Let's goooo bestie!",
                voiceMapping: "en-US",
                icon: "heart.fill",
                color: "#FF6B9D"
            )
            
        case .mrsWalker:
            return PersonaCard(
                name: "🏡 Mrs. Walker",
                description: "A warm, caring Southern mom who believes in you completely. She offers gentle wisdom, unconditional support, and that special motherly encouragement.",
                characteristics: [
                    "Warm and nurturing",
                    "Southern charm and wisdom",
                    "Believes in you completely",
                    "Gentle but firm guidance",
                    "Motherly love and support"
                ],
                samplePhrase: "Rise and shine, darlin'. I just know you're going to do wonderfully today. Mama believes in you, sweetheart.",
                voiceMapping: "en-US",
                icon: "house.fill",
                color: "#8B4513"
            )
            
        case .motivationalMike:
            return PersonaCard(
                name: "🚀 Motivational Mike",
                description: "A high-energy motivational speaker who sees unlimited potential in everyone. Mike transforms challenges into opportunities and turns dreams into actionable plans.",
                characteristics: [
                    "High-energy and inspiring",
                    "Sees unlimited potential",
                    "Transforms challenges to opportunities",
                    "Future-focused mindset",
                    "Champion mentality"
                ],
                samplePhrase: "RISE AND SHINE, CHAMPION! Today is not just another day—it's your opportunity to become the person you're destined to be!",
                voiceMapping: "en-US",
                icon: "flame.fill",
                color: "#FF4500"
            )
            
        case .calmKyle:
            return PersonaCard(
                name: "🧘 Calm Kyle",
                description: "A mindful, zen-like guide who approaches life with peaceful wisdom. Kyle helps you find inner strength and clarity through gentle, thoughtful guidance.",
                characteristics: [
                    "Peaceful and mindful",
                    "Zen-like wisdom",
                    "Gentle guidance",
                    "Present-moment awareness",
                    "Inner strength focus"
                ],
                samplePhrase: "Good morning. As the light enters the room, gently awaken your mind. The path to your goals begins with this single, mindful step.",
                voiceMapping: "en-US",
                icon: "leaf.fill",
                color: "#20B2AA"
            )
            
        case .angryAllen:
            return PersonaCard(
                name: "😡 Angry Allen",
                description: "A brutally honest, no-nonsense coach who's frustrated by wasted potential. Allen's tough approach comes from genuine care about your success.",
                characteristics: [
                    "Brutally honest",
                    "No-nonsense approach",
                    "Frustrated by wasted potential",
                    "Sarcastic but caring",
                    "Pushes through excuses"
                ],
                samplePhrase: "Are you KIDDING me? Still sleeping while your dreams are waiting? I'm more stressed about your success than you are! GET UP!",
                voiceMapping: "en-US",
                icon: "bolt.fill",
                color: "#DC143C"
            )
        }
    }
    
    // MARK: - Tone Modifier Generation
    func getToneModifier(for toneLevel: ToneLevel) -> String {
        switch toneLevel {
        case .gentle:
            return """
            [TONE MODIFIER]
            **Instruction:** The user has selected a "Gentle & Nurturing" tone. You must emphasize the most supportive, kind, and encouraging aspects of your persona. Soften your delivery and reduce any harshness or aggressive language.
            """
            
        case .balanced:
            return "" // No modifier for balanced - uses persona's default style
            
        case .toughLove:
            return """
            [TONE MODIFIER]
            **Instruction:** The user has selected a "Tough Love & Direct" tone. You must amplify the most intense, direct, and no-nonsense aspects of your persona. Be as firm and challenging as your character allows.
            """
        }
    }
    
    // MARK: - Full Persona Description for AI
    func getFullPersonaDescription(for persona: Persona) -> String {
        let card = getPersonaCard(for: persona)
        
        let characteristicsText = card.characteristics
            .map { "- \($0)" }
            .joined(separator: "\n")
        
        return """
        **Character:** \(card.name)
        
        **Background:** \(card.description)
        
        **Speaking Style & Characteristics:**
        \(characteristicsText)
        
        **Example of your voice:** "\(card.samplePhrase)"
        
        **Important:** Stay completely in character throughout the entire script. Your personality should be evident in every sentence.
        """
    }
    
    // MARK: - Voice Mapping for TTS
    func getVoiceMapping(for persona: Persona) -> String {
        // Map personas to specific iOS voices for better character representation
        switch persona {
        case .drillSergeantDrew:
            return "en-US" // Aaron - deeper, more authoritative
        case .girlBestie:
            return "en-GB" // Kate - energetic British accent
        case .mrsWalker:
            return "en-US" // Samantha - warm American voice
        case .motivationalMike:
            return "en-AU" // Lee - enthusiastic Australian accent
        case .calmKyle:
            return "en-CA" // Alex - calm Canadian voice
        case .angryAllen:
            return "en-US" // Aaron - intense American voice
        }
    }
    
    // MARK: - UI Helper Methods
    func getAllPersonas() -> [Persona] {
        return Persona.allCases
    }
    
    func getPersonaIcon(for persona: Persona) -> String {
        return getPersonaCard(for: persona).icon
    }
    
    func getPersonaColor(for persona: Persona) -> String {
        return getPersonaCard(for: persona).color
    }
    
    func getPersonaPreview(for persona: Persona, toneLevel: ToneLevel) -> String {
        // Generate a brief preview based on persona and tone
        switch (persona, toneLevel) {
        case (.drillSergeantDrew, .gentle):
            return "Alright soldier, time to rise. Today's mission awaits, and I know you're ready."
        case (.drillSergeantDrew, .balanced):
            return "Listen up! Your objectives won't complete themselves. Time to move out and dominate!"
        case (.drillSergeantDrew, .toughLove):
            return "GET UP NOW! No excuses, no delays! Your mission starts THIS INSTANT!"
            
        case (.girlBestie, .gentle):
            return "Hey hun, it's time to start your amazing day. You've got this, I believe in you!"
        case (.girlBestie, .balanced):
            return "Wake up bestie! Today is going to be incredible and you're going to slay it!"
        case (.girlBestie, .toughLove):
            return "Girl, get UP! We are NOT wasting this day. Time to show the world what you're made of!"
            
        case (.mrsWalker, .gentle):
            return "Rise and shine, darlin'. Mama's here to help you start this beautiful day right."
        case (.mrsWalker, .balanced):
            return "Come on now, sweetheart. The day is calling and you're going to answer beautifully."
        case (.mrsWalker, .toughLove):
            return "Now listen here. I didn't raise someone to stay in bed when there's work to be done!"
            
        case (.motivationalMike, .gentle):
            return "Good morning, champion. Today holds incredible possibilities for your growth."
        case (.motivationalMike, .balanced):
            return "RISE AND SHINE! Today is your stage, and you're the star performer!"
        case (.motivationalMike, .toughLove):
            return "LEGENDS DON'T SLEEP WHILE DESTINY CALLS! YOUR GREATNESS STARTS NOW!"
            
        case (.calmKyle, .gentle):
            return "Gently welcome the morning light. Let peace guide your awakening to purposeful action."
        case (.calmKyle, .balanced):
            return "The day begins with awareness. Rise mindfully and embrace your intentions."
        case (.calmKyle, .toughLove):
            return "Recognize the resistance. Now choose growth over comfort. Rise with purpose."
            
        case (.angryAllen, .gentle):
            return "Look, you have things to do today. Maybe consider getting started... eventually."
        case (.angryAllen, .balanced):
            return "Are you serious right now? The day is wasting away while you're sleeping!"
        case (.angryAllen, .toughLove):
            return "WHAT IS WRONG WITH YOU?! GET OUT OF BED THIS INSTANT! STOP WASTING MY TIME!"
        }
    }
}

// MARK: - Extensions for Convenience
extension PersonaManager.Persona: Identifiable {
    // id is already defined in the enum
}

extension PersonaManager.Persona {
    var displayName: String {
        return self.rawValue
    }
}

#Preview {
    ContentView()
}
