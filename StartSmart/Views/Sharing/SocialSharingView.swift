import SwiftUI
import Combine

// MARK: - Social Sharing View
struct SocialSharingView: View {
    @StateObject private var socialService = DependencyContainer.shared.resolve(SocialSharingServiceProtocol.self) as! SocialSharingService
    @StateObject private var streakService = DependencyContainer.shared.resolve(StreakTrackingServiceProtocol.self) as! StreakTrackingService
    
    @State private var stats = EnhancedUserStats()
    @State private var privacySettings = SharingPrivacySettings()
    @State private var showingPrivacySettings = false
    @State private var showingContentPicker = false
    @State private var showingPlatformPicker = false
    @State private var selectedShareData: ShareCardData?
    @State private var isSharing = false
    @State private var shareSuccess: Bool?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if !privacySettings.isEnabled {
                        // Privacy disabled state
                        PrivacyDisabledView {
                            showingPrivacySettings = true
                        }
                    } else {
                        // Main sharing content
                        VStack(spacing: 20) {
                            // Quick share options
                            QuickShareSection(
                                stats: stats,
                                onShare: { shareData, platform in
                                    shareContent(shareData, platform: platform)
                                }
                            )
                            
                            // Recent shareable moments
                            if hasShareableMoments {
                                RecentMomentsSection(
                                    stats: stats,
                                    onShare: { shareData, platform in
                                        shareContent(shareData, platform: platform)
                                    }
                                )
                            }
                            
                            // Sharing statistics
                            SharingStatsSection(stats: stats)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Share Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingPrivacySettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if privacySettings.isEnabled {
                        Button("Share") {
                            showingContentPicker = true
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingPrivacySettings) {
                SharingPrivacyView()
            }
            .sheet(isPresented: $showingContentPicker) {
                ShareContentPickerView(stats: stats) { shareData, platform in
                    showingContentPicker = false
                    shareContent(shareData, platform: platform)
                }
            }
            .overlay(
                // Loading overlay
                Group {
                    if isSharing {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Creating share card...")
                                .font(.body)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.8))
                        )
                    }
                }
            )
            .alert("Share Result", isPresented: .constant(shareSuccess != nil)) {
                Button("OK") {
                    shareSuccess = nil
                }
            } message: {
                if shareSuccess == true {
                    Text("Your progress has been shared successfully! 🎉")
                } else {
                    Text("Unable to share at this time. Please try again.")
                }
            }
            .onReceive(socialService.privacySettings) { settings in
                privacySettings = settings
            }
            .onReceive(streakService.enhancedStats) { newStats in
                stats = newStats
            }
        }
    }
    
    private var hasShareableMoments: Bool {
        stats.currentStreak > 0 || !stats.unlockedAchievements.isEmpty || stats.successfulWakeUps > 0
    }
    
    private func shareContent(_ shareData: ShareCardData, platform: SocialPlatform) {
        Task {
            isSharing = true
            let success = await socialService.shareContent(shareData, platform: platform)
            
            await MainActor.run {
                isSharing = false
                shareSuccess = success
            }
        }
    }
}

// MARK: - Privacy Disabled View
struct PrivacyDisabledView: View {
    let onEnableSharing: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            // Content
            VStack(spacing: 16) {
                Text("Sharing Disabled")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Enable social sharing to celebrate your progress with friends and stay motivated!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Enable button
            Button(action: onEnableSharing) {
                Text("Enable Sharing")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemGray6))
        )
    }
}

// MARK: - Quick Share Section
struct QuickShareSection: View {
    let stats: EnhancedUserStats
    let onShare: (ShareCardData, SocialPlatform) -> Void
    @StateObject private var socialService = DependencyContainer.shared.resolve(SocialSharingServiceProtocol.self) as! SocialSharingService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Share")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Current streak
                    if stats.currentStreak > 0 {
                        QuickShareCard(
                            title: "Streak",
                            value: "\(stats.currentStreak) day\(stats.currentStreak == 1 ? "" : "s")",
                            icon: "flame.fill",
                            gradient: [.orange, .red]
                        ) {
                            let shareData = socialService.createStreakShareCard(stats: stats)
                            onShare(shareData, .general)
                        }
                    }
                    
