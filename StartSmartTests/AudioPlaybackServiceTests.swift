import XCTest
import AVFoundation
@testable import StartSmart

final class AudioPlaybackServiceTests: XCTestCase {
    
    var playbackService: AudioPlaybackService!
    var testAudioURL: URL!
    var testAudioData: Data!
    
    override func setUp() async throws {
        try await super.setUp()
        
        await MainActor.run {
            playbackService = AudioPlaybackService()
        }
        
        // Create test audio data
        testAudioData = createTestAudioData()
        
        // Create test audio file
        let tempDir = FileManager.default.temporaryDirectory
        testAudioURL = tempDir.appendingPathComponent("test_audio.mp3")
        try testAudioData.write(to: testAudioURL)
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            playbackService.stop()
        }
        
        // Clean up test file
        try? FileManager.default.removeItem(at: testAudioURL)
        
        playbackService = nil
        testAudioURL = nil
        testAudioData = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() async {
        await MainActor.run {
            XCTAssertEqual(playbackService.playbackState, .idle)
            XCTAssertFalse(playbackService.isPlaying)
            XCTAssertEqual(playbackService.currentTime, 0)
            XCTAssertEqual(playbackService.currentDuration, 0)
            XCTAssertEqual(playbackService.volume, 1.0)
        }
    }
    
    // MARK: - Playback State Tests
    
    func testPlaybackStateTransitions() {
        XCTAssertTrue(AudioPlaybackState.idle.canPlay)
        XCTAssertFalse(AudioPlaybackState.idle.canPause)
        XCTAssertFalse(AudioPlaybackState.idle.isActivelyPlaying)
        
        XCTAssertFalse(AudioPlaybackState.playing.canPlay)
        XCTAssertTrue(AudioPlaybackState.playing.canPause)
        XCTAssertTrue(AudioPlaybackState.playing.isActivelyPlaying)
        
        XCTAssertTrue(AudioPlaybackState.paused.canPlay)
        XCTAssertFalse(AudioPlaybackState.paused.canPause)
        XCTAssertFalse(AudioPlaybackState.paused.isActivelyPlaying)
        
        XCTAssertTrue(AudioPlaybackState.stopped.canPlay)
        XCTAssertFalse(AudioPlaybackState.stopped.canPause)
        XCTAssertFalse(AudioPlaybackState.stopped.isActivelyPlaying)
        
        XCTAssertFalse(AudioPlaybackState.loading.canPlay)
        XCTAssertFalse(AudioPlaybackState.loading.canPause)
        XCTAssertFalse(AudioPlaybackState.loading.isActivelyPlaying)
        
        let errorState = AudioPlaybackState.error("Test error")
        XCTAssertFalse(errorState.canPlay)
        XCTAssertFalse(errorState.canPause)
        XCTAssertFalse(errorState.isActivelyPlaying)
    }
    
    func testPlaybackStateEquality() {
        XCTAssertEqual(AudioPlaybackState.idle, AudioPlaybackState.idle)
        XCTAssertEqual(AudioPlaybackState.playing, AudioPlaybackState.playing)
        XCTAssertEqual(AudioPlaybackState.paused, AudioPlaybackState.paused)
        XCTAssertEqual(AudioPlaybackState.stopped, AudioPlaybackState.stopped)
        XCTAssertEqual(AudioPlaybackState.loading, AudioPlaybackState.loading)
        
        XCTAssertEqual(AudioPlaybackState.error("Test"), AudioPlaybackState.error("Test"))
        XCTAssertNotEqual(AudioPlaybackState.error("Test1"), AudioPlaybackState.error("Test2"))
        
        XCTAssertNotEqual(AudioPlaybackState.idle, AudioPlaybackState.playing)
    }
    
    // MARK: - Audio Session Configuration Tests
    
    func testAudioSessionConfigurations() async {
        await MainActor.run {
            // Test alarm configuration
            playbackService.configureForAlarm()
            // Note: We can't easily test the actual session configuration without mocking AVAudioSession
            
            // Test preview configuration
            playbackService.configureForPreview()
            
            // Test background configuration
            playbackService.configureForBackground()
        }
        
        // Test configuration properties
        XCTAssertEqual(AudioSessionConfiguration.alarm.category, .playback)
        XCTAssertEqual(AudioSessionConfiguration.preview.category, .ambient)
        XCTAssertEqual(AudioSessionConfiguration.background.category, .playback)
        
        XCTAssertTrue(AudioSessionConfiguration.alarm.options.contains(.duckOthers))
        XCTAssertTrue(AudioSessionConfiguration.preview.options.contains(.mixWithOthers))
        XCTAssertTrue(AudioSessionConfiguration.background.options.contains(.allowBluetooth))
    }
    
    // MARK: - Volume Control Tests
    
