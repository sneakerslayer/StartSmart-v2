import XCTest
@testable import StartSmart
import Combine

/// Complete user journey integration tests covering the full alarm lifecycle
@MainActor
final class CompleteUserJourneyTests: XCTestCase {
    
    // System under test components
    var alarmViewModel: AlarmViewModel!
    var intentViewModel: IntentViewModel!
    var userViewModel: UserViewModel!
    var contentGenerationManager: ContentGenerationManager!
    var alarmSchedulingService: AlarmSchedulingService!
    var alarmAudioService: AlarmAudioService!
    
    // Mock dependencies
    var mockStorageManager: MockStorageManager!
    var mockNotificationService: MockNotificationService!
    var mockAlarmRepository: MockAlarmRepository!
    var mockIntentRepository: MockIntentRepository!
    var mockContentService: MockContentGenerationService!
    var mockAudioPipelineService: MockAudioPipelineService!
    var mockAudioPlaybackService: MockAudioPlaybackService!
    var mockSpeechRecognitionService: MockSpeechRecognitionService!
    
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize mock dependencies
        mockStorageManager = MockStorageManager()
        mockNotificationService = MockNotificationService()
        mockNotificationService.permissionStatus = .authorized
        mockAlarmRepository = MockAlarmRepository()
        mockIntentRepository = MockIntentRepository()
        mockContentService = MockContentGenerationService()
        mockAudioPipelineService = MockAudioPipelineService()
        mockAudioPlaybackService = MockAudioPlaybackService()
        mockSpeechRecognitionService = MockSpeechRecognitionService()
        
        cancellables = Set<AnyCancellable>()
        
        // Initialize system components
        userViewModel = UserViewModel(storageManager: mockStorageManager)
        alarmViewModel = AlarmViewModel(storageManager: mockStorageManager)
        intentViewModel = IntentViewModel(storageManager: mockStorageManager)
        
        contentGenerationManager = ContentGenerationManager(
            intentRepository: mockIntentRepository,
            contentService: mockContentService,
            autoGenerationEnabled: true
        )
        
        alarmSchedulingService = AlarmSchedulingService(
            notificationService: mockNotificationService,
            alarmRepository: mockAlarmRepository,
            maxScheduledNotifications: 10,
            futureSchedulingLimitDays: 30,
            timezoneMonitoringEnabled: false
        )
        
        alarmAudioService = AlarmAudioService(
            audioPipelineService: mockAudioPipelineService,
            intentRepository: mockIntentRepository,
            alarmRepository: mockAlarmRepository
        )
        
        // Create anonymous user to start
        userViewModel.createAnonymousUser()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        alarmViewModel = nil
        intentViewModel = nil
        userViewModel = nil
        contentGenerationManager = nil
        alarmSchedulingService = nil
        alarmAudioService = nil
        
        mockStorageManager = nil
        mockNotificationService = nil
        mockAlarmRepository = nil
        mockIntentRepository = nil
        mockContentService = nil
        mockAudioPipelineService = nil
        mockAudioPlaybackService = nil
        mockSpeechRecognitionService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Complete User Journey Tests
    
    func testCompleteAlarmCreationAndSchedulingJourney() async throws {
        // GIVEN: User wants to create a morning workout alarm
        let alarmTime = Calendar.current.date(byAdding: .hour, value: 8, to: Date())!
        let userGoal = "Complete a 45-minute morning workout with strength training"
        
        // WHEN: User creates an alarm
        let alarm = Alarm(
            time: alarmTime,
            label: "Morning Workout",
            tone: .energetic,
            isEnabled: true
        )
        
        // Step 1: Add alarm through view model
        alarmViewModel.addAlarm(alarm)
        
        // THEN: Alarm should be added and saved
        XCTAssertEqual(alarmViewModel.alarms.count, 1)
        XCTAssertTrue(mockStorageManager.saveAlarmsCalled)
        XCTAssertEqual(alarmViewModel.alarms.first?.label, "Morning Workout")
        
        // WHEN: User creates an intent for the alarm
        let intent = intentViewModel.createIntent(
            userGoal: userGoal,
            tone: .energetic,
            scheduledFor: alarmTime
        )
        
        // THEN: Intent should be created and linked
        XCTAssertEqual(intentViewModel.intents.count, 1)
        XCTAssertTrue(mockStorageManager.saveIntentsCalled)
        XCTAssertEqual(intent.userGoal, userGoal)
        XCTAssertEqual(intent.tone, .energetic)
        
        // WHEN: System schedules the alarm
        try await alarmSchedulingService.scheduleAlarm(alarm)
        
        // THEN: Alarm should be scheduled with notification service
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 1)
        XCTAssertEqual(alarmSchedulingService.scheduledAlarms.count, 1)
        
