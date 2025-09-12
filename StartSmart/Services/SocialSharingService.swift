import Foundation
import UIKit
import SwiftUI
import Combine

// MARK: - Share Content Types
enum ShareContentType: String, CaseIterable {
    case streak = "streak"
    case achievement = "achievement"
    case weeklyStats = "weekly_stats"
    case motivation = "motivation"
    case milestone = "milestone"
    
    var displayName: String {
        switch self {
        case .streak: return "Current Streak"
        case .achievement: return "Achievement Unlocked"
        case .weeklyStats: return "Weekly Progress"
        case .motivation: return "Morning Motivation"
        case .milestone: return "Milestone Reached"
        }
    }
}

// MARK: - Social Platform Types
enum SocialPlatform: String, CaseIterable {
    case instagram = "instagram"
    case tiktok = "tiktok"
    case twitter = "twitter"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .instagram: return "Instagram Stories"
        case .tiktok: return "TikTok"
        case .twitter: return "Twitter"
        case .general: return "Share"
        }
    }
    
    var iconName: String {
        switch self {
        case .instagram: return "camera.circle.fill"
        case .tiktok: return "video.circle.fill"
        case .twitter: return "bubble.right.circle.fill"
        case .general: return "square.and.arrow.up"
        }
    }
    
    var preferredSize: CGSize {
        switch self {
        case .instagram: return CGSize(width: 1080, height: 1920) // 9:16 aspect ratio
        case .tiktok: return CGSize(width: 1080, height: 1920)
        case .twitter: return CGSize(width: 1200, height: 675) // 16:9 aspect ratio
        case .general: return CGSize(width: 1080, height: 1080) // Square
        }
    }
}

// MARK: - Share Card Data
struct ShareCardData {
    let type: ShareContentType
    let title: String
    let subtitle: String?
    let primaryValue: String
    let secondaryValue: String?
    let backgroundGradient: [Color]
    let iconName: String
    let achievement: StreakAchievement?
    let stats: EnhancedUserStats?
    let motivationalQuote: String?
    let timestamp: Date
    
    init(
        type: ShareContentType,
        title: String,
        subtitle: String? = nil,
        primaryValue: String,
        secondaryValue: String? = nil,
        backgroundGradient: [Color] = [.blue, .purple],
        iconName: String = "star.fill",
        achievement: StreakAchievement? = nil,
        stats: EnhancedUserStats? = nil,
        motivationalQuote: String? = nil
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.primaryValue = primaryValue
        self.secondaryValue = secondaryValue
        self.backgroundGradient = backgroundGradient
        self.iconName = iconName
        self.achievement = achievement
        self.stats = stats
        self.motivationalQuote = motivationalQuote
        self.timestamp = Date()
    }
}

// MARK: - Privacy Settings
struct SharingPrivacySettings: Codable {
    var isEnabled: Bool = false
    var showPersonalStats: Bool = true
    var showAchievements: Bool = true
    var showStreakCount: Bool = true
    var showExactTimes: Bool = false
    var autoShareMilestones: Bool = false
    var preferredPlatforms: Set<String> = []
    
    // Analytics preferences
    var shareAnalyticsEnabled: Bool = false
    var anonymizeData: Bool = true
}

// MARK: - Social Sharing Service Protocol
protocol SocialSharingServiceProtocol {
    var privacySettings: AnyPublisher<SharingPrivacySettings, Never> { get }
    
    func generateShareCard(data: ShareCardData, platform: SocialPlatform) async -> UIImage?
    func shareContent(_ content: ShareCardData, platform: SocialPlatform) async -> Bool
    func createStreakShareCard(stats: EnhancedUserStats) -> ShareCardData
    func createAchievementShareCard(achievement: StreakAchievement, stats: EnhancedUserStats) -> ShareCardData
    func createWeeklyStatsShareCard(stats: EnhancedUserStats) -> ShareCardData
    func createMotivationShareCard(quote: String, stats: EnhancedUserStats) -> ShareCardData
    func updatePrivacySettings(_ settings: SharingPrivacySettings) async
    func canShare() -> Bool
}

// MARK: - Social Sharing Service Implementation
@MainActor
class SocialSharingService: ObservableObject, SocialSharingServiceProtocol {
    @Published private var _privacySettings = SharingPrivacySettings()
    
    private let storage: LocalStorageProtocol
    private let privacyKey = "sharing_privacy_settings"
    
