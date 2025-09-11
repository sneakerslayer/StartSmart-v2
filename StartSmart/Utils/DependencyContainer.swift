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

class ContentGenerationService: ContentGenerationServiceProtocol {
    private let aiService: Grok4ServiceProtocol
    private let ttsService: ElevenLabsServiceProtocol
    
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
}
