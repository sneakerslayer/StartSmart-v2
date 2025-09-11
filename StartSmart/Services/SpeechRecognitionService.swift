import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - Speech Recognition Service Protocol
protocol SpeechRecognitionServiceProtocol {
    var isListening: Bool { get }
    var recognizedText: String { get }
    var permissionStatus: SpeechPermissionStatus { get }
    
    func requestPermissions() async -> Bool
    func startListening() async throws
    func stopListening()
    func setDismissKeywords(_ keywords: [String])
    func getDismissKeywords() -> [String]
}

// MARK: - Speech Permission Status
enum SpeechPermissionStatus: Equatable {
    case notRequested
    case denied
    case authorized
    case restricted
    case temporarilyDenied
}

// MARK: - Speech Recognition Error
enum SpeechRecognitionError: LocalizedError {
    case permissionDenied
    case speechRecognitionUnavailable
    case audioEngineFailure
    case recognitionTaskFailed(String)
    case microphoneUnavailable
    case alreadyListening
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available on this device"
        case .audioEngineFailure:
            return "Audio engine failed to start"
        case .recognitionTaskFailed(let reason):
            return "Speech recognition failed: \(reason)"
        case .microphoneUnavailable:
            return "Microphone is not available"
        case .alreadyListening:
            return "Already listening for speech"
        }
    }
}

// MARK: - Speech Recognition Service Implementation
@MainActor
class SpeechRecognitionService: NSObject, SpeechRecognitionServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isListening = false
    @Published private(set) var recognizedText = ""
    @Published private(set) var permissionStatus: SpeechPermissionStatus = .notRequested
    @Published var detectedDismissKeyword: String?
    
    // MARK: - Private Properties
    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Configuration
    private var dismissKeywords: [String] = [
        "wake up", "get up", "I'm awake", "I'm up", "stop alarm", 
        "turn off", "dismiss", "good morning", "let's go", "ready"
    ]
    private let keywordMatchThreshold: Double = 0.8
    private let listeningTimeout: TimeInterval = 10.0 // 10 seconds
    private var listeningTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        super.init()
        
        speechRecognizer?.delegate = self
        updatePermissionStatus()
    }
    
    // MARK: - Public Methods
    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await requestSpeechRecognitionPermission()
        
        // Request microphone permission
        let microphoneStatus = await requestMicrophonePermission()
        
        let authorized = speechStatus && microphoneStatus
        
        await MainActor.run {
            if authorized {
                permissionStatus = .authorized
            } else {
                permissionStatus = .denied
            }
        }
        
        return authorized
    }
    
    func startListening() async throws {
        guard !isListening else {
            throw SpeechRecognitionError.alreadyListening
        }
        
        guard permissionStatus == .authorized else {
            throw SpeechRecognitionError.permissionDenied
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.speechRecognitionUnavailable
        }
        
        // Cancel any previous task
        stopListening()
        
        do {
            try await setupAudioSession()
            try setupRecognition()
            
            isListening = true
            recognizedText = ""
            detectedDismissKeyword = nil
            
            // Set a timeout for listening
            setupListeningTimeout()
            
        } catch {
            stopListening()
            throw error
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        
        listeningTimer?.invalidate()
        listeningTimer = nil
        
        // Reset audio session
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func setDismissKeywords(_ keywords: [String]) {
        dismissKeywords = keywords.map { $0.lowercased() }
    }
    
    func getDismissKeywords() -> [String] {
        return dismissKeywords
    }
    
    // MARK: - Private Methods
    private func updatePermissionStatus() {
        let speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch speechAuthStatus {
        case .notDetermined:
            permissionStatus = .notRequested
        case .denied:
            permissionStatus = .denied
        case .restricted:
            permissionStatus = .restricted
        case .authorized:
            permissionStatus = .authorized
        @unknown default:
            permissionStatus = .notRequested
        }
    }
    
    private func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.updatePermissionStatus()
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func setupAudioSession() async throws {
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func setupRecognition() throws {
        guard let speechRecognizer = speechRecognizer else {
            throw SpeechRecognitionError.speechRecognitionUnavailable
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.speechRecognitionUnavailable
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure for live transcription
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        let inputNode = audioEngine.inputNode
        
        // Remove any existing tap
        inputNode.removeTap(onBus: 0)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("Speech recognition error: \(error)")
            stopListening()
            return
        }
        
        guard let result = result else { return }
        
        let transcription = result.bestTranscription.formattedString
        recognizedText = transcription
        
        // Check for dismiss keywords
        checkForDismissKeywords(in: transcription)
        
        // If final result, stop listening
        if result.isFinal {
            stopListening()
        }
    }
    
    private func checkForDismissKeywords(in text: String) {
        let lowercasedText = text.lowercased()
        
        for keyword in dismissKeywords {
            if lowercasedText.contains(keyword) {
                detectedDismissKeyword = keyword
                stopListening()
                break
            }
        }
        
        // Also check for fuzzy matching
        if detectedDismissKeyword == nil {
            if let matchedKeyword = findFuzzyMatch(in: lowercasedText) {
                detectedDismissKeyword = matchedKeyword
                stopListening()
            }
        }
    }
    
    private func findFuzzyMatch(in text: String) -> String? {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        for keyword in dismissKeywords {
            let keywordWords = keyword.components(separatedBy: .whitespacesAndNewlines)
            
            for word in words {
                for keywordWord in keywordWords {
                    let similarity = calculateLevenshteinSimilarity(word, keywordWord)
                    if similarity >= keywordMatchThreshold {
                        return keyword
                    }
                }
            }
        }
        
        return nil
    }
    
    private func calculateLevenshteinSimilarity(_ str1: String, _ str2: String) -> Double {
        guard !str1.isEmpty && !str2.isEmpty else { return 0.0 }
        
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let arr1 = Array(str1)
        let arr2 = Array(str2)
        let len1 = arr1.count
        let len2 = arr2.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)
        
        for i in 0...len1 { matrix[i][0] = i }
        for j in 0...len2 { matrix[0][j] = j }
        
        for i in 1...len1 {
            for j in 1...len2 {
                let cost = arr1[i-1] == arr2[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }
        
        return matrix[len1][len2]
    }
    
    private func setupListeningTimeout() {
        listeningTimer = Timer.scheduledTimer(withTimeInterval: listeningTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.stopListening()
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if !available && self.isListening {
                self.stopListening()
            }
        }
    }
}

// MARK: - Alarm Integration Extensions
extension SpeechRecognitionService {
    /// Convenience method for alarm dismissal workflow
    func startAlarmDismissListening() async -> Bool {
        do {
            try await startListening()
            
            // Wait for either keyword detection or timeout
            return await withCheckedContinuation { continuation in
                var observer: AnyCancellable?
                observer = $detectedDismissKeyword
                    .dropFirst() // Skip initial nil value
                    .sink { keyword in
                        observer?.cancel()
                        continuation.resume(returning: keyword != nil)
                    }
                
                // Also handle timeout via isListening change
                let timeoutObserver = $isListening
                    .dropFirst()
                    .filter { !$0 } // When stops listening
                    .sink { _ in
                        observer?.cancel()
                        continuation.resume(returning: self.detectedDismissKeyword != nil)
                    }
                
                // Store observers to prevent deallocation
                _ = timeoutObserver
            }
        } catch {
            print("Failed to start alarm dismiss listening: \(error)")
            return false
        }
    }
}