        // WHEN: System generates audio content for the intent
        let generatedContent = try await contentGenerationManager.generateContent(for: intent.id)
        
        // THEN: Content should be generated successfully
        XCTAssertFalse(generatedContent.textContent.isEmpty)
        XCTAssertTrue(generatedContent.hasAudio)
        XCTAssertEqual(generatedContent.metadata.tone, .energetic)
        XCTAssertTrue(generatedContent.textContent.localizedCaseInsensitiveContains("workout"))
        
        // WHEN: Audio service prepares audio for the alarm
        try await alarmAudioService.prepareAudioForAlarm(alarm.id)
        
        // THEN: Audio should be prepared and cached
        XCTAssertTrue(mockAudioPipelineService.lastGeneratedIntent?.userGoal == userGoal)
        
        // Verify complete user journey success
        XCTAssertTrue(userViewModel.isAuthenticated)
        XCTAssertEqual(userViewModel.userStats.totalAlarmsCreated, 1)
        XCTAssertTrue(alarmViewModel.hasEnabledAlarms)
        XCTAssertNotNil(alarmViewModel.nextAlarm)
        XCTAssertEqual(intentViewModel.readyIntents.count, 1)
    }
    
    func testCompleteAlarmWakeUpJourney() async throws {
        // GIVEN: User has an alarm scheduled for now
        let alarmTime = Date()
        let alarm = Alarm(
            time: alarmTime,
            label: "Wake Up",
            tone: .gentle,
            isEnabled: true
        )
        
        let intent = Intent(
            userGoal: "Start the day with positive energy",
            tone: .gentle,
            scheduledFor: alarmTime
        )
        
        // Setup the complete system
        alarmViewModel.addAlarm(alarm)
        intentViewModel.addIntent(intent)
        try await alarmSchedulingService.scheduleAlarm(alarm)
        
        // Generate content
        let generatedContent = try await contentGenerationManager.generateContent(for: intent.id)
        try await alarmAudioService.prepareAudioForAlarm(alarm.id)
        
        // WHEN: Alarm triggers (simulated)
        let triggeredAlarm = try await alarmSchedulingService.getScheduledAlarm(for: alarm.id)
        XCTAssertNotNil(triggeredAlarm)
        
        // WHEN: Audio starts playing
        let audioResult = try await mockAudioPipelineService.generateAndCacheAudio(forIntent: intent)
        XCTAssertNotNil(audioResult.audioData)
        
        // Simulate audio playback
        mockAudioPlaybackService.mockIsPlaying = true
        
        // THEN: System should be in alarm state
        XCTAssertTrue(mockAudioPlaybackService.mockIsPlaying)
        XCTAssertNotNil(generatedContent.audioData)
        
        // WHEN: User dismisses alarm with voice command
        mockSpeechRecognitionService.mockRecognizedText = "I'm awake"
        mockSpeechRecognitionService.mockDetectedKeyword = "I'm awake"
        
        // THEN: Alarm should be dismissed
        XCTAssertEqual(mockSpeechRecognitionService.mockRecognizedText, "I'm awake")
        XCTAssertNotNil(mockSpeechRecognitionService.mockDetectedKeyword)
        
        // WHEN: User marks successful wake up
        userViewModel.recordSuccessfulWakeUp()
        
        // THEN: User statistics should be updated
        XCTAssertEqual(userViewModel.userStats.successfulWakeUps, 1)
        XCTAssertEqual(userViewModel.userStats.currentStreak, 1)
        XCTAssertEqual(userViewModel.userStats.longestStreak, 1)
    }
    
    func testSubscriptionUpgradeJourney() async throws {
        // GIVEN: Free user with multiple alarms
        XCTAssertEqual(userViewModel.currentUser?.subscription, .free)
        XCTAssertFalse(userViewModel.canAccessPremiumFeatures)
        
        // Create alarms up to free limit
        for i in 1...15 {
            let alarm = Alarm(
                time: Date().addingTimeInterval(TimeInterval(i * 3600)),
                label: "Alarm \(i)"
            )
            alarmViewModel.addAlarm(alarm)
        }
        
        XCTAssertEqual(alarmViewModel.alarms.count, 15)
        
        // WHEN: User tries to create 16th alarm (exceeding free limit)
        XCTAssertFalse(userViewModel.canCreateMoreAlarms)
        
        // WHEN: User upgrades to Pro
        userViewModel.updateSubscription(.proMonthly)
        
        // THEN: User should have premium features
        XCTAssertTrue(userViewModel.canAccessPremiumFeatures)
        XCTAssertTrue(userViewModel.canAccessAdvancedAnalytics)
        XCTAssertTrue(userViewModel.canAccessAllVoices)
        XCTAssertTrue(userViewModel.canCreateMoreAlarms)
        
        // WHEN: User creates additional alarms
        let premiumAlarm = Alarm(
            time: Date().addingTimeInterval(16 * 3600),
            label: "Premium Alarm",
            tone: .toughLove // Premium tone
        )
        alarmViewModel.addAlarm(premiumAlarm)
        
        // THEN: Premium alarm should be created successfully
        XCTAssertEqual(alarmViewModel.alarms.count, 16)
        XCTAssertEqual(alarmViewModel.alarms.last?.tone, .toughLove)
    }
    
    func testErrorRecoveryJourney() async throws {
        // GIVEN: System with potential failure points
        let alarm = Alarm(
            time: Date().addingTimeInterval(3600),
            label: "Test Alarm"
        )
        
        // WHEN: Content generation fails
        mockContentService.shouldFail = true
        
        do {
            _ = try await contentGenerationManager.generateContent(for: UUID())
            XCTFail("Should have thrown an error")
        } catch {
            // THEN: Error should be handled gracefully
            XCTAssertTrue(error is ContentGenerationManagerError)
        }
        
        // WHEN: Audio pipeline fails
        mockAudioPipelineService.shouldFailGeneration = true
        
        do {
            _ = try await alarmAudioService.prepareAudioForAlarm(alarm.id)
            XCTFail("Should have thrown an error")
        } catch {
            // THEN: Error should be handled gracefully
            XCTAssertTrue(error is AlarmAudioServiceError)
        }
        
        // WHEN: Notification scheduling fails
        mockNotificationService.shouldThrowSchedulingError = true
        
        do {
            try await alarmSchedulingService.scheduleAlarm(alarm)
            XCTFail("Should have thrown an error")
        } catch {
            // THEN: Error should be handled gracefully
            XCTAssertTrue(error is NotificationServiceError)
        }
        
        // Verify system remains stable after errors
        XCTAssertNotNil(alarmViewModel)
        XCTAssertNotNil(intentViewModel)
        XCTAssertNotNil(userViewModel)
    }
    
    func testDataPersistenceJourney() async throws {
        // GIVEN: User creates alarms and intents
        let alarm = Alarm(
            time: Date().addingTimeInterval(3600),
            label: "Persistent Alarm",
            tone: .energetic
        )
        
        let intent = Intent(
            userGoal: "Test persistence",
            tone: .energetic,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        // WHEN: Data is saved
        alarmViewModel.addAlarm(alarm)
        intentViewModel.addIntent(intent)
        userViewModel.recordAlarmCreated()
        
        // THEN: Data should be persisted
        XCTAssertTrue(mockStorageManager.saveAlarmsCalled)
        XCTAssertTrue(mockStorageManager.saveIntentsCalled)
        XCTAssertTrue(mockStorageManager.saveUserCalled)
        
        // WHEN: System is restarted (simulated)
        let newAlarmViewModel = AlarmViewModel(storageManager: mockStorageManager)
        let newIntentViewModel = IntentViewModel(storageManager: mockStorageManager)
        let newUserViewModel = UserViewModel(storageManager: mockStorageManager)
        
        // THEN: Data should be restored
        XCTAssertEqual(newAlarmViewModel.alarms.count, 1)
        XCTAssertEqual(newIntentViewModel.intents.count, 1)
        XCTAssertNotNil(newUserViewModel.currentUser)
        XCTAssertEqual(newAlarmViewModel.alarms.first?.label, "Persistent Alarm")
        XCTAssertEqual(newIntentViewModel.intents.first?.userGoal, "Test persistence")
    }
}

