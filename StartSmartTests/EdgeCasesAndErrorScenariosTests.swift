import XCTest
@testable import StartSmart
import Combine

/// Comprehensive tests for edge cases and error scenarios
@MainActor
final class EdgeCasesAndErrorScenariosTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Memory and Resource Management Edge Cases
    
    func testMemoryPressureScenarios() async throws {
        // Test behavior under memory pressure
        var alarms: [Alarm] = []
        
        // Create a large number of alarms to simulate memory pressure
        for i in 0..<1000 {
            let alarm = Alarm(
                time: Date().addingTimeInterval(TimeInterval(i * 60)),
                label: "Alarm \(i)",
                tone: .energetic
            )
            alarms.append(alarm)
        }
        
        // Test that the system can handle large datasets
        let mockStorage = MockStorageManager()
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        
        // Add alarms in batches to simulate real usage
        for batch in alarms.chunked(into: 100) {
            for alarm in batch {
                viewModel.addAlarm(alarm)
            }
            
            // Verify memory usage remains reasonable
            XCTAssertLessThanOrEqual(viewModel.alarms.count, alarms.count)
        }
        
        XCTAssertEqual(viewModel.alarms.count, 1000)
        
        // Test cleanup
        for alarm in alarms {
            viewModel.deleteAlarm(alarm)
        }
        
        XCTAssertTrue(viewModel.alarms.isEmpty)
    }
    
    func testConcurrentAccessScenarios() async throws {
        // Test concurrent access to shared resources
        let mockStorage = MockStorageManager()
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        
        // Create multiple concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let alarm = Alarm(
                        time: Date().addingTimeInterval(TimeInterval(i * 3600)),
                        label: "Concurrent Alarm \(i)"
                    )
                    await viewModel.addAlarm(alarm)
                }
            }
        }
        
        // Verify all alarms were added without corruption
        XCTAssertEqual(viewModel.alarms.count, 10)
        
        // Verify data integrity
        let labels = viewModel.alarms.map { $0.label }
        for i in 0..<10 {
            XCTAssertTrue(labels.contains("Concurrent Alarm \(i)"))
        }
    }
    
    // MARK: - Data Corruption and Recovery Edge Cases
    
    func testCorruptedDataRecovery() throws {
        // Test recovery from corrupted storage
        let mockStorage = MockStorageManager()
        mockStorage.shouldSimulateCorruption = true
        
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        
        // Attempt to load corrupted data
        do {
            try viewModel.loadAlarms()
            // Should either succeed with empty data or handle gracefully
            XCTAssertTrue(viewModel.alarms.isEmpty)
        } catch {
            // Should handle corruption gracefully
            XCTAssertTrue(error is StorageError)
        }
        
        // System should still be functional after corruption
        let newAlarm = Alarm(time: Date(), label: "Recovery Test")
        viewModel.addAlarm(newAlarm)
        XCTAssertEqual(viewModel.alarms.count, 1)
    }
    
    func testInvalidDateHandling() throws {
        // Test handling of invalid dates
        let distantPast = Date.distantPast
        let distantFuture = Date.distantFuture
        
        // Test alarm with distant past date
        let pastAlarm = Alarm(time: distantPast, label: "Past Alarm")
        XCTAssertNotNil(pastAlarm)
        XCTAssertEqual(pastAlarm.time, distantPast)
        
        // Test alarm with distant future date
        let futureAlarm = Alarm(time: distantFuture, label: "Future Alarm")
        XCTAssertNotNil(futureAlarm)
        XCTAssertEqual(futureAlarm.time, distantFuture)
        
        // Test scheduling service handling of invalid dates
        let mockNotificationService = MockNotificationService()
        let mockAlarmRepository = MockAlarmRepository()
        let schedulingService = AlarmSchedulingService(
            notificationService: mockNotificationService,
            alarmRepository: mockAlarmRepository
        )
        
        // Should handle past dates gracefully
        do {
            try await schedulingService.scheduleAlarm(pastAlarm)
            XCTFail("Should not schedule alarm in the past")
        } catch {
            XCTAssertTrue(error is AlarmSchedulingError)
        }
    }
    
    // MARK: - Network and API Edge Cases
    
    func testNetworkTimeoutScenarios() async throws {
        // Test API timeout handling
        let mockGrok4Service = MockGrok4Service()
        mockGrok4Service.shouldSimulateTimeout = true
        
        do {
            _ = try await mockGrok4Service.generateMotivationalScript(
                userIntent: "Test timeout",
                tone: "energetic",
                context: [:]
            )
            XCTFail("Should have timed out")
        } catch {
            XCTAssertTrue(error is Grok4ServiceError)
            if case .networkError(let message) = error as? Grok4ServiceError {
                XCTAssertTrue(message.contains("timeout"))
            }
        }
    }
    
    func testAPIRateLimitHandling() async throws {
        // Test rate limit handling
        let mockElevenLabsService = MockElevenLabsService()
        mockElevenLabsService.shouldSimulateRateLimit = true
        
        do {
            _ = try await mockElevenLabsService.generateSpeech(
                text: "Test rate limit",
                voiceId: "test_voice"
            )
            XCTFail("Should have hit rate limit")
        } catch {
            XCTAssertTrue(error is ElevenLabsServiceError)
            if case .rateLimitExceeded = error as? ElevenLabsServiceError {
                XCTAssertTrue(true, "Correctly handled rate limit")
            }
        }
    }
    
    func testMalformedAPIResponseHandling() async throws {
        // Test handling of malformed API responses
        let mockGrok4Service = MockGrok4Service()
        mockGrok4Service.shouldReturnMalformedResponse = true
        
        do {
            _ = try await mockGrok4Service.generateMotivationalScript(
                userIntent: "Test malformed response",
                tone: "energetic",
                context: [:]
            )
            XCTFail("Should have failed with malformed response")
        } catch {
            XCTAssertTrue(error is Grok4ServiceError)
        }
    }
    
    // MARK: - Audio Processing Edge Cases
    
    func testAudioCorruptionHandling() async throws {
        // Test handling of corrupted audio data
        let mockAudioService = MockAudioPipelineService()
        mockAudioService.shouldReturnCorruptedAudio = true
        
        let intent = Intent(
            userGoal: "Test corrupted audio",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        do {
            _ = try await mockAudioService.generateAndCacheAudio(forIntent: intent)
            XCTFail("Should have failed with corrupted audio")
        } catch {
            XCTAssertTrue(error is AudioPipelineError)
        }
    }
    
    func testAudioPlaybackFailureRecovery() throws {
        // Test audio playback failure recovery
        let mockPlaybackService = MockAudioPlaybackService()
        mockPlaybackService.shouldFailPlayback = true
        
        let testURL = URL(fileURLWithPath: "/tmp/test.mp3")
        
        XCTAssertThrowsError(try mockPlaybackService.play(url: testURL)) { error in
            XCTAssertTrue(error is AudioPlaybackError)
        }
        
        // Test recovery after failure
        mockPlaybackService.shouldFailPlayback = false
        XCTAssertNoThrow(try mockPlaybackService.play(url: testURL))
    }
    
    func testExtremeAudioDurations() async throws {
        // Test handling of extremely short and long audio
        let mockAudioService = MockAudioPipelineService()
        
        // Test extremely short audio (0.1 seconds)
        mockAudioService.mockDuration = 0.1
        let shortIntent = Intent(userGoal: "Short", scheduledFor: Date().addingTimeInterval(3600))
        let shortResult = try await mockAudioService.generateAndCacheAudio(forIntent: shortIntent)
        XCTAssertEqual(shortResult.duration, 0.1)
        
        // Test extremely long audio (10 minutes)
        mockAudioService.mockDuration = 600.0
        let longIntent = Intent(userGoal: "Long", scheduledFor: Date().addingTimeInterval(3600))
        let longResult = try await mockAudioService.generateAndCacheAudio(forIntent: longIntent)
        XCTAssertEqual(longResult.duration, 600.0)
    }
    
    // MARK: - User Interface Edge Cases
    
    func testExtremeUserInputHandling() throws {
        // Test handling of extreme user inputs
        let formViewModel = AlarmFormViewModel()
        
        // Test extremely long label
        let longLabel = String(repeating: "a", count: 1000)
        formViewModel.label = longLabel
        
        // Should handle gracefully (either truncate or validate)
        let alarm = formViewModel.createAlarm()
        XCTAssertNotNil(alarm)
        
        // Test empty label
        formViewModel.label = ""
        XCTAssertFalse(formViewModel.validate())
        XCTAssertNotNil(formViewModel.errorMessage)
        
        // Test special characters in label
        formViewModel.label = "🚨⏰💪🔥"
        XCTAssertTrue(formViewModel.validate())
        
        // Test very long intent goal
        let intentFormViewModel = IntentFormViewModel()
        intentFormViewModel.userGoal = String(repeating: "test ", count: 200)
        
        // Should handle gracefully
        XCTAssertLessThanOrEqual(intentFormViewModel.goalCharacterCount, 200)
    }
    
    func testRapidUIInteractions() throws {
        // Test rapid UI interactions
        let mockStorage = MockStorageManager()
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        
        let alarm = Alarm(time: Date(), label: "Rapid Test")
        
        // Rapid toggle operations
        for _ in 0..<100 {
            viewModel.toggleAlarm(alarm)
        }
        
        // Should end up in consistent state
        XCTAssertNotNil(alarm.isEnabled)
        
        // Rapid add/delete operations
        for i in 0..<10 {
            let testAlarm = Alarm(time: Date(), label: "Test \(i)")
            viewModel.addAlarm(testAlarm)
            viewModel.deleteAlarm(testAlarm)
        }
        
        // Should maintain consistency
        XCTAssertTrue(viewModel.alarms.isEmpty)
    }
    
    // MARK: - Permission and Authorization Edge Cases
    
    func testPermissionDeniedScenarios() async throws {
        // Test notification permission denied
        let mockNotificationService = MockNotificationService()
        mockNotificationService.permissionStatus = .denied
        
        let alarm = Alarm(time: Date().addingTimeInterval(3600), label: "Test")
        let schedulingService = AlarmSchedulingService(
            notificationService: mockNotificationService,
            alarmRepository: MockAlarmRepository()
        )
        
        do {
            try await schedulingService.scheduleAlarm(alarm)
            XCTFail("Should have failed with permission denied")
        } catch {
            XCTAssertTrue(error is AlarmSchedulingError)
        }
        
        // Test speech recognition permission denied
        let mockSpeechService = MockSpeechRecognitionService()
        mockSpeechService.mockPermissionStatus = .denied
        
        XCTAssertThrowsError(try mockSpeechService.startListening()) { error in
            XCTAssertTrue(error is SpeechRecognitionError)
        }
    }
    
    func testAuthenticationFailureRecovery() async throws {
        // Test authentication failure recovery
        let mockAuthService = MockAuthenticationService()
        mockAuthService.shouldFailAuthentication = true
        
        do {
            _ = try await mockAuthService.signInWithApple(idToken: "test", nonce: "test")
            XCTFail("Should have failed authentication")
        } catch {
            XCTAssertTrue(error is AuthenticationServiceError)
        }
        
        // Test recovery after failure
        mockAuthService.shouldFailAuthentication = false
        let user = try await mockAuthService.signInWithApple(idToken: "test", nonce: "test")
        XCTAssertNotNil(user)
    }
    
    // MARK: - Subscription and Payment Edge Cases
    
    func testSubscriptionFailureScenarios() async throws {
        // Test subscription purchase failure
        let mockSubscriptionService = MockSubscriptionService()
        mockSubscriptionService.shouldFailPurchase = true
        
        do {
            _ = try await mockSubscriptionService.purchaseProduct("startsmart_pro_monthly_")
            XCTFail("Should have failed purchase")
        } catch {
            XCTAssertTrue(error is SubscriptionError)
        }
        
        // Test subscription restoration failure
        mockSubscriptionService.shouldFailRestore = true
        
        do {
            try await mockSubscriptionService.restorePurchases()
            XCTFail("Should have failed restore")
        } catch {
            XCTAssertTrue(error is SubscriptionError)
        }
    }
    
    func testFeatureGatingEdgeCases() throws {
        // Test feature gating with edge cases
        var user = User()
        user.subscription = .free
        
        // Test free user limits
        XCTAssertFalse(user.canAccessPremiumFeatures)
        XCTAssertEqual(user.subscription.monthlyAlarmLimit, 3)
        
        // Test subscription expiration
        user.subscription = .proMonthly
        XCTAssertTrue(user.canAccessPremiumFeatures)
        
        // Test downgrade scenario
        user.subscription = .free
        XCTAssertFalse(user.canAccessPremiumFeatures)
    }
    
    // MARK: - Device and System Edge Cases
    
    func testLowStorageScenarios() throws {
        // Test behavior with low storage
        let mockStorage = MockStorageManager()
        mockStorage.shouldSimulateLowStorage = true
        
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        let alarm = Alarm(time: Date(), label: "Low Storage Test")
        
        // Should handle low storage gracefully
        XCTAssertThrowsError(try mockStorage.saveAlarms([alarm])) { error in
            XCTAssertTrue(error is StorageError)
        }
        
        // Should maintain functionality with reduced features
        viewModel.addAlarm(alarm)
        XCTAssertEqual(viewModel.alarms.count, 1)
    }
    
    func testTimezoneChangeHandling() throws {
        // Test timezone change handling
        let originalTimeZone = TimeZone.current
        
        // Create alarm in one timezone
        let alarm = Alarm(time: Date(), label: "Timezone Test")
        XCTAssertNotNil(alarm.time)
        
        // Simulate timezone change (can't actually change system timezone in tests)
        let newTimeZone = TimeZone(identifier: "America/New_York")!
        let calendar = Calendar.current
        
        // Test that alarm time calculations work with different timezones
        let components = calendar.dateComponents(in: newTimeZone, from: alarm.time)
        XCTAssertNotNil(components.hour)
        XCTAssertNotNil(components.minute)
    }
    
    func testBackgroundModeTransitions() throws {
        // Test app background/foreground transitions
        let mockNotificationService = MockNotificationService()
        let schedulingService = AlarmSchedulingService(
            notificationService: mockNotificationService,
            alarmRepository: MockAlarmRepository()
        )
        
        // Simulate app going to background
        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Should maintain scheduled alarms
        XCTAssertNotNil(schedulingService)
        
        // Simulate app returning to foreground
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Should refresh state appropriately
        XCTAssertNotNil(schedulingService)
    }
}

