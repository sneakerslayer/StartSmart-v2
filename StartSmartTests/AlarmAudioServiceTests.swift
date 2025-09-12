import XCTest
import Combine
@testable import StartSmart

// MARK: - Mock Dependencies
class MockAudioPipelineService: AudioPipelineServiceProtocol {
    var shouldFailGeneration = false
    var generationDelay: TimeInterval = 0.1
    var lastGeneratedIntent: Intent?
    
    func generateAndCacheAudio(forIntent intent: Intent) async throws -> AudioPipelineResult {
        lastGeneratedIntent = intent
        
        if shouldFailGeneration {
            throw AudioPipelineError.generationFailed(UUID(), NSError(domain: "Test", code: 1))
        }
        
        try await Task.sleep(nanoseconds: UInt64(generationDelay * 1_000_000_000))
        
        return AudioPipelineResult(
            textContent: "Generated motivational content for \(intent.goal)",
            audioFilePath: "/tmp/test_audio_\(intent.id.uuidString).mp3",
            voiceId: intent.tone.rawValue,
            generatedAt: Date(),
            duration: 45.0
        )
    }
    
    func preGenerateForUpcomingAlarms(alarms: [Alarm]) async throws {
        // Mock implementation
    }
    
    func getGenerationStatus() -> AudioPipelineStatus {
        return .idle
    }
}

class MockIntentRepository: IntentRepositoryProtocol {
    var mockIntents: [Intent] = []
    
    func addIntent(_ intent: Intent) async throws {
        mockIntents.append(intent)
    }
    
    func getIntents() async -> [Intent] {
        return mockIntents
    }
    
    func getIntent(by id: UUID) async -> Intent? {
        return mockIntents.first { $0.id == id }
    }
    
    func updateIntent(_ intent: Intent) async throws {
        if let index = mockIntents.firstIndex(where: { $0.id == intent.id }) {
            mockIntents[index] = intent
        }
    }
    
    func deleteIntent(_ intent: Intent) async throws {
        mockIntents.removeAll { $0.id == intent.id }
    }
    
    func deleteAllIntents() async throws {
        mockIntents.removeAll()
    }
    
    func getIntentsForTone(_ tone: AlarmTone) async -> [Intent] {
        return mockIntents.filter { $0.tone == tone }
    }
    
    func markIntentAsGenerating(_ intentId: UUID) async throws {
        // Mock implementation
    }
    
    func setIntentContent(_ intentId: UUID, content: GeneratedContent) async throws {
        // Mock implementation
    }
    
    func markIntentAsFailed(_ intentId: UUID, error: String) async throws {
        // Mock implementation
    }
    
    func cleanupExpiredIntents() async throws {
        // Mock implementation
    }
    
    func importIntents(_ intents: [Intent]) async throws {
        mockIntents.append(contentsOf: intents)
    }
    
    func exportIntents() async -> [Intent] {
        return mockIntents
    }
    
    func getStatistics() async -> IntentStatistics {
        return IntentStatistics(
            totalIntents: mockIntents.count,
            intentsByTone: [:],
            averageGoalLength: 0,
            recentActivity: [],
            generationSuccessRate: 1.0
        )
    }
}

class MockAlarmRepository: AlarmRepositoryProtocol {
    var mockAlarms: [Alarm] = []
    var onAlarmUpdated: ((Alarm) -> Void)?
    
    func addAlarm(_ alarm: Alarm) async throws {
        mockAlarms.append(alarm)
    }
    
    func getAlarms() async -> [Alarm] {
        return mockAlarms
    }
    
    func getAlarm(by id: UUID) async -> Alarm? {
        return mockAlarms.first { $0.id == id }
    }
    
    func updateAlarm(_ alarm: Alarm) async throws {
        if let index = mockAlarms.firstIndex(where: { $0.id == alarm.id }) {
            mockAlarms[index] = alarm
            onAlarmUpdated?(alarm)
        }
    }
    
