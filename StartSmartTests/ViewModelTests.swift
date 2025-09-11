import XCTest
import Combine
@testable import StartSmart

@MainActor
final class ViewModelTests: XCTestCase {
    
    var mockStorage: MockStorageManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockStorageManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        mockStorage = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - AlarmViewModel Tests
    func testAlarmViewModelInitialization() {
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        
        XCTAssertTrue(viewModel.alarms.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.hasEnabledAlarms)
        XCTAssertNil(viewModel.nextAlarm)
    }
    
    func testAlarmViewModelAddAlarm() {
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        let alarm = Alarm(time: Date(), label: "Test Alarm")
        
        viewModel.addAlarm(alarm)
        
        XCTAssertEqual(viewModel.alarms.count, 1)
        XCTAssertEqual(viewModel.alarms.first?.label, "Test Alarm")
        XCTAssertTrue(mockStorage.saveAlarmsCalled)
    }
    
    func testAlarmViewModelToggleAlarm() {
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        let alarm = Alarm(time: Date(), label: "Test Alarm", isEnabled: true)
        
        viewModel.addAlarm(alarm)
        XCTAssertTrue(viewModel.alarms.first?.isEnabled ?? false)
        
        viewModel.toggleAlarm(alarm)
        XCTAssertFalse(viewModel.alarms.first?.isEnabled ?? true)
    }
    
    func testAlarmViewModelDeleteAlarm() {
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        let alarm = Alarm(time: Date(), label: "Test Alarm")
        
        viewModel.addAlarm(alarm)
        XCTAssertEqual(viewModel.alarms.count, 1)
        
        viewModel.deleteAlarm(alarm)
        XCTAssertTrue(viewModel.alarms.isEmpty)
    }
    
    func testAlarmViewModelNextAlarm() {
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        
        let alarm1 = Alarm(time: dayAfter, label: "Later Alarm")
        let alarm2 = Alarm(time: tomorrow, label: "Earlier Alarm")
        
        viewModel.addAlarm(alarm1)
        viewModel.addAlarm(alarm2)
        
        XCTAssertEqual(viewModel.nextAlarm?.label, "Earlier Alarm")
    }
    
    func testAlarmViewModelEnabledAlarmsFilter() {
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        
        let enabledAlarm = Alarm(time: Date(), label: "Enabled", isEnabled: true)
        let disabledAlarm = Alarm(time: Date(), label: "Disabled", isEnabled: false)
        
        viewModel.addAlarm(enabledAlarm)
        viewModel.addAlarm(disabledAlarm)
        
        XCTAssertEqual(viewModel.enabledAlarms.count, 1)
        XCTAssertEqual(viewModel.enabledAlarms.first?.label, "Enabled")
        XCTAssertTrue(viewModel.hasEnabledAlarms)
    }
    