    // MARK: - Publishers
    var privacySettings: AnyPublisher<SharingPrivacySettings, Never> {
        $_privacySettings.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(storage: LocalStorageProtocol = LocalStorage.shared) {
        self.storage = storage
        Task {
            await loadPrivacySettings()
        }
    }
    
    // MARK: - Share Card Generation
    func generateShareCard(data: ShareCardData, platform: SocialPlatform) async -> UIImage? {
        let size = platform.preferredSize
        
        return await withCheckedContinuation { continuation in
            let hostingController = UIHostingController(
                rootView: ShareCardView(data: data, platform: platform)
                    .frame(width: size.width, height: size.height)
            )
            
            hostingController.view.frame = CGRect(origin: .zero, size: size)
            hostingController.view.backgroundColor = .clear
            
            DispatchQueue.main.async {
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { context in
                    hostingController.view.layer.render(in: context.cgContext)
                }
                continuation.resume(returning: image)
            }
        }
    }
    
    func shareContent(_ content: ShareCardData, platform: SocialPlatform) async -> Bool {
        guard canShare() else { return false }
        
        guard let image = await generateShareCard(data: content, platform: platform) else {
            return false
        }
        
        return await presentShareSheet(image: image, platform: platform)
    }
    
    // MARK: - Share Card Creation Methods
    func createStreakShareCard(stats: EnhancedUserStats) -> ShareCardData {
        let title = stats.currentStreak == 1 ? "Started My Journey" : "Streak Power!"
        let subtitle = stats.currentStreak > stats.longestStreak / 2 ? "Personal best in sight!" : nil
        
        return ShareCardData(
            type: .streak,
            title: title,
            subtitle: subtitle,
            primaryValue: "\(stats.currentStreak)",
            secondaryValue: "day\(stats.currentStreak == 1 ? "" : "s") strong",
            backgroundGradient: [.orange, .red, .pink],
            iconName: "flame.fill",
            stats: stats
        )
    }
    
    func createAchievementShareCard(achievement: StreakAchievement, stats: EnhancedUserStats) -> ShareCardData {
        let motivationalMessages = [
            "Unlocked a new level of awesome! 🚀",
            "Another milestone conquered! 💪",
            "Making progress one wake-up at a time! ⭐",
            "Achievement unlocked! What's next? 🔥"
        ]
        
        return ShareCardData(
            type: .achievement,
            title: achievement.title,
            subtitle: motivationalMessages.randomElement(),
            primaryValue: "UNLOCKED",
            secondaryValue: achievement.description,
            backgroundGradient: [.yellow, .orange, .red],
            iconName: achievement.iconName,
            achievement: achievement,
            stats: stats
        )
    }
    
    func createWeeklyStatsShareCard(stats: EnhancedUserStats) -> ShareCardData {
        let successRate = Int(stats.weeklySuccessRate * 100)
        let subtitle = successRate >= 80 ? "Crushing it this week!" :
                      successRate >= 60 ? "Good momentum!" :
                      "Building the habit!"
        
        return ShareCardData(
            type: .weeklyStats,
            title: "This Week's Progress",
            subtitle: subtitle,
            primaryValue: "\(successRate)%",
            secondaryValue: "\(stats.thisWeekSuccesses)/7 days",
            backgroundGradient: [.blue, .purple, .indigo],
            iconName: "chart.line.uptrend.xyaxis",
            stats: stats
        )
    }
    
    func createMotivationShareCard(quote: String, stats: EnhancedUserStats) -> ShareCardData {
        return ShareCardData(
            type: .motivation,
            title: "Morning Motivation",
            subtitle: "Powered by AI",
            primaryValue: quote,
            backgroundGradient: [.teal, .green, .blue],
            iconName: "quote.bubble.fill",
            stats: stats,
            motivationalQuote: quote
        )
    }
    
    // MARK: - Privacy & Settings
    func updatePrivacySettings(_ settings: SharingPrivacySettings) async {
        _privacySettings = settings
        await storage.save(settings, forKey: privacyKey)
    }
    
    func canShare() -> Bool {
        return _privacySettings.isEnabled
    }
    
    // MARK: - Private Methods
    private func loadPrivacySettings() async {
        if let settings = await storage.load(SharingPrivacySettings.self, forKey: privacyKey) {
            _privacySettings = settings
        }
    }
    
    private func presentShareSheet(image: UIImage, platform: SocialPlatform) async -> Bool {
        return await withCheckedContinuation { continuation in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                continuation.resume(returning: false)
                return
            }
            
            var items: [Any] = [image]
            
            // Add platform-specific text
            let shareText = createShareText(for: platform)
            if !shareText.isEmpty {
                items.append(shareText)
            }
            
            let activityController = UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )
            
            // Configure for specific platforms
            configureActivityController(activityController, for: platform)
            
            // Present the share sheet
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(
                    x: rootViewController.view.bounds.midX,
                    y: rootViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
            
            activityController.completionWithItemsHandler = { _, completed, _, _ in
                continuation.resume(returning: completed)
            }
            
            rootViewController.present(activityController, animated: true)
        }
    }
    
