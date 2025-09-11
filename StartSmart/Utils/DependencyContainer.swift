import Foundation

// MARK: - Dependency Container Protocol
protocol DependencyContainerProtocol {
    func resolve<T>() -> T
    func register<T>(_ dependency: T, for type: T.Type)
}

// MARK: - Dependency Container Implementation
class DependencyContainer: DependencyContainerProtocol {
    static let shared = DependencyContainer()
    
    private var dependencies: [String: Any] = [:]
    private let queue = DispatchQueue(label: "dependency.container", attributes: .concurrent)
    
    // MARK: - Convenience Properties
    var firebaseService: FirebaseServiceProtocol {
        resolve()
    }
    
    var authenticationService: AuthenticationServiceProtocol {
        resolve()
    }
    
    var audioCacheService: AudioCacheServiceProtocol {
        resolve()
    }
    
    var audioPlaybackService: AudioPlaybackServiceProtocol {
        resolve()
    }
    
    var audioPipelineService: AudioPipelineServiceProtocol {
        resolve()
    }
    
    var alarmAudioService: AlarmAudioServiceProtocol {
        resolve()
    }
    
    var speechRecognitionService: SpeechRecognitionServiceProtocol {
        resolve()
    }
    
    private init() {
        setupDefaultDependencies()
    }
    
    func register<T>(_ dependency: T, for type: T.Type) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.dependencies[key] = dependency
        }
    }
    
    func resolve<T>() -> T {
        let key = String(describing: T.self)
        return queue.sync {
            guard let dependency = dependencies[key] as? T else {
                fatalError("Dependency \(key) not registered")
            }
            return dependency
        }
    }
    
    private func setupDefaultDependencies() {
        // Register Firebase Service
        let firebaseService = FirebaseService()
        register(firebaseService, for: FirebaseServiceProtocol.self)
        
        // Register Authentication Service
        let authService = AuthenticationService()
        register(authService, for: AuthenticationServiceProtocol.self)
        
        // Register AI Content Service
        let grok4Service = Grok4Service(apiKey: ServiceConfiguration.APIKeys.grok4)
        register(grok4Service, for: Grok4ServiceProtocol.self)
        
        // Register TTS Service
        let elevenLabsService = ElevenLabsService(apiKey: ServiceConfiguration.APIKeys.elevenLabs)
        register(elevenLabsService, for: ElevenLabsServiceProtocol.self)
        
        // Register Content Generation Service (combines both)
        let contentService = ContentGenerationService(
            aiService: grok4Service,
            ttsService: elevenLabsService
        )
        register(contentService, for: ContentGenerationServiceProtocol.self)
        
        // Register Local Storage Service
        let localStorage = LocalStorage()
        register(localStorage, for: LocalStorageProtocol.self)
        
        // MARK: - Phase 5 Audio Services Integration
        
        // Register Audio Cache Service
        do {
            let audioCacheService = try AudioCacheService()
            register(audioCacheService, for: AudioCacheServiceProtocol.self)
            
            // Register Audio Playback Service
            let audioPlaybackService = AudioPlaybackService()
            register(audioPlaybackService, for: AudioPlaybackServiceProtocol.self)
            
            // Register Audio Pipeline Service (depends on cache service)
            let audioPipelineService = AudioPipelineService(
                aiService: grok4Service,
                ttsService: elevenLabsService,
                cacheService: audioCacheService
            )
            register(audioPipelineService, for: AudioPipelineServiceProtocol.self)
            
            // Register Alarm Audio Service (orchestrates audio generation for alarms)
            let alarmAudioService = AlarmAudioService(
                audioPipelineService: audioPipelineService,
                intentRepository: IntentRepository(localStorage: localStorage),
                alarmRepository: AlarmRepository(
                    localStorage: localStorage,
                    notificationService: NotificationService()
                )
            )
            register(alarmAudioService, for: AlarmAudioServiceProtocol.self)
            
            // Register Speech Recognition Service
            let speechRecognitionService = SpeechRecognitionService()
            register(speechRecognitionService, for: SpeechRecognitionServiceProtocol.self)
            
        } catch {
            print("Warning: Failed to initialize AudioCacheService: \(error)")
            print("Audio pipeline services will not be available.")
            // In a production app, you might want to register mock implementations
        }
    }
}

// MARK: - Property Wrapper for Dependency Injection
@propertyWrapper
struct Injected<T> {
    private let container: DependencyContainerProtocol
    
    var wrappedValue: T {
        container.resolve()
    }
    
    init(container: DependencyContainerProtocol = DependencyContainer.shared) {
        self.container = container
    }
}

// MARK: - Content Generation Service (Combines AI + TTS)
protocol ContentGenerationServiceProtocol {
    func generateAlarmContent(userIntent: String, tone: String, context: [String: String]) async throws -> AlarmContent
    func generateContentForIntent(_ intent: Intent) async throws -> GeneratedContent
    func processIntentQueue() async throws
    func getGenerationStatus() -> ContentGenerationStatus
}

