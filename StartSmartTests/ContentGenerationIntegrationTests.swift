import XCTest
@testable import StartSmart
import Combine

@MainActor
final class ContentGenerationIntegrationTests: XCTestCase {
    
    var contentGenerationManager: ContentGenerationManager!
    var mockIntentRepository: MockIntentRepository!
    var mockContentService: MockContentGenerationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockIntentRepository = MockIntentRepository()
        mockContentService = MockContentGenerationService()
        cancellables = Set<AnyCancellable>()
        
        contentGenerationManager = ContentGenerationManager(
            intentRepository: mockIntentRepository,
            contentService: mockContentService,
            autoGenerationEnabled: false // Disable for testing
        )
    }
    
    override func tearDown() async throws {
        contentGenerationManager = nil
        mockIntentRepository = nil
        mockContentService = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Generation Tests
    func testGenerateContentForIntent() async throws {
        let intent = Intent.quickIntent(
            goal: "Exercise for 30 minutes",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        // Save intent to mock repository
        try await mockIntentRepository.saveIntent(intent)
        
        let generatedContent = try await contentGenerationManager.generateContent(for: intent.id)
        
        XCTAssertFalse(generatedContent.textContent.isEmpty)
        XCTAssertTrue(generatedContent.hasAudio)
        XCTAssertEqual(generatedContent.metadata.tone, intent.tone)
        
        // Verify repository was updated
        let updatedIntent = try await mockIntentRepository.getIntent(by: intent.id)
        XCTAssertEqual(updatedIntent?.status, .ready)
        XCTAssertNotNil(updatedIntent?.generatedContent)
    }
    
    func testGenerateContentWithDirectIntent() async throws {
        let intent = Intent.quickIntent(
            goal: "Read 20 pages",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let generatedContent = try await contentGenerationManager.generateContent(for: intent)
        
        XCTAssertFalse(generatedContent.textContent.isEmpty)
        XCTAssertTrue(generatedContent.hasAudio)
        XCTAssertGreaterThan(generatedContent.metadata.generationTime, 0)
    }
    
    func testGenerateContentIntentNotFound() async throws {
        let nonExistentId = UUID()
        
        do {
            _ = try await contentGenerationManager.generateContent(for: nonExistentId)
            XCTFail("Should have thrown intentNotFound error")
        } catch let error as ContentGenerationManagerError {
            if case .intentNotFound(let id) = error {
                XCTAssertEqual(id, nonExistentId)
            } else {
                XCTFail("Expected intentNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Status Tracking Tests
    func testGenerationStatusTracking() async throws {
        let intent = Intent.quickIntent(
            goal: "Test status tracking",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await mockIntentRepository.saveIntent(intent)
        
        // Setup expectation for status changes
        let statusExpectation = expectation(description: "Status updates")
        statusExpectation.expectedFulfillmentCount = 2
        
        contentGenerationManager.$isGenerating
            .dropFirst()
            .sink { isGenerating in
                statusExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        let generatedContent = try await contentGenerationManager.generateContent(for: intent.id)
        
        await fulfillment(of: [statusExpectation], timeout: 2.0)
        
        XCTAssertFalse(contentGenerationManager.isGenerating)
        XCTAssertNil(contentGenerationManager.currentlyGeneratingIntent)
        XCTAssertEqual(contentGenerationManager.generationProgress, 1.0)
        XCTAssertNotNil(generatedContent)
    }
    
    func testAlreadyGeneratingError() async throws {
        let intent1 = Intent.quickIntent(
            goal: "First intent",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        let intent2 = Intent.quickIntent(
            goal: "Second intent",
            scheduledFor: Date().addingTimeInterval(7200)
        )
        
        try await mockIntentRepository.saveIntent(intent1)
        try await mockIntentRepository.saveIntent(intent2)
        
        // Configure mock to delay
        mockContentService.simulateDelay = true
        
        // Start first generation
        let firstTask = Task {
            try await contentGenerationManager.generateContent(for: intent1.id)
        }
        
        // Try to start second generation while first is in progress
        do {
            _ = try await contentGenerationManager.generateContent(for: intent2.id)
            XCTFail("Should have thrown alreadyGenerating error")
        } catch let error as ContentGenerationManagerError {
            if case .alreadyGenerating(let id) = error {
                XCTAssertEqual(id, intent2.id)
            } else {
                XCTFail("Expected alreadyGenerating error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Wait for first generation to complete
        _ = try await firstTask.value
        
        mockContentService.simulateDelay = false
    }
    
    // MARK: - Queue Processing Tests
    func testProcessQueuedIntents() async throws {
        let now = Date()
        let intent1 = Intent.quickIntent(
            goal: "Queued intent 1",
            scheduledFor: now.addingTimeInterval(30 * 60) // 30 minutes from now
        )
        let intent2 = Intent.quickIntent(
            goal: "Queued intent 2",
            scheduledFor: now.addingTimeInterval(45 * 60) // 45 minutes from now
        )
        let futureIntent = Intent.quickIntent(
            goal: "Future intent",
            scheduledFor: now.addingTimeInterval(2 * 60 * 60) // 2 hours from now
        )
        
        try await mockIntentRepository.saveIntent(intent1)
        try await mockIntentRepository.saveIntent(intent2)
        try await mockIntentRepository.saveIntent(futureIntent)
        
        try await contentGenerationManager.processQueuedIntents()
        
        // Check that the near-term intents were processed
        let updatedIntent1 = try await mockIntentRepository.getIntent(by: intent1.id)
        let updatedIntent2 = try await mockIntentRepository.getIntent(by: intent2.id)
        let updatedFutureIntent = try await mockIntentRepository.getIntent(by: futureIntent.id)
        
        XCTAssertEqual(updatedIntent1?.status, .ready)
        XCTAssertEqual(updatedIntent2?.status, .ready)
        XCTAssertEqual(updatedFutureIntent?.status, .pending) // Should not be processed yet
    }
    
    // MARK: - Error Handling Tests
    func testGenerationFailureHandling() async throws {
        let intent = Intent.quickIntent(
            goal: "Failing intent",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await mockIntentRepository.saveIntent(intent)
        
        // Configure mock to fail
        mockContentService.shouldFail = true
        
        do {
            _ = try await contentGenerationManager.generateContent(for: intent.id)
            XCTFail("Should have thrown generation error")
        } catch let error as ContentGenerationManagerError {
            if case .generationFailed(let id, _) = error {
                XCTAssertEqual(id, intent.id)
            } else {
                XCTFail("Expected generationFailed error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Verify intent was marked as failed
        let updatedIntent = try await mockIntentRepository.getIntent(by: intent.id)
        XCTAssertTrue(updatedIntent?.status.isFailure ?? false)
        
        // Verify error tracking
        XCTAssertTrue(contentGenerationManager.failedGenerations.keys.contains(intent.id))
        
        mockContentService.shouldFail = false
    }
    
    func testRetryFailedGeneration() async throws {
        let intent = Intent.quickIntent(
            goal: "Retry test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await mockIntentRepository.saveIntent(intent)
        
        // First attempt - configure to fail
        mockContentService.shouldFail = true
        
        do {
            _ = try await contentGenerationManager.generateContent(for: intent.id)
            XCTFail("Should have failed")
        } catch {
            // Expected failure
        }
        
        // Verify failure was tracked
        XCTAssertTrue(contentGenerationManager.failedGenerations.keys.contains(intent.id))
        
        // Second attempt - configure to succeed
        mockContentService.shouldFail = false
        
        let generatedContent = try await contentGenerationManager.retryGeneration(for: intent.id)
        
        XCTAssertNotNil(generatedContent)
        XCTAssertFalse(contentGenerationManager.failedGenerations.keys.contains(intent.id))
        
        let updatedIntent = try await mockIntentRepository.getIntent(by: intent.id)
        XCTAssertEqual(updatedIntent?.status, .ready)
    }
    
    // MARK: - Statistics Tests
    func testGenerationStatistics() async throws {
        // Create test data
        var pendingIntent = Intent.quickIntent(goal: "Pending", scheduledFor: Date().addingTimeInterval(3600))
        var failedIntent = Intent.quickIntent(goal: "Failed", scheduledFor: Date().addingTimeInterval(7200))
        let successIntent = Intent.quickIntent(goal: "Success", scheduledFor: Date().addingTimeInterval(10800))
        
        failedIntent.markAsFailed(error: "Test error")
        
        try await mockIntentRepository.saveIntent(pendingIntent)
        try await mockIntentRepository.saveIntent(failedIntent)
        try await mockIntentRepository.saveIntent(successIntent)
        
        // Generate content for success intent
        _ = try await contentGenerationManager.generateContent(for: successIntent)
        
        let stats = try await contentGenerationManager.getGenerationStatistics()
        
        XCTAssertEqual(stats.totalIntents, 3)
        XCTAssertEqual(stats.pendingGeneration, 1)
        XCTAssertEqual(stats.successfullyGenerated, 1)
        XCTAssertEqual(stats.failedGeneration, 1)
        XCTAssertEqual(stats.recentlyCompletedCount, 1)
        XCTAssertGreaterThan(stats.averageGenerationTime, 0)
    }
    
    // MARK: - Integration Tests
    func testFullContentGenerationPipeline() async throws {
        let intent = Intent(
            userGoal: "Complete morning routine with mindfulness",
            tone: .gentle,
            context: IntentContext(
                weather: "sunny",
                temperature: 72.0,
                timeOfDay: .morning,
                dayOfWeek: "Monday",
                calendarEvents: ["Team meeting at 10am"],
                customNote: "Focus on gratitude today"
            ),
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await mockIntentRepository.saveIntent(intent)
        
        let generatedContent = try await contentGenerationManager.generateContent(for: intent.id)
        
        // Verify content quality
        XCTAssertFalse(generatedContent.textContent.isEmpty)
        XCTAssertTrue(generatedContent.textContent.contains("morning routine") || 
                     generatedContent.textContent.contains("mindfulness"))
        
        // Verify metadata
        XCTAssertEqual(generatedContent.metadata.tone, .gentle)
        XCTAssertEqual(generatedContent.metadata.aiModel, "grok4")
        XCTAssertEqual(generatedContent.metadata.ttsModel, "elevenlabs")
        XCTAssertGreaterThan(generatedContent.metadata.wordCount, 0)
        XCTAssertGreaterThan(generatedContent.metadata.estimatedDuration, 0)
        
        // Verify repository state
        let updatedIntent = try await mockIntentRepository.getIntent(by: intent.id)
        XCTAssertEqual(updatedIntent?.status, .ready)
        XCTAssertNotNil(updatedIntent?.generatedContent)
        XCTAssertEqual(updatedIntent?.generatedContent?.textContent, generatedContent.textContent)
    }
    
    // MARK: - Performance Tests
    func testConcurrentGenerationHandling() async throws {
        let intents = (1...5).map { index in
            Intent.quickIntent(
                goal: "Concurrent test \(index)",
                scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
            )
        }
        
        // Save all intents
        for intent in intents {
            try await mockIntentRepository.saveIntent(intent)
        }
        
        // Try to generate content for all intents concurrently
        let tasks = intents.map { intent in
            Task {
                do {
                    return try await contentGenerationManager.generateContent(for: intent.id)
                } catch {
                    return nil
                }
            }
        }
        
        let results = await withTaskGroup(of: GeneratedContent?.self) { group in
            for task in tasks {
                group.addTask {
                    await task.value
                }
            }
            
            var results: [GeneratedContent?] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // Only one should succeed due to concurrent generation protection
        let successfulResults = results.compactMap { $0 }
        XCTAssertEqual(successfulResults.count, 1)
    }
    
    // MARK: - Memory Management Tests
    func testMemoryCleanup() async throws {
        contentGenerationManager.clearHistory()
        
        XCTAssertTrue(contentGenerationManager.recentlyCompleted.isEmpty)
        XCTAssertTrue(contentGenerationManager.failedGenerations.isEmpty)
    }
}

// MARK: - Mock Classes
class MockIntentRepository: IntentRepositoryProtocol {
    private var intents: [UUID: Intent] = [:]
    
    func getAllIntents() async throws -> [Intent] {
        return Array(intents.values)
    }
    
    func getIntent(by id: UUID) async throws -> Intent? {
        return intents[id]
    }
    
    func getIntentsForAlarm(_ alarmId: UUID) async throws -> [Intent] {
        return intents.values.filter { $0.alarmId == alarmId }
    }
    
    func getUpcomingIntents() async throws -> [Intent] {
        return intents.values.filter { !$0.isExpired && $0.status != .used }
    }
    
    func getTodaysIntents() async throws -> [Intent] {
        let today = Date()
        return intents.values.filter { Calendar.current.isDate($0.scheduledFor, inSameDayAs: today) }
    }
    
    func saveIntent(_ intent: Intent) async throws {
        intents[intent.id] = intent
    }
    
    func updateIntent(_ intent: Intent) async throws {
        intents[intent.id] = intent
    }
    
    func deleteIntent(_ intent: Intent) async throws {
        intents.removeValue(forKey: intent.id)
    }
    
    func deleteIntent(by id: UUID) async throws {
        intents.removeValue(forKey: id)
    }
    
    func deleteExpiredIntents() async throws {
        intents = intents.filter { !$0.value.isExpired }
    }
    
    func deleteUsedIntents() async throws {
        intents = intents.filter { $0.value.status != .used }
    }
    
    func exportIntents() async throws -> Data {
        return try JSONEncoder().encode(Array(intents.values))
    }
    
    func importIntents(_ data: Data) async throws {
        let importedIntents = try JSONDecoder().decode([Intent].self, from: data)
        for intent in importedIntents {
            intents[intent.id] = intent
        }
    }
    
    func getIntentsNeedingGeneration() async throws -> [Intent] {
        return intents.values.filter { $0.shouldAutoGenerate }
    }
    
    func markIntentAsGenerating(_ intentId: UUID) async throws {
        guard var intent = intents[intentId] else { return }
        intent.markAsGenerating()
        intents[intentId] = intent
    }
    
    func setGeneratedContent(for intentId: UUID, content: GeneratedContent) async throws {
        guard var intent = intents[intentId] else { return }
        intent.setGeneratedContent(content)
        intents[intentId] = intent
    }
    
    func markIntentAsUsed(_ intentId: UUID) async throws {
        guard var intent = intents[intentId] else { return }
        intent.markAsUsed()
        intents[intentId] = intent
    }
    
    func markIntentAsFailed(_ intentId: UUID, error: String) async throws {
        guard var intent = intents[intentId] else { return }
        intent.markAsFailed(error: error)
        intents[intentId] = intent
    }
    
    func getIntentStatistics() async throws -> IntentStatistics {
        let allIntents = Array(intents.values)
        let totalIntents = allIntents.count
        let pendingIntents = allIntents.filter { $0.status == .pending }.count
        let readyIntents = allIntents.filter { $0.status == .ready }.count
        let usedIntents = allIntents.filter { $0.status == .used }.count
        let failedIntents = allIntents.filter { $0.status.isFailure }.count
        
        return IntentStatistics(
            totalIntents: totalIntents,
            pendingIntents: pendingIntents,
            readyIntents: readyIntents,
            usedIntents: usedIntents,
            failedIntents: failedIntents,
            todaysIntents: 0,
            weeklyIntents: 0,
            averageGenerationTime: 1.5,
            mostPopularTone: .energetic
        )
    }
}

class MockContentGenerationService: ContentGenerationServiceProtocol {
    var shouldFail = false
    var simulateDelay = false
    private var currentStatus: ContentGenerationStatus = .idle
    
    func generateAlarmContent(userIntent: String, tone: String, context: [String: String]) async throws -> AlarmContent {
        if shouldFail {
            throw ContentGenerationError.serviceUnavailable
        }
        
        if simulateDelay {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        return AlarmContent(
            text: "Generated content for: \(userIntent)",
            audioData: "Mock audio data".data(using: .utf8) ?? Data(),
            metadata: AlarmContentMetadata(
                generatedAt: Date(),
                wordCount: 10,
                estimatedDuration: 30,
                voiceId: "test_voice",
                tone: tone
            )
        )
    }
    
    func generateContentForIntent(_ intent: Intent) async throws -> GeneratedContent {
        currentStatus = .generating(intentId: intent.id, progress: 0.0)
        
        if shouldFail {
            currentStatus = .failed(intentId: intent.id, error: ContentGenerationError.serviceUnavailable)
            throw ContentGenerationError.serviceUnavailable
        }
        
        if simulateDelay {
            currentStatus = .generating(intentId: intent.id, progress: 0.5)
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        currentStatus = .generating(intentId: intent.id, progress: 1.0)
        
        let content = GeneratedContent(
            textContent: "Generated motivational content for: \(intent.userGoal)",
            audioData: "Mock audio data for \(intent.userGoal)".data(using: .utf8),
            voiceId: intent.tone.rawValue,
            metadata: ContentMetadata(
                textContent: "Generated motivational content for: \(intent.userGoal)",
                tone: intent.tone,
                generationTime: 1.5
            )
        )
        
        currentStatus = .completed(intentId: intent.id)
        
        return content
    }
    
    func processIntentQueue() async throws {
        currentStatus = .idle
    }
    
    func getGenerationStatus() -> ContentGenerationStatus {
        return currentStatus
    }
}