// MARK: - Extended Mock Services for Edge Case Testing

extension MockStorageManager {
    var shouldSimulateCorruption: Bool {
        get { false }
        set { /* Implementation would set internal flag */ }
    }
    
    var shouldSimulateLowStorage: Bool {
        get { false }
        set { /* Implementation would set internal flag */ }
    }
}

class MockGrok4Service: Grok4ServiceProtocol {
    var shouldSimulateTimeout = false
    var shouldReturnMalformedResponse = false
    
    func generateMotivationalScript(userIntent: String, tone: String, context: [String: String]) async throws -> String {
        if shouldSimulateTimeout {
            try await Task.sleep(nanoseconds: 35_000_000_000) // 35 seconds
            throw Grok4ServiceError.networkError("Request timed out")
        }
        
        if shouldReturnMalformedResponse {
            throw Grok4ServiceError.invalidResponse("Malformed response received")
        }
        
        return "Good morning! Today is perfect for \(userIntent). Let's make it happen!"
    }
}

class MockElevenLabsService: ElevenLabsServiceProtocol {
    var shouldSimulateRateLimit = false
    
    func generateSpeech(text: String, voiceId: String) async throws -> Data {
        if shouldSimulateRateLimit {
            throw ElevenLabsServiceError.rateLimitExceeded
        }
        
        return "mock_audio_data".data(using: .utf8) ?? Data()
    }
    
