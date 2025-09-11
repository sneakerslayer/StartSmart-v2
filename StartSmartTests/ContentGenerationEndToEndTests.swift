import XCTest
@testable import StartSmart
import Combine

@MainActor
final class ContentGenerationEndToEndTests: XCTestCase {
    
    var contentManager: ContentGenerationManager!
    var intentRepository: MockIntentRepository!
    var contentService: ContentGenerationService!
    var grok4Service: MockGrok4Service!
    var elevenLabsService: MockElevenLabsService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup complete pipeline
        grok4Service = MockGrok4Service()
        grok4Service.enableRealisticContent = true
        
        elevenLabsService = MockElevenLabsService()
        elevenLabsService.enableRealisticAudio = true
        
        contentService = ContentGenerationService(
            aiService: grok4Service,
            ttsService: elevenLabsService
        )
        
        intentRepository = MockIntentRepository()
        contentManager = ContentGenerationManager(
            intentRepository: intentRepository,
            contentService: contentService,
            autoGenerationEnabled: false
        )
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        contentManager = nil
        intentRepository = nil
        contentService = nil
        grok4Service = nil
        elevenLabsService = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Complete Pipeline Tests
    func testCompleteContentGenerationPipeline() async throws {
        // Create a comprehensive intent
        var intent = Intent(
            userGoal: "Complete a 45-minute morning workout with strength training and cardio",
            tone: .energetic,
            context: IntentContext(
                weather: "sunny and energizing",
                temperature: 72.0,
                timeOfDay: .morning,
                dayOfWeek: "Monday",
                calendarEvents: ["Team meeting at 10am", "Lunch with mentor at 1pm"],
                location: "San Francisco",
                customNote: "Focus on building consistency and energy for the week ahead"
            ),
            scheduledFor: Date().addingTimeInterval(30 * 60) // 30 minutes from now
        )
        
        // Save intent to repository
        try await intentRepository.saveIntent(intent)
        
        // Generate content through complete pipeline
        let generatedContent = try await contentManager.generateContent(for: intent.id)
        
        // Verify complete content generation
        XCTAssertFalse(generatedContent.textContent.isEmpty)
        XCTAssertTrue(generatedContent.hasAudio)
        XCTAssertNotNil(generatedContent.audioData)
        
        // Verify content quality
        XCTAssertGreaterThan(generatedContent.metadata.wordCount, 30)
        XCTAssertLessThan(generatedContent.metadata.wordCount, 250)
        XCTAssertGreaterThan(generatedContent.metadata.estimatedDuration, 15)
        XCTAssertLessThan(generatedContent.metadata.estimatedDuration, 120)
        
        // Verify content includes goal context
        XCTAssertTrue(generatedContent.textContent.localizedCaseInsensitiveContains("workout") ||
                     generatedContent.textContent.localizedCaseInsensitiveContains("exercise") ||
                     generatedContent.textContent.localizedCaseInsensitiveContains("strength"))
        
        // Verify tone alignment
        XCTAssertEqual(generatedContent.metadata.tone, .energetic)
        XCTAssertEqual(generatedContent.voiceId, "energetic")
        
        // Verify weather context integration
        XCTAssertTrue(generatedContent.textContent.localizedCaseInsensitiveContains("sunny") ||
                     generatedContent.textContent.localizedCaseInsensitiveContains("energy"))
        
        // Verify custom note integration
        XCTAssertTrue(generatedContent.textContent.localizedCaseInsensitiveContains("consistency") ||
                     generatedContent.textContent.localizedCaseInsensitiveContains("week"))
        
        // Verify repository update
        let updatedIntent = try await intentRepository.getIntent(by: intent.id)
        XCTAssertEqual(updatedIntent?.status, .ready)
        XCTAssertNotNil(updatedIntent?.generatedContent)
        XCTAssertEqual(updatedIntent?.generatedContent?.textContent, generatedContent.textContent)
        
        // Verify metadata completeness
        XCTAssertEqual(generatedContent.metadata.aiModel, "grok4")
        XCTAssertEqual(generatedContent.metadata.ttsModel, "elevenlabs")
        XCTAssertGreaterThan(generatedContent.metadata.generationTime, 0)
    }
    
