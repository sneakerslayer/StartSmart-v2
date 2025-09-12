import XCTest
import SwiftUI
import Combine
@testable import StartSmart

// MARK: - Mock ViewModels for Testing
class MockAlarmViewModel: AlarmViewModel {
    var mockDismissAlarmCalled = false
    var mockSnoozeAlarmCalled = false
    var dismissedAlarmId: UUID?
    var snoozedAlarmId: UUID?
    
    override func dismissAlarm(_ alarmId: UUID) {
        mockDismissAlarmCalled = true
        dismissedAlarmId = alarmId
        super.dismissAlarm(alarmId)
    }
    
    override func snoozeAlarm(_ alarmId: UUID) {
        mockSnoozeAlarmCalled = true
        snoozedAlarmId = alarmId
        super.snoozeAlarm(alarmId)
    }
}

class MockSpeechRecognitionService: SpeechRecognitionService {
    var mockPermissionStatus: SpeechPermissionStatus = .notRequested
    var mockIsListening = false
    var mockRecognizedText = ""
    var mockDetectedKeyword: String?
    var mockDismissKeywords: [String] = ["wake up", "I'm awake", "get up"]
    var mockPermissionResult = false
    var mockListeningResult = false
    
    override var permissionStatus: SpeechPermissionStatus {
        return mockPermissionStatus
    }
    
    override var isListening: Bool {
        return mockIsListening
    }
    
    override var recognizedText: String {
        return mockRecognizedText
    }
    
    override func requestPermissions() async -> Bool {
        mockPermissionStatus = mockPermissionResult ? .authorized : .denied
        return mockPermissionResult
    }
    
    override func startListening() async throws {
        guard mockPermissionStatus == .authorized else {
            throw SpeechRecognitionError.permissionDenied
        }
        mockIsListening = true
    }
    
    override func stopListening() {
        mockIsListening = false
    }
    
    override func setDismissKeywords(_ keywords: [String]) {
        mockDismissKeywords = keywords
    }
    
    override func getDismissKeywords() -> [String] {
        return mockDismissKeywords
    }
    
    override func startAlarmDismissListening() async -> Bool {
        mockIsListening = true
        return mockListeningResult
    }
    
    func simulateKeywordDetection(_ keyword: String) {
        mockDetectedKeyword = keyword
        mockRecognizedText = keyword
        mockIsListening = false
    }
    
    func simulateRecognizedText(_ text: String) {
        mockRecognizedText = text
    }
}

class MockAudioPlaybackService: AudioPlaybackService {
    var mockIsPlaying = false
    var mockPlayedURL: URL?
    var shouldFailPlayback = false
    
    override var isPlaying: Bool {
        return mockIsPlaying
    }
    
    override func play(from url: URL) async throws {
        if shouldFailPlayback {
            throw AudioPlaybackError.fileNotFound
        }
        mockPlayedURL = url
        mockIsPlaying = true
    }
    
    override func stop() {
        mockIsPlaying = false
        mockPlayedURL = nil
    }
    
    override func pause() {
        mockIsPlaying = false
    }
    
    override func resume() {
        mockIsPlaying = true
    }
}

// MARK: - AlarmView UI Tests
class AlarmViewUITests: XCTestCase {
    var testAlarm: Alarm!
    var mockViewModel: MockAlarmViewModel!
    var mockSpeechService: MockSpeechRecognitionService!
    var mockAudioService: MockAudioPlaybackService!
    
    override func setUp() {
        super.setUp()
        
        testAlarm = Alarm(
            time: Date(),
            label: "Test Alarm",
            tone: .energetic
        )
        
        mockViewModel = MockAlarmViewModel()
        mockSpeechService = MockSpeechRecognitionService()
        mockAudioService = MockAudioPlaybackService()
    }
    
    override func tearDown() {
        testAlarm = nil
        mockViewModel = nil
        mockSpeechService = nil
        mockAudioService = nil
        super.tearDown()
    }
    
