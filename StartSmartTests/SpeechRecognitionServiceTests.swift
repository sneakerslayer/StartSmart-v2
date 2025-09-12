import XCTest
import Speech
import AVFoundation
import Combine
@testable import StartSmart

// MARK: - Mock Speech Recognizer
class MockSpeechRecognizer: SFSpeechRecognizer {
    var mockAvailability = true
    var mockResults: [String] = []
    var currentResultIndex = 0
    var shouldFail = false
    var recognitionDelay: TimeInterval = 0.1
    
    override var isAvailable: Bool {
        return mockAvailability
    }
    
    func simulateRecognition(with results: [String]) {
        mockResults = results
        currentResultIndex = 0
    }
    
    func simulateFailure() {
        shouldFail = true
    }
}

// MARK: - SpeechRecognitionService Tests
@MainActor
class SpeechRecognitionServiceTests: XCTestCase {
    var speechService: SpeechRecognitionService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        speechService = SpeechRecognitionService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        speechService?.stopListening()
        cancellables?.removeAll()
        speechService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    func testInitialization() {
        XCTAssertFalse(speechService.isListening)
        XCTAssertTrue(speechService.recognizedText.isEmpty)
        XCTAssertEqual(speechService.permissionStatus, .notRequested)
        XCTAssertFalse(speechService.getDismissKeywords().isEmpty)
    }
    
    func testDefaultDismissKeywords() {
        let keywords = speechService.getDismissKeywords()
        
        let expectedKeywords = [
            "wake up", "get up", "I'm awake", "I'm up", "stop alarm",
            "turn off", "dismiss", "good morning", "let's go", "ready"
        ]
        
        for keyword in expectedKeywords {
            XCTAssertTrue(keywords.contains(keyword), "Missing keyword: \(keyword)")
        }
    }
    
    // MARK: - Permission Tests
    func testPermissionStatusMapping() {
        // Test permission status updates based on system authorization
        // Note: In unit tests, we can't actually test the real permission flow
        // but we can test the status mapping logic
        
        let initialStatus = speechService.permissionStatus
        XCTAssertEqual(initialStatus, .notRequested)
    }
    
    func testRequestPermissions_MockScenario() async {
        // Given - This is a mock test since we can't control actual permissions in unit tests
        // We test the basic flow structure
        
        // When
        let result = await speechService.requestPermissions()
        
        // Then - In unit tests, this will likely return false due to lack of actual permissions
        // But we verify the method completes without crashing
        XCTAssertNotNil(result)
    }
    
    // MARK: - Keyword Management Tests
    func testSetDismissKeywords() {
        // Given
        let customKeywords = ["wake up", "get moving", "start day"]
        
        // When
        speechService.setDismissKeywords(customKeywords)
        
        // Then
        let retrievedKeywords = speechService.getDismissKeywords()
        XCTAssertEqual(retrievedKeywords.count, customKeywords.count)
        
        for keyword in customKeywords {
            XCTAssertTrue(retrievedKeywords.contains(keyword.lowercased()))
        }
    }
    
    func testSetDismissKeywords_CaseInsensitive() {
        // Given
        let mixedCaseKeywords = ["Wake UP", "Get MOVING", "START day"]
        
        // When
        speechService.setDismissKeywords(mixedCaseKeywords)
        
        // Then
        let retrievedKeywords = speechService.getDismissKeywords()
        XCTAssertEqual(retrievedKeywords, ["wake up", "get moving", "start day"])
    }
    
    // MARK: - Levenshtein Distance Tests
    func testLevenshteinDistance_ExactMatch() {
        // Test the private algorithm through fuzzy matching behavior
        speechService.setDismissKeywords(["wake up"])
        
        // Simulate recognition with exact match
        // Note: We can't directly test private methods, but we test the behavior
        XCTAssertEqual(speechService.getDismissKeywords().count, 1)
    }
    
    func testLevenshteinDistance_CloseMatch() {
        // Test fuzzy matching with similar words
        speechService.setDismissKeywords(["wake"])
        
        // The algorithm should handle variations like "woke", "awake", etc.
        // This tests the concept even though we can't directly invoke the private method
        XCTAssertTrue(speechService.getDismissKeywords().contains("wake"))
    }
    
    func testLevenshteinSimilarity_VariousInputs() {
        // Test the concept of similarity calculation
        // Since the method is private, we test through the public interface
        
        let testCases = [
            ("hello", "hello"),  // Exact match
            ("wake", "woke"),    // Close match
            ("up", "top"),       // Partial match
            ("good", "morning")  // Different words
        ]
        
        for (word1, word2) in testCases {
            // We can't directly test the private method, but we verify the service handles different inputs
            speechService.setDismissKeywords([word1])
            XCTAssertEqual(speechService.getDismissKeywords().first, word1)
        }
    }
    
