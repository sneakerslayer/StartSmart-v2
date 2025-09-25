import SwiftUI
import Combine

// MARK: - Sharing Privacy View
struct SharingPrivacyView: View {
    @StateObject private var socialService = DependencyContainer.shared.socialSharingService as! SocialSharingService
    @State private var privacySettings = SharingPrivacySettings()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                // Main sharing toggle
                Section(header: Text("Social Sharing")) {
                    Toggle("Enable Social Sharing", isOn: $privacySettings.isEnabled)
                        .onChange(of: privacySettings.isEnabled) { value in
                            updateSettings()
                        }
                    
                    if privacySettings.isEnabled {
                        Text("Share your progress and achievements with friends")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if privacySettings.isEnabled {
                    // What to share
                    Section(header: Text("What to Share"),
                            footer: Text("Choose what information you're comfortable sharing publicly.")) {
                        
                        Toggle("Personal Statistics", isOn: $privacySettings.showPersonalStats)
                            .onChange(of: privacySettings.showPersonalStats) { _ in updateSettings() }
                        
                        Toggle("Achievements & Badges", isOn: $privacySettings.showAchievements)
                            .onChange(of: privacySettings.showAchievements) { _ in updateSettings() }
                        
                        Toggle("Streak Count", isOn: $privacySettings.showStreakCount)
                            .onChange(of: privacySettings.showStreakCount) { _ in updateSettings() }
                        
                        Toggle("Exact Wake-up Times", isOn: $privacySettings.showExactTimes)
                            .onChange(of: privacySettings.showExactTimes) { _ in updateSettings() }
                    }
                    
                    // Automatic sharing
                    Section(header: Text("Automatic Sharing"),
                            footer: Text("Automatically share major milestones like week streaks or new achievements.")) {
                        
                        Toggle("Auto-share Milestones", isOn: $privacySettings.autoShareMilestones)
                            .onChange(of: privacySettings.autoShareMilestones) { _ in updateSettings() }
                    }
                    
                    // Preferred platforms
                    Section(header: Text("Preferred Platforms")) {
                        ForEach(SocialPlatform.allCases, id: \.self) { platform in
                            HStack {
                                Image(systemName: platform.iconName)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                Text(platform.displayName)
                                
                                Spacer()
                                
                                if privacySettings.preferredPlatforms.contains(platform.rawValue) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                togglePlatform(platform)
                            }
                        }
                    }
                    
                    // Analytics and data
                    Section(header: Text("Analytics & Data"),
                            footer: Text("Help improve the sharing experience while maintaining your privacy.")) {
                        
                        Toggle("Share Analytics", isOn: $privacySettings.shareAnalyticsEnabled)
                            .onChange(of: privacySettings.shareAnalyticsEnabled) { _ in updateSettings() }
                        
                        Toggle("Anonymize Data", isOn: $privacySettings.anonymizeData)
                            .onChange(of: privacySettings.anonymizeData) { _ in updateSettings() }
                    }
                }
                
                // Test sharing section
                if privacySettings.isEnabled {
                    Section(header: Text("Test Sharing")) {
                        Button("Preview Share Card") {
                            // This would show a preview of what the share card looks like
                        }
                        .foregroundColor(.blue)
                        
                        Button("Test Share") {
                            // This would test the actual sharing flow
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Sharing Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        updateSettings()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onReceive(socialService.privacySettings) { settings in
                privacySettings = settings
            }
        }
    }
    
    private func togglePlatform(_ platform: SocialPlatform) {
        if privacySettings.preferredPlatforms.contains(platform.rawValue) {
            privacySettings.preferredPlatforms.remove(platform.rawValue)
        } else {
            privacySettings.preferredPlatforms.insert(platform.rawValue)
        }
        updateSettings()
    }
    
    private func updateSettings() {
        Task {
            await socialService.updatePrivacySettings(privacySettings)
        }
    }
}

// MARK: - Share Content Picker View
struct ShareContentPickerView: View {
    let stats: EnhancedUserStats
    let onShareSelected: (ShareCardData, SocialPlatform) -> Void
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var socialService = DependencyContainer.shared.socialSharingService as! SocialSharingService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Share options
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        
                        ShareTypeCard(
                            type: .streak,
                            title: "Current Streak",
                            description: "\(stats.currentStreak) days strong",
                            icon: "flame.fill",
                            gradient: [.orange, .red]
                        ) {
                            let shareData = socialService.createStreakShareCard(stats: stats)
                            showPlatformPicker(for: shareData)
                        }
                        
                        if !stats.unlockedAchievements.isEmpty {
                            ShareTypeCard(
                                type: .achievement,
                                title: "Latest Achievement",
                                description: Array(stats.unlockedAchievements).last?.title ?? "",
                                icon: "trophy.fill",
                                gradient: [.yellow, .orange]
                            ) {
                                if let achievement = Array(stats.unlockedAchievements).last {
                                    let shareData = socialService.createAchievementShareCard(
                                        achievement: achievement,
                                        stats: stats
                                    )
                                    showPlatformPicker(for: shareData)
                                }
                            }
                        }
                        
                        ShareTypeCard(
                            type: .weeklyStats,
                            title: "Weekly Progress",
                            description: "\(Int(stats.weeklySuccessRate * 100))% success",
                            icon: "chart.line.uptrend.xyaxis",
                            gradient: [.blue, .purple]
                        ) {
                            let shareData = socialService.createWeeklyStatsShareCard(stats: stats)
                            showPlatformPicker(for: shareData)
                        }
                        
                        ShareTypeCard(
                            type: .motivation,
                            title: "Morning Motivation",
                            description: "Share an inspiring quote",
                            icon: "quote.bubble.fill",
                            gradient: [.teal, .green]
                        ) {
                            let quotes = [
                                "Every morning is a new opportunity to be better than yesterday.",
                                "The early bird catches the worm, and I'm ready to soar!",
                                "Consistency is the key to success, one wake-up at a time.",
                                "Building habits that build me up, morning by morning."
                            ]
                            let shareData = socialService.createMotivationShareCard(
                                quote: quotes.randomElement() ?? quotes[0],
                                stats: stats
                            )
                            showPlatformPicker(for: shareData)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Share Your Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func showPlatformPicker(for shareData: ShareCardData) {
        // In a real implementation, this would show a platform picker
        // For now, we'll default to general sharing
        onShareSelected(shareData, .general)
    }
}

// MARK: - Share Type Card
struct ShareTypeCard: View {
    let type: ShareContentType
    let title: String
    let description: String
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
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(gradient.first ?? .blue)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Platform Selection View
struct PlatformSelectionView: View {
    let shareData: ShareCardData
    let onPlatformSelected: (SocialPlatform) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Preview of share card (simplified)
                VStack(spacing: 16) {
                    Image(systemName: shareData.iconName)
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    
                    Text(shareData.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text(shareData.primaryValue)
                        .font(.title.bold())
                        .foregroundColor(.blue)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.1))
                )
                .padding()
                
                // Platform options
                VStack(spacing: 16) {
                    ForEach(SocialPlatform.allCases, id: \.self) { platform in
                        Button(action: {
                            onPlatformSelected(platform)
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: platform.iconName)
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(platform.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(Int(platform.preferredSize.width)) × \(Int(platform.preferredSize.height))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                .padding()
                
                Spacer()
            }
            .navigationTitle("Choose Platform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Previews
#Preview {
    SharingPrivacyView()
}

#Preview("Share Content Picker") {
    let mockStats = EnhancedUserStats()
    ShareContentPickerView(stats: mockStats) { _, _ in }
}

#Preview("Platform Selection") {
    let mockData = ShareCardData(
        type: .streak,
        title: "Streak Power!",
        primaryValue: "7",
        secondaryValue: "days strong"
    )
    PlatformSelectionView(shareData: mockData) { _ in }
}