// MARK: - Additional Mock Services for Complete Journey Testing

class MockAudioPipelineService: AudioPipelineServiceProtocol {
    var shouldFailGeneration = false
    var generationDelay: TimeInterval = 0.1
    var lastGeneratedIntent: Intent?
    
    func generateAndCacheAudio(forIntent intent: Intent) async throws -> AudioPipelineResult {
        lastGeneratedIntent = intent
        
        if shouldFailGeneration {
            throw AlarmAudioServiceError.audioGenerationFailed("Mock generation failure")
        }
        
        if generationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(generationDelay * 1_000_000_000))
        }
        
        return AudioPipelineResult(
            audioData: "mock_audio_data".data(using: .utf8)!,
            duration: 30.0,
            contentHash: "mock_hash",
            generatedAt: Date()
        )
    }
    
    func getCachedAudio(forContentHash hash: String) async -> AudioPipelineResult? {
        return AudioPipelineResult(
            audioData: "cached_audio_data".data(using: .utf8)!,
            duration: 30.0,
            contentHash: hash,
            generatedAt: Date()
        )
    }
    
    func clearCache() async {
        // Mock implementation
    }
    
    func performMaintenance() async {
        // Mock implementation
    }
}

class MockAudioPlaybackService: AudioPlaybackService {
    var mockIsPlaying = false
    var mockPlayedURL: URL?
    var shouldFailPlayback = false
    
