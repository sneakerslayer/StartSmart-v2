import Foundation
import Combine

// MARK: - Audio Pipeline Service Protocol
protocol AudioPipelineServiceProtocol {
    func generateAndCacheAudio(forIntent intent: Intent) async throws -> AudioPipelineResult
    func getOrGenerateAudio(forIntent intent: Intent) async throws -> AudioPipelineResult
    func preGenerateAudio(forAlarm alarm: Alarm) async throws
    func clearExpiredAudio() async throws
    func getPipelineStatistics() async -> AudioPipelineStatistics
}

// MARK: - Audio Pipeline Result
struct AudioPipelineResult {
    let audioFilePath: String
    let textContent: String
    let duration: TimeInterval?
    let voiceId: String
    let generatedAt: Date
    let fromCache: Bool
    
    var audioURL: URL {
        URL(fileURLWithPath: audioFilePath)
    }
}

// MARK: - Audio Pipeline Statistics
struct AudioPipelineStatistics {
    let totalGenerations: Int
    let cacheHitRate: Double
    let averageGenerationTime: TimeInterval
    let totalCachedItems: Int
    let totalCacheSize: String
    let successfulGenerations: Int
    let failedGenerations: Int
    
    var successRate: Double {
        guard totalGenerations > 0 else { return 0.0 }
        return Double(successfulGenerations) / Double(totalGenerations)
    }
}

// MARK: - Audio Generation Status
enum AudioGenerationStatus {
    case idle
    case generatingText
    case convertingToSpeech
    case caching
    case completed
    case failed(Error)
}

// MARK: - Audio Pipeline Service Implementation
@MainActor
class AudioPipelineService: AudioPipelineServiceProtocol, ObservableObject {
    
    // MARK: - Dependencies
    private let aiService: Grok4ServiceProtocol
    private let ttsService: ElevenLabsServiceProtocol
    private let cacheService: AudioCacheServiceProtocol
    
    // MARK: - Published Properties
    @Published var generationStatus: AudioGenerationStatus = .idle
    @Published var pipelineStatistics: AudioPipelineStatistics
    
