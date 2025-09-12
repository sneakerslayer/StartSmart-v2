import XCTest
import Combine
@testable import StartSmart

@MainActor
class StreakTrackingServiceTests: XCTestCase {
    var sut: StreakTrackingService!
    var mockStorage: MockLocalStorage!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockLocalStorage()
        sut = StreakTrackingService(storage: mockStorage)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockStorage = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialState() {
        let expectation = XCTestExpectation(description: "Initial stats received")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertEqual(stats.currentStreak, 0)
                XCTAssertEqual(stats.successfulWakeUps, 0)
                XCTAssertEqual(stats.totalSnoozes, 0)
                XCTAssertEqual(stats.longestStreak, 0)
                XCTAssertTrue(stats.unlockedAchievements.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRecordFirstAlarmDismiss() async {
        let alarmId = UUID()
        let testDate = Date()
        
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: testDate)
        
        let expectation = XCTestExpectation(description: "Stats updated")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertEqual(stats.currentStreak, 1)
                XCTAssertEqual(stats.successfulWakeUps, 1)
                XCTAssertEqual(stats.longestStreak, 1)
                XCTAssertEqual(stats.lastWakeUpDate?.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1.0)
                XCTAssertTrue(stats.unlockedAchievements.contains(.firstWakeUp))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStreakContinuation() async {
        let alarmId = UUID()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Record wake-up yesterday
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .button, time: yesterday)
        
        // Record wake-up today
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: today)
        
        let expectation = XCTestExpectation(description: "Streak continued")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertEqual(stats.currentStreak, 2)
                XCTAssertEqual(stats.successfulWakeUps, 2)
                XCTAssertEqual(stats.longestStreak, 2)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStreakBroken() async {
        let alarmId = UUID()
        let calendar = Calendar.current
        let today = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        
        // Record wake-up 3 days ago to establish streak
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .button, time: threeDaysAgo)
        
        // Record wake-up today (breaking the streak)
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: today)
        
        let expectation = XCTestExpectation(description: "Streak broken and restarted")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertEqual(stats.currentStreak, 1) // Restarted
                XCTAssertEqual(stats.successfulWakeUps, 2)
                XCTAssertEqual(stats.longestStreak, 1) // Previous streak was only 1 day
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAlarmMiss() async {
        let alarmId = UUID()
        let today = Date()
        
        // Establish a streak first
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: today)
        
        // Miss an alarm
        await sut.recordAlarmMiss(alarmId: alarmId, time: today)
        
        let expectation = XCTestExpectation(description: "Alarm miss recorded")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertEqual(stats.currentStreak, 0) // Streak broken
                XCTAssertEqual(stats.totalMissedAlarms, 1)
                XCTAssertEqual(stats.successfulWakeUps, 1) // Previous success still counted
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Achievement Tests
    
    func testFirstWakeUpAchievement() async {
        let alarmId = UUID()
        
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: Date())
        