struct AlarmContent {
    let text: String
    let audioData: Data
    let metadata: AlarmContentMetadata
}

struct AlarmContentMetadata {
    let generatedAt: Date
    let wordCount: Int
    let estimatedDuration: TimeInterval
    let voiceId: String
    let tone: String
}

// MARK: - Content Generation Status
enum ContentGenerationStatus: Equatable {
    case idle
    case generating(intentId: UUID, progress: Double)
    case completed(intentId: UUID)
    case failed(intentId: UUID, error: Error)
    
    static func == (lhs: ContentGenerationStatus, rhs: ContentGenerationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.generating(let lhsId, let lhsProgress), .generating(let rhsId, let rhsProgress)):
            return lhsId == rhsId && lhsProgress == rhsProgress
        case (.completed(let lhsId), .completed(let rhsId)):
            return lhsId == rhsId
        case (.failed(let lhsId, _), .failed(let rhsId, _)):
            return lhsId == rhsId
        default:
            return false
        }
    }
}

// MARK: - Content Generation Errors
enum ContentGenerationError: LocalizedError {
    case generationFailed(UUID, Error)
    case invalidIntent(UUID)
    case serviceUnavailable
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .generationFailed(let intentId, let error):
            return "Content generation failed for intent \(intentId.uuidString.prefix(8)): \(error.localizedDescription)"
        case .invalidIntent(let intentId):
            return "Invalid intent: \(intentId.uuidString.prefix(8))"
        case .serviceUnavailable:
            return "Content generation service is currently unavailable"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        }
    }
}

class ContentGenerationService: ContentGenerationServiceProtocol {
    private let aiService: Grok4ServiceProtocol
    private let ttsService: ElevenLabsServiceProtocol
    private var currentStatus: ContentGenerationStatus = .idle
    private var generationQueue: [UUID] = []
    private let maxConcurrentGenerations = 3
    
    init(aiService: Grok4ServiceProtocol, ttsService: ElevenLabsServiceProtocol) {
        self.aiService = aiService
        self.ttsService = ttsService
    }
    
    func generateAlarmContent(userIntent: String, tone: String, context: [String: String]) async throws -> AlarmContent {
        // Generate text content using Grok4
        let text = try await aiService.generateMotivationalScript(
            userIntent: userIntent,
            tone: tone,
            context: context
        )
        
        // Convert to speech using ElevenLabs
        let voiceId = (ttsService as? ElevenLabsService)?.getVoiceId(for: tone) ?? "default"
        let audioData = try await ttsService.generateSpeech(text: text, voiceId: voiceId)
        
        // Create metadata
        let metadata = AlarmContentMetadata(
            generatedAt: Date(),
            wordCount: text.split(separator: " ").count,
            estimatedDuration: TimeInterval(text.count / 10), // Rough estimate: ~10 chars per second
            voiceId: voiceId,
            tone: tone
        )
        
        return AlarmContent(
            text: text,
            audioData: audioData,
            metadata: metadata
        )
    }
    
    func generateContentForIntent(_ intent: Intent) async throws -> GeneratedContent {
        let startTime = Date()
        
        // Update status
        currentStatus = .generating(intentId: intent.id, progress: 0.0)
        
        do {
            // Step 1: Generate text content (60% of progress)
            currentStatus = .generating(intentId: intent.id, progress: 0.2)
            let textContent = try await aiService.generateContentForIntent(intent)
            
            currentStatus = .generating(intentId: intent.id, progress: 0.6)
            
            // Step 2: Generate audio content (30% of progress)
            let voiceId = (ttsService as? ElevenLabsService)?.getVoiceId(for: intent.tone.rawValue) ?? "default"
            let audioData = try await ttsService.generateSpeech(text: textContent, voiceId: voiceId)
            
            currentStatus = .generating(intentId: intent.id, progress: 0.9)
            
            // Step 3: Create metadata and finalize (10% of progress)
            let generationTime = Date().timeIntervalSince(startTime)
            let metadata = ContentMetadata(
                textContent: textContent,
                tone: intent.tone,
                aiModel: "grok4",
                ttsModel: "elevenlabs",
                generationTime: generationTime
            )
            
            let generatedContent = GeneratedContent(
                textContent: textContent,
                audioData: audioData,
                voiceId: voiceId,
                metadata: metadata
            )
            
            currentStatus = .completed(intentId: intent.id)
            
            // Auto-reset status after delay
            Task {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                if case .completed = currentStatus {
                    currentStatus = .idle
                }
            }
            
            return generatedContent
            
        } catch {
            currentStatus = .failed(intentId: intent.id, error: error)
            
            // Auto-reset status after delay
            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                if case .failed = currentStatus {
                    currentStatus = .idle
                }
            }
            
            throw ContentGenerationError.generationFailed(intent.id, error)
        }
    }
    
    func processIntentQueue() async throws {
        // This would be implemented to process multiple intents
        // For now, it's a placeholder for future batch processing
        currentStatus = .idle
    }
    
    func getGenerationStatus() -> ContentGenerationStatus {
        return currentStatus
    }
}