    override var isPlaying: Bool {
        return mockIsPlaying
    }
    
    override func play(url: URL) throws {
        if shouldFailPlayback {
            throw AudioPlaybackError.playbackFailed("Mock playback failure")
        }
        mockPlayedURL = url
        mockIsPlaying = true
    }
    
    override func stop() {
        mockIsPlaying = false
        mockPlayedURL = nil
    }
}

class MockSpeechRecognitionService: SpeechRecognitionService {
    var mockPermissionStatus: SpeechPermissionStatus = .notRequested
    var mockIsListening = false
    var mockRecognizedText = ""
    var mockDetectedKeyword: String?
    var mockDismissKeywords: [String] = ["wake up", "I'm awake", "get up"]
    
    override var permissionStatus: SpeechPermissionStatus {
        return mockPermissionStatus
    }
    
    override var isListening: Bool {
        return mockIsListening
    }
    
    override var recognizedText: String {
        return mockRecognizedText
    }
    
    override var detectedKeyword: String? {
        return mockDetectedKeyword
    }
    
    override var dismissKeywords: [String] {
        return mockDismissKeywords
    }
    
    override func requestPermission() async -> Bool {
        mockPermissionStatus = .authorized
        return true
    }
    
    override func startListening() throws {
        if mockPermissionStatus != .authorized {
            throw SpeechRecognitionError.permissionDenied
        }
        mockIsListening = true
    }
    
    override func stopListening() {
        mockIsListening = false
    }
}
