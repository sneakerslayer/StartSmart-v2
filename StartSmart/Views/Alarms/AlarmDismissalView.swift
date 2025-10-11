import SwiftUI
import AVFoundation

struct AlarmDismissalView: View {
    let alarm: Alarm
    let onDismiss: () -> Void
    
    @StateObject private var audioPlayer = AlarmAudioPlayer()
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // Alarm Title
                VStack(spacing: 8) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text(alarm.label.isEmpty ? "Alarm" : alarm.label)
                        .font(.title.bold())
                    
                    Text(alarm.time, style: .time)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Audio Playback Card
                VStack(spacing: 16) {
                    // Waveform animation
                    HStack(spacing: 4) {
                        ForEach(0..<20, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isPlaying ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 3, height: CGFloat.random(in: 20...60))
                                .animation(
                                    isPlaying ?
                                    .easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(index) * 0.05)
                                    : .default,
                                    value: isPlaying
                                )
                        }
                    }
                    .frame(height: 60)
                    
                    // Playback Progress
                    ProgressView(value: playbackProgress)
                        .tint(.blue)
                    
                    // Status Text
                    Text(isPlaying ? "Playing your AI script..." : "Ready to play")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    if !isPlaying {
                        Button(action: { playAudio() }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play AI Script")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    } else {
                        Button(action: { stopAudio() }) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: {
                        stopAudio()
                        onDismiss()
                    }) {
                        Text("Dismiss")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.blue, lineWidth: 2)
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(action: {
                stopAudio()
                onDismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            })
            .onAppear {
                // Auto-play the AI script when view appears
                playAudio()
            }
            .onDisappear {
                stopAudio()
            }
        }
    }
    
    private func playAudio() {
        guard let audioURL = alarm.audioFileURL else {
            print("❌ No audio URL for alarm")
            return
        }
        
        audioPlayer.play(from: audioURL) { progress in
            playbackProgress = progress
        } onComplete: {
            isPlaying = false
            playbackProgress = 0
        }
        
        isPlaying = true
    }
    
    private func stopAudio() {
        audioPlayer.stop()
        isPlaying = false
        playbackProgress = 0
    }
}

// MARK: - Audio Player
@MainActor
class AlarmAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    private var progressCallback: ((Double) -> Void)?
    private var completionCallback: (() -> Void)?
    private var timer: Timer?
    
    func play(from url: URL, onProgress: @escaping (Double) -> Void, onComplete: @escaping () -> Void) {
        stop()
        
        self.progressCallback = onProgress
        self.completionCallback = onComplete
        
        do {
            // Configure audio session for alarm playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            
            // Create and configure player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            // Start progress timer
            startProgressTimer()
            
            print("✅ Playing audio from: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to play audio: \(error)")
            completionCallback?()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func startProgressTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let player = self.audioPlayer,
                  player.duration > 0 else { return }
            
            let progress = player.currentTime / player.duration
            self.progressCallback?(progress)
        }
    }
    
    // AVAudioPlayerDelegate
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
            self.completionCallback?()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("❌ Audio decode error: \(error?.localizedDescription ?? "unknown")")
            self.stop()
            self.completionCallback?()
        }
    }
}

#Preview {
    AlarmDismissalView(
        alarm: Alarm(
            id: UUID(),
            time: Date(),
            label: "Wake Up!",
            isEnabled: true,
            repeatDays: [],
            snoozeEnabled: true,
            tone: .motivational,
            useTraditionalSound: false,
            traditionalSound: .classic,
            useAIScript: true
        ),
        onDismiss: {}
    )
}

