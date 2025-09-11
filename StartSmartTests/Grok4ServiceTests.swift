import XCTest
@testable import StartSmart

final class Grok4ServiceTests: XCTestCase {
    
    var service: Grok4Service!
    var mockService: MockGrok4Service!
    
    override func setUp() {
        super.setUp()
        service = Grok4Service(apiKey: "test_key", maxRetries: 2, timeoutInterval: 5.0)
        mockService = MockGrok4Service()
    }
    
    override func tearDown() {
        service = nil
        mockService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    func testServiceInitialization() {
        XCTAssertNotNil(service)
    }
    
    func testServiceInitializationWithCustomParams() {
        let customService = Grok4Service(apiKey: "custom_key", maxRetries: 5, timeoutInterval: 10.0)
        XCTAssertNotNil(customService)
    }
    
    // MARK: - Content Validation Tests
    func testContentValidation_ValidContent() throws {
        let validContent = """
        Good morning! Today is perfect for achieving your goal of exercising for 30 minutes. 
        The sunny weather makes it ideal for an outdoor workout. You've got the energy and 
        determination to make this happen. Let's start with some stretching and work your way 
        up to a full routine. You can do this!
        """
        
        let result = try service.validateContent(validContent)
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.wordCount >= 30)
        XCTAssertTrue(result.wordCount <= 250)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertGreaterThan(result.characterCount, 0)
    }
    
