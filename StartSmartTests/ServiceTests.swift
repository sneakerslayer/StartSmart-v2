import XCTest
@testable import StartSmart

final class ServiceTests: XCTestCase {
    
    // MARK: - Grok4 Service Tests
    func testGrok4ServiceInitialization() {
        let service = Grok4Service(apiKey: "test_key")
        XCTAssertNotNil(service)
    }
    
    func testGrok4PromptBuilding() async throws {
        let service = MockGrok4Service()
        
        let result = try await service.generateMotivationalScript(
            userIntent: "Exercise for 30 minutes",
            tone: "energetic",
            context: [
                "weather": "sunny",
                "timeOfDay": "morning",
                "dayOfWeek": "Monday"
            ]
        )
        
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.count > 50) // Should be substantial content
        XCTAssertTrue(result.count < 500) // But not too long
    }
    
    // MARK: - ElevenLabs Service Tests
    func testElevenLabsServiceInitialization() {
        let service = ElevenLabsService(apiKey: "test_key")
        XCTAssertNotNil(service)
    }
    
    func testVoiceIdMapping() {
        let service = ElevenLabsService(apiKey: "test_key")
        
        let gentleVoice = service.getVoiceId(for: "gentle")
        let energeticVoice = service.getVoiceId(for: "energetic")
        let toughLoveVoice = service.getVoiceId(for: "tough love")
        
        XCTAssertNotEqual(gentleVoice, energeticVoice)
        XCTAssertNotEqual(energeticVoice, toughLoveVoice)
        XCTAssertFalse(gentleVoice.isEmpty)
    }
    
    // MARK: - Dependency Container Tests
    func testDependencyContainerRegistration() {
        let container = DependencyContainer.shared
        
        // Test that services are registered
        let grok4Service: Grok4ServiceProtocol = container.resolve()
        let elevenLabsService: ElevenLabsServiceProtocol = container.resolve()
        let contentService: ContentGenerationServiceProtocol = container.resolve()
        
        XCTAssertNotNil(grok4Service)
        XCTAssertNotNil(elevenLabsService)
        XCTAssertNotNil(contentService)
    }
    
    // MARK: - Service Configuration Tests
    func testServiceConfigurationValidation() {
        let issues = ServiceConfiguration.validateConfiguration()
        
        // In test environment, we expect API keys to be missing
        XCTAssertTrue(issues.contains { $0.contains("Grok4") })
        XCTAssertTrue(issues.contains { $0.contains("ElevenLabs") })
    }
    
    func testServiceConfigurationDebugInfo() {
        let debugInfo = ServiceConfiguration.debugInfo()
        
        XCTAssertNotNil(debugInfo["grok4_configured"])
        XCTAssertNotNil(debugInfo["elevenlabs_configured"])
        XCTAssertNotNil(debugInfo["max_tokens"])
        XCTAssertEqual(debugInfo["max_tokens"] as? Int, 200)
    }
    
    // MARK: - Content Generation Integration Tests
    func testContentGenerationService() async throws {
        let mockAI = MockGrok4Service()
        let mockTTS = MockElevenLabsService()
        let contentService = ContentGenerationService(aiService: mockAI, ttsService: mockTTS)
        
        let content = try await contentService.generateAlarmContent(
            userIntent: "Go for a run",
            tone: "energetic",
            context: ["weather": "sunny", "timeOfDay": "morning"]
        )
        
        XCTAssertFalse(content.text.isEmpty)
        XCTAssertGreaterThan(content.audioData.count, 0)
        XCTAssertEqual(content.metadata.tone, "energetic")
        XCTAssertGreaterThan(content.metadata.wordCount, 0)
    }
}

// MARK: - Mock Services for Testing
class MockGrok4Service: Grok4ServiceProtocol {
    func generateMotivationalScript(userIntent: String, tone: String, context: [String: String]) async throws -> String {
        return "Good morning! Today is the perfect day to \(userIntent). The \(context["weather"] ?? "weather") looks great, so let's get out there and make it happen! You've got this!"
    }
}

class MockElevenLabsService: ElevenLabsServiceProtocol {
    func generateSpeech(text: String, voiceId: String) async throws -> Data {
        // Return some mock audio data
        return "mock_audio_data".data(using: .utf8) ?? Data()
    }
    
    func getAvailableVoices() async throws -> [Voice] {
        return [
            Voice(voiceId: "voice1", name: "Test Voice", category: "test", description: "A test voice")
        ]
    }
}