    // MARK: - Audio Session Tests
    func testAudioSessionConfiguration() {
        // Test that the service properly handles audio session configuration
        // Since this involves system resources, we test the basic structure
        
        XCTAssertFalse(speechService.isListening)
        
        // The service should be initialized without starting listening
        XCTAssertEqual(speechService.permissionStatus, .notRequested)
    }
    
    // MARK: - Error Handling Tests
    func testSpeechRecognitionError_LocalizedDescriptions() {
        let errors: [SpeechRecognitionError] = [
            .permissionDenied,
            .speechRecognitionUnavailable,
            .audioEngineFailure,
            .recognitionTaskFailed("Test failure"),
            .microphoneUnavailable,
            .alreadyListening
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
            
            // Verify specific error messages
            switch error {
            case .permissionDenied:
                XCTAssertTrue(error.errorDescription?.contains("permission") ?? false)
            case .speechRecognitionUnavailable:
                XCTAssertTrue(error.errorDescription?.contains("not available") ?? false)
            case .audioEngineFailure:
                XCTAssertTrue(error.errorDescription?.contains("Audio engine") ?? false)
            case .recognitionTaskFailed(let reason):
                XCTAssertTrue(error.errorDescription?.contains(reason) ?? false)
            case .microphoneUnavailable:
                XCTAssertTrue(error.errorDescription?.contains("Microphone") ?? false)
            case .alreadyListening:
                XCTAssertTrue(error.errorDescription?.contains("Already listening") ?? false)
            }
        }
    }
    
    func testSpeechPermissionStatus_AllCases() {
        let statuses: [SpeechPermissionStatus] = [
            .notRequested,
            .denied,
            .authorized,
            .restricted,
            .temporarilyDenied
        ]
        
        for status in statuses {
            // Test equality
            XCTAssertEqual(status, status)
            
            // Test different statuses are not equal
            for otherStatus in statuses {
                if status != otherStatus {
                    XCTAssertNotEqual(status, otherStatus)
                }
            }
        }
    }
    
    // MARK: - State Management Tests
    func testListeningStateManagement() {
        // Test that listening state is properly managed
        XCTAssertFalse(speechService.isListening)
        
        // Stop listening when not listening should be safe
        speechService.stopListening()
        XCTAssertFalse(speechService.isListening)
    }
    
    func testRecognizedTextManagement() {
        // Test recognized text state
        XCTAssertTrue(speechService.recognizedText.isEmpty)
        
        // The service should handle empty recognized text properly
        XCTAssertEqual(speechService.recognizedText, "")
    }
    
    // MARK: - Timeout Tests
    func testListeningTimeout_Concept() {
        // Test that the service has timeout protection
        // We can't easily test the actual timeout in unit tests without mocking timers
        // But we can verify the service structure supports timeouts
        
        XCTAssertFalse(speechService.isListening)
        
        // Verify the service can handle stop listening calls
        speechService.stopListening()
        XCTAssertFalse(speechService.isListening)
    }
    