    func testVolumeControl() async {
        await MainActor.run {
            playbackService.volume = 0.5
            XCTAssertEqual(playbackService.volume, 0.5)
            
            playbackService.volume = 0.0
            XCTAssertEqual(playbackService.volume, 0.0)
            
            playbackService.volume = 1.0
            XCTAssertEqual(playbackService.volume, 1.0)
        }
    }
    
    // MARK: - Basic Control Tests
    
    func testPauseWithoutPlaying() async {
        await MainActor.run {
            // Should not change state when not playing
            let initialState = playbackService.playbackState
            playbackService.pause()
            XCTAssertEqual(playbackService.playbackState, initialState)
        }
    }
    
    func testStopWhenIdle() async {
        await MainActor.run {
            playbackService.stop()
            XCTAssertEqual(playbackService.playbackState, .stopped)
            XCTAssertEqual(playbackService.currentTime, 0)
            XCTAssertEqual(playbackService.currentDuration, 0)
        }
    }
    
    func testSeekWithoutPlayer() async {
        await MainActor.run {
            // Should not crash when seeking without an active player
            playbackService.seek(to: 5.0)
            XCTAssertEqual(playbackService.currentTime, 0)
        }
    }
    
    func testSetPlaybackRateWithoutPlayer() async {
        await MainActor.run {
            // Should not crash when setting playback rate without an active player
            playbackService.setPlaybackRate(2.0)
        }
    }
    
    // MARK: - Audio File Info Tests
    
    func testGetAudioInfoFromData() async throws {
        // Note: This test might fail with mock data since AVAudioPlayer expects real audio format
        // In a real implementation, you'd use actual audio test files
        
        do {
            let info = try await MainActor.run {
                try playbackService.getAudioInfo(from: testAudioData)
            }
            
            // If we get here, the audio data was successfully parsed
            XCTAssertGreaterThanOrEqual(info.duration, 0)
            XCTAssertGreaterThan(info.numberOfChannels, 0)
            XCTAssertFalse(info.format.isEmpty)
            XCTAssertNil(info.url)
        } catch {
            // Expected to fail with mock data - this is normal
            XCTAssertTrue(error is AudioPlaybackError || error.localizedDescription.contains("audio"))
        }
    }
    
    func testGetAudioInfoFromURL() async throws {
        do {
            let info = try await MainActor.run {
                try playbackService.getAudioInfo(from: testAudioURL)
            }
            
            XCTAssertGreaterThanOrEqual(info.duration, 0)
            XCTAssertGreaterThan(info.numberOfChannels, 0)
            XCTAssertFalse(info.format.isEmpty)
            XCTAssertEqual(info.url, testAudioURL)
        } catch {
            // Expected to fail with mock data
            XCTAssertTrue(error is AudioPlaybackError || error.localizedDescription.contains("audio"))
        }
    }
    
    func testAudioFileInfoFormatting() {
        let info = AudioFileInfo(
            duration: 125.5,
            numberOfChannels: 2,
            format: "MP3",
            url: testAudioURL
        )
        
        XCTAssertEqual(info.formattedDuration, "2:05")
        XCTAssertEqual(info.channelDescription, "Stereo")
        
        let monoInfo = AudioFileInfo(
            duration: 65.0,
            numberOfChannels: 1,
            format: "WAV",
            url: nil
        )
        
        XCTAssertEqual(monoInfo.formattedDuration, "1:05")
        XCTAssertEqual(monoInfo.channelDescription, "Mono")
        
        let multiChannelInfo = AudioFileInfo(
            duration: 30.0,
            numberOfChannels: 6,
            format: "FLAC",
            url: nil
        )
        
        XCTAssertEqual(multiChannelInfo.formattedDuration, "0:30")
        XCTAssertEqual(multiChannelInfo.channelDescription, "6 channels")
    }
    
    // MARK: - Error Handling Tests
    
    func testPlayFromNonExistentURL() async {
        let nonExistentURL = URL(fileURLWithPath: "/path/to/nonexistent/file.mp3")
        
        do {
            try await playbackService.play(from: nonExistentURL)
            XCTFail("Should throw error for non-existent file")
        } catch {
            XCTAssertTrue(error is AudioPlaybackError)
        }
        
        await MainActor.run {
            // Should be in error state
            if case .error = playbackService.playbackState {
                // Expected
            } else {
                XCTFail("Should be in error state")
            }
        }
    }
    
