import XCTest
import AVFoundation
@testable import StartSmart

final class ElevenLabsServiceTests: XCTestCase {
    
    var service: ElevenLabsService!
    var mockService: MockElevenLabsService!
    
    override func setUp() {
        super.setUp()
        service = ElevenLabsService(apiKey: "test_api_key")
        mockService = MockElevenLabsService()
    }
    
    override func tearDown() {
        service = nil
        mockService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testServiceInitialization() {
        XCTAssertNotNil(service)
        
        let serviceWithEmptyKey = ElevenLabsService(apiKey: "")
        XCTAssertNotNil(serviceWithEmptyKey)
    }
    
    // MARK: - Voice Configuration Tests
    
    func testVoiceConfigurations() {
        let configurations = ElevenLabsService.voiceConfigurations
        
        XCTAssertEqual(configurations.count, 5) // gentle, energetic, tough_love, storyteller, default
        
        // Test gentle voice configuration
        let gentleConfig = configurations["gentle"]
        XCTAssertNotNil(gentleConfig)
        XCTAssertEqual(gentleConfig?.voiceId, "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(gentleConfig?.settings.stability, 0.75)
        XCTAssertEqual(gentleConfig?.settings.similarityBoost, 0.75)
        XCTAssertEqual(gentleConfig?.settings.style, 0.4)
        XCTAssertTrue(gentleConfig?.settings.useSpeakerBoost ?? false)
        
        // Test energetic voice configuration
        let energeticConfig = configurations["energetic"]
        XCTAssertNotNil(energeticConfig)
        XCTAssertEqual(energeticConfig?.voiceId, "pNInz6obpgDQGcFmaJgB")
        XCTAssertEqual(energeticConfig?.settings.stability, 0.5)
        XCTAssertEqual(energeticConfig?.settings.similarityBoost, 0.8)
        XCTAssertEqual(energeticConfig?.settings.style, 0.8)
        
        // Test tough love voice configuration
        let toughLoveConfig = configurations["tough_love"]
        XCTAssertNotNil(toughLoveConfig)
        XCTAssertEqual(toughLoveConfig?.voiceId, "VR6AewLTigWG4xSOukaG")
        XCTAssertEqual(toughLoveConfig?.settings.stability, 0.8)
        XCTAssertEqual(toughLoveConfig?.settings.similarityBoost, 0.9)
        
        // Test storyteller voice configuration
        let storytellerConfig = configurations["storyteller"]
        XCTAssertNotNil(storytellerConfig)
        XCTAssertEqual(storytellerConfig?.voiceId, "CYw3kZ02Hs0563khs1Fj")
        XCTAssertEqual(storytellerConfig?.settings.stability, 0.7)
        XCTAssertEqual(storytellerConfig?.settings.style, 0.5)
        
        // Test default configuration
        let defaultConfig = configurations["default"]
        XCTAssertNotNil(defaultConfig)
        XCTAssertEqual(defaultConfig?.voiceId, "21m00Tcm4TlvDq8ikWAM")
    }
    
    func testVoiceIdMapping() {
        // Test exact tone matches
        XCTAssertEqual(service.getVoiceId(for: "gentle"), "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(service.getVoiceId(for: "energetic"), "pNInz6obpgDQGcFmaJgB")
        XCTAssertEqual(service.getVoiceId(for: "tough_love"), "VR6AewLTigWG4xSOukaG")
        XCTAssertEqual(service.getVoiceId(for: "storyteller"), "CYw3kZ02Hs0563khs1Fj")
        
        // Test case insensitive matching
        XCTAssertEqual(service.getVoiceId(for: "GENTLE"), "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(service.getVoiceId(for: "Energetic"), "pNInz6obpgDQGcFmaJgB")
        
        // Test space handling
        XCTAssertEqual(service.getVoiceId(for: "tough love"), "VR6AewLTigWG4xSOukaG")
        XCTAssertEqual(service.getVoiceId(for: "Tough Love"), "VR6AewLTigWG4xSOukaG")
        
        // Test fallback to default for unknown tones
        XCTAssertEqual(service.getVoiceId(for: "unknown_tone"), "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(service.getVoiceId(for: ""), "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(service.getVoiceId(for: "random"), "21m00Tcm4TlvDq8ikWAM")
    }
    
    // MARK: - Mock Service Tests
    
    func testMockSpeechGeneration() async throws {
        let text = "Good morning! Today is a great day to achieve your goals!"
        let voiceId = "test_voice_id"
        
        let audioData = try await mockService.generateSpeech(text: text, voiceId: voiceId)
        
        XCTAssertGreaterThan(audioData.count, 0)
        
        // Mock service returns specific test data
        let mockString = String(data: audioData, encoding: .utf8)
        XCTAssertNotNil(mockString)
        XCTAssertTrue(mockString?.contains("mock_audio_data") ?? false)
    }
    
    func testMockVoiceRetrieval() async throws {
        let voices = try await mockService.getAvailableVoices()
        
        XCTAssertGreaterThan(voices.count, 0)
        XCTAssertEqual(voices.first?.voiceId, "voice1")
        XCTAssertEqual(voices.first?.name, "Test Voice")
        XCTAssertEqual(voices.first?.category, "test")
    }
    
    // MARK: - Error Handling Tests
    
    func testElevenLabsErrors() {
        let invalidURLError = ElevenLabsError.invalidURL
        XCTAssertEqual(invalidURLError.errorDescription, "Invalid ElevenLabs API URL")
        
        let invalidResponseError = ElevenLabsError.invalidResponse
        XCTAssertEqual(invalidResponseError.errorDescription, "Invalid response from ElevenLabs server")
        
        let apiError = ElevenLabsError.apiError(statusCode: 401, message: "Unauthorized")
        XCTAssertEqual(apiError.errorDescription, "ElevenLabs API Error 401: Unauthorized")
        
        let decodingError = ElevenLabsError.decodingError(NSError(domain: "test", code: 0))
        XCTAssertTrue(decodingError.errorDescription?.contains("Failed to decode") ?? false)
    }
    
    // MARK: - Request Building Tests
    
    func testElevenLabsRequestEncoding() throws {
        let voiceSettings = VoiceSettings(
            stability: 0.75,
            similarityBoost: 0.8,
            style: 0.5,
            useSpeakerBoost: true
        )
        
        let request = ElevenLabsRequest(
            text: "Test speech content",
            modelId: "eleven_monolingual_v1",
            voiceSettings: voiceSettings
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        XCTAssertGreaterThan(data.count, 0)
        
        // Test decoding to verify structure
        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(ElevenLabsRequest.self, from: data)
        
        XCTAssertEqual(decodedRequest.text, "Test speech content")
        XCTAssertEqual(decodedRequest.modelId, "eleven_monolingual_v1")
        XCTAssertEqual(decodedRequest.voiceSettings.stability, 0.75)
        XCTAssertEqual(decodedRequest.voiceSettings.similarityBoost, 0.8)
        XCTAssertEqual(decodedRequest.voiceSettings.style, 0.5)
        XCTAssertTrue(decodedRequest.voiceSettings.useSpeakerBoost)
    }
    
    func testVoiceEncoding() throws {
        let voice = Voice(
            voiceId: "test_voice_123",
            name: "Test Voice",
            category: "generated",
            description: "A test voice for unit testing"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(voice)
        XCTAssertGreaterThan(data.count, 0)
        
        let decoder = JSONDecoder()
        let decodedVoice = try decoder.decode(Voice.self, from: data)
        
        XCTAssertEqual(decodedVoice.voiceId, "test_voice_123")
        XCTAssertEqual(decodedVoice.name, "Test Voice")
        XCTAssertEqual(decodedVoice.category, "generated")
        XCTAssertEqual(decodedVoice.description, "A test voice for unit testing")
        XCTAssertEqual(decodedVoice.id, "test_voice_123") // Test computed property
    }
    
    // MARK: - Voice Settings Optimization Tests
    
    func testVoiceSettingsForTones() {
        let gentleSettings = ElevenLabsService.voiceConfigurations["gentle"]?.settings
        XCTAssertNotNil(gentleSettings)
        XCTAssertLessThanOrEqual(gentleSettings?.stability ?? 0, 0.8) // Gentle should be stable
        XCTAssertLessThanOrEqual(gentleSettings?.style ?? 0, 0.5) // Low style intensity
        
        let energeticSettings = ElevenLabsService.voiceConfigurations["energetic"]?.settings
        XCTAssertNotNil(energeticSettings)
        XCTAssertGreaterThanOrEqual(energeticSettings?.style ?? 0, 0.7) // High style for energy
        XCTAssertLessThanOrEqual(energeticSettings?.stability ?? 1, 0.6) // Less stable for variation
        
        let toughLoveSettings = ElevenLabsService.voiceConfigurations["tough_love"]?.settings
        XCTAssertNotNil(toughLoveSettings)
        XCTAssertGreaterThanOrEqual(toughLoveSettings?.stability ?? 0, 0.7) // Stable and authoritative
        XCTAssertGreaterThanOrEqual(toughLoveSettings?.similarityBoost ?? 0, 0.8) // High similarity
        
        let storytellerSettings = ElevenLabsService.voiceConfigurations["storyteller"]?.settings
        XCTAssertNotNil(storytellerSettings)
        XCTAssertGreaterThanOrEqual(storytellerSettings?.stability ?? 0, 0.6) // Reasonably stable
        XCTAssertLessThanOrEqual(storytellerSettings?.style ?? 1, 0.6) // Moderate style
    }
    
    // MARK: - Integration Readiness Tests
    
    func testVoiceConfigurationCompleteness() {
        let requiredTones = ["gentle", "energetic", "tough_love", "storyteller"]
        
        for tone in requiredTones {
            let config = ElevenLabsService.voiceConfigurations[tone]
            XCTAssertNotNil(config, "Missing configuration for tone: \(tone)")
            
            // Validate voice ID is not empty
            XCTAssertFalse(config?.voiceId.isEmpty ?? true, "Empty voice ID for tone: \(tone)")
            
            // Validate voice settings are within reasonable ranges
            let settings = config?.settings
            XCTAssertNotNil(settings, "Missing voice settings for tone: \(tone)")
            XCTAssertGreaterThanOrEqual(settings?.stability ?? -1, 0.0)
            XCTAssertLessThanOrEqual(settings?.stability ?? 2, 1.0)
            XCTAssertGreaterThanOrEqual(settings?.similarityBoost ?? -1, 0.0)
            XCTAssertLessThanOrEqual(settings?.similarityBoost ?? 2, 1.0)
            XCTAssertGreaterThanOrEqual(settings?.style ?? -1, 0.0)
            XCTAssertLessThanOrEqual(settings?.style ?? 2, 1.0)
        }
    }
    
    // MARK: - Audio Quality and Options Tests
    
    func testTTSGenerationOptions() {
        let defaultOptions = TTSGenerationOptions.default
        XCTAssertEqual(defaultOptions.audioQuality.sampleRate, 22050)
        XCTAssertEqual(defaultOptions.audioQuality.bitrate, 128)
        XCTAssertEqual(defaultOptions.audioQuality.format, .mp3)
        XCTAssertTrue(defaultOptions.enableOptimizations)
        XCTAssertEqual(defaultOptions.timeoutInterval, 30.0)
        XCTAssertEqual(defaultOptions.maxRetries, 3)
        
        let productionOptions = TTSGenerationOptions.production
        XCTAssertEqual(productionOptions.audioQuality.sampleRate, 44100)
        XCTAssertEqual(productionOptions.audioQuality.bitrate, 256)
        XCTAssertEqual(productionOptions.timeoutInterval, 45.0)
        XCTAssertEqual(productionOptions.maxRetries, 5)
    }
    
    func testAudioQualitySettings() {
        let standard = AudioQualitySettings.standard
        XCTAssertEqual(standard.sampleRate, 22050)
        XCTAssertEqual(standard.bitrate, 128)
        XCTAssertEqual(standard.format, .mp3)
        
        let high = AudioQualitySettings.high
        XCTAssertEqual(high.sampleRate, 44100)
        XCTAssertEqual(high.bitrate, 256)
        
        let premium = AudioQualitySettings.premium
        XCTAssertEqual(premium.sampleRate, 48000)
        XCTAssertEqual(premium.bitrate, 320)
    }
    
    func testAudioFormatOptions() {
        XCTAssertEqual(AudioFormat.mp3.rawValue, "audio/mpeg")
        XCTAssertEqual(AudioFormat.wav.rawValue, "audio/wav")
        XCTAssertEqual(AudioFormat.flac.rawValue, "audio/flac")
        
        let allFormats = AudioFormat.allCases
        XCTAssertEqual(allFormats.count, 3)
        XCTAssertTrue(allFormats.contains(.mp3))
        XCTAssertTrue(allFormats.contains(.wav))
        XCTAssertTrue(allFormats.contains(.flac))
    }
    
    // MARK: - Audio Validation Tests
    
    func testAudioValidationWithValidMP3() async throws {
        // Generate mock MP3 data through the public interface
        let mockMP3Data = try await mockService.generateSpeech(text: "test", voiceId: "test")
        let result = try service.validateAudioData(mockMP3Data)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.format, .mp3)
        XCTAssertNotNil(result.estimatedDuration)
        XCTAssertGreaterThan(result.fileSize, 0)
        XCTAssertNil(result.errorMessage)
    }
    
    func testAudioValidationWithEmptyData() throws {
        let emptyData = Data()
        let result = try service.validateAudioData(emptyData)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Audio data is empty")
    }
    
    func testAudioValidationWithSmallData() throws {
        let smallData = Data([0x01, 0x02, 0x03]) // Too small for valid audio
        let result = try service.validateAudioData(smallData)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Audio data too small")
    }
    
    func testAudioValidationWithLargeUnknownFormat() throws {
        let largeData = Data(repeating: 0x41, count: 2000) // Large data but unknown format
        let result = try service.validateAudioData(largeData)
        
        XCTAssertTrue(result.isValid) // Should assume valid if large enough
        XCTAssertEqual(result.format, .mp3) // Default assumption
        XCTAssertEqual(result.fileSize, 2000)
    }
    
    // MARK: - Enhanced Generation Tests with Options
    
    func testSpeechGenerationWithOptions() async throws {
        let customOptions = TTSGenerationOptions(
            audioQuality: .high,
            enableOptimizations: false,
            timeoutInterval: 60.0,
            maxRetries: 2
        )
        
        let audioData = try await mockService.generateSpeech(
            text: "Test speech with custom options",
            voiceId: "test_voice",
            options: customOptions
        )
        
        XCTAssertGreaterThan(audioData.count, 0)
        
        // Validate the generated audio
        let validation = try mockService.validateAudioData(audioData)
        XCTAssertTrue(validation.isValid)
    }
    
    func testSpeechGenerationInputValidation() async {
        // Test empty text
        do {
            let _ = try await service.generateSpeech(text: "", voiceId: "test")
            XCTFail("Should throw error for empty text")
        } catch let error as ElevenLabsError {
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("empty"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Test text that's too long
        let longText = String(repeating: "a", count: 6000)
        do {
            let _ = try await service.generateSpeech(text: longText, voiceId: "test")
            XCTFail("Should throw error for text that's too long")
        } catch let error as ElevenLabsError {
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("exceeds"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testEnhancedErrorMessages() {
        let invalidInputError = ElevenLabsError.invalidInput("Test input error")
        XCTAssertEqual(invalidInputError.errorDescription, "Invalid input: Test input error")
        XCTAssertEqual(invalidInputError.recoverySuggestion, "Please check your input text and try again.")
        
        let invalidAudioError = ElevenLabsError.invalidAudioData("Corrupted audio")
        XCTAssertEqual(invalidAudioError.errorDescription, "Invalid audio data: Corrupted audio")
        XCTAssertEqual(invalidAudioError.recoverySuggestion, "The generated audio data is corrupted. Please try again.")
        
        let rateLimitError = ElevenLabsError.rateLimitExceeded
        XCTAssertEqual(rateLimitError.errorDescription, "Rate limit exceeded. Please try again later.")
        XCTAssertEqual(rateLimitError.recoverySuggestion, "Wait for a few minutes before making more requests.")
        
        let quotaError = ElevenLabsError.quotaExceeded
        XCTAssertEqual(quotaError.errorDescription, "Monthly quota exceeded. Please upgrade your plan.")
        XCTAssertEqual(quotaError.recoverySuggestion, "Upgrade your ElevenLabs plan to continue using the service.")
    }
    
    func testAPIErrorRecoverySuggestions() {
        let unauthorizedError = ElevenLabsError.apiError(statusCode: 401, message: "Unauthorized")
        XCTAssertEqual(unauthorizedError.recoverySuggestion, "Please check your API key.")
        
        let rateLimitAPIError = ElevenLabsError.apiError(statusCode: 429, message: "Too Many Requests")
        XCTAssertEqual(rateLimitAPIError.recoverySuggestion, "You've exceeded the rate limit. Please wait before trying again.")
        
        let serverError = ElevenLabsError.apiError(statusCode: 500, message: "Internal Server Error")
        XCTAssertEqual(serverError.recoverySuggestion, "ElevenLabs is experiencing issues. Please try again later.")
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentVoiceIdLookup() {
        let expectation = XCTestExpectation(description: "Concurrent voice ID lookup")
        expectation.expectedFulfillmentCount = 100
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        for i in 0..<100 {
            queue.async {
                let tone = ["gentle", "energetic", "tough_love", "storyteller"][i % 4]
                let voiceId = self.service.getVoiceId(for: tone)
                XCTAssertFalse(voiceId.isEmpty)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testVoiceConfigurationMemoryEfficiency() {
        // Test that voice configurations are efficiently stored and accessed
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<1000 {
            let _ = ElevenLabsService.voiceConfigurations["gentle"]
            let _ = ElevenLabsService.voiceConfigurations["energetic"]
            let _ = ElevenLabsService.voiceConfigurations["tough_love"]
            let _ = ElevenLabsService.voiceConfigurations["storyteller"]
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Should complete 4000 lookups in well under 0.1 seconds
        XCTAssertLessThan(executionTime, 0.1)
    }
    
    func testConcurrentSpeechGeneration() async throws {
        let expectations = (0..<5).map { i in
            XCTestExpectation(description: "Speech generation \(i)")
        }
        
        // Generate multiple speeches concurrently
        await withTaskGroup(of: Void.self) { group in
            for (index, expectation) in expectations.enumerated() {
                group.addTask {
                    do {
                        let audioData = try await self.mockService.generateSpeech(
                            text: "Concurrent test \(index)",
                            voiceId: "test_voice"
                        )
                        XCTAssertGreaterThan(audioData.count, 0)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Concurrent generation failed: \(error)")
                    }
                }
            }
        }
        
        wait(for: expectations, timeout: 10.0)
    }
}

// MARK: - Enhanced Mock Service

class MockElevenLabsService: ElevenLabsServiceProtocol {
    var shouldReturnError = false
    var customErrorToReturn: Error?
    var generationDelay: TimeInterval = 0.0
    var mockAudioData: Data?
    
    func generateSpeech(text: String, voiceId: String) async throws -> Data {
        return try await generateSpeech(text: text, voiceId: voiceId, options: .default)
    }
    
    func generateSpeech(text: String, voiceId: String, options: TTSGenerationOptions) async throws -> Data {
        if shouldReturnError {
            if let error = customErrorToReturn {
                throw error
            }
            throw ElevenLabsError.apiError(statusCode: 500, message: "Mock error")
        }
        
        if generationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(generationDelay * 1_000_000_000))
        }
        
        if let mockData = mockAudioData {
            return mockData
        }
        
        // Return mock MP3-like audio data for testing
        let mockContent = createMockMP3Data(for: text, voiceId: voiceId)
        return mockContent
    }
    
    func getAvailableVoices() async throws -> [Voice] {
        if shouldReturnError {
            if let error = customErrorToReturn {
                throw error
            }
            throw ElevenLabsError.apiError(statusCode: 500, message: "Mock error")
        }
        
        return [
            Voice(voiceId: "voice1", name: "Test Voice", category: "test", description: "A test voice"),
            Voice(voiceId: "gentle_voice", name: "Gentle Voice", category: "calm", description: "Soothing voice"),
            Voice(voiceId: "energetic_voice", name: "Energetic Voice", category: "dynamic", description: "High-energy voice"),
            Voice(voiceId: "tough_voice", name: "Tough Love Voice", category: "motivational", description: "Firm but caring"),
            Voice(voiceId: "story_voice", name: "Storyteller Voice", category: "narrative", description: "Engaging storyteller")
        ]
    }
    
    func validateAudioData(_ data: Data) throws -> AudioValidationResult {
        guard !data.isEmpty else {
            return AudioValidationResult(isValid: false, errorMessage: "Mock: Audio data is empty")
        }
        
        // Mock validation - check if it's our mock format
        if String(data: data, encoding: .utf8)?.contains("mock_mp3_data") == true {
            return AudioValidationResult(
                isValid: true,
                format: .mp3,
                estimatedDuration: 2.5, // Mock 2.5 second duration
                fileSize: data.count
            )
        }
        
        return AudioValidationResult(
            isValid: true,
            format: .mp3,
            estimatedDuration: nil,
            fileSize: data.count
        )
    }
    
    // Helper method to get voice ID (matching real service)
    func getVoiceId(for tone: String) -> String {
        let normalizedTone = tone.lowercased().replacingOccurrences(of: " ", with: "_")
        switch normalizedTone {
        case "gentle": return "gentle_voice"
        case "energetic": return "energetic_voice"
        case "tough_love": return "tough_voice"
        case "storyteller": return "story_voice"
        default: return "voice1"
        }
    }
    
    private func createMockMP3Data(for text: String, voiceId: String) -> Data {
        // Create mock MP3-like data with proper header
        var mockData = Data()
        
        // Add MP3 header signature (simplified)
        mockData.append(contentsOf: [0xFF, 0xFB, 0x90, 0x00]) // MP3 frame header
        
        // Add some mock content
        let mockContent = "mock_mp3_data_for_text_\(text.prefix(20))_voice_\(voiceId)"
        if let contentData = mockContent.data(using: .utf8) {
            mockData.append(contentData)
        }
        
        // Pad to reasonable size (at least 1KB for realistic MP3)
        while mockData.count < 1024 {
            mockData.append(contentsOf: [0x00, 0x01, 0x02, 0x03])
        }
        
        return mockData
    }
}
