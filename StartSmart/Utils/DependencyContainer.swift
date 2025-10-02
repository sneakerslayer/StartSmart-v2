import Foundation

// MARK: - Dependency Container Errors
enum DependencyContainerError: Error, LocalizedError {
    case initializationFailed
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize application dependencies"
        }
    }
}

// MARK: - Dependency Container Protocol
protocol DependencyContainerProtocol {
    func resolve<T>() -> T
    func register<T>(_ dependency: T, for type: T.Type)
}

// MARK: - Dependency Container Implementation
class DependencyContainer: DependencyContainerProtocol, ObservableObject {
    static let shared = DependencyContainer()
    
    private var dependencies: [String: Any] = [:]
    private let queue = DispatchQueue(label: "dependency.container", attributes: .concurrent)
    var isInitialized = false
    private let initializationQueue = DispatchQueue(label: "dependency.initialization")
    
    
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
    
    var onboardingDemoService: OnboardingDemoServiceProtocol {
        resolve()
    }
    
    private init() {
        print("🔥 DEBUG: DependencyContainer init() called")
        // Initialize dependencies asynchronously on background thread to avoid blocking UI
        Task.detached(priority: .high) { @MainActor in
            await self.setupDefaultDependencies()
        }
    }
    
    func register<T>(_ dependency: T, for type: T.Type) {
        let key = String(describing: type)
        queue.sync(flags: .barrier) {
            self.dependencies[key] = dependency
        }
    }
    
    func resolve<T>() -> T {
        // Wait for initialization to complete
        initializationQueue.sync {
            while !isInitialized {
                Thread.sleep(forTimeInterval: 0.001) // Wait 1ms
            }
        }
        
        let key = String(describing: T.self)
        return queue.sync {
            guard let dependency = dependencies[key] as? T else {
                fatalError("Dependency \(key) not registered")
            }
            return dependency
        }
    }
    
    // MARK: - Async Initialization for Production
    func initializeAsync() async throws {
        if isInitialized {
            return // Already initialized
        }
        
        await setupDefaultDependencies()
        
        // Verify initialization completed
        if !isInitialized {
            throw DependencyContainerError.initializationFailed
        }
    }
    
