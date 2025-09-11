import Foundation
import AVFoundation
import Combine

// MARK: - Audio Playback Service Protocol
protocol AudioPlaybackServiceProtocol {
    var isPlaying: Bool { get }
    var currentDuration: TimeInterval { get }
    var currentTime: TimeInterval { get }
    var volume: Float { get set }
    
    func play(from url: URL) async throws
    func play(data: Data) async throws
    func pause()
    func stop()
    func seek(to time: TimeInterval)
    func setPlaybackRate(_ rate: Float)
}

// MARK: - Audio Playback State
enum AudioPlaybackState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case stopped
    case error(String)
    
    var isActivelyPlaying: Bool {
        self == .playing
    }
    
    var canPause: Bool {
        self == .playing
    }
    
    var canPlay: Bool {
        switch self {
        case .idle, .paused, .stopped:
            return true
        default:
            return false
        }
    }
}

// MARK: - Audio Session Configuration
enum AudioSessionConfiguration {
    case alarm // For alarm playback - bypasses silent mode
    case preview // For content preview - respects silent mode
    case background // For background audio
    
    var category: AVAudioSession.Category {
        switch self {
        case .alarm:
            return .playback
        case .preview:
            return .ambient
        case .background:
            return .playback
        }
    }
    
    var options: AVAudioSession.CategoryOptions {
        switch self {
        case .alarm:
            return [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
        case .preview:
            return [.mixWithOthers]
        case .background:
            return [.allowBluetooth, .allowBluetoothA2DP]
        }
    }
}

// MARK: - Audio Playback Service Implementation
@MainActor
class AudioPlaybackService: NSObject, AudioPlaybackServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published var playbackState: AudioPlaybackState = .idle
    @Published var currentTime: TimeInterval = 0
    @Published var currentDuration: TimeInterval = 0
    @Published var volume: Float = 1.0 {
        didSet {
            audioPlayer?.volume = volume
        }
    }
    
    // MARK: - Computed Properties
    var isPlaying: Bool {
        playbackState == .playing
    }
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var sessionConfiguration: AudioSessionConfiguration = .preview
    
    // MARK: - Combine Publishers
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupAudioSession()
        setupPlaybackObservation()
    }
    
    deinit {
        audioPlayer?.stop()
        audioPlayer = nil
        stopPlaybackTimer()
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    func play(from url: URL) async throws {
        await stopCurrentPlayback()
        
        do {
            playbackState = .loading
            
            // Configure audio session for the current configuration
            try configureAudioSession(for: sessionConfiguration)
            
            // Create audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            
            // Validate audio file
            guard let player = audioPlayer else {
                throw AudioPlaybackError.playerInitializationFailed
            }
            
            // Start playback
            if player.play() {
                currentDuration = player.duration
                playbackState = .playing
                startPlaybackTimer()
            } else {
                throw AudioPlaybackError.playbackStartFailed
            }
            
        } catch {
            playbackState = .error(error.localizedDescription)
            throw AudioPlaybackError.fileLoadError(error)
        }
    }
    
    func play(data: Data) async throws {
        await stopCurrentPlayback()
        
        do {
            playbackState = .loading
            
            // Configure audio session
            try configureAudioSession(for: sessionConfiguration)
            
            // Create audio player from data
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            
            guard let player = audioPlayer else {
                throw AudioPlaybackError.playerInitializationFailed
            }
            
            // Start playback
            if player.play() {
                currentDuration = player.duration
                playbackState = .playing
                startPlaybackTimer()
            } else {
                throw AudioPlaybackError.playbackStartFailed
            }
            
        } catch {
            playbackState = .error(error.localizedDescription)
            throw AudioPlaybackError.dataPlaybackError(error)
        }
    }
    
    func pause() {
        guard playbackState.canPause else { return }
        
        audioPlayer?.pause()
        playbackState = .paused
        stopPlaybackTimer()
    }
    
    func stop() {
        stopCurrentPlayback()
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer, time >= 0, time <= player.duration else {
            return
        }
        
        player.currentTime = time
        currentTime = time
    }
    
    func setPlaybackRate(_ rate: Float) {
        audioPlayer?.rate = rate
    }
    
    // MARK: - Session Configuration
    
    func configureForAlarm() {
        sessionConfiguration = .alarm
    }
    
    func configureForPreview() {
        sessionConfiguration = .preview
    }
    
    func configureForBackground() {
        sessionConfiguration = .background
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }
    
    private func configureAudioSession(for configuration: AudioSessionConfiguration) throws {
        let session = AVAudioSession.sharedInstance()
        
        try session.setCategory(
            configuration.category,
            mode: .default,
            options: configuration.options
        )
        
        try session.setActive(true)
    }
    
    private func setupPlaybackObservation() {
        // Observe audio session interruptions
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleAudioSessionInterruption(notification)
            }
            .store(in: &cancellables)
        
        // Observe route changes (headphones disconnect, etc.)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    private func stopCurrentPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopPlaybackTimer()
        currentTime = 0
        currentDuration = 0
        playbackState = .stopped
    }
    
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            
            Task { @MainActor in
                self.currentTime = player.currentTime
            }
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptionTypeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue) else {
            return
        }
        
        switch interruptionType {
        case .began:
            if isPlaying {
                pause()
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && playbackState == .paused {
                    audioPlayer?.play()
                    playbackState = .playing
                    startPlaybackTimer()
                }
            }
        @unknown default:
            break
        }
    }
    
    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones were unplugged - pause playback for preview audio
            if sessionConfiguration == .preview && isPlaying {
                pause()
            }
        default:
            break
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlaybackService: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                self.playbackState = .idle
            } else {
                self.playbackState = .error("Playback finished unsuccessfully")
            }
            
            self.stopPlaybackTimer()
            self.currentTime = 0
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            let errorMessage = error?.localizedDescription ?? "Unknown decode error"
            self.playbackState = .error(errorMessage)
            self.stopPlaybackTimer()
        }
    }
}