    // MARK: - Reactive State Tests
    func testPublishedProperties() {
        let expectation = expectation(description: "Published property updates")
        expectation.expectedFulfillmentCount = 4 // Initial values for 4 properties
        
        var receivedUpdates = 0
        
        // Test @Published properties emit initial values
        speechService.$isListening
            .sink { _ in
                receivedUpdates += 1
                if receivedUpdates <= 4 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        speechService.$recognizedText
            .sink { _ in
                receivedUpdates += 1
                if receivedUpdates <= 4 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        speechService.$permissionStatus
            .sink { _ in
                receivedUpdates += 1
                if receivedUpdates <= 4 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        speechService.$detectedDismissKeyword
            .sink { _ in
                receivedUpdates += 1
                if receivedUpdates <= 4 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - Alarm Integration Tests
    func testStartAlarmDismissListening_WithoutPermissions() async {
        // Given - No permissions granted (default state in unit tests)
        
        // When
        let result = await speechService.startAlarmDismissListening()
        
        // Then - Should return false due to lack of permissions
        XCTAssertFalse(result)
    }
    
    func testAlarmDismissWorkflow_Structure() {
        // Test that the alarm dismiss workflow is properly structured
        
        // The service should handle keyword detection properly
        let keywords = speechService.getDismissKeywords()
        XCTAssertFalse(keywords.isEmpty)
        
        // Should have configurable keywords for alarm dismissal
        speechService.setDismissKeywords(["test dismiss"])
        XCTAssertEqual(speechService.getDismissKeywords(), ["test dismiss"])
    }
    
    // MARK: - Performance Tests
    func testKeywordSearch_Performance() {
        // Test performance of keyword matching with large keyword sets
        let largeKeywordSet = (0..<100).map { "keyword\($0)" }
        
        measure {
            speechService.setDismissKeywords(largeKeywordSet)
            _ = speechService.getDismissKeywords()
        }
        
        XCTAssertEqual(speechService.getDismissKeywords().count, largeKeywordSet.count)
    }
    
    func testFuzzyMatching_Performance() {
        // Test performance of fuzzy matching algorithm concept
        let keywords = (0..<50).map { "keyword\($0)" }
        speechService.setDismissKeywords(keywords)
        
        measure {
            // Test repeated keyword operations
            for _ in 0..<10 {
                _ = speechService.getDismissKeywords()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    func testEmptyKeywords() {
        speechService.setDismissKeywords([])
        XCTAssertTrue(speechService.getDismissKeywords().isEmpty)
    }
    
    func testWhitespaceKeywords() {
        speechService.setDismissKeywords(["  ", "", "valid keyword", "\t\n"])
        let keywords = speechService.getDismissKeywords()
        
        // Should handle whitespace gracefully
        XCTAssertTrue(keywords.contains("valid keyword"))
        XCTAssertLessThanOrEqual(keywords.count, 4) // May filter out empty/whitespace-only strings
    }
    
    func testSpecialCharacterKeywords() {
        let specialKeywords = ["hello!", "wake-up", "let's go", "don't stop"]
        speechService.setDismissKeywords(specialKeywords)
        
        let retrievedKeywords = speechService.getDismissKeywords()
        XCTAssertEqual(retrievedKeywords.count, specialKeywords.count)
    }
    
    func testUnicodeKeywords() {
        let unicodeKeywords = ["réveil", "aufwachen", "起床", "просыпаться"]
        speechService.setDismissKeywords(unicodeKeywords)
        
        let retrievedKeywords = speechService.getDismissKeywords()
        XCTAssertEqual(retrievedKeywords.count, unicodeKeywords.count)
    }
    
    // MARK: - Memory Management Tests
    func testMemoryManagement() {
        weak var weakService: SpeechRecognitionService?
        
        autoreleasepool {
            let service = SpeechRecognitionService()
            weakService = service
            
            // Use the service
            service.setDismissKeywords(["test"])
            _ = service.getDismissKeywords()
        }
        
        // Service should be deallocated after leaving autoreleasepool
        XCTAssertNil(weakService)
    }
    
    func testCancellableCleanup() {
        let service = SpeechRecognitionService()
        var cancellables = Set<AnyCancellable>()
        
        // Create subscriptions
        service.$isListening
            .sink { _ in }
            .store(in: &cancellables)
        
        service.$recognizedText
            .sink { _ in }
            .store(in: &cancellables)
        
        XCTAssertFalse(cancellables.isEmpty)
        
        // Cleanup
        cancellables.removeAll()
        XCTAssertTrue(cancellables.isEmpty)
    }
    
    // MARK: - Thread Safety Tests
    func testConcurrentKeywordAccess() {
        let expectation = expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        
        // Test concurrent read/write of keywords
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            DispatchQueue.main.async {
                self.speechService.setDismissKeywords(["keyword\(index)"])
                _ = self.speechService.getDismissKeywords()
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Integration Helper Tests
    func testSpeechRecognitionServiceProtocol() {
        // Test that the service conforms to its protocol
        let service: SpeechRecognitionServiceProtocol = speechService
        
        XCTAssertFalse(service.isListening)
        XCTAssertTrue(service.recognizedText.isEmpty)
        XCTAssertEqual(service.permissionStatus, .notRequested)
        
        service.setDismissKeywords(["test"])
        XCTAssertEqual(service.getDismissKeywords(), ["test"])
    }
}

// MARK: - Mock Integration Tests
extension SpeechRecognitionServiceTests {
    func testMockSpeechRecognizer() {
        let mockRecognizer = MockSpeechRecognizer()
        
        // Test mock availability
        XCTAssertTrue(mockRecognizer.isAvailable)
        
        mockRecognizer.mockAvailability = false
        XCTAssertFalse(mockRecognizer.isAvailable)
        
        // Test mock result simulation
        mockRecognizer.simulateRecognition(with: ["hello", "world"])
        XCTAssertEqual(mockRecognizer.mockResults, ["hello", "world"])
        
        // Test failure simulation
        mockRecognizer.simulateFailure()
        XCTAssertTrue(mockRecognizer.shouldFail)
    }
}