    func testAllTonesEndToEnd() async throws {
        let toneScenarios: [(AlarmTone, String, String)] = [
            (.gentle, "Practice mindful meditation for inner peace", "peaceful and calming"),
            (.energetic, "Conquer a challenging HIIT workout", "high-energy and motivating"),
            (.toughLove, "Organize cluttered workspace once and for all", "direct and firm"),
            (.storyteller, "Begin writing the first chapter of your novel", "narrative and inspiring")
        ]
        
        for (tone, goal, expectedCharacteristic) in toneScenarios {
            let intent = Intent.quickIntent(
                goal: goal,
                tone: tone,
                scheduledFor: Date().addingTimeInterval(3600)
            )
            
            try await intentRepository.saveIntent(intent)
            
            let content = try await contentManager.generateContent(for: intent.id)
            
            // Verify tone-specific characteristics
            XCTAssertEqual(content.metadata.tone, tone)
            XCTAssertEqual(content.voiceId, tone.rawValue)
            
            // Verify content quality for each tone
            XCTAssertFalse(content.textContent.isEmpty)
            XCTAssertGreaterThan(content.metadata.wordCount, 30)
            
            // Verify goal integration
            let goalKeywords = goal.lowercased().split(separator: " ")
            let hasGoalKeywords = goalKeywords.contains { keyword in
                content.textContent.localizedCaseInsensitiveContains(String(keyword))
            }
            XCTAssertTrue(hasGoalKeywords, "Content should reference goal keywords for \(tone.displayName)")
            
            print("✅ \(tone.displayName) tone test passed: \(expectedCharacteristic)")
        }
    }
    
    func testComplexIntentTypesEndToEnd() async throws {
        let complexIntents = [
            (
                goal: "Prepare for important client presentation while managing pre-meeting anxiety",
                context: IntentContext(
                    weather: "rainy",
                    timeOfDay: .morning,
                    dayOfWeek: "Tuesday",
                    calendarEvents: ["Client presentation at 11am", "Team debrief at 3pm"],
                    customNote: "Remember to breathe and trust your preparation"
                )
            ),
            (
                goal: "Balance work deadlines with family time and self-care",
                context: IntentContext(
                    weather: "cloudy",
                    timeOfDay: .evening,
                    dayOfWeek: "Friday",
                    calendarEvents: ["Kids soccer game at 6pm"],
                    customNote: "Quality over quantity in all areas"
                )
            ),
            (
                goal: "Start learning a new language while traveling for business",
                context: IntentContext(
                    weather: "clear",
                    timeOfDay: .morning,
                    dayOfWeek: "Wednesday",
                    location: "Tokyo, Japan",
                    customNote: "Embrace the challenge of cultural immersion"
                )
            )
        ]
        
        for (index, (goal, context)) in complexIntents.enumerated() {
            var intent = Intent.quickIntent(
                goal: goal,
                tone: .gentle,
                scheduledFor: Date().addingTimeInterval(TimeInterval((index + 1) * 3600))
            )
            intent.context = context
            
            try await intentRepository.saveIntent(intent)
            
            let content = try await contentManager.generateContent(for: intent.id)
            
            // Verify complex context handling
            XCTAssertFalse(content.textContent.isEmpty)
            XCTAssertGreaterThan(content.metadata.wordCount, 40) // Complex intents should generate more content
            
            // Verify goal complexity is addressed
            let goalWords = goal.split(separator: " ").map { String($0).lowercased() }
            let contentWords = content.textContent.lowercased().split(separator: " ").map { String($0) }
            
            let matchingWords = goalWords.filter { goalWord in
                contentWords.contains { contentWord in
                    contentWord.contains(goalWord) || goalWord.contains(contentWord)
                }
            }
            
            XCTAssertGreaterThan(matchingWords.count, 2, "Complex intent should have multiple keyword matches")
            
            // Verify custom note integration
            if let customNote = context.customNote {
                let noteWords = customNote.lowercased().split(separator: " ")
                let hasNoteReference = noteWords.contains { noteWord in
                    content.textContent.localizedCaseInsensitiveContains(String(noteWord))
                }
                XCTAssertTrue(hasNoteReference, "Should reference custom note: \(customNote)")
            }
        }
    }
    
