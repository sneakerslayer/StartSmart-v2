import XCTest
@testable import StartSmart

@MainActor
final class IntentRepositoryTests: XCTestCase {
    
    var repository: IntentRepository!
    var mockStorageManager: MockStorageManager!
    
    override func setUp() async throws {
        try await super.setUp()
        mockStorageManager = MockStorageManager()
        repository = IntentRepository(storageManager: mockStorageManager)
    }
    
    override func tearDown() async throws {
        repository = nil
        mockStorageManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    func testRepositoryInitialization() async throws {
        XCTAssertNotNil(repository)
        
        let intents = try await repository.getAllIntents()
        XCTAssertTrue(intents.isEmpty)
    }
    
    // MARK: - Basic CRUD Tests
    func testSaveIntent() async throws {
        let intent = Intent.quickIntent(
            goal: "Exercise for 30 minutes",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        
        let savedIntents = try await repository.getAllIntents()
        XCTAssertEqual(savedIntents.count, 1)
        XCTAssertEqual(savedIntents.first?.userGoal, "Exercise for 30 minutes")
        XCTAssertEqual(savedIntents.first?.id, intent.id)
    }
    
    func testGetIntentById() async throws {
        let intent = Intent.quickIntent(
            goal: "Read 20 pages",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        
        let retrievedIntent = try await repository.getIntent(by: intent.id)
        XCTAssertNotNil(retrievedIntent)
        XCTAssertEqual(retrievedIntent?.userGoal, "Read 20 pages")
        XCTAssertEqual(retrievedIntent?.id, intent.id)
    }
    
    func testGetIntentById_NotFound() async throws {
        let nonExistentId = UUID()
        
        let retrievedIntent = try await repository.getIntent(by: nonExistentId)
        XCTAssertNil(retrievedIntent)
    }
    
    func testUpdateIntent() async throws {
        var intent = Intent.quickIntent(
            goal: "Original goal",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        
        intent.updateGoal("Updated goal")
        try await repository.updateIntent(intent)
        
        let updatedIntent = try await repository.getIntent(by: intent.id)
        XCTAssertEqual(updatedIntent?.userGoal, "Updated goal")
    }
    
    func testUpdateIntent_NotFound() async throws {
        let intent = Intent.quickIntent(
            goal: "Test goal",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        do {
            try await repository.updateIntent(intent)
            XCTFail("Should have thrown intentNotFound error")
        } catch let error as IntentRepositoryError {
            XCTAssertEqual(error, IntentRepositoryError.intentNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDeleteIntent() async throws {
        let intent = Intent.quickIntent(
            goal: "Delete me",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        
        let beforeDelete = try await repository.getAllIntents()
        XCTAssertEqual(beforeDelete.count, 1)
        
        try await repository.deleteIntent(intent)
        
        let afterDelete = try await repository.getAllIntents()
        XCTAssertEqual(afterDelete.count, 0)
    }
    
    func testDeleteIntentById() async throws {
        let intent = Intent.quickIntent(
            goal: "Delete by ID",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        try await repository.deleteIntent(by: intent.id)
        
        let intents = try await repository.getAllIntents()
        XCTAssertEqual(intents.count, 0)
    }
    
    func testDeleteIntent_NotFound() async throws {
        let nonExistentId = UUID()
        
        do {
            try await repository.deleteIntent(by: nonExistentId)
            XCTFail("Should have thrown intentNotFound error")
        } catch let error as IntentRepositoryError {
            XCTAssertEqual(error, IntentRepositoryError.intentNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Duplicate Prevention Tests
    func testSaveDuplicateIntent() async throws {
        let intent = Intent.quickIntent(
            goal: "Duplicate test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        
        do {
            try await repository.saveIntent(intent)
            XCTFail("Should have thrown duplicateIntent error")
        } catch let error as IntentRepositoryError {
            XCTAssertEqual(error, IntentRepositoryError.duplicateIntent)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Filtering Tests
    func testGetIntentsForAlarm() async throws {
        let alarmId = UUID()
        let intent1 = Intent(
            userGoal: "Alarm intent",
            scheduledFor: Date().addingTimeInterval(3600),
            alarmId: alarmId
        )
        let intent2 = Intent.quickIntent(
            goal: "No alarm intent",
            scheduledFor: Date().addingTimeInterval(7200)
        )
        
        try await repository.saveIntent(intent1)
        try await repository.saveIntent(intent2)
        
        let alarmIntents = try await repository.getIntentsForAlarm(alarmId)
        XCTAssertEqual(alarmIntents.count, 1)
        XCTAssertEqual(alarmIntents.first?.userGoal, "Alarm intent")
    }
    
    func testGetUpcomingIntents() async throws {
        let now = Date()
        let futureIntent = Intent.quickIntent(
            goal: "Future goal",
            scheduledFor: now.addingTimeInterval(3600)
        )
        var pastIntent = Intent.quickIntent(
            goal: "Past goal",
            scheduledFor: now.addingTimeInterval(-3600)
        )
        var usedIntent = Intent.quickIntent(
            goal: "Used goal",
            scheduledFor: now.addingTimeInterval(7200)
        )
        usedIntent.markAsUsed()
        
        try await repository.saveIntent(futureIntent)
        try await repository.saveIntent(pastIntent)
        try await repository.saveIntent(usedIntent)
        
        let upcomingIntents = try await repository.getUpcomingIntents()
        XCTAssertEqual(upcomingIntents.count, 1)
        XCTAssertEqual(upcomingIntents.first?.userGoal, "Future goal")
    }
    
    func testGetTodaysIntents() async throws {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        
        let todayIntent = Intent.quickIntent(
            goal: "Today's goal",
            scheduledFor: today
        )
        let tomorrowIntent = Intent.quickIntent(
            goal: "Tomorrow's goal",
            scheduledFor: tomorrow
        )
        
        try await repository.saveIntent(todayIntent)
        try await repository.saveIntent(tomorrowIntent)
        
        let todaysIntents = try await repository.getTodaysIntents()
        XCTAssertEqual(todaysIntents.count, 1)
        XCTAssertEqual(todaysIntents.first?.userGoal, "Today's goal")
    }
    
    // MARK: - Cleanup Tests
    func testDeleteExpiredIntents() async throws {
        let now = Date()
        let expiredIntent = Intent.quickIntent(
            goal: "Expired goal",
            scheduledFor: now.addingTimeInterval(-3600)
        )
        let activeIntent = Intent.quickIntent(
            goal: "Active goal",
            scheduledFor: now.addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(expiredIntent)
        try await repository.saveIntent(activeIntent)
        
        let beforeCleanup = try await repository.getAllIntents()
        XCTAssertEqual(beforeCleanup.count, 2)
        
        try await repository.deleteExpiredIntents()
        
        let afterCleanup = try await repository.getAllIntents()
        XCTAssertEqual(afterCleanup.count, 1)
        XCTAssertEqual(afterCleanup.first?.userGoal, "Active goal")
    }
    
    func testDeleteUsedIntents() async throws {
        var usedIntent = Intent.quickIntent(
            goal: "Used goal",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        usedIntent.markAsUsed()
        
        let activeIntent = Intent.quickIntent(
            goal: "Active goal",
            scheduledFor: Date().addingTimeInterval(7200)
        )
        
        try await repository.saveIntent(usedIntent)
        try await repository.saveIntent(activeIntent)
        
        let beforeCleanup = try await repository.getAllIntents()
        XCTAssertEqual(beforeCleanup.count, 2)
        
        try await repository.deleteUsedIntents()
        
        let afterCleanup = try await repository.getAllIntents()
        XCTAssertEqual(afterCleanup.count, 1)
        XCTAssertEqual(afterCleanup.first?.userGoal, "Active goal")
    }
    
    // MARK: - Content Generation Helper Tests
    func testGetIntentsNeedingGeneration() async throws {
        let now = Date()
        let needsGenerationIntent = Intent.quickIntent(
            goal: "Needs generation",
            scheduledFor: now.addingTimeInterval(30 * 60) // 30 minutes from now
        )
        let tooFarIntent = Intent.quickIntent(
            goal: "Too far",
            scheduledFor: now.addingTimeInterval(2 * 60 * 60) // 2 hours from now
        )
        
        try await repository.saveIntent(needsGenerationIntent)
        try await repository.saveIntent(tooFarIntent)
        
        let needingGeneration = try await repository.getIntentsNeedingGeneration()
        XCTAssertEqual(needingGeneration.count, 1)
        XCTAssertEqual(needingGeneration.first?.userGoal, "Needs generation")
    }
    
    func testMarkIntentAsGenerating() async throws {
        let intent = Intent.quickIntent(
            goal: "Test generating",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        XCTAssertEqual(intent.status, .pending)
        
        try await repository.markIntentAsGenerating(intent.id)
        
        let updatedIntent = try await repository.getIntent(by: intent.id)
        XCTAssertEqual(updatedIntent?.status, .generating)
    }
    
    func testSetGeneratedContent() async throws {
        let intent = Intent.quickIntent(
            goal: "Test content",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        
        let content = GeneratedContent(
            textContent: "Great motivational content",
            voiceId: "test_voice",
            metadata: ContentMetadata(
                textContent: "Great motivational content",
                tone: .energetic
            )
        )
        
        try await repository.setGeneratedContent(for: intent.id, content: content)
        
        let updatedIntent = try await repository.getIntent(by: intent.id)
        XCTAssertEqual(updatedIntent?.status, .ready)
        XCTAssertEqual(updatedIntent?.generatedContent?.textContent, "Great motivational content")
    }
    
    func testMarkIntentAsUsed() async throws {
        let intent = Intent.quickIntent(
            goal: "Test used",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        try await repository.markIntentAsUsed(intent.id)
        
        let updatedIntent = try await repository.getIntent(by: intent.id)
        XCTAssertEqual(updatedIntent?.status, .used)
    }
    
    func testMarkIntentAsFailed() async throws {
        let intent = Intent.quickIntent(
            goal: "Test failed",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        try await repository.markIntentAsFailed(intent.id, error: "Test error")
        
        let updatedIntent = try await repository.getIntent(by: intent.id)
        XCTAssertTrue(updatedIntent?.status.isFailure ?? false)
    }
    
    // MARK: - Import/Export Tests
    func testExportImportIntents() async throws {
        let intent1 = Intent.quickIntent(
            goal: "Export test 1",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        let intent2 = Intent.quickIntent(
            goal: "Export test 2",
            scheduledFor: Date().addingTimeInterval(7200)
        )
        
        try await repository.saveIntent(intent1)
        try await repository.saveIntent(intent2)
        
        let exportData = try await repository.exportIntents()
        XCTAssertGreaterThan(exportData.count, 0)
        
        // Clear repository
        try await repository.deleteIntent(intent1)
        try await repository.deleteIntent(intent2)
        
        let beforeImport = try await repository.getAllIntents()
        XCTAssertEqual(beforeImport.count, 0)
        
        try await repository.importIntents(exportData)
        
        let afterImport = try await repository.getAllIntents()
        XCTAssertEqual(afterImport.count, 2)
    }
    
    func testImportDuplicateIntents() async throws {
        let intent = Intent.quickIntent(
            goal: "Duplicate import test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        
        let exportData = try await repository.exportIntents()
        
        // Import again - should not create duplicates
        try await repository.importIntents(exportData)
        
        let intents = try await repository.getAllIntents()
        XCTAssertEqual(intents.count, 1)
    }
    
    // MARK: - Statistics Tests
    func testGetIntentStatistics() async throws {
        var pendingIntent = Intent.quickIntent(goal: "Pending", scheduledFor: Date().addingTimeInterval(3600))
        var readyIntent = Intent.quickIntent(goal: "Ready", scheduledFor: Date().addingTimeInterval(7200))
        var usedIntent = Intent.quickIntent(goal: "Used", scheduledFor: Date().addingTimeInterval(10800))
        var failedIntent = Intent.quickIntent(goal: "Failed", scheduledFor: Date().addingTimeInterval(14400))
        
        readyIntent.setGeneratedContent(GeneratedContent(
            textContent: "Ready content",
            voiceId: "test",
            metadata: ContentMetadata(textContent: "Ready content", tone: .energetic, generationTime: 2.5)
        ))
        usedIntent.markAsUsed()
        failedIntent.markAsFailed(error: "Test error")
        
        try await repository.saveIntent(pendingIntent)
        try await repository.saveIntent(readyIntent)
        try await repository.saveIntent(usedIntent)
        try await repository.saveIntent(failedIntent)
        
        let stats = try await repository.getIntentStatistics()
        
        XCTAssertEqual(stats.totalIntents, 4)
        XCTAssertEqual(stats.pendingIntents, 1)
        XCTAssertEqual(stats.readyIntents, 1)
        XCTAssertEqual(stats.usedIntents, 1)
        XCTAssertEqual(stats.failedIntents, 1)
        XCTAssertEqual(stats.successRate, 0.5) // 2 successful out of 4
        XCTAssertEqual(stats.failureRate, 0.25) // 1 failed out of 4
        XCTAssertEqual(stats.averageGenerationTime, 2.5)
    }
    
    // MARK: - Publisher Tests
    func testIntentsPublisher() async throws {
        let expectation = XCTestExpectation(description: "Publisher notification")
        
        let cancellable = repository.intentsPublisher
            .dropFirst() // Skip initial empty array
            .sink { intents in
                if intents.count == 1 {
                    expectation.fulfill()
                }
            }
        
        let intent = Intent.quickIntent(
            goal: "Publisher test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await repository.saveIntent(intent)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
    
    // MARK: - Performance Tests
    func testPerformanceMultipleIntents() async throws {
        measure {
            Task {
                let intents = (1...100).map { index in
                    Intent.quickIntent(
                        goal: "Performance test \(index)",
                        scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
                    )
                }
                
                for intent in intents {
                    try? await repository.saveIntent(intent)
                }
            }
        }
    }
    
    func testPerformanceGetAllIntents() async throws {
        // Setup data
        let intents = (1...1000).map { index in
            Intent.quickIntent(
                goal: "Load test \(index)",
                scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
            )
        }
        
        for intent in intents {
            try await repository.saveIntent(intent)
        }
        
        measure {
            Task {
                _ = try? await repository.getAllIntents()
            }
        }
    }
}

// MARK: - Mock Storage Manager for Testing
class MockStorageManager: StorageManager {
    private var storedIntents: [Intent] = []
    
    override func loadIntents() throws -> [Intent] {
        return storedIntents
    }
    
    override func saveIntents(_ intents: [Intent]) throws {
        storedIntents = intents
    }
}