    func deleteAlarm(_ alarm: Alarm) async throws {
        mockAlarms.removeAll { $0.id == alarm.id }
    }
    
    func deleteAllAlarms() async throws {
        mockAlarms.removeAll()
    }
    
    func getEnabledAlarms() async -> [Alarm] {
        return mockAlarms.filter { $0.isEnabled }
    }
    
    func getAlarmsForToday() async -> [Alarm] {
        return mockAlarms.filter { alarm in
            guard alarm.isEnabled else { return false }
            return alarm.nextTriggerDate != nil
        }
    }
    
    func importAlarms(_ alarms: [Alarm]) async throws {
        mockAlarms.append(contentsOf: alarms)
    }
    
    func exportAlarms() async -> [Alarm] {
        return mockAlarms
    }
    
    func getStatistics() async -> AlarmStatistics {
        return AlarmStatistics(
            totalAlarms: mockAlarms.count,
            enabledAlarms: mockAlarms.filter { $0.isEnabled }.count,
            averageSnoozeCount: 0,
            mostUsedTone: .energetic,
            streakData: []
        )
    }
    
    func dismissAlarm(_ alarmId: UUID) async throws {
        if let index = mockAlarms.firstIndex(where: { $0.id == alarmId }) {
            var alarm = mockAlarms[index]
            alarm.markTriggered()
            alarm.resetSnooze()
            mockAlarms[index] = alarm
        }
    }
}

// MARK: - AlarmAudioService Tests
class AlarmAudioServiceTests: XCTestCase {
    var alarmAudioService: AlarmAudioService!
    var mockAudioPipelineService: MockAudioPipelineService!
    var mockIntentRepository: MockIntentRepository!
    var mockAlarmRepository: MockAlarmRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        mockAudioPipelineService = MockAudioPipelineService()
        mockIntentRepository = MockIntentRepository()
        mockAlarmRepository = MockAlarmRepository()
        cancellables = Set<AnyCancellable>()
        
        alarmAudioService = AlarmAudioService(
            audioPipelineService: mockAudioPipelineService,
            intentRepository: mockIntentRepository,
            alarmRepository: mockAlarmRepository
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        alarmAudioService = nil
        mockAudioPipelineService = nil
        mockIntentRepository = nil
        mockAlarmRepository = nil
        super.tearDown()
    }
    
    // MARK: - Audio Generation Tests
    func testGenerateAudioForAlarm_WithMatchingIntent() async throws {
        // Given
        let alarm = Alarm(
            time: Date(),
            label: "Morning workout",
            tone: .energetic
        )
        
        let matchingIntent = Intent(
            goal: "Get energized for morning workout",
            tone: .energetic
        )
        
        await mockIntentRepository.addIntent(matchingIntent)
        
        // When
        let result = try await alarmAudioService.generateAudioForAlarm(alarm)
        
        // Then
        XCTAssertEqual(result.textContent, "Generated motivational content for Get energized for morning workout")
        XCTAssertTrue(result.audioFilePath.contains("test_audio"))
        XCTAssertEqual(result.voiceId, "energetic")
        XCTAssertEqual(mockAudioPipelineService.lastGeneratedIntent?.id, matchingIntent.id)
    }
    
    func testGenerateAudioForAlarm_WithoutMatchingIntent_CreatesDefault() async throws {
        // Given
        let alarm = Alarm(
            time: Date(),
            label: "Wake up call",
            tone: .gentle
        )
        
        // When
        let result = try await alarmAudioService.generateAudioForAlarm(alarm)
        
        // Then
        XCTAssertEqual(result.textContent, "Generated motivational content for Start the day peacefully and with gratitude")
        XCTAssertEqual(result.voiceId, "gentle")
        XCTAssertNotNil(mockAudioPipelineService.lastGeneratedIntent)
        XCTAssertEqual(mockAudioPipelineService.lastGeneratedIntent?.tone, .gentle)
    }
    
