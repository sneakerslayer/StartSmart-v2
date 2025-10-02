import XCTest
@testable import StartSmart

final class ModelTests: XCTestCase {

    // MARK: - Alarm Model Tests
    func testAlarmInitialization() {
        let time = Date()
        let alarm = Alarm(time: time, label: "Test Alarm")
        
        XCTAssertEqual(alarm.time, time)
        XCTAssertEqual(alarm.label, "Test Alarm")
        XCTAssertTrue(alarm.isEnabled)
        XCTAssertTrue(alarm.repeatDays.isEmpty)
        XCTAssertEqual(alarm.tone, .energetic)
        XCTAssertTrue(alarm.snoozeEnabled)
        XCTAssertEqual(alarm.snoozeDuration, 300) // 5 minutes
        XCTAssertEqual(alarm.maxSnoozeCount, 3)
        XCTAssertEqual(alarm.currentSnoozeCount, 0)
    }
    
    func testAlarmToggle() {
        var alarm = Alarm(time: Date(), label: "Test")
        XCTAssertTrue(alarm.isEnabled)
        
        alarm.toggle()
        XCTAssertFalse(alarm.isEnabled)
        
        alarm.toggle()
        XCTAssertTrue(alarm.isEnabled)
    }
    
    func testAlarmSnooze() {
        var alarm = Alarm(time: Date(), label: "Test", maxSnoozeCount: 2)
        XCTAssertTrue(alarm.canSnooze)
        XCTAssertEqual(alarm.currentSnoozeCount, 0)
        
        alarm.snooze()
        XCTAssertEqual(alarm.currentSnoozeCount, 1)
        XCTAssertTrue(alarm.canSnooze)
        
        alarm.snooze()
        XCTAssertEqual(alarm.currentSnoozeCount, 2)
        XCTAssertFalse(alarm.canSnooze)
        
        // Should not increment beyond max
        alarm.snooze()
        XCTAssertEqual(alarm.currentSnoozeCount, 2)
    }
    
    func testAlarmRepeatingLogic() {
        let alarm1 = Alarm(time: Date(), repeatDays: [])
        XCTAssertFalse(alarm1.isRepeating)
        
        let alarm2 = Alarm(time: Date(), repeatDays: [.monday, .friday])
        XCTAssertTrue(alarm2.isRepeating)
    }
    
    func testWeekDayComparison() {
        XCTAssertTrue(WeekDay.sunday < WeekDay.monday)
        XCTAssertTrue(WeekDay.friday < WeekDay.saturday)
        
        let sorted = [WeekDay.friday, WeekDay.monday, WeekDay.sunday].sorted()
        XCTAssertEqual(sorted, [.sunday, .monday, .friday])
    }
    
    func testAlarmToneProperties() {
        XCTAssertEqual(AlarmTone.gentle.displayName, "Gentle")
        XCTAssertEqual(AlarmTone.energetic.voiceId, "energetic")
        XCTAssertEqual(AlarmTone.toughLove.rawValue, "tough_love")
    }
    
