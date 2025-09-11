import XCTest
@testable import StartSmart

final class ContentGenerationQualityTests: XCTestCase {
    
    var grok4Service: MockGrok4Service!
    var contentService: ContentGenerationService!
    var intentRepository: MockIntentRepository!
    var contentManager: ContentGenerationManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup services with realistic mock behavior
        grok4Service = MockGrok4Service()
        grok4Service.enableRealisticContent = true
        
        let elevenLabsService = MockElevenLabsService()
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
    }
    
    override func tearDown() async throws {
        grok4Service = nil
        contentService = nil
        intentRepository = nil
        contentManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Tone Variation Tests
    func testContentGenerationWithGentleTone() async throws {
        let intent = Intent.quickIntent(
            goal: "Start a morning meditation practice",
            tone: .gentle,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await contentService.generateContentForIntent(intent)
        
        // Verify content characteristics for gentle tone
        XCTAssertFalse(content.textContent.isEmpty)
        XCTAssertTrue(content.textContent.localizedCaseInsensitiveContains("meditation") ||
                     content.textContent.localizedCaseInsensitiveContains("peaceful") ||
                     content.textContent.localizedCaseInsensitiveContains("gentle"))
        
        // Gentle tone should use softer language
        XCTAssertFalse(content.textContent.localizedCaseInsensitiveContains("WAKE UP!"))
        XCTAssertFalse(content.textContent.localizedCaseInsensitiveContains("GET MOVING!"))
        
        // Verify metadata
        XCTAssertEqual(content.metadata.tone, .gentle)
        XCTAssertGreaterThan(content.metadata.wordCount, 30)
        XCTAssertLessThan(content.metadata.wordCount, 250)
    }
    
    func testContentGenerationWithEnergeticTone() async throws {
        let intent = Intent.quickIntent(
            goal: "Complete a 5K run",
            tone: .energetic,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await contentService.generateContentForIntent(intent)
        
        // Verify content characteristics for energetic tone
        XCTAssertFalse(content.textContent.isEmpty)
        XCTAssertTrue(content.textContent.localizedCaseInsensitiveContains("run") ||
                     content.textContent.localizedCaseInsensitiveContains("energy") ||
                     content.textContent.localizedCaseInsensitiveContains("go"))
        
        // Energetic tone should be more motivating
        let energeticKeywords = ["energy", "power", "strong", "go", "move", "action"]
        let hasEnergeticLanguage = energeticKeywords.contains { keyword in
            content.textContent.localizedCaseInsensitiveContains(keyword)
        }
        XCTAssertTrue(hasEnergeticLanguage)
        
        XCTAssertEqual(content.metadata.tone, .energetic)
    }
    
    func testContentGenerationWithToughLoveTone() async throws {
        let intent = Intent.quickIntent(
            goal: "Clean the entire house",
            tone: .toughLove,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await contentService.generateContentForIntent(intent)
        
        // Verify content characteristics for tough love tone
        XCTAssertFalse(content.textContent.isEmpty)
        XCTAssertTrue(content.textContent.localizedCaseInsensitiveContains("clean") ||
                     content.textContent.localizedCaseInsensitiveContains("house"))
        
        // Tough love should be more direct
        let directKeywords = ["time", "need", "must", "important", "responsibility"]
        let hasDirectLanguage = directKeywords.contains { keyword in
            content.textContent.localizedCaseInsensitiveContains(keyword)
        }
        XCTAssertTrue(hasDirectLanguage)
        
        XCTAssertEqual(content.metadata.tone, .toughLove)
    }
    
    func testContentGenerationWithStorytellerTone() async throws {
        let intent = Intent.quickIntent(
            goal: "Write in my journal",
            tone: .storyteller,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await contentService.generateContentForIntent(intent)
        
        // Verify content characteristics for storyteller tone
        XCTAssertFalse(content.textContent.isEmpty)
        XCTAssertTrue(content.textContent.localizedCaseInsensitiveContains("journal") ||
                     content.textContent.localizedCaseInsensitiveContains("write") ||
                     content.textContent.localizedCaseInsensitiveContains("story"))
        
        // Storyteller should be more narrative
        let narrativeKeywords = ["once", "story", "journey", "chapter", "imagine"]
        let hasNarrativeLanguage = narrativeKeywords.contains { keyword in
            content.textContent.localizedCaseInsensitiveContains(keyword)
        }
        XCTAssertTrue(hasNarrativeLanguage)
        
        XCTAssertEqual(content.metadata.tone, .storyteller)
    }
    
    // MARK: - Intent Type Variation Tests
    func testPhysicalActivityIntents() async throws {
        let physicalIntents = [
            Intent.quickIntent(goal: "Go for a 30-minute walk", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Do 50 push-ups", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Practice yoga for 20 minutes", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Go swimming", scheduledFor: Date().addingTimeInterval(3600))
        ]
        
        for intent in physicalIntents {
            let content = try await contentService.generateContentForIntent(intent)
            
            XCTAssertFalse(content.textContent.isEmpty)
            XCTAssertGreaterThan(content.metadata.wordCount, 30)
            
            // Should mention physical activity or movement
            let physicalKeywords = ["move", "body", "exercise", "active", "strength", "health"]
            let hasPhysicalContext = physicalKeywords.contains { keyword in
                content.textContent.localizedCaseInsensitiveContains(keyword)
            }
            XCTAssertTrue(hasPhysicalContext, "Content should reference physical activity for: \(intent.userGoal)")
        }
    }
    
    func testLearningAndGrowthIntents() async throws {
        let learningIntents = [
            Intent.quickIntent(goal: "Read 25 pages of a book", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Study Spanish for 30 minutes", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Practice piano", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Learn a new skill online", scheduledFor: Date().addingTimeInterval(3600))
        ]
        
        for intent in learningIntents {
            let content = try await contentService.generateContentForIntent(intent)
            
            XCTAssertFalse(content.textContent.isEmpty)
            
            // Should mention learning, growth, or knowledge
            let learningKeywords = ["learn", "grow", "knowledge", "skill", "practice", "improve"]
            let hasLearningContext = learningKeywords.contains { keyword in
                content.textContent.localizedCaseInsensitiveContains(keyword)
            }
            XCTAssertTrue(hasLearningContext, "Content should reference learning for: \(intent.userGoal)")
        }
    }
    
    func testProductivityIntents() async throws {
        let productivityIntents = [
            Intent.quickIntent(goal: "Organize my workspace", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Complete important project tasks", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Plan my week", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Clear my email inbox", scheduledFor: Date().addingTimeInterval(3600))
        ]
        
        for intent in productivityIntents {
            let content = try await contentService.generateContentForIntent(intent)
            
            XCTAssertFalse(content.textContent.isEmpty)
            
            // Should mention productivity, organization, or accomplishment
            let productivityKeywords = ["organize", "accomplish", "productive", "focus", "complete", "achieve"]
            let hasProductivityContext = productivityKeywords.contains { keyword in
                content.textContent.localizedCaseInsensitiveContains(keyword)
            }
            XCTAssertTrue(hasProductivityContext, "Content should reference productivity for: \(intent.userGoal)")
        }
    }
    
    func testWellnessIntents() async throws {
        let wellnessIntents = [
            Intent.quickIntent(goal: "Practice mindfulness meditation", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Drink 8 glasses of water", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Take a mental health break", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Practice gratitude", scheduledFor: Date().addingTimeInterval(3600))
        ]
        
        for intent in wellnessIntents {
            let content = try await contentService.generateContentForIntent(intent)
            
            XCTAssertFalse(content.textContent.isEmpty)
            
            // Should mention wellness, health, or self-care
            let wellnessKeywords = ["wellness", "health", "care", "mindful", "peaceful", "balance"]
            let hasWellnessContext = wellnessKeywords.contains { keyword in
                content.textContent.localizedCaseInsensitiveContains(keyword)
            }
            XCTAssertTrue(hasWellnessContext, "Content should reference wellness for: \(intent.userGoal)")
        }
    }
    
    // MARK: - Context Integration Tests
    func testWeatherContextIntegration() async throws {
        var intent = Intent.quickIntent(
            goal: "Go for an outdoor run",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        intent.context.weather = "sunny and warm"
        intent.context.temperature = 75.0
        
        let content = try await contentService.generateContentForIntent(intent)
        
        XCTAssertFalse(content.textContent.isEmpty)
        
        // Should reference weather conditions
        let weatherKeywords = ["sunny", "warm", "weather", "outside", "outdoor"]
        let hasWeatherReference = weatherKeywords.contains { keyword in
            content.textContent.localizedCaseInsensitiveContains(keyword)
        }
        XCTAssertTrue(hasWeatherReference, "Content should reference weather context")
    }
    
    func testCalendarContextIntegration() async throws {
        var intent = Intent.quickIntent(
            goal: "Prepare for important meetings",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        intent.context.calendarEvents = ["Team standup at 9am", "Client presentation at 2pm"]
        
        let content = try await contentService.generateContentForIntent(intent)
        
        XCTAssertFalse(content.textContent.isEmpty)
        
        // Should reference meeting or preparation
        let calendarKeywords = ["meeting", "prepare", "presentation", "team", "ready"]
        let hasCalendarReference = calendarKeywords.contains { keyword in
            content.textContent.localizedCaseInsensitiveContains(keyword)
        }
        XCTAssertTrue(hasCalendarReference, "Content should reference calendar context")
    }
    
    func testCustomNoteIntegration() async throws {
        var intent = Intent.quickIntent(
            goal: "Start a creative writing session",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        intent.context.customNote = "Focus on the novel chapter about perseverance"
        
        let content = try await contentService.generateContentForIntent(intent)
        
        XCTAssertFalse(content.textContent.isEmpty)
        
        // Should reference creative writing or the custom note
        let customNoteKeywords = ["creative", "writing", "novel", "perseverance", "story"]
        let hasCustomNoteReference = customNoteKeywords.contains { keyword in
            content.textContent.localizedCaseInsensitiveContains(keyword)
        }
        XCTAssertTrue(hasCustomNoteReference, "Content should reference custom note context")
    }
    
    // MARK: - Content Appropriateness Tests
    func testContentAppropriateness() async throws {
        let intents = [
            Intent.quickIntent(goal: "Exercise for fitness", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Study for exam", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Clean the house", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Practice guitar", scheduledFor: Date().addingTimeInterval(3600)),
            Intent.quickIntent(goal: "Meditate for peace", scheduledFor: Date().addingTimeInterval(3600))
        ]
        
        for intent in intents {
            let content = try await contentService.generateContentForIntent(intent)
            
            // Test content validation
            let validation = try grok4Service.validateContent(content.textContent)
            XCTAssertTrue(validation.isValid, "Content should pass validation for: \(intent.userGoal)")
            
            // No inappropriate language
            let inappropriateTerms = ["damn", "hell", "shit", "fuck", "crap"]
            for term in inappropriateTerms {
                XCTAssertFalse(content.textContent.localizedCaseInsensitiveContains(term),
                              "Content should not contain inappropriate language: \(term)")
            }
            
            // Should be motivational
            let motivationalKeywords = ["you", "can", "will", "today", "achieve", "success", "goal"]
            let hasMotivationalContent = motivationalKeywords.contains { keyword in
                content.textContent.localizedCaseInsensitiveContains(keyword)
            }
            XCTAssertTrue(hasMotivationalContent, "Content should be motivational for: \(intent.userGoal)")
        }
    }
    
    // MARK: - Content Length and Quality Tests
    func testContentLengthRequirements() async throws {
        let intent = Intent.quickIntent(
            goal: "Complete daily workout routine",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await contentService.generateContentForIntent(intent)
        
        // Test word count requirements
        XCTAssertGreaterThanOrEqual(content.metadata.wordCount, 30, "Content should have at least 30 words")
        XCTAssertLessThanOrEqual(content.metadata.wordCount, 250, "Content should have at most 250 words")
        
        // Test character count
        XCTAssertGreaterThan(content.metadata.characterCount, 100, "Content should have substantial character count")
        
        // Test estimated duration (should be reasonable for speech)
        XCTAssertGreaterThan(content.metadata.estimatedDuration, 10, "Content should take at least 10 seconds to read")
        XCTAssertLessThan(content.metadata.estimatedDuration, 120, "Content should take less than 2 minutes to read")
    }
    
    func testContentStructure() async throws {
        let intent = Intent.quickIntent(
            goal: "Organize my workspace for productivity",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await contentService.generateContentForIntent(intent)
        
        // Should have proper sentence structure
        XCTAssertTrue(content.textContent.contains(".") || content.textContent.contains("!"),
                     "Content should have proper sentence endings")
        
        // Should start and end appropriately
        XCTAssertFalse(content.textContent.hasPrefix(" "), "Content should not start with whitespace")
        XCTAssertFalse(content.textContent.hasSuffix(" "), "Content should not end with whitespace")
        
        // Should have a clear call to action (typically at the end)
        let callToActionKeywords = ["let's", "start", "begin", "go", "take", "make", "do", "get"]
        let hasCallToAction = callToActionKeywords.contains { keyword in
            content.textContent.localizedCaseInsensitiveContains(keyword)
        }
        XCTAssertTrue(hasCallToAction, "Content should include a call to action")
    }
    
    // MARK: - Edge Case Tests
    func testVeryShortGoal() async throws {
        let intent = Intent.quickIntent(
            goal: "Run",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await contentService.generateContentForIntent(intent)
        
        // Even with short goal, should generate substantial content
        XCTAssertGreaterThan(content.metadata.wordCount, 30)
        XCTAssertTrue(content.textContent.localizedCaseInsensitiveContains("run"))
    }
    
    func testVeryLongGoal() async throws {
        let longGoal = """
        Complete a comprehensive morning routine that includes meditation, exercise, 
        healthy breakfast preparation, review of daily goals, checking important emails, 
        and setting positive intentions for the day ahead while maintaining mindfulness
        """
        
        let intent = Intent.quickIntent(
            goal: longGoal,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await contentService.generateContentForIntent(intent)
        
        // Should handle long goals gracefully
        XCTAssertFalse(content.textContent.isEmpty)
        XCTAssertLessThan(content.metadata.wordCount, 250) // Should still respect limits
        
        // Should reference key elements from the long goal
        let keyTerms = ["morning", "routine", "meditation", "exercise"]
        let referencesGoal = keyTerms.contains { term in
            content.textContent.localizedCaseInsensitiveContains(term)
        }
        XCTAssertTrue(referencesGoal, "Content should reference elements from long goal")
    }
    
    func testSpecialCharactersInGoal() async throws {
        let intent = Intent.quickIntent(
            goal: "Practice coding: algorithms & data structures (30 min)",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await contentService.generateContentForIntent(intent)
        
        // Should handle special characters gracefully
        XCTAssertFalse(content.textContent.isEmpty)
        XCTAssertTrue(content.textContent.localizedCaseInsensitiveContains("coding") ||
                     content.textContent.localizedCaseInsensitiveContains("algorithms") ||
                     content.textContent.localizedCaseInsensitiveContains("practice"))
    }
    
    // MARK: - Performance Tests
    func testContentGenerationPerformance() async throws {
        let intent = Intent.quickIntent(
            goal: "Complete morning workout",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        measure {
            Task {
                do {
                    _ = try await contentService.generateContentForIntent(intent)
                } catch {
                    XCTFail("Generation should not fail: \(error)")
                }
            }
        }
    }
    
    func testMultipleIntentGeneration() async throws {
        let intents = (1...10).map { index in
            Intent.quickIntent(
                goal: "Performance test goal \(index)",
                scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
            )
        }
        
        let startTime = Date()
        
        for intent in intents {
            let content = try await contentService.generateContentForIntent(intent)
            XCTAssertFalse(content.textContent.isEmpty)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(totalTime, 30, "Should generate 10 intents in under 30 seconds")
    }
}

// MARK: - Enhanced Mock Service for Quality Testing
extension MockGrok4Service {
    var enableRealisticContent: Bool {
        get { return _enableRealisticContent }
        set { _enableRealisticContent = newValue }
    }
    
    private var _enableRealisticContent = false
    
    override func generateContentForIntent(_ intent: Intent) async throws -> String {
        if enableRealisticContent {
            return generateRealisticContent(for: intent)
        } else {
            return try await super.generateContentForIntent(intent)
        }
    }
    
    private func generateRealisticContent(for intent: Intent) -> String {
        let toneStyle = getToneStyleForTesting(intent.tone)
        let goal = intent.userGoal.lowercased()
        let context = intent.context
        
        var content = "\(toneStyle) "
        
        // Add weather context if available
        if let weather = context.weather, !weather.isEmpty {
            content += "The \(weather) weather creates perfect conditions for your goal. "
        }
        
        // Add goal-specific content
        if goal.contains("exercise") || goal.contains("workout") || goal.contains("run") {
            content += "Your body is ready to move and become stronger. Physical activity will energize your entire day. "
        } else if goal.contains("read") || goal.contains("study") || goal.contains("learn") {
            content += "Your mind is sharp and ready to absorb new knowledge. Learning expands your horizons. "
        } else if goal.contains("meditate") || goal.contains("mindful") || goal.contains("peaceful") {
            content += "Inner peace and clarity await you. Take time to center yourself and find balance. "
        } else if goal.contains("clean") || goal.contains("organize") || goal.contains("tidy") {
            content += "A clean space creates a clear mind. Organization brings peace and productivity. "
        } else {
            content += "Today is the perfect day to focus on \(intent.userGoal). You have everything within you to succeed. "
        }
        
        // Add custom note if available
        if let note = context.customNote, !note.isEmpty {
            content += "Remember: \(note). "
        }
        
        // Add call to action based on tone
        switch intent.tone {
        case .gentle:
            content += "Take a deep breath, trust in yourself, and gently begin this meaningful journey."
        case .energetic:
            content += "Let's go! Your energy is contagious and your determination unstoppable!"
        case .toughLove:
            content += "No more excuses. The time is now. Take action and make it happen."
        case .storyteller:
            content += "Your story continues today with this new chapter of growth and achievement."
        }
        
        return content
    }
    
    private func getToneStyleForTesting(_ tone: AlarmTone) -> String {
        switch tone {
        case .gentle:
            return "Good morning, beautiful soul."
        case .energetic:
            return "Rise and shine, champion!"
        case .toughLove:
            return "Time to get serious about your goals."
        case .storyteller:
            return "Once upon a time, on a morning just like this..."
        }
    }
}
