import XCTest
import Combine
@testable import StartSmart

final class AudioPipelineServiceTests: XCTestCase {
    
    var pipelineService: AudioPipelineService!
    var mockAIService: MockGrok4Service!
    var mockTTSService: MockElevenLabsService!
    var mockCacheService: MockAudioCacheService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockAIService = MockGrok4Service()
        mockTTSService = MockElevenLabsService()
        mockCacheService = MockAudioCacheService()
        cancellables = Set<AnyCancellable>()
        
        await MainActor.run {
            pipelineService = AudioPipelineService(
                aiService: mockAIService,
                ttsService: mockTTSService,
                cacheService: mockCacheService
            )
        }
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        pipelineService = nil
        mockAIService = nil
        mockTTSService = nil
        mockCacheService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Pipeline Generation Tests
    
    func testGenerateAndCacheAudio() async throws {
        let intent = createTestIntent()
        
        let result = try await pipelineService.generateAndCacheAudio(forIntent: intent)
        
        XCTAssertFalse(result.audioFilePath.isEmpty)
        XCTAssertFalse(result.textContent.isEmpty)
        XCTAssertNotNil(result.duration)
        XCTAssertFalse(result.voiceId.isEmpty)
        XCTAssertFalse(result.fromCache)
        
        // Verify that all services were called
        XCTAssertTrue(mockAIService.generateCalled)
        XCTAssertTrue(mockTTSService.generateCalled)
        XCTAssertTrue(mockCacheService.cacheAudioCalled)
    }
    
    func testGetOrGenerateAudioFromCache() async throws {
        let intent = createTestIntent()
        
        // Set up cache to return a result
        mockCacheService.shouldReturnCachedResult = true
        
        let result = try await pipelineService.getOrGenerateAudio(forIntent: intent)
        
        XCTAssertTrue(result.fromCache)
        XCTAssertTrue(mockCacheService.getCachedAudioCalled)
        XCTAssertFalse(mockAIService.generateCalled) // Should not generate new content
    }
    
    func testGetOrGenerateAudioCacheMiss() async throws {
        let intent = createTestIntent()
        
        // Set up cache to return nil (cache miss)
        mockCacheService.shouldReturnCachedResult = false
        
        let result = try await pipelineService.getOrGenerateAudio(forIntent: intent)
        
        XCTAssertFalse(result.fromCache)
        XCTAssertTrue(mockCacheService.getCachedAudioCalled)
        XCTAssertTrue(mockAIService.generateCalled) // Should generate new content
        XCTAssertTrue(mockTTSService.generateCalled)
        XCTAssertTrue(mockCacheService.cacheAudioCalled)
    }
    
    func testPreGenerateAudioForNearbyAlarm() async throws {
        // Create alarm scheduled within next 24 hours
        let futureTime = Date().addingTimeInterval(3600) // 1 hour from now
        let alarm = createTestAlarm(scheduledFor: futureTime)
        
        // Should complete without throwing
        try await pipelineService.preGenerateAudio(forAlarm: alarm)
        
        // Verify generation was attempted
        XCTAssertTrue(mockCacheService.getCachedAudioCalled)
    }
    
    func testPreGenerateAudioForDistantAlarm() async throws {
        // Create alarm scheduled more than 24 hours away
        let distantTime = Date().addingTimeInterval(48 * 3600) // 48 hours from now
        let alarm = createTestAlarm(scheduledFor: distantTime)
        
        // Should complete without attempting generation
        try await pipelineService.preGenerateAudio(forAlarm: alarm)
        
        // Verify generation was not attempted
        XCTAssertFalse(mockCacheService.getCachedAudioCalled)
    }
    
    // MARK: - Error Handling Tests
    