    func testGenerateAudioForAlarm_WithMultipleIntents_SelectsMostRecent() async throws {
        // Given
        let alarm = Alarm(time: Date(), tone: .toughLove)
        
        let olderIntent = Intent(
            id: UUID(),
            goal: "Old goal",
            tone: .toughLove,
            createdAt: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        
        let newerIntent = Intent(
            id: UUID(),
            goal: "New goal",
            tone: .toughLove,
            createdAt: Date().addingTimeInterval(-1800) // 30 minutes ago
        )
        
        await mockIntentRepository.addIntent(olderIntent)
        await mockIntentRepository.addIntent(newerIntent)
        
        // When
        let result = try await alarmAudioService.generateAudioForAlarm(alarm)
        
        // Then
        XCTAssertEqual(result.textContent, "Generated motivational content for New goal")
        XCTAssertEqual(mockAudioPipelineService.lastGeneratedIntent?.id, newerIntent.id)
    }
    
    func testGenerateAudioForAlarm_StatusUpdates() async throws {
        // Given
        let alarm = Alarm(time: Date(), tone: .storyteller)
        mockAudioPipelineService.generationDelay = 0.2
        
        let statusExpectation = expectation(description: "Status updates")
        statusExpectation.expectedFulfillmentCount = 3 // generating, completed, idle
        
        var statusUpdates: [AudioGenerationStatus] = []
        
        alarmAudioService.$currentStatus
            .sink { status in
                statusUpdates.append(status)
                statusExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        _ = try await alarmAudioService.generateAudioForAlarm(alarm)
        
        await fulfillment(of: [statusExpectation], timeout: 5.0)
        
        // Then
        XCTAssertEqual(statusUpdates.count, 3)
        
        if case .generating(let alarmId) = statusUpdates[1] {
            XCTAssertEqual(alarmId, alarm.id)
        } else {
            XCTFail("Expected generating status")
        }
        
        if case .completed(let alarmId) = statusUpdates[2] {
            XCTAssertEqual(alarmId, alarm.id)
        } else {
            XCTFail("Expected completed status")
        }
    }
    
    func testGenerateAudioForAlarm_ErrorHandling() async throws {
        // Given
        let alarm = Alarm(time: Date(), tone: .gentle)
        mockAudioPipelineService.shouldFailGeneration = true
        
        // When/Then
        do {
            _ = try await alarmAudioService.generateAudioForAlarm(alarm)
            XCTFail("Expected error")
        } catch let error as AlarmAudioServiceError {
            if case .audioGenerationFailed = error {
                // Expected
            } else {
                XCTFail("Expected audioGenerationFailed error")
            }
        }
        
        // Verify status is set to failed
        if case .failed(let alarmId, _) = alarmAudioService.getAudioGenerationStatus() {
            XCTAssertEqual(alarmId, alarm.id)
        } else {
            XCTFail("Expected failed status")
        }
    }
    
    // MARK: - Pre-Generation Tests
    func testPreGenerateAudioForUpcomingAlarms() async throws {
        // Given
        let now = Date()
        let upcomingAlarm = Alarm(
            time: now.addingTimeInterval(3600), // 1 hour from now
            label: "Tomorrow morning",
            isEnabled: true,
            tone: .energetic
        )
        
        let pastAlarm = Alarm(
            time: now.addingTimeInterval(-3600), // 1 hour ago
            isEnabled: true
        )
        
        let disabledAlarm = Alarm(
            time: now.addingTimeInterval(3600),
            isEnabled: false
        )
        
        await mockAlarmRepository.addAlarm(upcomingAlarm)
        await mockAlarmRepository.addAlarm(pastAlarm)
        await mockAlarmRepository.addAlarm(disabledAlarm)
        
        var updatedAlarms: [Alarm] = []
        mockAlarmRepository.onAlarmUpdated = { alarm in
            updatedAlarms.append(alarm)
        }
        
        // When
        try await alarmAudioService.preGenerateAudioForUpcomingAlarms()
        
        // Then
        XCTAssertEqual(updatedAlarms.count, 1)
        XCTAssertEqual(updatedAlarms.first?.id, upcomingAlarm.id)
        XCTAssertNotNil(updatedAlarms.first?.generatedContent)
    }
    
    func testEnsureAudioForAlarm_AlreadyHasAudio() async throws {
        // Given
        var alarm = Alarm(time: Date(), tone: .gentle)
        let existingContent = AlarmGeneratedContent(
            textContent: "Existing content",
            audioFilePath: "/tmp/existing.mp3",
            voiceId: "gentle",
            generatedAt: Date(),
            duration: 30.0,
            intentId: nil
        )
        alarm.setGeneratedContent(existingContent)
        
        // When
        let result = try await alarmAudioService.ensureAudioForAlarm(alarm)
        
        // Then
        XCTAssertEqual(result.generatedContent?.textContent, "Existing content")
        XCTAssertNil(mockAudioPipelineService.lastGeneratedIntent) // Should not generate new content
    }
    
    func testEnsureAudioForAlarm_NeedsGeneration() async throws {
        // Given
        let alarm = Alarm(time: Date(), tone: .energetic)
        
        // When
        let result = try await alarmAudioService.ensureAudioForAlarm(alarm)
        
        // Then
        XCTAssertNotNil(result.generatedContent)
        XCTAssertNotNil(mockAudioPipelineService.lastGeneratedIntent) // Should generate new content
    }
    
    // MARK: - Cleanup Tests
    func testClearExpiredAudioContent() async throws {
        // Given
        let expiredContent = AlarmGeneratedContent(
            textContent: "Old content",
            audioFilePath: "/tmp/expired.mp3",
            voiceId: "gentle",
            generatedAt: Date().addingTimeInterval(-8 * 24 * 60 * 60), // 8 days ago
            duration: 30.0,
            intentId: nil
        )
        
        let validContent = AlarmGeneratedContent(
            textContent: "New content",
            audioFilePath: "/tmp/valid.mp3",
            voiceId: "energetic",
            generatedAt: Date(),
            duration: 30.0,
            intentId: nil
        )
        
        var expiredAlarm = Alarm(time: Date(), tone: .gentle)
        expiredAlarm.setGeneratedContent(expiredContent)
        
        var validAlarm = Alarm(time: Date(), tone: .energetic)
        validAlarm.setGeneratedContent(validContent)
        
        await mockAlarmRepository.addAlarm(expiredAlarm)
        await mockAlarmRepository.addAlarm(validAlarm)
        
        var updatedAlarms: [Alarm] = []
        mockAlarmRepository.onAlarmUpdated = { alarm in
            updatedAlarms.append(alarm)
        }
        
        // When
        try await alarmAudioService.clearExpiredAudioContent()
        
        // Then
        XCTAssertEqual(updatedAlarms.count, 1)
        let clearedAlarm = updatedAlarms.first
        XCTAssertEqual(clearedAlarm?.id, expiredAlarm.id)
        XCTAssertNil(clearedAlarm?.generatedContent)
    }
    
    // MARK: - Default Intent Creation Tests
    func testCreateDefaultIntent_ForDifferentTones() async throws {
        // Test each tone creates appropriate default intent
        let tones: [AlarmTone] = [.gentle, .energetic, .toughLove, .storyteller]
        
        for tone in tones {
            let alarm = Alarm(time: Date(), label: "Test alarm", tone: tone)
            
            // When
            let result = try await alarmAudioService.generateAudioForAlarm(alarm)
            
            // Then
            XCTAssertNotNil(result)
            XCTAssertEqual(result.voiceId, tone.rawValue)
            
            let generatedIntent = mockAudioPipelineService.lastGeneratedIntent
            XCTAssertNotNil(generatedIntent)
            XCTAssertEqual(generatedIntent?.tone, tone)
            XCTAssertFalse(generatedIntent?.goal.isEmpty ?? true)
            
            // Reset for next iteration
            mockAudioPipelineService.lastGeneratedIntent = nil
        }
    }
    
    func testCreateDefaultIntent_WithAlarmLabel() async throws {
        // Given
        let alarm = Alarm(time: Date(), label: "Important meeting", tone: .energetic)
        
        // When
        _ = try await alarmAudioService.generateAudioForAlarm(alarm)
        
        // Then
        let generatedIntent = mockAudioPipelineService.lastGeneratedIntent
        XCTAssertEqual(generatedIntent?.context.customNotes, "Important meeting")
        XCTAssertTrue(generatedIntent?.context.includeWeather ?? false)
    }
    
    // MARK: - Background Generation Tests
    func testScheduleBackgroundAudioGeneration() async throws {
        // Given
        let upcomingAlarm = Alarm(
            time: Date().addingTimeInterval(3600),
            isEnabled: true,
            tone: .gentle
        )
        
        var expiredAlarm = Alarm(time: Date(), tone: .energetic)
        let expiredContent = AlarmGeneratedContent(
            textContent: "Expired",
            audioFilePath: "/tmp/expired.mp3",
            voiceId: "energetic",
            generatedAt: Date().addingTimeInterval(-8 * 24 * 60 * 60),
            duration: 30.0,
            intentId: nil
        )
        expiredAlarm.setGeneratedContent(expiredContent)
        
        await mockAlarmRepository.addAlarm(upcomingAlarm)
        await mockAlarmRepository.addAlarm(expiredAlarm)
        
        var updatedAlarms: [Alarm] = []
        mockAlarmRepository.onAlarmUpdated = { alarm in
            updatedAlarms.append(alarm)
        }
        
        // When
        alarmAudioService.scheduleBackgroundAudioGeneration()
        
        // Wait for background task
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then
        XCTAssertGreaterThanOrEqual(updatedAlarms.count, 1)
        // Should have generated audio for upcoming alarm and cleared expired content
    }
    
    // MARK: - Performance Tests
    func testConcurrentAudioGeneration() async throws {
        // Given
        let alarms = (0..<5).map { index in
            Alarm(time: Date(), label: "Alarm \(index)", tone: AlarmTone.allCases.randomElement()!)
        }
        
        // When - Generate audio for multiple alarms concurrently
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: AlarmGeneratedContent.self) { group in
            for alarm in alarms {
                group.addTask {
                    return try await self.alarmAudioService.generateAudioForAlarm(alarm)
                }
            }
            
            var results: [AlarmGeneratedContent] = []
            for try await result in group {
                results.append(result)
            }
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // Then
            XCTAssertEqual(results.count, alarms.count)
            XCTAssertLessThan(duration, 2.0) // Should complete quickly with mocked services
        }
    }
}

// MARK: - Error Handling Tests
extension AlarmAudioServiceTests {
    func testAlarmAudioServiceError_LocalizedDescriptions() {
        let errors: [AlarmAudioServiceError] = [
            .alarmNotFound,
            .intentNotFound,
            .audioGenerationFailed(NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])),
            .audioCachingFailed(NSError(domain: "Cache", code: 2)),
            .serviceUnavailable
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    func testAudioGenerationStatus_Equality() {
        let id1 = UUID()
        let id2 = UUID()
        
        let statuses: [(AudioGenerationStatus, AudioGenerationStatus, Bool)] = [
            (.idle, .idle, true),
            (.generating(alarmId: id1), .generating(alarmId: id1), true),
            (.generating(alarmId: id1), .generating(alarmId: id2), false),
            (.completed(alarmId: id1), .completed(alarmId: id1), true),
            (.completed(alarmId: id1), .completed(alarmId: id2), false),
            (.failed(alarmId: id1, error: NSError(domain: "Test", code: 1)), .failed(alarmId: id1, error: NSError(domain: "Test", code: 2)), true), // Same ID, different errors
            (.idle, .generating(alarmId: id1), false)
        ]
        
        for (status1, status2, expectedEqual) in statuses {
            if expectedEqual {
                XCTAssertEqual(status1, status2)
            } else {
                XCTAssertNotEqual(status1, status2)
            }
        }
    }
}