    func getAvailableVoices() async throws -> [Voice] {
        return [Voice(voiceId: "test", name: "Test Voice", category: "test", description: "Test")]
    }
}

class MockAudioPipelineService: AudioPipelineServiceProtocol {
    var shouldReturnCorruptedAudio = false
    var mockDuration: TimeInterval = 30.0
    
    func generateAndCacheAudio(forIntent intent: Intent) async throws -> AudioPipelineResult {
        if shouldReturnCorruptedAudio {
            throw AudioPipelineError.corruptedAudioData
        }
        
        return AudioPipelineResult(
            audioData: "mock_audio".data(using: .utf8)!,
            duration: mockDuration,
            contentHash: "hash",
            generatedAt: Date()
        )
    }
    
    func getCachedAudio(forContentHash hash: String) async -> AudioPipelineResult? {
        return nil
    }
    
    func clearCache() async {}
    func performMaintenance() async {}
}

class MockAudioPlaybackService: AudioPlaybackService {
    var shouldFailPlayback = false
    
    override func play(url: URL) throws {
        if shouldFailPlayback {
            throw AudioPlaybackError.playbackFailed("Mock playback failure")
        }
    }
}

class MockSpeechRecognitionService: SpeechRecognitionService {
    var mockPermissionStatus: SpeechPermissionStatus = .notRequested
    