    @MainActor
    private func setupDefaultDependencies() async {
        print("DEBUG: Starting dependency setup...")
        print("DEBUG: About to start Stage 1...")
        
        do {
            // Stage 1: Core Services
            // Progress handled by ContentView
            print("DEBUG: Creating FirebaseService...")
            let firebaseService = FirebaseService()
            register(firebaseService, for: FirebaseServiceProtocol.self)
            print("DEBUG: Successfully registered FirebaseService")
            
        } catch {
            print("DEBUG: ERROR in Stage 1 - Firebase: \(error)")
            // Continue with basic service for now
            // updateProgress(1, stage: "Firebase Error - Using Fallback...")
        }
        
        do {
            // Stage 2: Authentication
            // updateProgress(2, stage: "Setting up Authentication...")
            print("DEBUG: Creating AuthenticationService...")
            let authService = AuthenticationService()
            register(authService, for: AuthenticationServiceProtocol.self)
            print("DEBUG: Successfully registered AuthenticationService")
            
        } catch {
            print("DEBUG: ERROR in Stage 2 - Auth: \(error)")
            // updateProgress(2, stage: "Auth Error - Using Fallback...")
        }
        
        do {
            // Stage 3: AI Services
            // updateProgress(3, stage: "Connecting AI Services...")
            print("DEBUG: Creating Grok4Service...")
            let grok4Service = Grok4Service(apiKey: ServiceConfiguration.APIKeys.grok4)
            register(grok4Service, for: Grok4ServiceProtocol.self)
            print("DEBUG: Successfully registered Grok4Service")
            
        } catch {
            print("DEBUG: ERROR in Stage 3 - Grok4: \(error)")
            // updateProgress(3, stage: "AI Service Error - Using Fallback...")
        }
        
        do {
            // Stage 4: Voice Services
            // updateProgress(4, stage: "Initializing Voice Engine...")
            print("DEBUG: Creating ElevenLabsService...")
            let elevenLabsService = ElevenLabsService(apiKey: ServiceConfiguration.APIKeys.elevenLabs)
            register(elevenLabsService, for: ElevenLabsServiceProtocol.self)
            print("DEBUG: Successfully registered ElevenLabsService")
            
        } catch {
            print("DEBUG: ERROR in Stage 4 - ElevenLabs: \(error)")
            // updateProgress(4, stage: "Voice Service Error - Using Fallback...")
        }
        
        #if DEBUG
        do {
            // Stage 4.5: Onboarding Demo Service (DEBUG only)
            print("DEBUG: Creating OnboardingDemoService...")
            let onboardingDemoService = OnboardingDemoService()
            register(onboardingDemoService, for: OnboardingDemoServiceProtocol.self)
            print("DEBUG: Successfully registered OnboardingDemoService")
        } catch {
            print("DEBUG: ERROR in Stage 4.5 - OnboardingDemo: \(error)")
        }
        #endif
        
        do {
            // Register Content Generation Service (combines both)
            print("DEBUG: Creating ContentGenerationService...")
            let grok4Service: Grok4ServiceProtocol = resolve()
            let elevenLabsService: ElevenLabsServiceProtocol = resolve()
            let contentService = ContentGenerationService(
                aiService: grok4Service,
                ttsService: elevenLabsService
            )
            register(contentService, for: ContentGenerationServiceProtocol.self)
            print("DEBUG: Successfully registered ContentGenerationService")
            
        } catch {
            print("DEBUG: ERROR creating ContentGenerationService: \(error)")
        }
        
        do {
            // Stage 5: Storage & Audio
            // updateProgress(5, stage: "Setting up Storage & Audio...")
            print("DEBUG: Creating UserDefaultsStorage...")
            let localStorage = UserDefaultsStorage()
            register(localStorage, for: LocalStorageProtocol.self)
            print("DEBUG: Successfully registered UserDefaultsStorage")
            
        } catch {
            print("DEBUG: ERROR in Stage 5 - Storage: \(error)")
            // updateProgress(5, stage: "Storage Error - Using Fallback...")
        }
        
        // MARK: - Phase 5 Audio Services Integration
        
        print("DEBUG: Starting Audio Services initialization...")
        
        // Register Audio Cache Service
        do {
            print("DEBUG: Creating AudioCacheService...")
            let audioCacheService = try AudioCacheService()
            register(audioCacheService, for: AudioCacheServiceProtocol.self)
            print("DEBUG: Successfully registered AudioCacheService")
            
            // Register Audio Playback Service
            print("DEBUG: Creating AudioPlaybackService...")
            let audioPlaybackService = AudioPlaybackService()
            register(audioPlaybackService, for: AudioPlaybackServiceProtocol.self)
            print("DEBUG: Successfully registered AudioPlaybackService")
            
            // Register Audio Pipeline Service (depends on cache service)
            print("DEBUG: Creating AudioPipelineService...")
            let grok4Service: Grok4ServiceProtocol = resolve()
            let elevenLabsService: ElevenLabsServiceProtocol = resolve()
            let audioPipelineService = AudioPipelineService(
                aiService: grok4Service,
                ttsService: elevenLabsService,
                cacheService: audioCacheService
            )
            register(audioPipelineService, for: AudioPipelineServiceProtocol.self)
            print("DEBUG: Successfully registered AudioPipelineService")
            
            // Register Alarm Audio Service (orchestrates audio generation for alarms)
            print("DEBUG: Creating AlarmAudioService...")
            let alarmAudioService = AlarmAudioService(
                audioPipelineService: audioPipelineService,
                intentRepository: IntentRepository(),
                alarmRepository: AlarmRepository(
                    notificationService: NotificationService()
                )
            )
            register(alarmAudioService, for: AlarmAudioServiceProtocol.self)
            print("DEBUG: Successfully registered AlarmAudioService")
            
            // Register Speech Recognition Service
            print("DEBUG: Creating SpeechRecognitionService...")
            let speechRecognitionService = SpeechRecognitionService()
            register(speechRecognitionService, for: SpeechRecognitionServiceProtocol.self)
            print("DEBUG: Successfully registered SpeechRecognitionService")
            
        } catch {
            print("DEBUG: ERROR in Audio Services: \(error)")
            print("DEBUG: Audio pipeline services will not be available.")
            // Continue without audio services for now
        }
        
        // MARK: - Phase 7 Gamification Services
        do {
            // updateProgress(6, stage: "Loading Gamification...")
            print("DEBUG: Creating Gamification Services...")
            
            // Register User View Model
            let userViewModel = UserViewModel()
            register(userViewModel, for: UserViewModel.self)
            print("DEBUG: Successfully registered UserViewModel")
            
            // Register Streak Tracking Service
            let localStorage: LocalStorageProtocol = resolve()
            let streakTrackingService = StreakTrackingService(storage: localStorage)
            register(streakTrackingService, for: StreakTrackingServiceProtocol.self)
            print("DEBUG: Successfully registered StreakTrackingService")
            
            // Register Social Sharing Service
            let socialSharingService = SocialSharingService(storage: localStorage)
            register(socialSharingService, for: SocialSharingServiceProtocol.self)
            print("DEBUG: Successfully registered SocialSharingService")
            
        } catch {
            print("DEBUG: ERROR in Stage 6 - Gamification: \(error)")
            // updateProgress(6, stage: "Gamification Error - Using Fallback...")
        }
        
        // MARK: - Phase 8 Subscription Services
        do {
            // updateProgress(7, stage: "Configuring Subscriptions...")
            print("DEBUG: Creating Subscription Services...")
            
            // Register Subscription Service
            let subscriptionService = SubscriptionService()
            register(subscriptionService, for: SubscriptionServiceProtocol.self)
            print("DEBUG: Successfully registered SubscriptionService")
            
            // Register Subscription Manager
            let localStorage: LocalStorageProtocol = resolve()
            let subscriptionManager = SubscriptionManager(
                subscriptionService: subscriptionService,
                localStorage: localStorage
            )
            register(subscriptionManager, for: SubscriptionManagerProtocol.self)
            print("DEBUG: Successfully registered SubscriptionManager")
            
        } catch {
            print("DEBUG: ERROR in Stage 7 - Subscriptions: \(error)")
            // updateProgress(7, stage: "Subscription Error - Using Fallback...")
        }
        
        print("DEBUG: All dependencies registered successfully")
        
        // Stage 8: Finalization
        // updateProgress(8, stage: "Ready!")
        
        // Mark initialization as complete
        initializationQueue.sync {
            self.isInitialized = true
            print("DEBUG: isInitialized set to true")
        }
    } // End of setupDefaultDependencies
}

// MARK: - Convenience Properties
extension DependencyContainer {
    // Phase 7 Services
    var streakTrackingService: StreakTrackingServiceProtocol {
        resolve()
    }
    
    var socialSharingService: SocialSharingServiceProtocol {
        resolve()
    }
    
    // Existing services (for easy access in Phase 7 integration)
    var userViewModel: UserViewModel {
        resolve()
    }
    
    // Phase 8 Services
    var subscriptionService: SubscriptionServiceProtocol {
        resolve()
    }
    
    var subscriptionManager: SubscriptionManagerProtocol {
        resolve()
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