    private func createShareText(for platform: SocialPlatform) -> String {
        switch platform {
        case .instagram:
            return "#StartSmartAlarm #MorningMotivation #StreakLife"
        case .tiktok:
            return "My morning routine is getting stronger! 💪 #StartSmartAlarm #MorningVibes"
        case .twitter:
            return "Building better morning habits with @StartSmartAlarm 🌅 #MorningMotivation #StreakLife"
        case .general:
            return "Check out my progress with StartSmart! 🚀"
        }
    }
    
    private func configureActivityController(_ controller: UIActivityViewController, for platform: SocialPlatform) {
        switch platform {
        case .instagram:
            // Prefer Instagram Stories
            controller.excludedActivityTypes = [
                .postToTwitter,
                .postToWeibo,
                .postToTencentWeibo,
                .postToVimeo
            ]
        case .tiktok:
            // Prefer video sharing apps
            controller.excludedActivityTypes = [
                .postToTwitter,
                .postToWeibo,
                .postToTencentWeibo
            ]
        case .twitter:
            // Prefer Twitter
            controller.excludedActivityTypes = [
                .postToWeibo,
                .postToTencentWeibo,
                .postToVimeo
            ]
        case .general:
            // Allow all platforms
            break
        }
    }
}

// MARK: - Share Card View
struct ShareCardView: View {
    let data: ShareCardData
    let platform: SocialPlatform
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: data.backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // App branding
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("StartSmart")
                        .font(.title2.bold())
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
                
                Spacer()
                
                // Main content area
                VStack(spacing: 20) {
                    // Icon
                    Image(systemName: data.iconName)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    // Title
                    Text(data.title)
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    // Subtitle
                    if let subtitle = data.subtitle {
                        Text(subtitle)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Primary value
                    if data.type == .motivation {
                        // Special layout for motivational quotes
                        Text(data.primaryValue)
                            .font(.title2.weight(.medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.2))
                                    .backdrop(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3), lineWidth: 1))
                            )
                    } else {
                        VStack(spacing: 8) {
                            Text(data.primaryValue)
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            
                            if let secondaryValue = data.secondaryValue {
                                Text(secondaryValue)
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    
                    // Achievement description for achievement cards
                    if data.type == .achievement, let achievement = data.achievement {
                        Text(achievement.description)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Stats footer (if relevant)
                if let stats = data.stats, data.type != .motivation {
                    HStack(spacing: 40) {
                        if data.type != .streak {
                            StatItem(
                                title: "Streak",
                                value: "\(stats.currentStreak)",
                                icon: "flame.fill"
                            )
                        }
                        
                        StatItem(
                            title: "Success Rate",
                            value: "\(Int(stats.successRate * 100))%",
                            icon: "target"
                        )
                        
                        StatItem(
                            title: "Total",
                            value: "\(stats.successfulWakeUps)",
                            icon: "sun.max.fill"
                        )
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Stat Item Component
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Backdrop Modifier
extension View {
    func backdrop<Background: View>(_ background: Background) -> some View {
        self.overlay(background)
    }
}

// MARK: - Mock Implementation
class MockSocialSharingService: SocialSharingServiceProtocol {
    @Published private var mockSettings = SharingPrivacySettings()
    
    var privacySettings: AnyPublisher<SharingPrivacySettings, Never> {
        $mockSettings.eraseToAnyPublisher()
    }
    
    func generateShareCard(data: ShareCardData, platform: SocialPlatform) async -> UIImage? {
        // Return a mock image for testing
        return UIImage(systemName: "photo")
    }
    
    func shareContent(_ content: ShareCardData, platform: SocialPlatform) async -> Bool {
        return true // Mock success
    }
    
    func createStreakShareCard(stats: EnhancedUserStats) -> ShareCardData {
        return ShareCardData(
            type: .streak,
            title: "Mock Streak",
            primaryValue: "5",
            secondaryValue: "days strong"
        )
    }
    
    func createAchievementShareCard(achievement: StreakAchievement, stats: EnhancedUserStats) -> ShareCardData {
        return ShareCardData(
            type: .achievement,
            title: achievement.title,
            primaryValue: "UNLOCKED"
        )
    }
    
    func createWeeklyStatsShareCard(stats: EnhancedUserStats) -> ShareCardData {
        return ShareCardData(
            type: .weeklyStats,
            title: "Weekly Progress",
            primaryValue: "80%"
        )
    }
    
    func createMotivationShareCard(quote: String, stats: EnhancedUserStats) -> ShareCardData {
        return ShareCardData(
            type: .motivation,
            title: "Motivation",
            primaryValue: quote
        )
    }
    
    func updatePrivacySettings(_ settings: SharingPrivacySettings) async {
        mockSettings = settings
    }
    
    func canShare() -> Bool {
        return mockSettings.isEnabled
    }
}
