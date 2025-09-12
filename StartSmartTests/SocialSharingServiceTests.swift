import XCTest
import UIKit
import Combine
@testable import StartSmart

@MainActor
class SocialSharingServiceTests: XCTestCase {
    var sut: SocialSharingService!
    var mockStorage: MockLocalStorage!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockLocalStorage()
        sut = SocialSharingService(storage: mockStorage)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockStorage = nil
        super.tearDown()
    }
    
    // MARK: - Privacy Settings Tests
    
    func testInitialPrivacySettings() {
        let expectation = XCTestExpectation(description: "Initial privacy settings received")
        
        sut.privacySettings
            .sink { settings in
                XCTAssertFalse(settings.isEnabled) // Should be disabled by default
                XCTAssertTrue(settings.showPersonalStats)
                XCTAssertTrue(settings.showAchievements)
                XCTAssertTrue(settings.showStreakCount)
                XCTAssertFalse(settings.showExactTimes)
                XCTAssertFalse(settings.autoShareMilestones)
                XCTAssertTrue(settings.preferredPlatforms.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdatePrivacySettings() async {
        var newSettings = SharingPrivacySettings()
        newSettings.isEnabled = true
        newSettings.showExactTimes = true
        newSettings.autoShareMilestones = true
        newSettings.preferredPlatforms = ["instagram", "twitter"]
        
        await sut.updatePrivacySettings(newSettings)
        
        let expectation = XCTestExpectation(description: "Privacy settings updated")
        
        sut.privacySettings
            .sink { settings in
                XCTAssertTrue(settings.isEnabled)
                XCTAssertTrue(settings.showExactTimes)
                XCTAssertTrue(settings.autoShareMilestones)
                XCTAssertTrue(settings.preferredPlatforms.contains("instagram"))
                XCTAssertTrue(settings.preferredPlatforms.contains("twitter"))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify persistence
        XCTAssertTrue(mockStorage.saveCallCount > 0)
    }
    
    func testCanShareWhenDisabled() {
        XCTAssertFalse(sut.canShare()) // Should be false when disabled
    }
    
    func testCanShareWhenEnabled() async {
        var settings = SharingPrivacySettings()
        settings.isEnabled = true
        
        await sut.updatePrivacySettings(settings)
        
        XCTAssertTrue(sut.canShare())
    }
    
    // MARK: - Share Card Creation Tests
    
    func testCreateStreakShareCard() {
        var stats = EnhancedUserStats()
        stats.currentStreak = 7
        stats.longestStreak = 10
        
        let shareData = sut.createStreakShareCard(stats: stats)
        
        XCTAssertEqual(shareData.type, .streak)
        XCTAssertEqual(shareData.primaryValue, "7")
        XCTAssertEqual(shareData.secondaryValue, "days strong")
        XCTAssertEqual(shareData.iconName, "flame.fill")
        XCTAssertNotNil(shareData.stats)
    }
    
    func testCreateStreakShareCardForFirstDay() {
        var stats = EnhancedUserStats()
        stats.currentStreak = 1
        
        let shareData = sut.createStreakShareCard(stats: stats)
        
        XCTAssertEqual(shareData.title, "Started My Journey")
        XCTAssertEqual(shareData.primaryValue, "1")
        XCTAssertEqual(shareData.secondaryValue, "day strong")
    }
    
    func testCreateAchievementShareCard() {
        var stats = EnhancedUserStats()
        stats.currentStreak = 7
        
        let achievement = StreakAchievement.weekStreak
        let shareData = sut.createAchievementShareCard(achievement: achievement, stats: stats)
        
        XCTAssertEqual(shareData.type, .achievement)
        XCTAssertEqual(shareData.title, achievement.title)
        XCTAssertEqual(shareData.primaryValue, "UNLOCKED")
        XCTAssertEqual(shareData.secondaryValue, achievement.description)
        XCTAssertEqual(shareData.iconName, achievement.iconName)
        XCTAssertEqual(shareData.achievement, achievement)
        XCTAssertNotNil(shareData.subtitle) // Should have motivational message
    }
    
    func testCreateWeeklyStatsShareCard() {
        var stats = EnhancedUserStats()
        stats.thisWeekSuccesses = 6
        stats.thisWeekMisses = 1
        
        let shareData = sut.createWeeklyStatsShareCard(stats: stats)
        
        XCTAssertEqual(shareData.type, .weeklyStats)
        XCTAssertEqual(shareData.title, "This Week's Progress")
        XCTAssertEqual(shareData.primaryValue, "86%") // 6/7 = ~86%
        XCTAssertEqual(shareData.secondaryValue, "6/7 days")
        XCTAssertEqual(shareData.iconName, "chart.line.uptrend.xyaxis")
        XCTAssertNotNil(shareData.subtitle)
    }
    
    func testCreateWeeklyStatsShareCardHighSuccess() {
        var stats = EnhancedUserStats()
        stats.thisWeekSuccesses = 7
        stats.thisWeekMisses = 0
        
        let shareData = sut.createWeeklyStatsShareCard(stats: stats)
        
        XCTAssertEqual(shareData.primaryValue, "100%")
        XCTAssertTrue(shareData.subtitle?.contains("Crushing it") ?? false)
    }
    
    func testCreateMotivationShareCard() {
        var stats = EnhancedUserStats()
        stats.currentStreak = 5
        
        let quote = "Every morning is a new opportunity!"
        let shareData = sut.createMotivationShareCard(quote: quote, stats: stats)
        
        XCTAssertEqual(shareData.type, .motivation)
        XCTAssertEqual(shareData.title, "Morning Motivation")
        XCTAssertEqual(shareData.subtitle, "Powered by AI")
        XCTAssertEqual(shareData.primaryValue, quote)
        XCTAssertEqual(shareData.iconName, "quote.bubble.fill")
        XCTAssertEqual(shareData.motivationalQuote, quote)
    }
    
    // MARK: - Share Card Generation Tests
    
    func testGenerateShareCardForInstagram() async {
        let shareData = ShareCardData(
            type: .streak,
            title: "Test Streak",
            primaryValue: "5",
            iconName: "flame.fill"
        )
        
        let image = await sut.generateShareCard(data: shareData, platform: .instagram)
        
        XCTAssertNotNil(image)
        
        // Verify image dimensions match Instagram's preferred size
        if let image = image {
            XCTAssertEqual(image.size.width, 1080, accuracy: 1.0)
            XCTAssertEqual(image.size.height, 1920, accuracy: 1.0)
        }
    }
    
    func testGenerateShareCardForTwitter() async {
        let shareData = ShareCardData(
            type: .achievement,
            title: "Achievement",
            primaryValue: "UNLOCKED",
            iconName: "trophy.fill"
        )
        
        let image = await sut.generateShareCard(data: shareData, platform: .twitter)
        
        XCTAssertNotNil(image)
        
        // Verify image dimensions match Twitter's preferred size
        if let image = image {
            XCTAssertEqual(image.size.width, 1200, accuracy: 1.0)
            XCTAssertEqual(image.size.height, 675, accuracy: 1.0)
        }
    }
    
    func testGenerateShareCardForGeneral() async {
        let shareData = ShareCardData(
            type: .weeklyStats,
            title: "Weekly Progress",
            primaryValue: "85%",
            iconName: "chart.line.uptrend.xyaxis"
        )
        
        let image = await sut.generateShareCard(data: shareData, platform: .general)
        
        XCTAssertNotNil(image)
        
        // Verify image dimensions match general (square) size
        if let image = image {
            XCTAssertEqual(image.size.width, 1080, accuracy: 1.0)
            XCTAssertEqual(image.size.height, 1080, accuracy: 1.0)
        }
    }
    
    // MARK: - Platform Configuration Tests
    
    func testSocialPlatformProperties() {
        XCTAssertEqual(SocialPlatform.instagram.displayName, "Instagram Stories")
        XCTAssertEqual(SocialPlatform.tiktok.displayName, "TikTok")
        XCTAssertEqual(SocialPlatform.twitter.displayName, "Twitter")
        XCTAssertEqual(SocialPlatform.general.displayName, "Share")
        
        // Test preferred sizes
        XCTAssertEqual(SocialPlatform.instagram.preferredSize, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(SocialPlatform.twitter.preferredSize, CGSize(width: 1200, height: 675))
        XCTAssertEqual(SocialPlatform.general.preferredSize, CGSize(width: 1080, height: 1080))
    }
    
    func testShareContentTypeProperties() {
        XCTAssertEqual(ShareContentType.streak.displayName, "Current Streak")
        XCTAssertEqual(ShareContentType.achievement.displayName, "Achievement Unlocked")
        XCTAssertEqual(ShareContentType.weeklyStats.displayName, "Weekly Progress")
        XCTAssertEqual(ShareContentType.motivation.displayName, "Morning Motivation")
        XCTAssertEqual(ShareContentType.milestone.displayName, "Milestone Reached")
    }
    
    // MARK: - Share Card Data Tests
    
    func testShareCardDataInitialization() {
        let shareData = ShareCardData(
            type: .streak,
            title: "Test Title",
            subtitle: "Test Subtitle",
            primaryValue: "Test Value",
            secondaryValue: "Secondary Value",
            backgroundGradient: [.red, .blue],
            iconName: "star.fill"
        )
        
        XCTAssertEqual(shareData.type, .streak)
        XCTAssertEqual(shareData.title, "Test Title")
        XCTAssertEqual(shareData.subtitle, "Test Subtitle")
        XCTAssertEqual(shareData.primaryValue, "Test Value")
        XCTAssertEqual(shareData.secondaryValue, "Secondary Value")
        XCTAssertEqual(shareData.backgroundGradient, [.red, .blue])
        XCTAssertEqual(shareData.iconName, "star.fill")
        XCTAssertNotNil(shareData.timestamp)
    }
    
    func testShareCardDataWithStats() {
        var stats = EnhancedUserStats()
        stats.currentStreak = 10
        
        let shareData = ShareCardData(
            type: .streak,
            title: "Streak Card",
            primaryValue: "10",
            stats: stats
        )
        
        XCTAssertNotNil(shareData.stats)
        XCTAssertEqual(shareData.stats?.currentStreak, 10)
    }
    
    // MARK: - Persistence Tests
    
    func testPrivacySettingsPersistence() async {
        var settings = SharingPrivacySettings()
        settings.isEnabled = true
        settings.showPersonalStats = false
        
        await sut.updatePrivacySettings(settings)
        
        // Verify that save was called on storage
        XCTAssertTrue(mockStorage.saveCallCount > 0)
        XCTAssertNotNil(mockStorage.lastSavedData)
    }
    
    func testLoadPrivacySettings() async {
        // Pre-populate storage with test data
        var testSettings = SharingPrivacySettings()
        testSettings.isEnabled = true
        testSettings.autoShareMilestones = true
        testSettings.preferredPlatforms = ["instagram"]
        
        mockStorage.mockData["sharing_privacy_settings"] = try! JSONEncoder().encode(testSettings)
        
        // Create new service instance to test loading
        let newService = SocialSharingService(storage: mockStorage)
        
        // Wait a moment for async loading to complete
        try! await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let expectation = XCTestExpectation(description: "Settings loaded")
        
        newService.privacySettings
            .sink { settings in
                XCTAssertTrue(settings.isEnabled)
                XCTAssertTrue(settings.autoShareMilestones)
                XCTAssertTrue(settings.preferredPlatforms.contains("instagram"))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testShareContentWhenSharingDisabled() async {
        // Ensure sharing is disabled
        var settings = SharingPrivacySettings()
        settings.isEnabled = false
        await sut.updatePrivacySettings(settings)
        
        let shareData = ShareCardData(
            type: .streak,
            title: "Test",
            primaryValue: "5"
        )
        
        let success = await sut.shareContent(shareData, platform: .general)
        
        XCTAssertFalse(success) // Should fail when sharing is disabled
    }
    
    func testInvalidStorageHandling() async {
        let failingStorage = FailingSocialStorage()
        let service = SocialSharingService(storage: failingStorage)
        
        var settings = SharingPrivacySettings()
        settings.isEnabled = true
        
        // Should not crash when storage operations fail
        await service.updatePrivacySettings(settings)
        
        // Service should still function with default settings
        XCTAssertFalse(service.canShare()) // Should default to disabled
    }
    
    // MARK: - Integration Tests
    
    func testCompleteShareWorkflow() async {
        // Enable sharing
        var settings = SharingPrivacySettings()
        settings.isEnabled = true
        settings.showPersonalStats = true
        await sut.updatePrivacySettings(settings)
        
        // Create stats
        var stats = EnhancedUserStats()
        stats.currentStreak = 7
        stats.successfulWakeUps = 50
        
        // Create share card
        let shareData = sut.createStreakShareCard(stats: stats)
        
        // Generate image
        let image = await sut.generateShareCard(data: shareData, platform: .instagram)
        XCTAssertNotNil(image)
        
        // Verify sharing is enabled
        XCTAssertTrue(sut.canShare())
    }
    
    func testMultiplePlatformGeneration() async {
        let shareData = ShareCardData(
            type: .achievement,
            title: "Test Achievement",
            primaryValue: "UNLOCKED",
            iconName: "trophy.fill"
        )
        
        // Test all platforms
        for platform in SocialPlatform.allCases {
            let image = await sut.generateShareCard(data: shareData, platform: platform)
            XCTAssertNotNil(image, "Failed to generate image for platform: \(platform)")
            
            if let image = image {
                let expectedSize = platform.preferredSize
                XCTAssertEqual(image.size.width, expectedSize.width, accuracy: 1.0)
                XCTAssertEqual(image.size.height, expectedSize.height, accuracy: 1.0)
            }
        }
    }
}

// MARK: - Mock Failing Storage
class FailingSocialStorage: LocalStorageProtocol {
    func save<T: Codable>(_ object: T, forKey key: String) async {
        // Simulate storage failure by doing nothing
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) async -> T? {
        // Simulate storage failure by returning nil
        return nil
    }
    
    func delete(forKey key: String) async {
        // Do nothing
    }
    
    func exists(forKey key: String) async -> Bool {
        return false
    }
    
    func getAllKeys() async -> [String] {
        return []
    }
    
    func clearAll() async {
        // Do nothing
    }
}