    // MARK: - User Model Tests
    func testUserInitialization() {
        let user = User(email: "test@example.com", displayName: "Test User")
        
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.subscription, .free)
        XCTAssertFalse(user.canAccessPremiumFeatures)
    }
    
    func testAnonymousUser() {
        let user = User()
        
        XCTAssertNil(user.email)
        XCTAssertTrue(user.isAnonymous)
        XCTAssertEqual(user.displayNameOrEmail, "Anonymous User")
    }
    
    func testUserStatsUpdate() {
        var stats = UserStats()
        
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.successfulWakeUps, 0)
        
        stats.updateStreak()
        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.longestStreak, 1)
    }
    
    func testSubscriptionFeatures() {
        XCTAssertTrue(SubscriptionStatus.free.monthlyAlarmLimit == 3)
        XCTAssertNil(SubscriptionStatus.proMonthly.monthlyAlarmLimit)
        XCTAssertTrue(SubscriptionStatus.proAnnual.hasEarlyAccess)
        XCTAssertFalse(SubscriptionStatus.free.isPremium)
    }
    
    func testUserPreferencesToneMapping() {
        var preferences = UserPreferences()
        
        preferences.toneSliderPosition = 0.1
        XCTAssertEqual(preferences.computedTone, .gentle)
        
        preferences.toneSliderPosition = 0.4
        XCTAssertEqual(preferences.computedTone, .storyteller)
        
        preferences.toneSliderPosition = 0.6
        XCTAssertEqual(preferences.computedTone, .energetic)
        
        preferences.toneSliderPosition = 0.9
        XCTAssertEqual(preferences.computedTone, .toughLove)
    }
    
    // MARK: - Intent Model Tests
    func testIntentInitialization() {
        let goal = "Exercise for 30 minutes"
        let scheduledTime = Date().addingTimeInterval(3600) // 1 hour from now
        let intent = Intent(userGoal: goal, scheduledFor: scheduledTime)
        
        XCTAssertEqual(intent.userGoal, goal)
        XCTAssertEqual(intent.tone, .energetic)
        XCTAssertEqual(intent.status, .pending)
        XCTAssertNil(intent.generatedContent)
        XCTAssertFalse(intent.isReady)
        XCTAssertFalse(intent.isExpired)
    }
    
    func testIntentExpiration() {
        let pastTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let intent = Intent(userGoal: "Test", scheduledFor: pastTime)
        
        XCTAssertTrue(intent.isExpired)
    }
    
    func testIntentAutoGeneration() {
        let nearFutureTime = Date().addingTimeInterval(1800) // 30 minutes from now
        let intent = Intent(userGoal: "Test", scheduledFor: nearFutureTime)
        
        XCTAssertTrue(intent.shouldAutoGenerate)
    }
    
    func testIntentStatusTransitions() {
        var intent = Intent(userGoal: "Test", scheduledFor: Date().addingTimeInterval(3600))
        
        XCTAssertEqual(intent.status, .pending)
        
        intent.markAsGenerating()
        XCTAssertEqual(intent.status, .generating)
        
        let content = GeneratedContent(
            textContent: "Test content",
            voiceId: "test_voice",
            metadata: ContentMetadata(textContent: "Test content", tone: .energetic)
        )
        intent.setGeneratedContent(content)
        XCTAssertEqual(intent.status, .ready)
        XCTAssertTrue(intent.isReady)
        
        intent.markAsUsed()
        XCTAssertEqual(intent.status, .used)
    }
    
    func testIntentContextEnrichment() {
        var context = IntentContext()
        XCTAssertFalse(context.dayOfWeek.isEmpty) // Should be auto-filled
        
        context.enrichWithCurrentData()
        XCTAssertFalse(context.dayOfWeek.isEmpty)
    }
    
    func testTimeOfDayMapping() {
        XCTAssertEqual(TimeOfDay.from(hour: 7), .earlyMorning)
        XCTAssertEqual(TimeOfDay.from(hour: 10), .morning)
        XCTAssertEqual(TimeOfDay.from(hour: 15), .afternoon)
        XCTAssertEqual(TimeOfDay.from(hour: 19), .evening)
        XCTAssertEqual(TimeOfDay.from(hour: 23), .night)
    }
    
    func testContentMetadataCalculation() {
        let text = "This is a test message with exactly ten words total."
        let metadata = ContentMetadata(textContent: text, tone: .energetic)
        
        XCTAssertEqual(metadata.wordCount, 10)
        XCTAssertGreaterThan(metadata.estimatedDuration, 0)
        XCTAssertEqual(metadata.tone, .energetic)
    }
    
    func testQuickIntentCreation() {
        let intent = Intent.quickIntent(
            goal: "Quick test",
            tone: .gentle,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        XCTAssertEqual(intent.userGoal, "Quick test")
        XCTAssertEqual(intent.tone, .gentle)
        XCTAssertFalse(intent.context.dayOfWeek.isEmpty)
    }
    
    // MARK: - Integration Tests
    func testAlarmIntentIntegration() {
        let alarm = Alarm(time: Date(), label: "Morning Workout", tone: .energetic)
        let intent = Intent.from(alarm: alarm, goal: "Complete 30-minute workout")
        
        XCTAssertEqual(intent.userGoal, "Complete 30-minute workout")
        XCTAssertEqual(intent.tone, alarm.tone)
        XCTAssertEqual(intent.alarmId, alarm.id)
    }
    
    func testUserAlarmCreationTracking() {
        var user = User()
        XCTAssertEqual(user.stats.totalAlarmsCreated, 0)
        
        user.incrementAlarmCount()
        XCTAssertEqual(user.stats.totalAlarmsCreated, 1)
        
        user.recordSuccessfulWakeUp()
        XCTAssertEqual(user.stats.successfulWakeUps, 1)
        XCTAssertEqual(user.stats.currentStreak, 1)
    }
}

// MARK: - Codable Tests
extension ModelTests {
    func testAlarmCodable() throws {
        let original = Alarm(
            time: Date(),
            label: "Test Alarm",
            repeatDays: [.monday, .wednesday, .friday],
            tone: .toughLove
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Alarm.self, from: encoded)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.label, decoded.label)
        XCTAssertEqual(original.repeatDays, decoded.repeatDays)
        XCTAssertEqual(original.tone, decoded.tone)
    }
    
    func testUserCodable() throws {
        let original = User(
            email: "test@example.com",
            displayName: "Test User",
            subscription: .proMonthly
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(User.self, from: encoded)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.email, decoded.email)
        XCTAssertEqual(original.subscription, decoded.subscription)
    }
    
    func testIntentCodable() throws {
        let original = Intent(
            userGoal: "Test goal",
            tone: .storyteller,
            scheduledFor: Date()
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Intent.self, from: encoded)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.userGoal, decoded.userGoal)
        XCTAssertEqual(original.tone, decoded.tone)
    }
}