    // MARK: - Real-time Status Monitoring Tests
    func testStatusMonitoringDuringGeneration() async throws {
        let intent = Intent.quickIntent(
            goal: "Status monitoring test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await intentRepository.saveIntent(intent)
        
        // Setup status monitoring
        var statusUpdates: [Bool] = []
        var progressUpdates: [Double] = []
        
        let statusExpectation = expectation(description: "Status updates")
        statusExpectation.expectedFulfillmentCount = 2 // Start and end
        
        contentManager.$isGenerating
            .sink { isGenerating in
                statusUpdates.append(isGenerating)
                statusExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        contentManager.$generationProgress
            .sink { progress in
                progressUpdates.append(progress)
            }
            .store(in: &cancellables)
        
        // Generate content
        let content = try await contentManager.generateContent(for: intent.id)
        
        await fulfillment(of: [statusExpectation], timeout: 5.0)
        
        // Verify status tracking
        XCTAssertGreaterThanOrEqual(statusUpdates.count, 2)
        XCTAssertTrue(statusUpdates.contains(true)) // Should show generating
        XCTAssertTrue(statusUpdates.contains(false)) // Should show complete
        
        // Verify progress tracking
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertTrue(progressUpdates.contains(1.0)) // Should reach 100%
        
        XCTAssertNotNil(content)
    }
    
    func testRecentlyCompletedTracking() async throws {
        let intents = (1...3).map { index in
            Intent.quickIntent(
                goal: "Completion tracking test \(index)",
                scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
            )
        }
        
        for intent in intents {
            try await intentRepository.saveIntent(intent)
            _ = try await contentManager.generateContent(for: intent.id)
        }
        
        // Verify completion tracking
        XCTAssertEqual(contentManager.recentlyCompleted.count, 3)
        
        // Verify all intents are marked complete
        for intent in intents {
            XCTAssertTrue(contentManager.recentlyCompleted.contains(intent.id))
        }
    }
    
    // MARK: - Error Recovery End-to-End Tests
    func testCompleteErrorRecoveryPipeline() async throws {
        let intent = Intent.quickIntent(
            goal: "Error recovery test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await intentRepository.saveIntent(intent)
        
        // Configure to fail first attempt
        grok4Service.failFirstNAttempts = 1
        
        // Should eventually succeed through retry mechanism
        let content = try await contentManager.generateContent(for: intent.id)
        
        XCTAssertFalse(content.textContent.isEmpty)
        
        // Verify intent was properly updated after recovery
        let updatedIntent = try await intentRepository.getIntent(by: intent.id)
        XCTAssertEqual(updatedIntent?.status, .ready)
        XCTAssertNotNil(updatedIntent?.generatedContent)
        
        grok4Service.failFirstNAttempts = 0
    }
    
    func testFailureTrackingAndRetry() async throws {
        let intent = Intent.quickIntent(
            goal: "Failure tracking test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        try await intentRepository.saveIntent(intent)
        
        // Configure to always fail
        grok4Service.alwaysFail = true
        
        // First attempt should fail
        do {
            _ = try await contentManager.generateContent(for: intent.id)
            XCTFail("Should have failed")
        } catch {
            // Expected failure
        }
        
        // Verify failure tracking
        XCTAssertTrue(contentManager.failedGenerations.keys.contains(intent.id))
        
        let updatedIntent = try await intentRepository.getIntent(by: intent.id)
        XCTAssertTrue(updatedIntent?.status.isFailure ?? false)
        
        // Configure to succeed and retry
        grok4Service.alwaysFail = false
        
        let content = try await contentManager.retryGeneration(for: intent.id)
        
        XCTAssertNotNil(content)
        XCTAssertFalse(contentManager.failedGenerations.keys.contains(intent.id))
        
        let retriedIntent = try await intentRepository.getIntent(by: intent.id)
        XCTAssertEqual(retriedIntent?.status, .ready)
    }
    
    // MARK: - Statistics and Analytics End-to-End Tests
    func testGenerationStatisticsAccuracy() async throws {
        // Create diverse test data
        let successIntents = (1...3).map { index in
            Intent.quickIntent(
                goal: "Success test \(index)",
                scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
            )
        }
        
        var failureIntent = Intent.quickIntent(
            goal: "Failure test",
            scheduledFor: Date().addingTimeInterval(7200)
        )
        
        let pendingIntent = Intent.quickIntent(
            goal: "Pending test",
            scheduledFor: Date().addingTimeInterval(10800)
        )
        
        // Save all intents
        for intent in successIntents {
            try await intentRepository.saveIntent(intent)
        }
        try await intentRepository.saveIntent(failureIntent)
        try await intentRepository.saveIntent(pendingIntent)
        
        // Generate success content
        for intent in successIntents {
            _ = try await contentManager.generateContent(for: intent.id)
        }
        
        // Create failure
        grok4Service.alwaysFail = true
        do {
            _ = try await contentManager.generateContent(for: failureIntent.id)
        } catch {
            // Expected failure
        }
        grok4Service.alwaysFail = false
        
        // Get statistics
        let stats = try await contentManager.getGenerationStatistics()
        
        // Verify statistics accuracy
        XCTAssertEqual(stats.totalIntents, 5)
        XCTAssertEqual(stats.successfullyGenerated, 3)
        XCTAssertEqual(stats.failedGeneration, 1)
        XCTAssertEqual(stats.pendingGeneration, 1)
        XCTAssertEqual(stats.recentlyCompletedCount, 3)
        XCTAssertEqual(stats.queuedForRetry, 1)
        
        // Verify calculated rates
        XCTAssertEqual(stats.completionRate, 0.6) // 3/5
        XCTAssertEqual(stats.failureRate, 0.2) // 1/5
        XCTAssertEqual(stats.pendingRate, 0.2) // 1/5
        
        XCTAssertGreaterThan(stats.averageGenerationTime, 0)
    }
    
    // MARK: - Auto-Generation Pipeline Tests
    func testAutoGenerationTriggerLogic() async throws {
        let now = Date()
        
        // Create intents at different time intervals
        let immediateIntent = Intent.quickIntent(
            goal: "Immediate generation test",
            scheduledFor: now.addingTimeInterval(30 * 60) // 30 minutes - should trigger
        )
        
        let futureIntent = Intent.quickIntent(
            goal: "Future generation test",
            scheduledFor: now.addingTimeInterval(2 * 60 * 60) // 2 hours - should not trigger
        )
        
        try await intentRepository.saveIntent(immediateIntent)
        try await intentRepository.saveIntent(futureIntent)
        
        // Get intents needing generation
        let needingGeneration = try await intentRepository.getIntentsNeedingGeneration()
        
        XCTAssertEqual(needingGeneration.count, 1)
        XCTAssertEqual(needingGeneration.first?.id, immediateIntent.id)
    }
    
    // MARK: - Complete User Journey Tests
    func testCompleteUserJourney() async throws {
        // Simulate complete user journey from intent creation to content consumption
        
        // Step 1: User creates intent
        var userIntent = Intent(
            userGoal: "Build a consistent morning routine with exercise and reflection",
            tone: .gentle,
            context: IntentContext(
                weather: "partly cloudy",
                temperature: 68.0,
                timeOfDay: .morning,
                dayOfWeek: "Monday",
                customNote: "Start small and build momentum"
            ),
            scheduledFor: Date().addingTimeInterval(8 * 60 * 60) // 8 hours from now
        )
        
        // Step 2: Save to repository
        try await intentRepository.saveIntent(userIntent)
        
        // Step 3: System generates content
        let generatedContent = try await contentManager.generateContent(for: userIntent.id)
        
        // Step 4: Verify complete content package
        XCTAssertFalse(generatedContent.textContent.isEmpty)
        XCTAssertTrue(generatedContent.hasAudio)
        XCTAssertNotNil(generatedContent.audioData)
        
        // Step 5: Verify content quality and personalization
        XCTAssertTrue(generatedContent.textContent.localizedCaseInsensitiveContains("routine") ||
                     generatedContent.textContent.localizedCaseInsensitiveContains("morning"))
        
        XCTAssertTrue(generatedContent.textContent.localizedCaseInsensitiveContains("exercise") ||
                     generatedContent.textContent.localizedCaseInsensitiveContains("reflection"))
        
        // Gentle tone verification
        let gentleKeywords = ["gentle", "peaceful", "soft", "calm", "gradual"]
        let hasGentleLanguage = gentleKeywords.contains { keyword in
            generatedContent.textContent.localizedCaseInsensitiveContains(keyword)
        }
        XCTAssertTrue(hasGentleLanguage, "Should use gentle language")
        
        // Step 6: Verify custom note integration
        XCTAssertTrue(generatedContent.textContent.localizedCaseInsensitiveContains("small") ||
                     generatedContent.textContent.localizedCaseInsensitiveContains("momentum"))
        
        // Step 7: Verify intent status progression
        let finalIntent = try await intentRepository.getIntent(by: userIntent.id)
        XCTAssertEqual(finalIntent?.status, .ready)
        XCTAssertNotNil(finalIntent?.generatedContent)
        
        // Step 8: Simulate usage (alarm triggered)
        try await intentRepository.markIntentAsUsed(userIntent.id)
        
        let usedIntent = try await intentRepository.getIntent(by: userIntent.id)
        XCTAssertEqual(usedIntent?.status, .used)
        
        // Step 9: Verify statistics tracking
        let finalStats = try await contentManager.getGenerationStatistics()
        XCTAssertEqual(finalStats.totalIntents, 1)
        XCTAssertEqual(finalStats.successfullyGenerated, 1)
        XCTAssertEqual(finalStats.usedIntents, 1)
        XCTAssertEqual(finalStats.successRate, 1.0)
    }
    
    // MARK: - Performance Validation
    func testEndToEndPerformance() async throws {
        let performanceIntents = (1...5).map { index in
            Intent.quickIntent(
                goal: "Performance validation test \(index)",
                scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
            )
        }
        
        let startTime = Date()
        
        for intent in performanceIntents {
            try await intentRepository.saveIntent(intent)
            _ = try await contentManager.generateContent(for: intent.id)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageTime = totalTime / Double(performanceIntents.count)
        
        // Performance validation
        XCTAssertLessThan(averageTime, 5.0, "Average generation time should be under 5 seconds")
        XCTAssertLessThan(totalTime, 20.0, "Total time for 5 intents should be under 20 seconds")
        
        // Verify all completed successfully
        let stats = try await contentManager.getGenerationStatistics()
        XCTAssertEqual(stats.successfullyGenerated, 5)
        XCTAssertEqual(stats.failedGeneration, 0)
    }
}

// MARK: - Enhanced Mock Services for End-to-End Testing
extension MockElevenLabsService {
    var enableRealisticAudio: Bool {
        get { return _enableRealisticAudio }
        set { _enableRealisticAudio = newValue }
    }
    
    private var _enableRealisticAudio = false
    
    override func generateSpeech(text: String, voiceId: String) async throws -> Data {
        if enableRealisticAudio {
            // Simulate realistic audio generation with size proportional to text length
            let audioSize = min(max(text.count * 100, 1024), 50000) // 1KB to 50KB
            return Data(count: audioSize)
        } else {
            return try await super.generateSpeech(text: text, voiceId: voiceId)
        }
    }
}
