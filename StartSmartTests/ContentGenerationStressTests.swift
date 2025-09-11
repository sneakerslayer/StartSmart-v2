import XCTest
@testable import StartSmart

final class ContentGenerationStressTests: XCTestCase {
    
    var grok4Service: Grok4Service!
    var mockGrok4Service: MockGrok4Service!
    var contentService: ContentGenerationService!
    var contentManager: ContentGenerationManager!
    var intentRepository: MockIntentRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup both real and mock services for different test scenarios
        grok4Service = Grok4Service(apiKey: "test_key", maxRetries: 2, timeoutInterval: 5.0)
        mockGrok4Service = MockGrok4Service()
        
        let elevenLabsService = MockElevenLabsService()
        contentService = ContentGenerationService(
            aiService: mockGrok4Service,
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
        mockGrok4Service = nil
        contentService = nil
        contentManager = nil
        intentRepository = nil
        try await super.tearDown()
    }
    
    // MARK: - Rate Limiting Tests
    func testRateLimitingBehavior() async throws {
        // Configure mock to simulate rate limiting
        mockGrok4Service.simulateRateLimit = true
        mockGrok4Service.rateLimitRequests = 3
        
        let intents = (1...5).map { index in
            Intent.quickIntent(
                goal: "Rate limit test \(index)",
                scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
            )
        }
        
        var successCount = 0
        var rateLimitErrorCount = 0
        
        for intent in intents {
            do {
                _ = try await contentService.generateContentForIntent(intent)
                successCount += 1
            } catch let error as Grok4Error {
                if case .apiError(let statusCode, _) = error, statusCode == 429 {
                    rateLimitErrorCount += 1
                }
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
        
        // Should successfully process first 3, then hit rate limit
        XCTAssertEqual(successCount, 3)
        XCTAssertEqual(rateLimitErrorCount, 2)
        
        mockGrok4Service.simulateRateLimit = false
    }
    
    func testRateLimitRecovery() async throws {
        mockGrok4Service.simulateRateLimit = true
        mockGrok4Service.rateLimitRequests = 1
        
        let intent = Intent.quickIntent(
            goal: "Rate limit recovery test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        // First request should succeed
        _ = try await contentService.generateContentForIntent(intent)
        
        // Second request should hit rate limit
        do {
            _ = try await contentService.generateContentForIntent(intent)
            XCTFail("Should have hit rate limit")
        } catch let error as Grok4Error {
            if case .apiError(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 429)
            } else {
                XCTFail("Expected rate limit error, got: \(error)")
            }
        }
        
        // Reset rate limit and try again
        mockGrok4Service.resetRateLimit()
        let content = try await contentService.generateContentForIntent(intent)
        XCTAssertFalse(content.textContent.isEmpty)
        
        mockGrok4Service.simulateRateLimit = false
    }
    
    // MARK: - Network Error Scenarios
    func testNetworkTimeoutHandling() async throws {
        mockGrok4Service.simulateTimeout = true
        
        let intent = Intent.quickIntent(
            goal: "Timeout test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        do {
            _ = try await contentService.generateContentForIntent(intent)
            XCTFail("Should have timed out")
        } catch let error as Grok4Error {
            if case .timeout = error {
                XCTAssertTrue(true) // Expected timeout error
            } else {
                XCTFail("Expected timeout error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        mockGrok4Service.simulateTimeout = false
    }
    
    func testNetworkIntermittentFailures() async throws {
        mockGrok4Service.intermittentFailureRate = 0.7 // 70% failure rate
        
        let intent = Intent.quickIntent(
            goal: "Intermittent failure test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        var attempts = 0
        var succeeded = false
        let maxAttempts = 10
        
        while attempts < maxAttempts && !succeeded {
            attempts += 1
            do {
                let content = try await contentService.generateContentForIntent(intent)
                XCTAssertFalse(content.textContent.isEmpty)
                succeeded = true
            } catch {
                // Expected failures due to intermittent issues
                continue
            }
        }
        
        XCTAssertTrue(succeeded, "Should eventually succeed despite intermittent failures")
        XCTAssertGreaterThan(attempts, 1, "Should require multiple attempts due to failures")
        
        mockGrok4Service.intermittentFailureRate = 0.0
    }
    
    func testServiceUnavailableScenario() async throws {
        mockGrok4Service.simulateServiceUnavailable = true
        
        let intent = Intent.quickIntent(
            goal: "Service unavailable test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        do {
            _ = try await contentService.generateContentForIntent(intent)
            XCTFail("Should have failed with service unavailable")
        } catch let error as Grok4Error {
            if case .apiError(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 503)
            } else {
                XCTFail("Expected service unavailable error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        mockGrok4Service.simulateServiceUnavailable = false
    }
    
    // MARK: - Retry Logic Tests
    func testRetryLogicWithTransientErrors() async throws {
        // Configure service to fail first 2 attempts, then succeed
        mockGrok4Service.failFirstNAttempts = 2
        
        let intent = Intent.quickIntent(
            goal: "Retry logic test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        // Should eventually succeed after retries
        let content = try await contentService.generateContentForIntent(intent)
        XCTAssertFalse(content.textContent.isEmpty)
        
        // Verify that retries were attempted
        XCTAssertEqual(mockGrok4Service.attemptCount, 3) // 2 failures + 1 success
        
        mockGrok4Service.failFirstNAttempts = 0
    }
    
    func testMaxRetriesExceeded() async throws {
        // Configure service to always fail
        mockGrok4Service.alwaysFail = true
        
        let intent = Intent.quickIntent(
            goal: "Max retries test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        do {
            _ = try await contentService.generateContentForIntent(intent)
            XCTFail("Should have exceeded max retries")
        } catch let error as Grok4Error {
            if case .maxRetriesExceeded = error {
                XCTAssertTrue(true) // Expected max retries error
            } else {
                XCTFail("Expected max retries error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        mockGrok4Service.alwaysFail = false
    }
    
    func testExponentialBackoffTiming() async throws {
        mockGrok4Service.failFirstNAttempts = 2
        mockGrok4Service.trackRetryTimings = true
        
        let intent = Intent.quickIntent(
            goal: "Backoff timing test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let startTime = Date()
        _ = try await contentService.generateContentForIntent(intent)
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Should have some delay due to exponential backoff
        XCTAssertGreaterThan(totalTime, 3.0) // Should take at least 3 seconds due to backoff
        
        // Verify retry intervals increased
        let retryIntervals = mockGrok4Service.retryIntervals
        XCTAssertEqual(retryIntervals.count, 2) // Two retry delays
        if retryIntervals.count >= 2 {
            XCTAssertGreaterThan(retryIntervals[1], retryIntervals[0]) // Second delay should be longer
        }
        
        mockGrok4Service.failFirstNAttempts = 0
        mockGrok4Service.trackRetryTimings = false
    }
    
    // MARK: - Content Validation Error Scenarios
    func testContentValidationFailure() async throws {
        mockGrok4Service.generateInvalidContent = true
        
        let intent = Intent.quickIntent(
            goal: "Validation failure test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        do {
            _ = try await contentService.generateContentForIntent(intent)
            XCTFail("Should have failed content validation")
        } catch let error as Grok4Error {
            if case .contentValidationFailed(let issues) = error {
                XCTAssertFalse(issues.isEmpty)
            } else {
                XCTFail("Expected content validation error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        mockGrok4Service.generateInvalidContent = false
    }
    
    func testInappropriateContentDetection() async throws {
        let inappropriateContent = "This is damn inappropriate content with shit language!"
        
        do {
            let validationResult = try grok4Service.validateContent(inappropriateContent)
            XCTAssertFalse(validationResult.isValid)
            XCTAssertTrue(validationResult.issues.contains { $0.contains("inappropriate") })
        } catch {
            XCTFail("Validation should not throw, but return invalid result")
        }
    }
    
    func testTooShortContentDetection() async throws {
        let shortContent = "Too short"
        
        do {
            let validationResult = try grok4Service.validateContent(shortContent)
            XCTAssertFalse(validationResult.isValid)
            XCTAssertTrue(validationResult.issues.contains { $0.contains("too short") })
        } catch {
            XCTFail("Validation should not throw, but return invalid result")
        }
    }
    
    func testTooLongContentDetection() async throws {
        let longContent = Array(repeating: "word", count: 300).joined(separator: " ")
        
        do {
            let validationResult = try grok4Service.validateContent(longContent)
            XCTAssertFalse(validationResult.isValid)
            XCTAssertTrue(validationResult.issues.contains { $0.contains("too long") })
        } catch {
            XCTFail("Validation should not throw, but return invalid result")
        }
    }
    
    // MARK: - Concurrent Generation Stress Tests
    func testConcurrentGenerationRequests() async throws {
        let intents = (1...20).map { index in
            Intent.quickIntent(
                goal: "Concurrent test \(index)",
                scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
            )
        }
        
        // Save all intents to repository
        for intent in intents {
            try await intentRepository.saveIntent(intent)
        }
        
        // Try to generate content concurrently
        let tasks = intents.map { intent in
            Task {
                do {
                    return try await contentManager.generateContent(for: intent.id)
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
        
        let successfulResults = results.compactMap { $0 }
        
        // Due to concurrent protection, should only process one at a time
        // But all should eventually complete successfully
        XCTAssertGreaterThan(successfulResults.count, 0)
        XCTAssertLessThanOrEqual(successfulResults.count, intents.count)
    }
    
    // MARK: - Memory and Resource Tests
    func testMemoryUsageUnderLoad() async throws {
        let intents = (1...100).map { index in
            Intent.quickIntent(
                goal: "Memory test \(index)",
                scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
            )
        }
        
        let initialMemory = getMemoryUsage()
        
        for intent in intents {
            do {
                _ = try await contentService.generateContentForIntent(intent)
            } catch {
                // Allow some failures under load
                continue
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 50MB)
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Memory usage should not increase excessively")
    }
    
    func testResourceCleanupAfterErrors() async throws {
        mockGrok4Service.alwaysFail = true
        
        let intents = (1...10).map { index in
            Intent.quickIntent(
                goal: "Cleanup test \(index)",
                scheduledFor: Date().addingTimeInterval(TimeInterval(index * 3600))
            )
        }
        
        for intent in intents {
            do {
                _ = try await contentService.generateContentForIntent(intent)
            } catch {
                // Expected failures
                continue
            }
        }
        
        mockGrok4Service.alwaysFail = false
        
        // Should be able to generate content normally after cleanup
        let testIntent = Intent.quickIntent(
            goal: "Post-cleanup test",
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        let content = try await contentService.generateContentForIntent(testIntent)
        XCTAssertFalse(content.textContent.isEmpty)
    }
    
    // MARK: - Edge Case Stress Tests
    func testVeryLargeGoalTexts() async throws {
        let hugeGoal = String(repeating: "Complete a very complex and detailed task that involves multiple steps and considerations ", count: 50)
        
        let intent = Intent.quickIntent(
            goal: hugeGoal,
            scheduledFor: Date().addingTimeInterval(3600)
        )
        
        // Should handle large inputs gracefully
        let content = try await contentService.generateContentForIntent(intent)
        XCTAssertFalse(content.textContent.isEmpty)
        XCTAssertLessThan(content.metadata.wordCount, 250) // Should still respect output limits
    }
    
    func testSpecialCharacterHandling() async throws {
        let specialCharGoals = [
            "Learn 日本語 (Japanese) for 30 minutes",
            "Practice C++ programming with pointers & references",
            "Study français with accent marks: é, è, ç",
            "Work on project #123 @workplace $budget",
            "Complete task with emoji 🏃‍♂️💪🎯"
        ]
        
        for goal in specialCharGoals {
            let intent = Intent.quickIntent(
                goal: goal,
                scheduledFor: Date().addingTimeInterval(3600)
            )
            
            let content = try await contentService.generateContentForIntent(intent)
            XCTAssertFalse(content.textContent.isEmpty)
            
            // Should handle special characters without breaking
            let validation = try grok4Service.validateContent(content.textContent)
            XCTAssertTrue(validation.isValid)
        }
    }
    
    // MARK: - Helper Methods
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
}

// MARK: - Enhanced Mock Service for Stress Testing
extension MockGrok4Service {
    var simulateRateLimit: Bool {
        get { return _simulateRateLimit }
        set { _simulateRateLimit = newValue }
    }
    
    var rateLimitRequests: Int {
        get { return _rateLimitRequests }
        set { _rateLimitRequests = newValue }
    }
    
    var simulateTimeout: Bool {
        get { return _simulateTimeout }
        set { _simulateTimeout = newValue }
    }
    
    var intermittentFailureRate: Double {
        get { return _intermittentFailureRate }
        set { _intermittentFailureRate = newValue }
    }
    
    var simulateServiceUnavailable: Bool {
        get { return _simulateServiceUnavailable }
        set { _simulateServiceUnavailable = newValue }
    }
    
    var failFirstNAttempts: Int {
        get { return _failFirstNAttempts }
        set { _failFirstNAttempts = newValue }
    }
    
    var alwaysFail: Bool {
        get { return _alwaysFail }
        set { _alwaysFail = newValue }
    }
    
    var trackRetryTimings: Bool {
        get { return _trackRetryTimings }
        set { _trackRetryTimings = newValue }
    }
    
    var generateInvalidContent: Bool {
        get { return _generateInvalidContent }
        set { _generateInvalidContent = newValue }
    }
    
    private var _simulateRateLimit = false
    private var _rateLimitRequests = 0
    private var _requestCount = 0
    private var _simulateTimeout = false
    private var _intermittentFailureRate = 0.0
    private var _simulateServiceUnavailable = false
    private var _failFirstNAttempts = 0
    private var _alwaysFail = false
    private var _trackRetryTimings = false
    private var _generateInvalidContent = false
    private var _attemptCount = 0
    private var _retryIntervals: [TimeInterval] = []
    private var _lastAttemptTime: Date?
    
    var attemptCount: Int { _attemptCount }
    var retryIntervals: [TimeInterval] { _retryIntervals }
    
    func resetRateLimit() {
        _requestCount = 0
    }
    
    override func generateContentForIntent(_ intent: Intent) async throws -> String {
        _attemptCount += 1
        
        if trackRetryTimings {
            if let lastTime = _lastAttemptTime {
                let interval = Date().timeIntervalSince(lastTime)
                _retryIntervals.append(interval)
            }
            _lastAttemptTime = Date()
        }
        
        if alwaysFail {
            throw Grok4Error.apiError(statusCode: 500, message: "Simulated persistent failure")
        }
        
        if failFirstNAttempts > 0 && _attemptCount <= failFirstNAttempts {
            throw Grok4Error.apiError(statusCode: 500, message: "Simulated transient failure")
        }
        
        if simulateTimeout {
            throw Grok4Error.timeout
        }
        
        if simulateServiceUnavailable {
            throw Grok4Error.apiError(statusCode: 503, message: "Service unavailable")
        }
        
        if simulateRateLimit {
            _requestCount += 1
            if _requestCount > rateLimitRequests {
                throw Grok4Error.apiError(statusCode: 429, message: "Rate limit exceeded")
            }
        }
        
        if intermittentFailureRate > 0 {
            if Double.random(in: 0...1) < intermittentFailureRate {
                throw Grok4Error.apiError(statusCode: 500, message: "Intermittent failure")
            }
        }
        
        if generateInvalidContent {
            return "Bad" // Too short, will fail validation
        }
        
        return try await super.generateContentForIntent(intent)
    }
}