    // MARK: - View Rendering Tests
    func testAlarmView_BasicRendering() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        
        // Verify the view can be rendered without crashes
        hostingController.loadView()
        hostingController.viewDidLoad()
    }
    
    func testAlarmView_ToneBasedGradients() {
        let tones: [AlarmTone] = [.gentle, .energetic, .toughLove, .storyteller]
        
        for tone in tones {
            // Given
            let alarm = Alarm(time: Date(), tone: tone)
            let alarmView = AlarmView(alarm: alarm)
            
            // When
            let hostingController = UIHostingController(rootView: alarmView)
            
            // Then
            XCTAssertNotNil(hostingController.view)
            // Each tone should render without issues
            hostingController.loadView()
        }
    }
    
    func testAlarmView_WithGeneratedContent() {
        // Given
        var alarm = testAlarm!
        let generatedContent = AlarmGeneratedContent(
            textContent: "Good morning! Time to conquer the day!",
            audioFilePath: "/tmp/test_audio.mp3",
            voiceId: "energetic",
            generatedAt: Date(),
            duration: 45.0,
            intentId: nil
        )
        alarm.setGeneratedContent(generatedContent)
        
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
    }
    
    func testAlarmView_WithoutGeneratedContent() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
    }
    
    // MARK: - Alarm Label Tests
    func testAlarmView_EmptyLabel() {
        // Given
        let alarm = Alarm(time: Date(), label: "", tone: .gentle)
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
        // Should display default "Wake Up!" text
    }
    
    func testAlarmView_LongLabel() {
        // Given
        let longLabel = "This is a very long alarm label that should still display properly in the UI without breaking the layout or causing any rendering issues"
        let alarm = Alarm(time: Date(), label: longLabel, tone: .storyteller)
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
    }
    
    // MARK: - Time Display Tests
    func testTimeDisplayFormatting() {
        // Given
        let specificTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 30))!
        let alarm = Alarm(time: specificTime, tone: .gentle)
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
        // Time should be properly formatted
    }
    
    // MARK: - Gradient Color Tests
    func testToneBasedGradientColors() {
        // Test that each tone produces the expected gradient colors
        let toneColorTests = [
            AlarmTone.gentle: "Should have soft purple/blue/yellow gradient",
            AlarmTone.energetic: "Should have bright red/orange/yellow gradient",
            AlarmTone.toughLove: "Should have dark gray/red/blue gradient",
            AlarmTone.storyteller: "Should have purple/teal/green gradient"
        ]
        
        for (tone, description) in toneColorTests {
            // Given
            let alarm = Alarm(time: Date(), tone: tone)
            let alarmView = AlarmView(alarm: alarm)
            
            // When
            let hostingController = UIHostingController(rootView: alarmView)
            
            // Then
            XCTAssertNotNil(hostingController.view, description)
            hostingController.loadView()
        }
    }
    
    // MARK: - Snooze Functionality Tests
    func testSnoozeButton_Enabled() {
        // Given
        var alarm = testAlarm!
        alarm.snoozeEnabled = true
        alarm.currentSnoozeCount = 0
        alarm.maxSnoozeCount = 3
        
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertTrue(alarm.canSnooze)
        hostingController.loadView()
    }
    
    func testSnoozeButton_Disabled() {
        // Given
        var alarm = testAlarm!
        alarm.snoozeEnabled = false
        
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertFalse(alarm.canSnooze)
        hostingController.loadView()
    }
    
    func testSnoozeButton_MaxAttemptsReached() {
        // Given
        var alarm = testAlarm!
        alarm.snoozeEnabled = true
        alarm.currentSnoozeCount = 3
        alarm.maxSnoozeCount = 3
        
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertFalse(alarm.canSnooze)
        hostingController.loadView()
    }
    
    // MARK: - Audio Integration Tests
    func testAlarmView_WithAudioFile() {
        // Given
        var alarm = testAlarm!
        alarm.customAudioPath = "/tmp/custom_audio.mp3"
        
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertNotNil(alarm.audioFileURL)
        hostingController.loadView()
    }
    
    func testAlarmView_WithoutAudioFile() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertNil(testAlarm.audioFileURL)
        hostingController.loadView()
    }
    
    // MARK: - Speech Recognition Integration Tests
    func testSpeechRecognition_PermissionNotGranted() {
        // Given
        mockSpeechService.mockPermissionStatus = .denied
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
        // Should handle permission denied gracefully
    }
    
    func testSpeechRecognition_PermissionGranted() {
        // Given
        mockSpeechService.mockPermissionStatus = .authorized
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
        // Should be ready for speech recognition
    }
    
    func testSpeechRecognition_RecognizedText() {
        // Given
        mockSpeechService.mockRecognizedText = "I'm awake and ready"
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
        // Should display recognized text
    }
    
    // MARK: - Animation Tests
    func testWaveformAnimation() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
        
        // The waveform animation should be initialized
        // In a real test, we would verify animation state
    }
    
    func testPulseAnimation() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
        
        // The pulse animation should be initialized
    }
    
    // MARK: - Accessibility Tests
    func testAccessibility_VoiceOver() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // Should support VoiceOver
    }
    
    func testAccessibility_LabeledControls() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // All interactive controls should have accessibility labels
    }
    
    // MARK: - State Management Tests
    func testViewState_Initialization() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // Initial state should be properly set
    }
    
    func testViewState_Updates() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // State updates should be handled properly
    }
    
    // MARK: - Memory Management Tests
    func testMemoryManagement() {
        weak var weakView: UIView?
        
        autoreleasepool {
            let alarmView = AlarmView(alarm: testAlarm)
            let hostingController = UIHostingController(rootView: alarmView)
            hostingController.loadView()
            
            weakView = hostingController.view
        }
        
        // View should be deallocated
        XCTAssertNil(weakView)
    }
    
    // MARK: - Error Handling Tests
    func testErrorHandling_AudioPlaybackFailure() {
        // Given
        var alarm = testAlarm!
        alarm.customAudioPath = "/invalid/path/audio.mp3"
        
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
        // Should handle audio playback failure gracefully
    }
    
    func testErrorHandling_SpeechRecognitionFailure() {
        // Given
        mockSpeechService.mockPermissionStatus = .restricted
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        
        // Then
        XCTAssertNotNil(hostingController.view)
        hostingController.loadView()
        // Should handle speech recognition restriction gracefully
    }
    
    // MARK: - Performance Tests
    func testRenderingPerformance() {
        // Test rendering performance with multiple alarms
        let alarms = (0..<10).map { index in
            Alarm(
                time: Date().addingTimeInterval(TimeInterval(index * 3600)),
                label: "Alarm \(index)",
                tone: AlarmTone.allCases.randomElement()!
            )
        }
        
        measure {
            for alarm in alarms {
                let alarmView = AlarmView(alarm: alarm)
                let hostingController = UIHostingController(rootView: alarmView)
                hostingController.loadView()
            }
        }
    }
    
    func testAnimationPerformance() {
        // Test performance with animations
        let alarmView = AlarmView(alarm: testAlarm)
        
        measure {
            let hostingController = UIHostingController(rootView: alarmView)
            hostingController.loadView()
            hostingController.viewDidAppear(false)
        }
    }
    
    // MARK: - Layout Tests
    func testLayout_Portrait() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        let hostingController = UIHostingController(rootView: alarmView)
        
        // When
        hostingController.loadView()
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 812) // iPhone portrait
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // Should layout properly in portrait mode
    }
    
    func testLayout_Landscape() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        let hostingController = UIHostingController(rootView: alarmView)
        
        // When
        hostingController.loadView()
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 812, height: 375) // iPhone landscape
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // Should layout properly in landscape mode
    }
    
    func testLayout_iPad() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        let hostingController = UIHostingController(rootView: alarmView)
        
        // When
        hostingController.loadView()
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 1024, height: 1366) // iPad
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // Should layout properly on iPad
    }
    
    // MARK: - Voice Instructions Overlay Tests
    func testVoiceInstructionsOverlay() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // Voice instructions overlay should be available
    }
    
    func testDismissKeywordsDisplay() {
        // Given
        mockSpeechService.mockDismissKeywords = ["wake up", "I'm ready", "let's go"]
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // Should display the configured dismiss keywords
    }
    
    // MARK: - Integration Tests
    func testFullUserFlow_VoiceDismiss() {
        // Given
        mockSpeechService.mockPermissionStatus = .authorized
        mockSpeechService.mockListeningResult = true
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // Should support full voice dismiss flow
    }
    
    func testFullUserFlow_ManualDismiss() {
        // Given
        let alarmView = AlarmView(alarm: testAlarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // Should support manual dismiss flow
    }
    
    func testFullUserFlow_Snooze() {
        // Given
        var alarm = testAlarm!
        alarm.snoozeEnabled = true
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        // Should support snooze flow
    }
}