    // MARK: - Private Properties
    private var generationMetrics: GenerationMetrics
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        aiService: Grok4ServiceProtocol,
        ttsService: ElevenLabsServiceProtocol,
        cacheService: AudioCacheServiceProtocol
    ) {
        self.aiService = aiService
        self.ttsService = ttsService
        self.cacheService = cacheService
        self.generationMetrics = GenerationMetrics()
        self.pipelineStatistics = AudioPipelineStatistics(
            totalGenerations: 0,
            cacheHitRate: 0.0,
            averageGenerationTime: 0.0,
            totalCachedItems: 0,
            totalCacheSize: "0 MB",
            successfulGenerations: 0,
            failedGenerations: 0
        )
        
        setupStatisticsUpdates()
    }
    
    // MARK: - Public Interface
    
    func generateAndCacheAudio(forIntent intent: Intent) async throws -> AudioPipelineResult {
        let startTime = Date()
        generationStatus = .generatingText
        
        do {
            // Step 1: Generate text content using AI
            let textContent = try await generateTextContent(from: intent)
            
            // Step 2: Convert text to speech
            generationStatus = .convertingToSpeech
            let audioData = try await convertTextToSpeech(text: textContent, intent: intent)
            
            // Step 3: Cache the audio
            generationStatus = .caching
            let audioFilePath = try await cacheAudio(data: audioData, intent: intent, textContent: textContent)
            
            // Create result
            let result = AudioPipelineResult(
                audioFilePath: audioFilePath,
                textContent: textContent,
                duration: estimateAudioDuration(from: audioData),
                voiceId: getVoiceId(for: intent),
                generatedAt: Date(),
                fromCache: false
            )
            
            // Update metrics
            let generationTime = Date().timeIntervalSince(startTime)
            generationMetrics.recordSuccessfulGeneration(duration: generationTime)
            
            generationStatus = .completed
            await updateStatistics()
            
            return result
            
        } catch {
            generationMetrics.recordFailedGeneration()
            generationStatus = .failed(error)
            await updateStatistics()
            throw AudioPipelineError.generationFailed(error)
        }
    }
    
    func getOrGenerateAudio(forIntent intent: Intent) async throws -> AudioPipelineResult {
        // First, try to get from cache
        let cacheKey = createCacheKey(for: intent)
        
        if let cachedResult = try await cacheService.getCachedAudio(forKey: cacheKey) {
            generationMetrics.recordCacheHit()
            await updateStatistics()
            
            return AudioPipelineResult(
                audioFilePath: cachedResult.filePath,
                textContent: intent.generatedContent?.textContent ?? "",
                duration: cachedResult.metadata.duration,
                voiceId: cachedResult.metadata.voiceId,
                generatedAt: cachedResult.metadata.generatedAt,
                fromCache: true
            )
        }
        
        // If not in cache, generate new audio
        generationMetrics.recordCacheMiss()
        return try await generateAndCacheAudio(forIntent: intent)
    }
    
    func preGenerateAudio(forAlarm alarm: Alarm) async throws {
        // Pre-generate audio for alarms scheduled within the next 24 hours
        guard let nextTrigger = alarm.nextTriggerDate else {
            return
        }
        let timeUntilTrigger = nextTrigger.timeIntervalSinceNow
        
        // Only pre-generate if alarm is within next 24 hours
        guard timeUntilTrigger > 0 && timeUntilTrigger <= 24 * 3600 else {
            return
        }
        
        // Get the most recent intent for this alarm or create a default one
        let intent = alarm.mostRecentIntent ?? createDefaultIntent(for: alarm)
        
        do {
            _ = try await getOrGenerateAudio(forIntent: intent)
        } catch {
            print("Failed to pre-generate audio for alarm \(alarm.id): \(error)")
            // Don't throw error for pre-generation failures
        }
    }
    
    func clearExpiredAudio() async throws {
        try await cacheService.performMaintenance()
        await updateStatistics()
    }
    
    func getPipelineStatistics() async -> AudioPipelineStatistics {
        await updateStatistics()
        return pipelineStatistics
    }
    
    // MARK: - Private Methods
    
    private func generateTextContent(from intent: Intent) async throws -> String {
        let context = createContextDictionary(from: intent)
        
        return try await aiService.generateMotivationalScript(
            userIntent: intent.userGoal,
            tone: intent.tone.rawValue,
            context: context
        )
    }
    
    private func convertTextToSpeech(text: String, intent: Intent) async throws -> Data {
        let voiceId = getVoiceId(for: intent)
        
        // Get TTS options based on intent preferences
        let options = TTSGenerationOptions.production // Use high quality for cached audio
        
        return try await ttsService.generateSpeech(
            text: text,
            voiceId: voiceId,
            options: options
        )
    }
    
    private func cacheAudio(data: Data, intent: Intent, textContent: String) async throws -> String {
        let metadata = SimpleAudioMetadata(
            intentId: intent.id.uuidString,
            voiceId: getVoiceId(for: intent),
            duration: estimateAudioDuration(from: data),
            format: "mp3",
            quality: "high"
        )
        
        let cacheKey = createCacheKey(for: intent)
        return try await cacheService.cacheAudio(data: data, forKey: cacheKey, metadata: metadata)
    }
    
    private func createCacheKey(for intent: Intent) -> String {
        // Create a unique cache key based on intent content and preferences
        let baseKey = "\(intent.id)_\(intent.tone.rawValue)_\(intent.userGoal.prefix(50))"
        return baseKey.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
            .lowercased()
    }
    
    private func getVoiceId(for intent: Intent) -> String {
        // Map intent tone to voice ID (if we had access to ElevenLabsService.voiceConfigurations)
        // For now, use a simple mapping
        switch intent.tone.rawValue.lowercased() {
        case "gentle":
            return "21m00Tcm4TlvDq8ikWAM" // Rachel
        case "energetic":
            return "pNInz6obpgDQGcFmaJgB" // Adam
        case "tough_love", "tough love":
            return "VR6AewLTigWG4xSOukaG" // Arnold
        case "storyteller":
            return "CYw3kZ02Hs0563khs1Fj" // Dave
        default:
            return "21m00Tcm4TlvDq8ikWAM" // Default to Rachel
        }
    }
    
    private func createContextDictionary(from intent: Intent) -> [String: String] {
        var context: [String: String] = [:]
        
        // Add time-based context
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        context["current_time"] = formatter.string(from: now)
        context["day_of_week"] = Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: now) - 1]
        
        // Add intent-specific context
        if let customNote = intent.context.customNote {
            context["custom_note"] = customNote
        }
        
        formatter.timeStyle = .short
        context["target_time"] = formatter.string(from: intent.scheduledFor)
        
        // Add motivational context
        context["tone"] = intent.tone.rawValue
        context["user_goal"] = intent.userGoal
        
        return context
    }
    
    private func estimateAudioDuration(from data: Data) -> TimeInterval? {
        // Basic estimation: assume 128kbps MP3
        let estimatedBitrate: Double = 128 * 1000 / 8 // bytes per second
        return Double(data.count) / estimatedBitrate
    }
    
    private func createDefaultIntent(for alarm: Alarm) -> Intent {
        // Create a basic intent for alarms without specific intents
        return Intent(
            userGoal: "Wake up refreshed and ready for the day",
            tone: .gentle,
            context: IntentContext(),
            scheduledFor: alarm.time,
            alarmId: alarm.id
        )
    }
    
    private func setupStatisticsUpdates() {
        // Update statistics periodically
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateStatistics()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateStatistics() async {
        let cacheStats = await cacheService.getCacheStatistics()
        
        pipelineStatistics = AudioPipelineStatistics(
            totalGenerations: generationMetrics.totalGenerations,
            cacheHitRate: generationMetrics.cacheHitRate,
            averageGenerationTime: generationMetrics.averageGenerationTime,
            totalCachedItems: cacheStats.totalItems,
            totalCacheSize: cacheStats.formattedTotalSize,
            successfulGenerations: generationMetrics.successfulGenerations,
            failedGenerations: generationMetrics.failedGenerations
        )
    }
}