        let expectation = XCTestExpectation(description: "First wake-up achievement unlocked")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertTrue(stats.unlockedAchievements.contains(.firstWakeUp))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testThreeDayStreakAchievement() async {
        let alarmId = UUID()
        let calendar = Calendar.current
        let today = Date()
        
        // Build up a 3-day streak
        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -2 + i, to: today)!
            await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: date)
        }
        
        let expectation = XCTestExpectation(description: "Three-day streak achievement unlocked")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertEqual(stats.currentStreak, 3)
                XCTAssertTrue(stats.unlockedAchievements.contains(.threeDayStreak))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testEarlyBirdAchievement() async {
        let alarmId = UUID()
        let calendar = Calendar.current
        
        // Create early morning times (6 AM) for 5 consecutive days
        for i in 0..<5 {
            let baseDate = calendar.date(byAdding: .day, value: i, to: Date())!
            let earlyMorning = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: baseDate)!
            await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: earlyMorning)
        }
        
        let expectation = XCTestExpectation(description: "Early bird achievement unlocked")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertGreaterThanOrEqual(stats.earlyBirdDays, 5)
                XCTAssertTrue(stats.unlockedAchievements.contains(.earlyBird))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testNoSnoozeAchievement() async {
        let alarmId = UUID()
        let calendar = Calendar.current
        let today = Date()
        
        // Record 7 days of wake-ups without snoozing
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: i, to: today)!
            await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: date)
        }
        
        let expectation = XCTestExpectation(description: "No snooze achievement unlocked")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertGreaterThanOrEqual(stats.noSnoozeDays, 7)
                XCTAssertTrue(stats.unlockedAchievements.contains(.noSnooze))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSnoozeBreaksNoSnoozeStreak() async {
        let alarmId = UUID()
        let calendar = Calendar.current
        let today = Date()
        
        // Build up some no-snooze days
        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: i, to: today)!
            await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: date)
        }
        
        // Then snooze an alarm
        await sut.recordAlarmSnooze(alarmId: alarmId, count: 1, time: today)
        
        let expectation = XCTestExpectation(description: "Snooze resets no-snooze counter")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertEqual(stats.noSnoozeDays, 0) // Reset by snooze
                XCTAssertEqual(stats.totalSnoozes, 1)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Weekly/Monthly Stats Tests
    
    func testWeeklyStats() async {
        let alarmId = UUID()
        let calendar = Calendar.current
        let today = Date()
        
        // Record successes and misses throughout the week
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: today)
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .button, time: today)
        await sut.recordAlarmMiss(alarmId: alarmId, time: today)
        
        let expectation = XCTestExpectation(description: "Weekly stats updated")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertEqual(stats.thisWeekSuccesses, 2)
                XCTAssertEqual(stats.thisWeekMisses, 1)
                XCTAssertEqual(stats.weeklySuccessRate, 2.0/3.0, accuracy: 0.01)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testWeekendWarriorAchievement() async {
        let alarmId = UUID()
        let calendar = Calendar.current
        
        // Create weekend dates (Saturday and Sunday) for 4 consecutive weekends
        var weekendDates: [Date] = []
        var currentDate = Date()
        
        // Find the next Saturday
        while calendar.component(.weekday, from: currentDate) != 7 { // Saturday = 7
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Add 4 weekends (Saturday and Sunday each)
        for week in 0..<4 {
            let saturday = calendar.date(byAdding: .weekOfYear, value: week, to: currentDate)!
            let sunday = calendar.date(byAdding: .day, value: 1, to: saturday)!
            weekendDates.append(saturday)
            weekendDates.append(sunday)
        }
        
        // Record wake-ups on all weekend days
        for date in weekendDates {
            await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: date)
        }
        
        let expectation = XCTestExpectation(description: "Weekend warrior achievement unlocked")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertGreaterThanOrEqual(stats.weekendSuccesses, 4)
                XCTAssertTrue(stats.unlockedAchievements.contains(.weekendWarrior))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Progress Tracking Tests
    
    func testAchievementProgress() {
        let progress = sut.getAchievementProgress()
        
        XCTAssertTrue(progress.keys.contains(.firstWakeUp))
        XCTAssertTrue(progress.keys.contains(.threeDayStreak))
        XCTAssertTrue(progress.keys.contains(.weekStreak))
        
        // All progress should be 0.0 initially
        for (_, value) in progress {
            XCTAssertEqual(value, 0.0, accuracy: 0.01)
        }
    }
    
    func testRecentActivity() async {
        let alarmId = UUID()
        let today = Date()
        
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: today)
        await sut.recordAlarmSnooze(alarmId: alarmId, count: 1, time: today)
        
        let recentEvents = sut.getRecentActivity(days: 7)
        
        XCTAssertEqual(recentEvents.count, 2)
        
        // Check that we have both a dismiss and snooze event
        let dismissEvents = recentEvents.compactMap { event in
            if case .alarmDismissed = event { return event }
            return nil
        }
        let snoozeEvents = recentEvents.compactMap { event in
            if case .alarmSnoozed = event { return event }
            return nil
        }
        
        XCTAssertEqual(dismissEvents.count, 1)
        XCTAssertEqual(snoozeEvents.count, 1)
    }
    
    // MARK: - Persistence Tests
    
    func testStatsPersistence() async {
        let alarmId = UUID()
        
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: Date())
        
        // Verify that save was called on storage
        XCTAssertTrue(mockStorage.saveCallCount > 0)
        XCTAssertNotNil(mockStorage.lastSavedData)
    }
    
    func testStatsLoading() async {
        // Pre-populate storage with test data
        var testStats = EnhancedUserStats()
        testStats.currentStreak = 5
        testStats.successfulWakeUps = 10
        testStats.unlockedAchievements.insert(.threeDayStreak)
        
        mockStorage.mockData["enhanced_user_stats"] = try! JSONEncoder().encode(testStats)
        
        // Create new service instance to test loading
        let newService = StreakTrackingService(storage: mockStorage)
        await newService.loadStats()
        
        let expectation = XCTestExpectation(description: "Stats loaded")
        
        newService.enhancedStats
            .sink { stats in
                XCTAssertEqual(stats.currentStreak, 5)
                XCTAssertEqual(stats.successfulWakeUps, 10)
                XCTAssertTrue(stats.unlockedAchievements.contains(.threeDayStreak))
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testResetStats() async {
        let alarmId = UUID()
        
        // Build up some stats
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: Date())
        await sut.recordAlarmSnooze(alarmId: alarmId, count: 2, time: Date())
        
        // Reset stats
        await sut.resetStats()
        
        let expectation = XCTestExpectation(description: "Stats reset")
        
        sut.enhancedStats
            .sink { stats in
                XCTAssertEqual(stats.currentStreak, 0)
                XCTAssertEqual(stats.successfulWakeUps, 0)
                XCTAssertEqual(stats.totalSnoozes, 0)
                XCTAssertTrue(stats.unlockedAchievements.isEmpty)
                XCTAssertTrue(stats.recentEvents.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - New Achievement Notification Tests
    
    func testNewAchievementNotification() async {
        let alarmId = UUID()
        
        let achievementExpectation = XCTestExpectation(description: "New achievement notification")
        
        sut.newAchievements
            .sink { achievements in
                if !achievements.isEmpty {
                    XCTAssertTrue(achievements.contains(.firstWakeUp))
                    achievementExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await sut.recordAlarmDismiss(alarmId: alarmId, method: .voice, time: Date())
        
        wait(for: [achievementExpectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidStorageHandling() async {
        let failingStorage = FailingMockStorage()
        let service = StreakTrackingService(storage: failingStorage)
        
        // Should not crash when storage operations fail
        await service.recordAlarmDismiss(alarmId: UUID(), method: .voice, time: Date())
        await service.loadStats()
        await service.resetStats()
    }
}

// MARK: - Mock Storage for Testing
class FailingMockStorage: LocalStorageProtocol {
    func save<T: Codable>(_ object: T, forKey key: String) async {
        // Simulate storage failure by doing nothing
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) async -> T? {
        // Simulate storage failure by returning nil
        return nil
    }
    
    func delete(forKey key: String) async {
        // Simulate storage failure by doing nothing
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