    // MARK: - UserViewModel Tests
    func testUserViewModelInitialization() {
        let viewModel = UserViewModel(storageManager: mockStorage)
        
        XCTAssertNil(viewModel.currentUser)
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.displayName, "Anonymous User")
        XCTAssertTrue(viewModel.isAnonymous)
    }
    
    func testUserViewModelCreateAnonymousUser() {
        let viewModel = UserViewModel(storageManager: mockStorage)
        
        viewModel.createAnonymousUser()
        
        XCTAssertNotNil(viewModel.currentUser)
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertTrue(viewModel.isAnonymous)
        XCTAssertTrue(mockStorage.saveUserCalled)
    }
    
    func testUserViewModelSignIn() {
        let viewModel = UserViewModel(storageManager: mockStorage)
        
        viewModel.signIn(email: "test@example.com", displayName: "Test User")
        
        XCTAssertNotNil(viewModel.currentUser)
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertFalse(viewModel.isAnonymous)
        XCTAssertEqual(viewModel.displayName, "Test User")
        XCTAssertEqual(viewModel.currentUser?.email, "test@example.com")
    }
    
    func testUserViewModelSignOut() {
        let viewModel = UserViewModel(storageManager: mockStorage)
        
        viewModel.signIn(email: "test@example.com", displayName: "Test User")
        XCTAssertTrue(viewModel.isAuthenticated)
        
        viewModel.signOut()
        XCTAssertNil(viewModel.currentUser)
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertTrue(mockStorage.deleteUserCalled)
    }
    
    func testUserViewModelStatistics() {
        let viewModel = UserViewModel(storageManager: mockStorage)
        viewModel.createAnonymousUser()
        
        XCTAssertEqual(viewModel.userStats.totalAlarmsCreated, 0)
        
        viewModel.recordAlarmCreated()
        XCTAssertEqual(viewModel.userStats.totalAlarmsCreated, 1)
        
        viewModel.recordSuccessfulWakeUp()
        XCTAssertEqual(viewModel.userStats.successfulWakeUps, 1)
        XCTAssertEqual(viewModel.userStats.currentStreak, 1)
    }
    
    func testUserViewModelSubscriptionFeatures() {
        let viewModel = UserViewModel(storageManager: mockStorage)
        viewModel.createAnonymousUser()
        
        // Free user limitations
        XCTAssertFalse(viewModel.canAccessPremiumFeatures)
        XCTAssertFalse(viewModel.canAccessAdvancedAnalytics)
        XCTAssertFalse(viewModel.canAccessAllVoices)
        XCTAssertTrue(viewModel.canCreateMoreAlarms)
        
        // Upgrade to premium
        viewModel.updateSubscription(.proMonthly)
        XCTAssertTrue(viewModel.canAccessPremiumFeatures)
        XCTAssertTrue(viewModel.canAccessAdvancedAnalytics)
        XCTAssertTrue(viewModel.canAccessAllVoices)
    }
    
    // MARK: - IntentViewModel Tests
    func testIntentViewModelInitialization() {
        let viewModel = IntentViewModel(storageManager: mockStorage)
        
        XCTAssertTrue(viewModel.intents.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.pendingIntents.isEmpty)
        XCTAssertTrue(viewModel.readyIntents.isEmpty)
    }
    
    func testIntentViewModelCreateIntent() {
        let viewModel = IntentViewModel(storageManager: mockStorage)
        
        let scheduledTime = Date().addingTimeInterval(3600)
        let intent = viewModel.createIntent(
            userGoal: "Exercise for 30 minutes",
            tone: .energetic,
            scheduledFor: scheduledTime
        )
        
        XCTAssertEqual(viewModel.intents.count, 1)
        XCTAssertEqual(intent.userGoal, "Exercise for 30 minutes")
        XCTAssertEqual(intent.tone, .energetic)
        XCTAssertEqual(intent.status, .pending)
        XCTAssertTrue(mockStorage.saveIntentsCalled)
    }
    
    func testIntentViewModelQuickIntent() {
        let viewModel = IntentViewModel(storageManager: mockStorage)
        
        let scheduledTime = Date().addingTimeInterval(3600)
        let intent = viewModel.createQuickIntent(
            goal: "Quick goal",
            scheduledFor: scheduledTime
        )
        
        XCTAssertEqual(intent.userGoal, "Quick goal")
        XCTAssertEqual(intent.tone, .energetic)
        XCTAssertFalse(intent.context.dayOfWeek.isEmpty)
    }
    
    func testIntentViewModelStatusFiltering() {
        let viewModel = IntentViewModel(storageManager: mockStorage)
        
        let pendingIntent = Intent(userGoal: "Pending", scheduledFor: Date().addingTimeInterval(3600))
        viewModel.addIntent(pendingIntent)
        
        var readyIntent = Intent(userGoal: "Ready", scheduledFor: Date().addingTimeInterval(3600))
        let content = GeneratedContent(
            textContent: "Test content",
            voiceId: "test_voice",
            metadata: ContentMetadata(textContent: "Test content", tone: .energetic)
        )
        readyIntent.setGeneratedContent(content)
        viewModel.addIntent(readyIntent)
        
        XCTAssertEqual(viewModel.pendingIntents.count, 1)
        XCTAssertEqual(viewModel.readyIntents.count, 1)
        XCTAssertEqual(viewModel.pendingIntents.first?.userGoal, "Pending")
        XCTAssertEqual(viewModel.readyIntents.first?.userGoal, "Ready")
    }
    
    func testIntentViewModelTodayIntents() {
        let viewModel = IntentViewModel(storageManager: mockStorage)
        
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayIntent = Intent(userGoal: "Today", scheduledFor: today)
        let tomorrowIntent = Intent(userGoal: "Tomorrow", scheduledFor: tomorrow)
        
        viewModel.addIntent(todayIntent)
        viewModel.addIntent(tomorrowIntent)
        
        let todaysIntents = viewModel.intentsForToday()
        XCTAssertEqual(todaysIntents.count, 1)
        XCTAssertEqual(todaysIntents.first?.userGoal, "Today")
    }
    
    // MARK: - AlarmFormViewModel Tests
    func testAlarmFormViewModelInitialization() {
        let viewModel = AlarmFormViewModel()
        
        XCTAssertEqual(viewModel.label, "Wake up")
        XCTAssertTrue(viewModel.isEnabled)
        XCTAssertEqual(viewModel.tone, .energetic)
        XCTAssertTrue(viewModel.snoozeEnabled)
        XCTAssertEqual(viewModel.snoozeDuration, 300)
        XCTAssertEqual(viewModel.maxSnoozeCount, 3)
        XCTAssertFalse(viewModel.isEditing)
    }
    
    func testAlarmFormViewModelCreateAlarm() {
        let viewModel = AlarmFormViewModel()
        
        viewModel.label = "Morning Workout"
        viewModel.tone = .toughLove
        viewModel.repeatDays = [.monday, .wednesday, .friday]
        
        let alarm = viewModel.createAlarm()
        
        XCTAssertEqual(alarm.label, "Morning Workout")
        XCTAssertEqual(alarm.tone, .toughLove)
        XCTAssertEqual(alarm.repeatDays, [.monday, .wednesday, .friday])
    }
    
    func testAlarmFormViewModelValidation() {
        let viewModel = AlarmFormViewModel()
        
        // Valid form
        viewModel.label = "Valid Alarm"
        XCTAssertTrue(viewModel.validate())
        XCTAssertNil(viewModel.errorMessage)
        
        // Empty label
        viewModel.label = ""
        XCTAssertFalse(viewModel.validate())
        XCTAssertNotNil(viewModel.errorMessage)
        
        // Invalid snooze duration
        viewModel.label = "Valid Alarm"
        viewModel.snoozeDuration = 30 // Too short
        XCTAssertFalse(viewModel.validate())
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testAlarmFormViewModelLoadFromAlarm() {
        let alarm = Alarm(
            time: Date(),
            label: "Test Alarm",
            repeatDays: [.saturday, .sunday],
            tone: .gentle
        )
        
        let viewModel = AlarmFormViewModel(alarm: alarm)
        
        XCTAssertEqual(viewModel.label, "Test Alarm")
        XCTAssertEqual(viewModel.tone, .gentle)
        XCTAssertEqual(viewModel.repeatDays, [.saturday, .sunday])
        XCTAssertTrue(viewModel.isEditing)
    }
    
    // MARK: - IntentFormViewModel Tests
    func testIntentFormViewModelInitialization() {
        let viewModel = IntentFormViewModel()
        
        XCTAssertTrue(viewModel.userGoal.isEmpty)
        XCTAssertEqual(viewModel.tone, .energetic)
        XCTAssertTrue(viewModel.includeWeather)
        XCTAssertFalse(viewModel.includeCalendar)
        XCTAssertFalse(viewModel.isValid)
    }
    
    func testIntentFormViewModelValidation() {
        let viewModel = IntentFormViewModel()
        
        // Empty goal should be invalid
        XCTAssertFalse(viewModel.isValid)
        
        // Valid goal should be valid
        viewModel.userGoal = "Exercise for 30 minutes"
        viewModel.scheduledFor = Date().addingTimeInterval(3600)
        
        // Need to manually trigger validation since we're not in a SwiftUI context
        let intent = viewModel.createIntent()
        XCTAssertNotNil(intent)
        XCTAssertEqual(intent?.userGoal, "Exercise for 30 minutes")
    }
    
    func testIntentFormViewModelCharacterCount() {
        let viewModel = IntentFormViewModel()
        
        viewModel.userGoal = "Test"
        XCTAssertEqual(viewModel.goalCharacterCount, 4)
        XCTAssertEqual(viewModel.remainingCharacters, 196)
    }
    
    // MARK: - PreferencesViewModel Tests
    func testPreferencesViewModelInitialization() {
        let userViewModel = UserViewModel(storageManager: mockStorage)
        let viewModel = PreferencesViewModel(userViewModel: userViewModel)
        
        XCTAssertFalse(viewModel.hasChanges)
        XCTAssertEqual(viewModel.preferences.defaultAlarmTone, .energetic)
        XCTAssertTrue(viewModel.preferences.notificationsEnabled)
    }
    
    func testPreferencesViewModelToneSlider() {
        let userViewModel = UserViewModel(storageManager: mockStorage)
        let viewModel = PreferencesViewModel(userViewModel: userViewModel)
        
        viewModel.updateToneFromSlider(0.1)
        XCTAssertEqual(viewModel.preferences.computedTone, .gentle)
        
        viewModel.updateToneFromSlider(0.9)
        XCTAssertEqual(viewModel.preferences.computedTone, .toughLove)
    }
    
    func testPreferencesViewModelToggleMethods() {
        let userViewModel = UserViewModel(storageManager: mockStorage)
        let viewModel = PreferencesViewModel(userViewModel: userViewModel)
        
        let originalNotifications = viewModel.preferences.notificationsEnabled
        viewModel.toggleNotifications()
        XCTAssertEqual(viewModel.preferences.notificationsEnabled, !originalNotifications)
        
        let originalSound = viewModel.preferences.soundEnabled
        viewModel.toggleSound()
        XCTAssertEqual(viewModel.preferences.soundEnabled, !originalSound)
    }
}

// MARK: - Mock Storage Manager
class MockStorageManager: StorageManager {
    var saveAlarmsCalled = false
    var saveUserCalled = false
    var saveIntentsCalled = false
    var deleteUserCalled = false
    
    var mockAlarms: [Alarm] = []
    var mockUser: User?
    var mockIntents: [Intent] = []
    
    override func saveAlarms(_ alarms: [Alarm]) throws {
        saveAlarmsCalled = true
        mockAlarms = alarms
    }
    
    override func loadAlarms() throws -> [Alarm] {
        return mockAlarms
    }
    
    override func saveCurrentUser(_ user: User) throws {
        saveUserCalled = true
        mockUser = user
    }
    
    override func loadCurrentUser() throws -> User? {
        return mockUser
    }
    
    override func deleteCurrentUser() {
        deleteUserCalled = true
        mockUser = nil
    }
    
    override func saveIntents(_ intents: [Intent]) throws {
        saveIntentsCalled = true
        mockIntents = intents
    }
    
    override func loadIntents() throws -> [Intent] {
        return mockIntents
    }
}