    func testGenerationFailureFromAIService() async {
        let intent = createTestIntent()
        
        // Set up AI service to fail
        mockAIService.shouldFail = true
        
        do {
            _ = try await pipelineService.generateAndCacheAudio(forIntent: intent)
            XCTFail("Should have thrown an error")
        } catch let error as AudioPipelineError {
            if case .generationFailed = error {
                // Expected error type
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        await MainActor.run {
            if case .failed = pipelineService.generationStatus {
                // Expected status
            } else {
                XCTFail("Expected failed status")
            }
        }
    }
    
    func testGenerationFailureFromTTSService() async {
        let intent = createTestIntent()
        
        // Set up TTS service to fail
        mockTTSService.shouldFail = true
        
        do {
            _ = try await pipelineService.generateAndCacheAudio(forIntent: intent)
            XCTFail("Should have thrown an error")
        } catch let error as AudioPipelineError {
            if case .generationFailed = error {
                // Expected error type
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testGenerationFailureFromCacheService() async {
        let intent = createTestIntent()
        
        // Set up cache service to fail
        mockCacheService.shouldFailCaching = true
        
        do {
            _ = try await pipelineService.generateAndCacheAudio(forIntent: intent)
            XCTFail("Should have thrown an error")
        } catch let error as AudioPipelineError {
            if case .generationFailed = error {
                // Expected error type
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Status Tracking Tests
    
    func testGenerationStatusProgression() async throws {
        let intent = createTestIntent()
        
        let statusExpectation = XCTestExpectation(description: "Status progression")
        var receivedStatuses: [AudioGenerationStatus] = []
        
        await MainActor.run {
            pipelineService.$generationStatus
                .sink { status in
                    receivedStatuses.append(status)
                    if case .completed = status {
                        statusExpectation.fulfill()
                    }
                }
                .store(in: &cancellables)
        }
        
        _ = try await pipelineService.generateAndCacheAudio(forIntent: intent)
        
        await fulfillment(of: [statusExpectation], timeout: 5.0)
        
        // Verify status progression
        XCTAssertTrue(receivedStatuses.contains { if case .idle = $0 { return true }; return false })
        XCTAssertTrue(receivedStatuses.contains { if case .generatingText = $0 { return true }; return false })
        XCTAssertTrue(receivedStatuses.contains { if case .convertingToSpeech = $0 { return true }; return false })
        XCTAssertTrue(receivedStatuses.contains { if case .caching = $0 { return true }; return false })
        XCTAssertTrue(receivedStatuses.contains { if case .completed = $0 { return true }; return false })
    }
    
    // MARK: - Statistics Tests
    
    func testPipelineStatisticsUpdating() async throws {
        let intent = createTestIntent()
        
        // Initial statistics should be empty
        let initialStats = await pipelineService.getPipelineStatistics()
        XCTAssertEqual(initialStats.totalGenerations, 0)
        XCTAssertEqual(initialStats.successfulGenerations, 0)
        
        // Generate audio
        _ = try await pipelineService.generateAndCacheAudio(forIntent: intent)
        
        // Check updated statistics
        let updatedStats = await pipelineService.getPipelineStatistics()
        XCTAssertGreaterThan(updatedStats.totalGenerations, 0)
        XCTAssertGreaterThan(updatedStats.successfulGenerations, 0)
        XCTAssertGreaterThan(updatedStats.averageGenerationTime, 0)
    }
    
    func testCacheHitRateTracking() async throws {
        let intent = createTestIntent()
        
        // First call should be cache miss and generation
        mockCacheService.shouldReturnCachedResult = false
        _ = try await pipelineService.getOrGenerateAudio(forIntent: intent)
        
        // Second call should be cache hit
        mockCacheService.shouldReturnCachedResult = true
        _ = try await pipelineService.getOrGenerateAudio(forIntent: intent)
        
        let stats = await pipelineService.getPipelineStatistics()
        XCTAssertGreaterThan(stats.cacheHitRate, 0.0)
        XCTAssertLessThanOrEqual(stats.cacheHitRate, 1.0)
    }
    
    // MARK: - Voice ID Mapping Tests
    
    func testVoiceIdMappingForDifferentTones() async {
        // Test different tone mappings by checking the cache metadata
        let gentleIntent = createTestIntent(tone: "gentle")
        let energeticIntent = createTestIntent(tone: "energetic")
        let toughIntent = createTestIntent(tone: "tough_love")
        let storytellerIntent = createTestIntent(tone: "storyteller")
        
        _ = try await pipelineService.generateAndCacheAudio(forIntent: gentleIntent)
        _ = try await pipelineService.generateAndCacheAudio(forIntent: energeticIntent)
        _ = try await pipelineService.generateAndCacheAudio(forIntent: toughIntent)
        _ = try await pipelineService.generateAndCacheAudio(forIntent: storytellerIntent)
        
        // Verify that different voice IDs were used (through mock service tracking)
        XCTAssertEqual(mockTTSService.lastUsedVoiceIds.count, 4)
        
        // Check specific voice mappings
        XCTAssertTrue(mockTTSService.lastUsedVoiceIds.contains("21m00Tcm4TlvDq8ikWAM")) // Rachel for gentle
        XCTAssertTrue(mockTTSService.lastUsedVoiceIds.contains("pNInz6obpgDQGcFmaJgB")) // Adam for energetic
        XCTAssertTrue(mockTTSService.lastUsedVoiceIds.contains("VR6AewLTigWG4xSOukaG")) // Arnold for tough love
        XCTAssertTrue(mockTTSService.lastUsedVoiceIds.contains("CYw3kZ02Hs0563khs1Fj")) // Dave for storyteller
    }
    
    // MARK: - Cache Key Generation Tests
    
    func testCacheKeyUniqueness() async throws {
        let intent1 = createTestIntent(description: "Go for a run")
        let intent2 = createTestIntent(description: "Study for exam")
        let intent3 = createTestIntent(description: "Go for a run", tone: "energetic")
        
        // Generate audio for different intents
        _ = try await pipelineService.generateAndCacheAudio(forIntent: intent1)
        _ = try await pipelineService.generateAndCacheAudio(forIntent: intent2)
        _ = try await pipelineService.generateAndCacheAudio(forIntent: intent3)
        
        // Verify that different cache keys were used
        XCTAssertEqual(mockCacheService.usedCacheKeys.count, 3)
        XCTAssertEqual(Set(mockCacheService.usedCacheKeys).count, 3) // All unique
    }
    
    // MARK: - Context Generation Tests
    
    func testContextDictionaryGeneration() async throws {
        let intent = createTestIntent()
        
        _ = try await pipelineService.generateAndCacheAudio(forIntent: intent)
        
        // Verify that context was passed to AI service
        XCTAssertTrue(mockAIService.generateCalled)
        XCTAssertNotNil(mockAIService.lastUsedContext)
        XCTAssertFalse(mockAIService.lastUsedContext!.isEmpty)
        
        // Check for expected context keys
        let context = mockAIService.lastUsedContext!
        XCTAssertNotNil(context["current_time"])
        XCTAssertNotNil(context["day_of_week"])
        XCTAssertNotNil(context["motivation_level"])
        XCTAssertNotNil(context["intent_category"])
    }
    
    // MARK: - Maintenance Tests
    
    func testClearExpiredAudio() async throws {
        try await pipelineService.clearExpiredAudio()
        
        XCTAssertTrue(mockCacheService.performMaintenanceCalled)
    }
    
    // MARK: - Error Description Tests
    
    func testAudioPipelineErrorDescriptions() {
        let testError = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        let generationError = AudioPipelineError.generationFailed(testError)
        XCTAssertTrue(generationError.errorDescription?.contains("Audio generation failed") ?? false)
        XCTAssertTrue(generationError.recoverySuggestion?.contains("internet connection") ?? false)
        
        let invalidIntentError = AudioPipelineError.invalidIntent
        XCTAssertTrue(invalidIntentError.errorDescription?.contains("Invalid intent") ?? false)
        
        let ttsError = AudioPipelineError.ttsConversionFailed(testError)
        XCTAssertTrue(ttsError.errorDescription?.contains("Text-to-speech") ?? false)
        
        let cachingError = AudioPipelineError.cachingFailed(testError)
        XCTAssertTrue(cachingError.errorDescription?.contains("caching failed") ?? false)
        
        let notFoundError = AudioPipelineError.audioNotFound
        XCTAssertTrue(notFoundError.errorDescription?.contains("not found") ?? false)
    }
    
    // MARK: - Helper Methods
    
    private func createTestIntent(
        description: String = "Test intent description",
        tone: String = "gentle"
    ) -> Intent {
        return Intent(
            description: description,
            category: .general,
            motivationLevel: .medium,
            preferredTone: tone,
            targetTime: Date(),
            customPrompts: ["Be positive", "Be encouraging"]
        )
    }
    
    private func createTestAlarm(scheduledFor date: Date) -> Alarm {
        return Alarm(
            time: date,
            label: "Test Alarm",
            sound: .default,
            isEnabled: true,
            repeatDays: []
        )
    }
}

// MARK: - Mock Services

class MockAudioCacheService: AudioCacheServiceProtocol {
    var cacheAudioCalled = false
    var getCachedAudioCalled = false
    var performMaintenanceCalled = false
    var shouldReturnCachedResult = false
    var shouldFailCaching = false
    var usedCacheKeys: [String] = []
    
    func cacheAudio(data: Data, forKey key: String, metadata: SimpleAudioMetadata) async throws -> String {
        cacheAudioCalled = true
        usedCacheKeys.append(key)
        
        if shouldFailCaching {
            throw AudioCacheError.cacheLimitExceeded
        }
        
        return "/mock/path/\(key).mp3"
    }
    
    func getCachedAudio(forKey key: String) async throws -> CachedAudioResult? {
        getCachedAudioCalled = true
        
        if shouldReturnCachedResult {
            let metadata = SimpleAudioMetadata(
                intentId: "test-intent",
                voiceId: "test-voice",
                duration: 5.0
            )
            let item = SimpleCachedAudioItem(
                filePath: "/mock/cached/\(key).mp3",
                sizeKB: 100.0,
                duration: 5.0,
                createdAt: Date(),
                intentId: "test-intent",
                voiceId: "test-voice",
                format: "mp3",
                quality: "high"
            )
            return CachedAudioResult(
                filePath: "/mock/cached/\(key).mp3",
                metadata: metadata,
                item: item,
                isValid: true
            )
        }
        
        return nil
    }
    
    func removeCachedAudio(forKey key: String) async throws {
        // Mock implementation
    }
    
    func clearCache() async throws {
        // Mock implementation
    }
    
    func getCacheStatistics() async -> AudioCacheStatistics {
        return AudioCacheStatistics(
            totalItems: 5,
            totalSizeMB: 10.0,
            oldestItemDate: Date(),
            newestItemDate: Date(),
            averageFileSizeKB: 200.0,
            expiredItemsCount: 0,
            availableStorageGB: 50.0,
            cacheHitRate: 0.8
        )
    }
    
    func performMaintenance() async throws {
        performMaintenanceCalled = true
    }
}

// Enhanced Mock Services with tracking
extension MockGrok4Service {
    var generateCalled = false
    var shouldFail = false
    var lastUsedContext: [String: String]?
    
    func generateMotivationalScript(userIntent: String, tone: String, context: [String: String]) async throws -> String {
        generateCalled = true
        lastUsedContext = context
        
        if shouldFail {
            throw NSError(domain: "MockAIError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mock AI generation failed"])
        }
        
        return "Mock motivational script for \(userIntent) with \(tone) tone. Context includes \(context.keys.joined(separator: ", "))"
    }
}

extension MockElevenLabsService {
    var generateCalled = false
    var shouldFail = false
    var lastUsedVoiceIds: Set<String> = []
    
    func generateSpeech(text: String, voiceId: String) async throws -> Data {
        return try await generateSpeech(text: text, voiceId: voiceId, options: .default)
    }
    
    func generateSpeech(text: String, voiceId: String, options: TTSGenerationOptions) async throws -> Data {
        generateCalled = true
        lastUsedVoiceIds.insert(voiceId)
        
        if shouldFail {
            throw ElevenLabsError.apiError(statusCode: 500, message: "Mock TTS generation failed")
        }
        
        // Return mock MP3 data
        var mockData = Data()
        mockData.append(contentsOf: [0xFF, 0xFB, 0x90, 0x00]) // MP3 header
        mockData.append("mock_tts_audio_\(voiceId)".data(using: .utf8) ?? Data())
        
        // Pad to reasonable size
        while mockData.count < 1024 {
            mockData.append(contentsOf: [0x41, 0x42, 0x43, 0x44])
        }
        
        return mockData
    }
}