                    // Latest achievement
                    if let latestAchievement = stats.unlockedAchievements.last {
                        QuickShareCard(
                            title: "Achievement",
                            value: latestAchievement.title,
                            icon: latestAchievement.iconName,
                            gradient: [.yellow, .orange]
                        ) {
                            let shareData = socialService.createAchievementShareCard(
                                achievement: latestAchievement,
                                stats: stats
                            )
                            onShare(shareData, .general)
                        }
                    }
                    
                    // Weekly progress
                    if stats.thisWeekSuccesses > 0 {
                        QuickShareCard(
                            title: "This Week",
                            value: "\(Int(stats.weeklySuccessRate * 100))%",
                            icon: "chart.line.uptrend.xyaxis",
                            gradient: [.blue, .purple]
                        ) {
                            let shareData = socialService.createWeeklyStatsShareCard(stats: stats)
                            onShare(shareData, .general)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Quick Share Card
struct QuickShareCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.3) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(gradient.first ?? .blue)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.headline.bold())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(width: 120, height: 100)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Moments Section
struct RecentMomentsSection: View {
    let stats: EnhancedUserStats
    let onShare: (ShareCardData, SocialPlatform) -> Void
    @StateObject private var socialService = DependencyContainer.shared.resolve(SocialSharingServiceProtocol.self) as! SocialSharingService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Moments")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // New streak milestone
                if stats.currentStreak > 0 && stats.currentStreak % 7 == 0 {
                    MomentCard(
                        title: "Week Milestone! 🎉",
                        description: "You've maintained a \(stats.currentStreak)-day streak",
                        time: "Today",
                        icon: "flame.fill",
                        color: .orange
                    ) {
                        let shareData = socialService.createStreakShareCard(stats: stats)
                        onShare(shareData, .general)
                    }
                }
                
                // Recent achievements
                for achievement in Array(stats.unlockedAchievements.suffix(2)) {
                    MomentCard(
                        title: "Achievement Unlocked!",
                        description: achievement.title,
                        time: "Recent",
                        icon: achievement.iconName,
                        color: .yellow
                    ) {
                        let shareData = socialService.createAchievementShareCard(
                            achievement: achievement,
                            stats: stats
                        )
                        onShare(shareData, .general)
                    }
                }
                
                // Perfect week
                if stats.weeklySuccessRate == 1.0 && stats.thisWeekSuccesses >= 7 {
                    MomentCard(
                        title: "Perfect Week! 💯",
                        description: "7/7 successful wake-ups",
                        time: "This week",
                        icon: "checkmark.seal.fill",
                        color: .green
                    ) {
                        let shareData = socialService.createWeeklyStatsShareCard(stats: stats)
                        onShare(shareData, .general)
                    }
                }
            }
        }
    }
}

// MARK: - Moment Card
struct MomentCard: View {
    let title: String
    let description: String
    let time: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text(time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Share icon
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sharing Stats Section
struct SharingStatsSection: View {
    let stats: EnhancedUserStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Impact")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                StatRow(
                    title: "Total Achievements",
                    value: "\(stats.unlockedAchievements.count)",
                    icon: "trophy.fill",
                    color: .yellow
                )
                
                StatRow(
                    title: "Longest Streak",
                    value: "\(stats.longestStreak) days",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatRow(
                    title: "Success Rate",
                    value: "\(Int(stats.successRate * 100))%",
                    icon: "target",
                    color: .green
                )
                
                StatRow(
                    title: "Total Wake-ups",
                    value: "\(stats.successfulWakeUps)",
                    icon: "sun.max.fill",
                    color: .blue
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemGray6))
            )
        }
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Previews
#Preview {
    SocialSharingView()
}

#Preview("Privacy Disabled") {
    PrivacyDisabledView {
        print("Enable sharing tapped")
    }
}