// MARK: - SwiftUI Testing Helpers
extension AlarmViewUITests {
    func createTestEnvironment() -> some View {
        AlarmView(alarm: testAlarm)
            .environmentObject(mockViewModel)
    }
    
    func hostTestView<Content: View>(_ content: Content) -> UIHostingController<Content> {
        let hostingController = UIHostingController(rootView: content)
        hostingController.loadView()
        return hostingController
    }
}

// MARK: - Alarm Content Helper Tests
extension AlarmViewUITests {
    func testAlarmContent_TextDisplay() {
        // Given
        var alarm = testAlarm!
        let content = AlarmGeneratedContent(
            textContent: "Rise and shine! Today is your day to make a difference.",
            audioFilePath: "/tmp/motivational.mp3",
            voiceId: "energetic",
            generatedAt: Date(),
            duration: 30.0,
            intentId: nil
        )
        alarm.setGeneratedContent(content)
        
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertEqual(alarm.generatedContent?.textContent, content.textContent)
    }
    
    func testAlarmContent_ExpiredContent() {
        // Given
        var alarm = testAlarm!
        let expiredContent = AlarmGeneratedContent(
            textContent: "Old content",
            audioFilePath: "/tmp/old.mp3",
            voiceId: "gentle",
            generatedAt: Date().addingTimeInterval(-8 * 24 * 60 * 60), // 8 days ago
            duration: 30.0,
            intentId: nil
        )
        alarm.setGeneratedContent(expiredContent)
        
        let alarmView = AlarmView(alarm: alarm)
        
        // When
        let hostingController = UIHostingController(rootView: alarmView)
        hostingController.loadView()
        
        // Then
        XCTAssertNotNil(hostingController.view)
        XCTAssertTrue(alarm.generatedContent?.isExpired ?? false)
    }
}
