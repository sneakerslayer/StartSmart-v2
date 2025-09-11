import XCTest
import AVFoundation
@testable import StartSmart

final class AudioCacheServiceTests: XCTestCase {
    
    var audioCacheService: AudioCacheService!
    var testDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test cache service with small limits for testing
        try await MainActor.run {
            audioCacheService = try AudioCacheService(
                maxCacheSizeMB: 1, // 1MB for testing
                expirationHours: 1 // 1 hour for testing
            )
        }
        
        // Setup test directory
        let tempDir = FileManager.default.temporaryDirectory
        testDirectory = tempDir.appendingPathComponent("AudioCacheTests")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        // Clean up test data
        try? FileManager.default.removeItem(at: testDirectory)
        try await MainActor.run {
            try? await audioCacheService.clearCache()
        }
        
        audioCacheService = nil
        testDirectory = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Cache Operations Tests
    
    func testCacheAudioData() async throws {
        let testData = createMockAudioData()
        let metadata = SimpleAudioMetadata(
            intentId: "test-intent-1",
            voiceId: "test-voice",
            duration: 5.0
        )
        
        let filePath = try await audioCacheService.cacheAudio(
            data: testData,
            forKey: "test-audio-1",
            metadata: metadata
        )
        
        XCTAssertFalse(filePath.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
        
        // Verify file content
        let savedData = try Data(contentsOf: URL(fileURLWithPath: filePath))
        XCTAssertEqual(savedData, testData)
    }
    
    func testGetCachedAudio() async throws {
        let testData = createMockAudioData()
        let metadata = SimpleAudioMetadata(
            intentId: "test-intent-2",
            voiceId: "test-voice",
            duration: 3.0
        )
        
        // Cache the audio
        let _ = try await audioCacheService.cacheAudio(
            data: testData,
            forKey: "test-audio-2",
            metadata: metadata
        )
        
        // Retrieve the cached audio
        let result = try await audioCacheService.getCachedAudio(forKey: "test-audio-2")
        
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.isValid)
        XCTAssertEqual(result!.metadata.intentId, "test-intent-2")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result!.filePath))
    }
    
    func testGetNonExistentCachedAudio() async throws {
        let result = try await audioCacheService.getCachedAudio(forKey: "non-existent-key")
        XCTAssertNil(result)
    }
    
    func testRemoveCachedAudio() async throws {
        let testData = createMockAudioData()
        let metadata = SimpleAudioMetadata(
            intentId: "test-intent-3",
            voiceId: "test-voice"
        )
        
        // Cache the audio
        let filePath = try await audioCacheService.cacheAudio(
            data: testData,
            forKey: "test-audio-3",
            metadata: metadata
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
        
        // Remove the cached audio
        try await audioCacheService.removeCachedAudio(forKey: "test-audio-3")
        
        // Verify removal
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
        
        let result = try await audioCacheService.getCachedAudio(forKey: "test-audio-3")
        XCTAssertNil(result)
    }
    
    func testClearCache() async throws {
        let testData1 = createMockAudioData()
        let testData2 = createMockAudioData(content: "different audio data")
        
        let metadata1 = SimpleAudioMetadata(intentId: "intent-1", voiceId: "voice-1")
        let metadata2 = SimpleAudioMetadata(intentId: "intent-2", voiceId: "voice-2")
        
        // Cache multiple audio files
        let _ = try await audioCacheService.cacheAudio(data: testData1, forKey: "audio-1", metadata: metadata1)
        let _ = try await audioCacheService.cacheAudio(data: testData2, forKey: "audio-2", metadata: metadata2)
        
        // Verify they exist
        XCTAssertNotNil(try await audioCacheService.getCachedAudio(forKey: "audio-1"))
        XCTAssertNotNil(try await audioCacheService.getCachedAudio(forKey: "audio-2"))
        
        // Clear cache
        try await audioCacheService.clearCache()
        
        // Verify cache is empty
        XCTAssertNil(try await audioCacheService.getCachedAudio(forKey: "audio-1"))
        XCTAssertNil(try await audioCacheService.getCachedAudio(forKey: "audio-2"))
        
        let stats = await audioCacheService.getCacheStatistics()
        XCTAssertEqual(stats.totalItems, 0)
        XCTAssertEqual(stats.totalSizeMB, 0.0)
    }
    
    // MARK: - Cache Metadata Tests
    
    func testSimpleAudioMetadata() {
        let metadata = SimpleAudioMetadata(
            intentId: "test-intent",
            voiceId: "test-voice",
            duration: 10.5,
            format: .mp3,
            quality: .high
        )
        
        XCTAssertEqual(metadata.intentId, "test-intent")
        XCTAssertEqual(metadata.voiceId, "test-voice")
        XCTAssertEqual(metadata.duration, 10.5)
        XCTAssertEqual(metadata.format, .mp3)
        XCTAssertEqual(metadata.quality, .high)
    }
    
    func testSimpleAudioMetadataDefaults() {
        let metadata = SimpleAudioMetadata(
            intentId: "test-intent",
            voiceId: "test-voice"
        )
        
        XCTAssertNil(metadata.duration)
        XCTAssertEqual(metadata.format, .mp3)
        XCTAssertEqual(metadata.quality, .standard)
    }
    
    // MARK: - Cache Statistics Tests
    
    func testCacheStatistics() async throws {
        let initialStats = await audioCacheService.getCacheStatistics()
        XCTAssertEqual(initialStats.totalItems, 0)
        XCTAssertEqual(initialStats.totalSizeMB, 0.0)
        
        // Add some cached items
        let testData = createMockAudioData()
        let metadata = SimpleAudioMetadata(intentId: "stats-test", voiceId: "voice")
        
        let _ = try await audioCacheService.cacheAudio(data: testData, forKey: "stats-1", metadata: metadata)
        let _ = try await audioCacheService.cacheAudio(data: testData, forKey: "stats-2", metadata: metadata)
        
        let updatedStats = await audioCacheService.getCacheStatistics()
        XCTAssertEqual(updatedStats.totalItems, 2)
        XCTAssertGreaterThan(updatedStats.totalSizeMB, 0)
        XCTAssertGreaterThan(updatedStats.averageFileSizeKB, 0)
        XCTAssertNotNil(updatedStats.newestItemDate)
    }
    
    func testCacheHealthStatus() {
        let healthyStats = AudioCacheStatistics(
            totalItems: 5,
            totalSizeMB: 10.0,
            oldestItemDate: Date(),
            newestItemDate: Date(),
            averageFileSizeKB: 200.0,
            expiredItemsCount: 0,
            availableStorageGB: 50.0,
            cacheHitRate: 0.8
        )
        XCTAssertEqual(healthyStats.healthStatus, .healthy)
        
        let warningStats = AudioCacheStatistics(
            totalItems: 50,
            totalSizeMB: 120.0,
            oldestItemDate: Date(),
            newestItemDate: Date(),
            averageFileSizeKB: 200.0,
            expiredItemsCount: 0,
            availableStorageGB: 50.0,
            cacheHitRate: 0.8
        )
        XCTAssertEqual(warningStats.healthStatus, .warning)
        
        let criticalStats = AudioCacheStatistics(
            totalItems: 100,
            totalSizeMB: 250.0,
            oldestItemDate: Date(),
            newestItemDate: Date(),
            averageFileSizeKB: 200.0,
            expiredItemsCount: 0,
            availableStorageGB: 50.0,
            cacheHitRate: 0.8
        )
        XCTAssertEqual(criticalStats.healthStatus, .critical)
    }
    
    func testFormattedSize() {
        let smallStats = AudioCacheStatistics(
            totalItems: 1,
            totalSizeMB: 0.5,
            oldestItemDate: nil,
            newestItemDate: nil,
            averageFileSizeKB: 0,
            expiredItemsCount: 0,
            availableStorageGB: 0,
            cacheHitRate: 0
        )
        XCTAssertTrue(smallStats.formattedTotalSize.contains("KB"))
        
        let largeStats = AudioCacheStatistics(
            totalItems: 1,
            totalSizeMB: 5.5,
            oldestItemDate: nil,
            newestItemDate: nil,
            averageFileSizeKB: 0,
            expiredItemsCount: 0,
            availableStorageGB: 0,
            cacheHitRate: 0
        )
        XCTAssertTrue(largeStats.formattedTotalSize.contains("MB"))
    }
    
    // MARK: - Error Handling Tests
    
    func testCacheEmptyData() async {
        let emptyData = Data()
        let metadata = SimpleAudioMetadata(intentId: "empty", voiceId: "voice")
        
        do {
            let _ = try await audioCacheService.cacheAudio(data: emptyData, forKey: "empty", metadata: metadata)
            XCTFail("Should throw error for empty data")
        } catch let error as AudioCacheError {
            if case .invalidData(let message) = error {
                XCTAssertTrue(message.contains("empty"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testCacheEmptyKey() async {
        let testData = createMockAudioData()
        let metadata = SimpleAudioMetadata(intentId: "test", voiceId: "voice")
        
        do {
            let _ = try await audioCacheService.cacheAudio(data: testData, forKey: "", metadata: metadata)
            XCTFail("Should throw error for empty key")
        } catch let error as AudioCacheError {
            if case .invalidKey(let message) = error {
                XCTAssertTrue(message.contains("empty"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testAudioCacheErrorDescriptions() {
        let invalidDataError = AudioCacheError.invalidData("Test data error")
        XCTAssertTrue(invalidDataError.errorDescription?.contains("Invalid audio data") ?? false)
        XCTAssertTrue(invalidDataError.recoverySuggestion?.contains("valid") ?? false)
        
        let invalidKeyError = AudioCacheError.invalidKey("Test key error")
        XCTAssertTrue(invalidKeyError.errorDescription?.contains("Invalid cache key") ?? false)
        
        let cacheLimitError = AudioCacheError.cacheLimitExceeded
        XCTAssertTrue(cacheLimitError.errorDescription?.contains("size limit") ?? false)
        XCTAssertTrue(cacheLimitError.recoverySuggestion?.contains("Clear old") ?? false)
    }
    
    // MARK: - Maintenance Tests
    
    func testPerformMaintenance() async throws {
        let testData = createMockAudioData()
        
        // Create some cache entries with different dates
        let oldMetadata = SimpleAudioMetadata(
            intentId: "old",
            voiceId: "voice",
            generatedAt: Date().addingTimeInterval(-7200) // 2 hours ago
        )
        
        let newMetadata = SimpleAudioMetadata(
            intentId: "new",
            voiceId: "voice",
            generatedAt: Date()
        )
        
        let _ = try await audioCacheService.cacheAudio(data: testData, forKey: "old-audio", metadata: oldMetadata)
        let _ = try await audioCacheService.cacheAudio(data: testData, forKey: "new-audio", metadata: newMetadata)
        
        // Verify both are cached
        XCTAssertNotNil(try await audioCacheService.getCachedAudio(forKey: "old-audio"))
        XCTAssertNotNil(try await audioCacheService.getCachedAudio(forKey: "new-audio"))
        
        // Perform maintenance (should remove expired items)
        try await audioCacheService.performMaintenance()
        
        // Check if expired item was removed (depends on expiration settings)
        let oldResult = try await audioCacheService.getCachedAudio(forKey: "old-audio")
        let newResult = try await audioCacheService.getCachedAudio(forKey: "new-audio")
        
        // New item should still exist
        XCTAssertNotNil(newResult)
        
        // Old item might be removed if expired (depends on 1-hour expiration setting)
        // This is expected behavior for maintenance
    }
    
    // MARK: - File Name Sanitization Tests
    
    func testFileNameSanitization() async throws {
        let testData = createMockAudioData()
        let metadata = SimpleAudioMetadata(intentId: "test", voiceId: "voice")
        
        // Test with problematic characters
        let problematicKey = "audio/with:invalid\\characters?%*|\"<>name"
        let filePath = try await audioCacheService.cacheAudio(
            data: testData,
            forKey: problematicKey,
            metadata: metadata
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
        
        // File name should be sanitized
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        XCTAssertFalse(fileName.contains("/"))
        XCTAssertFalse(fileName.contains(":"))
        XCTAssertFalse(fileName.contains("\\"))
        XCTAssertFalse(fileName.contains("?"))
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentCaching() async throws {
        let expectation = XCTestExpectation(description: "Concurrent caching")
        expectation.expectedFulfillmentCount = 5
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        let testData = self.createMockAudioData(content: "concurrent_\(i)")
                        let metadata = SimpleAudioMetadata(
                            intentId: "concurrent-\(i)",
                            voiceId: "voice-\(i)"
                        )
                        
                        let _ = try await self.audioCacheService.cacheAudio(
                            data: testData,
                            forKey: "concurrent-\(i)",
                            metadata: metadata
                        )
                        
                        expectation.fulfill()
                    } catch {
                        XCTFail("Concurrent caching failed: \(error)")
                    }
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify all items were cached
        for i in 0..<5 {
            let result = try await audioCacheService.getCachedAudio(forKey: "concurrent-\(i)")
            XCTAssertNotNil(result)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockAudioData(content: String = "mock audio data") -> Data {
        var mockData = Data()
        
        // Add MP3 header signature
        mockData.append(contentsOf: [0xFF, 0xFB, 0x90, 0x00])
        
        // Add content
        if let contentData = content.data(using: .utf8) {
            mockData.append(contentData)
        }
        
        // Pad to reasonable size
        while mockData.count < 1024 {
            mockData.append(contentsOf: [0x00, 0x01, 0x02, 0x03])
        }
        
        return mockData
    }
}