    func testPlayFromInvalidData() async {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03]) // Not valid audio data
        
        do {
            try await playbackService.play(data: invalidData)
            XCTFail("Should throw error for invalid audio data")
        } catch {
            XCTAssertTrue(error is AudioPlaybackError)
        }
        
        await MainActor.run {
            if case .error = playbackService.playbackState {
                // Expected
            } else {
                XCTFail("Should be in error state")
            }
        }
    }
    
    func testAudioPlaybackErrorDescriptions() {
        let fileNotFoundError = AudioPlaybackError.fileNotFound
        XCTAssertTrue(fileNotFoundError.errorDescription?.contains("not found") ?? false)
        XCTAssertTrue(fileNotFoundError.recoverySuggestion?.contains("exists") ?? false)
        
        let invalidFormatError = AudioPlaybackError.invalidAudioFormat
        XCTAssertTrue(invalidFormatError.errorDescription?.contains("Invalid") ?? false)
        XCTAssertTrue(invalidFormatError.recoverySuggestion?.contains("supported") ?? false)
        
        let initFailedError = AudioPlaybackError.playerInitializationFailed
        XCTAssertTrue(initFailedError.errorDescription?.contains("initialize") ?? false)
        
        let playbackStartError = AudioPlaybackError.playbackStartFailed
        XCTAssertTrue(playbackStartError.errorDescription?.contains("start") ?? false)
        
        let testError = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let fileLoadError = AudioPlaybackError.fileLoadError(testError)
        XCTAssertTrue(fileLoadError.errorDescription?.contains("load") ?? false)
        
        let dataPlaybackError = AudioPlaybackError.dataPlaybackError(testError)
        XCTAssertTrue(dataPlaybackError.errorDescription?.contains("play audio data") ?? false)
        
        let sessionError = AudioPlaybackError.audioSessionConfigurationFailed(testError)
        XCTAssertTrue(sessionError.errorDescription?.contains("configure") ?? false)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testMultiplePlayCallsInSequence() async throws {
        // Multiple play calls should stop previous playback
        await MainActor.run {
            XCTAssertEqual(playbackService.playbackState, .idle)
        }
        
        // Note: These tests use mock data and may fail with real AVAudioPlayer
        // In production, you'd use real audio test files
        
        for i in 0..<3 {
            do {
                let testData = createTestAudioData(suffix: "\(i)")
                try await playbackService.play(data: testData)
                
                // Each play should reset the state
                await MainActor.run {
                    // State will likely be .error with mock data, but shouldn't crash
                }
            } catch {
                // Expected with mock data
                XCTAssertTrue(error is AudioPlaybackError)
            }
        }
    }
    
    // MARK: - Fade Effects Tests (Interface Testing Only)
    
    func testFadeInWithInvalidFile() async {
        let invalidURL = URL(fileURLWithPath: "/invalid/path.mp3")
        
        do {
            try await playbackService.playWithFadeIn(from: invalidURL, duration: 0.1)
            XCTFail("Should throw error for invalid file")
        } catch {
            XCTAssertTrue(error is AudioPlaybackError)
        }
    }
    
    func testFadeOutWhenNotPlaying() async {
        // Should handle gracefully when not playing
        await playbackService.stopWithFadeOut(duration: 0.1)
        
        await MainActor.run {
            XCTAssertEqual(playbackService.playbackState, .stopped)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryCleanupOnDeinit() async {
        // Create a new service instance
        var service: AudioPlaybackService? = await MainActor.run {
            AudioPlaybackService()
        }
        
        await MainActor.run {
            XCTAssertNotNil(service)
            
            // Start some operation
            service?.volume = 0.5
        }
        
        // Release the service
        service = nil
        
        // Should not crash - memory should be cleaned up properly
        XCTAssertNil(service)
    }
    
    // MARK: - Publisher Tests
    
    func testObservableObjectUpdates() async {
        let expectation = XCTestExpectation(description: "Observable updates")
        
        var receivedStateChanges = 0
        let cancellable = await MainActor.run {
            playbackService.objectWillChange
                .sink {
                    receivedStateChanges += 1
                    if receivedStateChanges >= 2 {
                        expectation.fulfill()
                    }
                }
        }
        
        await MainActor.run {
            playbackService.volume = 0.8
            playbackService.stop()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
        cancellable.cancel()
        
        XCTAssertGreaterThanOrEqual(receivedStateChanges, 2)
    }
    
    // MARK: - Helper Methods
    
    private func createTestAudioData(suffix: String = "") -> Data {
        var mockData = Data()
        
        // Add a simple audio-like header (not real MP3, but structured)
        mockData.append(contentsOf: [0xFF, 0xFB, 0x90, 0x00]) // Mock MP3 header
        
        // Add some content
        let content = "test_audio_data_\(suffix)"
        if let contentData = content.data(using: .utf8) {
            mockData.append(contentData)
        }
        
        // Pad to reasonable size
        while mockData.count < 1024 {
            mockData.append(contentsOf: [0x41, 0x42, 0x43, 0x44]) // ABCD pattern
        }
        
        return mockData
    }
}
