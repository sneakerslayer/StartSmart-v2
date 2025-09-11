import Foundation
import Combine

// MARK: - Alarm Audio Service Protocol
protocol AlarmAudioServiceProtocol {
    func generateAudioForAlarm(_ alarm: Alarm) async throws -> AlarmGeneratedContent
    func preGenerateAudioForUpcomingAlarms() async throws
    func ensureAudioForAlarm(_ alarm: Alarm) async throws -> Alarm
    func clearExpiredAudioContent() async throws
    func getAudioGenerationStatus() -> AudioGenerationStatus
}

// MARK: - Audio Generation Status
enum AudioGenerationStatus {
    case idle
    case generating(alarmId: UUID)
    case completed(alarmId: UUID)
    case failed(alarmId: UUID, error: Error)
}

// MARK: - Alarm Audio Service Error
enum AlarmAudioServiceError: LocalizedError {
    case alarmNotFound
    case intentNotFound
    case audioGenerationFailed(Error)
    case audioCachingFailed(Error)
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .alarmNotFound:
            return "Alarm not found"
        case .intentNotFound:
            return "No intent found for audio generation"
        case .audioGenerationFailed(let error):
            return "Audio generation failed: \(error.localizedDescription)"
        case .audioCachingFailed(let error):
            return "Audio caching failed: \(error.localizedDescription)"
        case .serviceUnavailable:
            return "Audio generation service is unavailable"
        }
    }
}

// MARK: - Alarm Audio Service Implementation
class AlarmAudioService: AlarmAudioServiceProtocol, ObservableObject {
    @Published private var currentStatus: AudioGenerationStatus = .idle
    
    private let audioPipelineService: AudioPipelineServiceProtocol
    private let intentRepository: IntentRepositoryProtocol
    private let alarmRepository: AlarmRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        audioPipelineService: AudioPipelineServiceProtocol,
        intentRepository: IntentRepositoryProtocol,
        alarmRepository: AlarmRepositoryProtocol
    ) {
        self.audioPipelineService = audioPipelineService
        self.intentRepository = intentRepository
        self.alarmRepository = alarmRepository
    }
    
    // MARK: - Public Methods
    func generateAudioForAlarm(_ alarm: Alarm) async throws -> AlarmGeneratedContent {
        currentStatus = .generating(alarmId: alarm.id)
        
        do {
            // Find the most recent intent matching the alarm's tone
            let intents = await intentRepository.getIntents()
            let matchingIntent = findBestIntentForAlarm(alarm, from: intents)
            
            guard let intent = matchingIntent else {
                // Create a default intent if none exists
                let defaultIntent = createDefaultIntent(for: alarm)
                let result = try await audioPipelineService.generateAndCacheAudio(forIntent: defaultIntent)
                let content = convertToAlarmContent(result, for: alarm)
                currentStatus = .completed(alarmId: alarm.id)
                return content
            }
            
            // Generate audio using the intent
            let result = try await audioPipelineService.generateAndCacheAudio(forIntent: intent)
            let content = convertToAlarmContent(result, for: alarm)
            
            currentStatus = .completed(alarmId: alarm.id)
            
            // Auto-reset status after delay
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                if case .completed = currentStatus {
                    currentStatus = .idle
                }
            }
            
            return content
            
        } catch {
            currentStatus = .failed(alarmId: alarm.id, error: error)
            
            // Auto-reset status after delay
            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                if case .failed = currentStatus {
                    currentStatus = .idle
                }
            }
            
            throw AlarmAudioServiceError.audioGenerationFailed(error)
        }
    }
    
    func preGenerateAudioForUpcomingAlarms() async throws {
        let alarms = await alarmRepository.getAlarms()
        let upcomingAlarms = alarms.filter { alarm in
            guard alarm.isEnabled else { return false }
            
            // Check if alarm is in next 24 hours
            if let nextTrigger = alarm.nextTriggerDate {
                let timeUntilTrigger = nextTrigger.timeIntervalSinceNow
                return timeUntilTrigger > 0 && timeUntilTrigger <= 24 * 60 * 60 // 24 hours
            }
            
            return false
        }
        
        for alarm in upcomingAlarms {
            if alarm.needsAudioGeneration {
                do {
                    let generatedContent = try await generateAudioForAlarm(alarm)
                    var updatedAlarm = alarm
                    updatedAlarm.setGeneratedContent(generatedContent)
                    
                    try await alarmRepository.updateAlarm(updatedAlarm)
                    
                    print("Pre-generated audio for alarm: \(alarm.label) at \(alarm.timeDisplayString)")
                } catch {
                    print("Failed to pre-generate audio for alarm \(alarm.id): \(error)")
                    // Continue with other alarms
                }
            }
        }
    }
    
    func ensureAudioForAlarm(_ alarm: Alarm) async throws -> Alarm {
        guard alarm.needsAudioGeneration else {
            return alarm // Already has valid audio
        }
        
        let generatedContent = try await generateAudioForAlarm(alarm)
        var updatedAlarm = alarm
        updatedAlarm.setGeneratedContent(generatedContent)
        
        return updatedAlarm
    }
    
    func clearExpiredAudioContent() async throws {
        let alarms = await alarmRepository.getAlarms()
        
        for alarm in alarms {
            if let content = alarm.generatedContent, content.isExpired {
                var updatedAlarm = alarm
                updatedAlarm.clearGeneratedContent()
                
                try await alarmRepository.updateAlarm(updatedAlarm)
                
                // Remove the expired audio file
                try? FileManager.default.removeItem(at: content.audioURL)
            }
        }
    }
    
    func getAudioGenerationStatus() -> AudioGenerationStatus {
        return currentStatus
    }
    
    // MARK: - Private Helper Methods
    private func findBestIntentForAlarm(_ alarm: Alarm, from intents: [Intent]) -> Intent? {
        // Find intent that matches the alarm's tone and is most recent
        let matchingIntents = intents.filter { intent in
            intent.tone == alarm.tone && !intent.content.isEmpty
        }
        
        return matchingIntents.max { $0.createdAt < $1.createdAt }
    }
    
    private func createDefaultIntent(for alarm: Alarm) -> Intent {
        let defaultGoals = [
            .gentle: "Start the day peacefully and with gratitude",
            .energetic: "Wake up with energy and excitement for the day ahead",
            .toughLove: "Get up immediately and tackle the day's challenges",
            .storyteller: "Begin the day with inspiration and purpose"
        ]
        
        return Intent(
            id: UUID(),
            goal: defaultGoals[alarm.tone] ?? "Wake up feeling motivated",
            tone: alarm.tone,
            context: IntentContext(
                customNotes: alarm.label.isEmpty ? nil : alarm.label,
                includeWeather: true,
                includeCalendarEvents: false,
                includeLocation: false
            )
        )
    }
    
    private func convertToAlarmContent(_ result: AudioPipelineResult, for alarm: Alarm) -> AlarmGeneratedContent {
        return AlarmGeneratedContent(
            textContent: result.textContent,
            audioFilePath: result.audioFilePath,
            voiceId: result.voiceId,
            generatedAt: result.generatedAt,
            duration: result.duration,
            intentId: nil // We'll set this if we have intent tracking
        )
    }
}

// MARK: - Background Audio Generation Extension
extension AlarmAudioService {
    /// Schedule background audio generation for all upcoming alarms
    /// This should be called during app backgrounding or at strategic times
    func scheduleBackgroundAudioGeneration() {
        Task {
            do {
                try await preGenerateAudioForUpcomingAlarms()
                try await clearExpiredAudioContent()
            } catch {
                print("Background audio generation failed: \(error)")
            }
        }
    }
}