// MARK: - Audio Playback Errors
enum AudioPlaybackError: LocalizedError {
    case fileNotFound
    case invalidAudioFormat
    case playerInitializationFailed
    case playbackStartFailed
    case fileLoadError(Error)
    case dataPlaybackError(Error)
    case audioSessionConfigurationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file not found"
        case .invalidAudioFormat:
            return "Invalid audio file format"
        case .playerInitializationFailed:
            return "Failed to initialize audio player"
        case .playbackStartFailed:
            return "Failed to start audio playback"
        case .fileLoadError(let error):
            return "Failed to load audio file: \(error.localizedDescription)"
        case .dataPlaybackError(let error):
            return "Failed to play audio data: \(error.localizedDescription)"
        case .audioSessionConfigurationFailed(let error):
            return "Failed to configure audio session: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Check if the audio file exists and try again."
        case .invalidAudioFormat:
            return "Ensure the audio file is in a supported format (MP3, WAV, etc.)."
        case .playerInitializationFailed, .playbackStartFailed:
            return "Try restarting the app or check device audio settings."
        case .fileLoadError, .dataPlaybackError:
            return "Check the audio file and try again."
        case .audioSessionConfigurationFailed:
            return "Check device audio settings and permissions."
        }
    }
}

// MARK: - Audio Playback Extensions

extension AudioPlaybackService {
    
    /// Play audio with fade-in effect
    func playWithFadeIn(from url: URL, duration: TimeInterval = 1.0) async throws {
        try await play(from: url)
        
        guard let player = audioPlayer else { return }
        
        // Start with volume 0 and fade in
        let originalVolume = volume
        player.volume = 0
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let steps = 20
                let stepDuration = duration / Double(steps)
                let volumeIncrement = originalVolume / Float(steps)
                
                for step in 1...steps {
                    try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                    await MainActor.run {
                        player.volume = volumeIncrement * Float(step)
                    }
                }
            }
        }
    }
    
    /// Stop audio with fade-out effect
    func stopWithFadeOut(duration: TimeInterval = 1.0) async {
        guard let player = audioPlayer, isPlaying else {
            stop()
            return
        }
        
        let originalVolume = player.volume
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let steps = 20
                let stepDuration = duration / Double(steps)
                let volumeDecrement = originalVolume / Float(steps)
                
                for step in 1...steps {
                    try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                    await MainActor.run {
                        player.volume = originalVolume - (volumeDecrement * Float(step))
                    }
                }
                
                await MainActor.run {
                    self.stop()
                    player.volume = originalVolume // Restore for next playback
                }
            }
        }
    }
    
    /// Get audio file information without playing
    func getAudioInfo(from url: URL) throws -> AudioFileInfo {
        let player = try AVAudioPlayer(contentsOf: url)
        
        return AudioFileInfo(
            duration: player.duration,
            numberOfChannels: player.numberOfChannels,
            format: player.format.description,
            url: url
        )
    }
    
    /// Get audio data information without playing
    func getAudioInfo(from data: Data) throws -> AudioFileInfo {
        let player = try AVAudioPlayer(data: data)
        
        return AudioFileInfo(
            duration: player.duration,
            numberOfChannels: player.numberOfChannels,
            format: player.format.description,
            url: nil
        )
    }
}

// MARK: - Audio File Info
struct AudioFileInfo {
    let duration: TimeInterval
    let numberOfChannels: Int
    let format: String
    let url: URL?
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var channelDescription: String {
        switch numberOfChannels {
        case 1: return "Mono"
        case 2: return "Stereo"
        default: return "\(numberOfChannels) channels"
        }
    }
}