// MARK: - Generation Metrics
private class GenerationMetrics {
    var totalGenerations: Int = 0
    var successfulGenerations: Int = 0
    var failedGenerations: Int = 0
    private var totalGenerationTime: TimeInterval = 0
    private var cacheHits: Int = 0
    private var cacheRequests: Int = 0
    
    var cacheHitRate: Double {
        guard cacheRequests > 0 else { return 0.0 }
        return Double(cacheHits) / Double(cacheRequests)
    }
    
    var averageGenerationTime: TimeInterval {
        guard successfulGenerations > 0 else { return 0.0 }
        return totalGenerationTime / Double(successfulGenerations)
    }
    
    func recordSuccessfulGeneration(duration: TimeInterval) {
        totalGenerations += 1
        successfulGenerations += 1
        totalGenerationTime += duration
    }
    
    func recordFailedGeneration() {
        totalGenerations += 1
        failedGenerations += 1
    }
    
    func recordCacheHit() {
        cacheRequests += 1
        cacheHits += 1
    }
    
    func recordCacheMiss() {
        cacheRequests += 1
    }
}

// MARK: - Audio Pipeline Errors
enum AudioPipelineError: LocalizedError {
    case generationFailed(Error)
    case invalidIntent
    case ttsConversionFailed(Error)
    case cachingFailed(Error)
    case audioNotFound
    
    var errorDescription: String? {
        switch self {
        case .generationFailed(let error):
            return "Audio generation failed: \(error.localizedDescription)"
        case .invalidIntent:
            return "Invalid intent provided for audio generation"
        case .ttsConversionFailed(let error):
            return "Text-to-speech conversion failed: \(error.localizedDescription)"
        case .cachingFailed(let error):
            return "Audio caching failed: \(error.localizedDescription)"
        case .audioNotFound:
            return "Generated audio file not found"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .generationFailed:
            return "Check your internet connection and API keys, then try again."
        case .invalidIntent:
            return "Ensure the intent has valid content and preferences."
        case .ttsConversionFailed:
            return "Verify the text content and voice settings, then retry."
        case .cachingFailed:
            return "Check available storage space and cache permissions."
        case .audioNotFound:
            return "Try generating the audio again."
        }
    }
}

// MARK: - Extensions for Alarm and Intent Models

extension Alarm {
    var mostRecentIntent: Intent? {
        // This would need to be implemented based on how intents are associated with alarms
        // For now, return nil to use default intent
        return nil
    }
}

extension Intent {
    // Add convenience computed properties if needed
    var estimatedSpeechDuration: TimeInterval {
        // Rough estimation: ~150 words per minute, ~5 characters per word
        let estimatedWords = Double(userGoal.count) / 5.0
        return (estimatedWords / 150.0) * 60.0
    }
}