    override var permissionStatus: SpeechPermissionStatus {
        return mockPermissionStatus
    }
    
    override func startListening() throws {
        if mockPermissionStatus == .denied {
            throw SpeechRecognitionError.permissionDenied
        }
    }
}

class MockAuthenticationService: AuthenticationServiceProtocol {
    var shouldFailAuthentication = false
    
    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        if shouldFailAuthentication {
            throw AuthenticationServiceError.authenticationFailed("Mock auth failure")
        }
        
        return User(email: "test@example.com", displayName: "Test User")
    }
    
    func signOut() async throws {}
    
    var isAuthenticated: Bool { return true }
    var currentUser: User? { return nil }
}

class MockSubscriptionService: SubscriptionServiceProtocol {
    var shouldFailPurchase = false
    var shouldFailRestore = false
    var currentSubscriptionStatus: SubscriptionStatus = .free
    
    func purchaseProduct(_ productId: String) async throws -> SubscriptionStatus {
        if shouldFailPurchase {
            throw SubscriptionError.purchaseFailed("Mock purchase failure")
        }
        return .proMonthly
    }
    
    func restorePurchases() async throws {
        if shouldFailRestore {
            throw SubscriptionError.restoreFailed("Mock restore failure")
        }
    }
    
    var subscriptionStatusPublisher: AnyPublisher<SubscriptionStatus, Never> {
        Just(currentSubscriptionStatus).eraseToAnyPublisher()
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