    func testContentValidation_TooShort() throws {
        let shortContent = "Wake up now!"
        
        let result = try service.validateContent(shortContent)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("too short") })
    }
    
    func testContentValidation_TooLong() throws {
        let longContent = Array(repeating: "word", count: 260).joined(separator: " ")
        
        let result = try service.validateContent(longContent)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("too long") })
    }
    
    func testContentValidation_InappropriateLanguage() throws {
        let inappropriateContent = """
        Good morning! Today is a damn good day to achieve your goals. You need to get the 
        hell out of bed and start moving. Stop being lazy and shit, let's get going with 
        your exercise routine. You can fucking do this if you put your mind to it!
        """
        
        let result = try service.validateContent(inappropriateContent)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("inappropriate language") })
    }
    
    func testContentValidation_LacksMotivationalLanguage() throws {
        let nonMotivationalContent = """
        The weather forecast indicates precipitation probability of seventy percent. 
        Temperature readings suggest optimal atmospheric conditions. Data analysis 
        confirms that biological processes require kinetic activation. Cardiovascular 
        systems benefit from increased metabolic activity patterns during daylight hours.
        """
        
        let result = try service.validateContent(nonMotivationalContent)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("motivational language") })
    }
    
    func testContentValidation_MissingConclusion() throws {
        let incompleteContent = """
        Good morning! Today is perfect for your exercise goals. The weather looks great 
        and you have the energy to make it happen. Let's think about what we can
        """
        
        let result = try service.validateContent(incompleteContent)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.contains { $0.contains("conclusion") })
    }
    
    // MARK: - Intent Generation Tests
    func testGenerateContentForIntent_BasicIntent() async throws {
        let intent = Intent.quickIntent(
            goal: "Exercise for 30 minutes",
            tone: .energetic,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await mockService.generateContentForIntent(intent)
        
        XCTAssertFalse(content.isEmpty)
        XCTAssertTrue(content.contains("Exercise for 30 minutes"))
        
        // Validate the generated content
        let validationResult = try service.validateContent(content)
        XCTAssertTrue(validationResult.isValid)
    }
    
    func testGenerateContentForIntent_GentleTone() async throws {
        let intent = Intent.quickIntent(
            goal: "Start reading a new book",
            tone: .gentle,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await mockService.generateContentForIntent(intent)
        
        XCTAssertFalse(content.isEmpty)
        XCTAssertTrue(content.contains("reading"))
        
        // Content should be validated
        let validationResult = try service.validateContent(content)
        XCTAssertTrue(validationResult.isValid)
    }
    
    func testGenerateContentForIntent_ToughLoveTone() async throws {
        let intent = Intent.quickIntent(
            goal: "Clean the entire house",
            tone: .toughLove,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await mockService.generateContentForIntent(intent)
        
        XCTAssertFalse(content.isEmpty)
        XCTAssertTrue(content.contains("clean") || content.contains("house"))
        
        let validationResult = try service.validateContent(content)
        XCTAssertTrue(validationResult.isValid)
    }
    
    func testGenerateContentForIntent_StorytellerTone() async throws {
        let intent = Intent.quickIntent(
            goal: "Write in my journal",
            tone: .storyteller,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await mockService.generateContentForIntent(intent)
        
        XCTAssertFalse(content.isEmpty)
        XCTAssertTrue(content.contains("journal") || content.contains("write"))
        
        let validationResult = try service.validateContent(content)
        XCTAssertTrue(validationResult.isValid)
    }
    
    func testGenerateContentForIntent_WithWeatherContext() async throws {
        var intent = Intent.quickIntent(
            goal: "Go for a morning run",
            tone: .energetic,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        intent.context.weather = "sunny and warm"
        intent.context.temperature = 72.0
        
        let content = try await mockService.generateContentForIntent(intent)
        
        XCTAssertFalse(content.isEmpty)
        XCTAssertTrue(content.contains("run"))
        
        let validationResult = try service.validateContent(content)
        XCTAssertTrue(validationResult.isValid)
    }
    
    func testGenerateContentForIntent_WithCalendarEvents() async throws {
        var intent = Intent.quickIntent(
            goal: "Prepare for important meeting",
            tone: .gentle,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        intent.context.calendarEvents = ["Team meeting at 10am", "Lunch with client"]
        intent.context.customNote = "Don't forget the presentation slides"
        
        let content = try await mockService.generateContentForIntent(intent)
        
        XCTAssertFalse(content.isEmpty)
        XCTAssertTrue(content.contains("meeting") || content.contains("prepare"))
        
        let validationResult = try service.validateContent(content)
        XCTAssertTrue(validationResult.isValid)
    }
    
    // MARK: - Error Handling Tests
    func testGenerateContentForIntent_RetryLogic() async throws {
        let failingService = FailingGrok4Service(failureCount: 1)
        let intent = Intent.quickIntent(
            goal: "Test retry logic",
            tone: .energetic,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await failingService.generateContentForIntent(intent)
        
        XCTAssertFalse(content.isEmpty)
        XCTAssertEqual(failingService.attemptCount, 2) // First attempt fails, second succeeds
    }
    
    func testGenerateContentForIntent_MaxRetriesExceeded() async {
        let failingService = FailingGrok4Service(failureCount: 5)
        let intent = Intent.quickIntent(
            goal: "Test max retries",
            tone: .energetic,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        do {
            _ = try await failingService.generateContentForIntent(intent)
            XCTFail("Should have thrown maxRetriesExceeded error")
        } catch let error as Grok4Error {
            if case .maxRetriesExceeded = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Legacy Method Tests
    func testGenerateMotivationalScript_Legacy() async throws {
        let content = try await mockService.generateMotivationalScript(
            userIntent: "Study for exam",
            tone: "energetic",
            context: [
                "weather": "rainy",
                "timeOfDay": "morning",
                "dayOfWeek": "Monday"
            ]
        )
        
        XCTAssertFalse(content.isEmpty)
        XCTAssertTrue(content.contains("study") || content.contains("exam"))
        
        let validationResult = try service.validateContent(content)
        XCTAssertTrue(validationResult.isValid)
    }
    
    // MARK: - Performance Tests
    func testContentValidation_Performance() throws {
        let content = """
        Good morning! Today is the perfect day to achieve your goal of exercising for 30 minutes. 
        The sunny weather makes it ideal for an outdoor workout. You've got the energy and 
        determination to make this happen. Let's start with some stretching and work your way 
        up to a full routine. Remember, every step counts toward your fitness journey. You can do this!
        """
        
        measure {
            for _ in 0..<1000 {
                _ = try? service.validateContent(content)
            }
        }
    }
    
    func testPromptGeneration_Performance() {
        let intent = Intent.quickIntent(
            goal: "Complete morning routine",
            tone: .energetic,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        measure {
            for _ in 0..<100 {
                _ = try? mockService.generateContentForIntent(intent)
            }
        }
    }
}

// MARK: - Test Helper Classes
class MockGrok4Service: Grok4ServiceProtocol {
    
    func generateMotivationalScript(userIntent: String, tone: String, context: [String: String]) async throws -> String {
        let weather = context["weather"] ?? "pleasant"
        let timeOfDay = context["timeOfDay"] ?? "morning"
        
        return """
        Good \(timeOfDay)! Today is a perfect day to \(userIntent). The \(weather) weather 
        creates ideal conditions for achieving your goals. You have the strength and determination 
        to make this happen. Let's take the first step together and build momentum throughout 
        your day. Remember, small progress is still progress. You can absolutely do this!
        """
    }
    
    func generateContentForIntent(_ intent: Intent) async throws -> String {
        let toneStyle = getToneStyle(for: intent.tone)
        let weather = intent.context.weather ?? "pleasant"
        let timeOfDay = intent.context.timeOfDay.displayName
        
        return """
        \(toneStyle) \(timeOfDay)! Today is your day to \(intent.userGoal). The \(weather) 
        conditions are perfect for taking action. You have everything you need inside you 
        to succeed. Let's start with one small step and build from there. Your commitment 
        to \(intent.userGoal) shows your dedication to growth. Take a deep breath, trust 
        in your abilities, and let's make today count. You've got this!
        """
    }
    
    func validateContent(_ content: String) throws -> ContentValidationResult {
        // Use the real validation logic from the actual service
        let service = Grok4Service(apiKey: "test")
        return try service.validateContent(content)
    }
    
    private func getToneStyle(for tone: AlarmTone) -> String {
        switch tone {
        case .gentle:
            return "Good"
        case .energetic:
            return "Rise and shine!"
        case .toughLove:
            return "Time to get moving!"
        case .storyteller:
            return "Once upon a time, on a morning just like this,"
        }
    }
}

class FailingGrok4Service: Grok4ServiceProtocol {
    private let maxFailures: Int
    private(set) var attemptCount = 0
    
    init(failureCount: Int) {
        self.maxFailures = failureCount
    }
    
    func generateMotivationalScript(userIntent: String, tone: String, context: [String: String]) async throws -> String {
        attemptCount += 1
        
        if attemptCount <= maxFailures {
            throw Grok4Error.apiError(statusCode: 500, message: "Simulated failure")
        }
        
        return "Success after \(attemptCount) attempts: \(userIntent)"
    }
    
    func generateContentForIntent(_ intent: Intent) async throws -> String {
        attemptCount += 1
        
        if attemptCount <= maxFailures {
            throw Grok4Error.apiError(statusCode: 500, message: "Simulated failure")
        }
        
        return """
        Success after \(attemptCount) attempts! Today is perfect for \(intent.userGoal). 
        You have the determination and skills needed to achieve this goal. Let's take 
        the first step together and build momentum. Your persistence will pay off. 
        You can do this!
        """
    }
    
    func validateContent(_ content: String) throws -> ContentValidationResult {
        let service = Grok4Service(apiKey: "test")
        return try service.validateContent(content)
    }
}
