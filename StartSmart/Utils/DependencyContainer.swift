import Foundation
import Combine

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

/// Protocol defining the dependency injection container interface.
/// Provides methods for registering and resolving dependencies throughout the application.
protocol DependencyContainerProtocol {
    /// Resolves a dependency of the specified type.
    /// - Returns: An instance of the requested type
    /// - Throws: DependencyContainerError if the dependency is not registered
    func resolve<T>() -> T
    
    /// Registers a dependency instance for a specific type.
    /// - Parameters:
    ///   - dependency: The instance to register
    ///   - type: The type to register the dependency for
    func register<T>(_ dependency: T, for type: T.Type)
}

// MARK: - Dependency Container Implementation

/// Centralized dependency injection container for the StartSmart application.
/// 
/// This container manages the lifecycle and resolution of all application dependencies,
/// using a two-stage initialization process for optimal startup performance:
/// - Stage 1: Essential services needed for UI functionality
/// - Stage 2: Heavy services loaded in background
class DependencyContainer: DependencyContainerProtocol, ObservableObject {
    static let shared = DependencyContainer()
    
    private var dependencies: [String: Any] = [:]
    private let queue = DispatchQueue(label: "dependency.container", attributes: .concurrent)
    
    // ✅ Two-stage initialization
    @Published var isInitialized = false        // Essential services (UI can proceed)
    @Published var isFullyInitialized = false   // All services loaded
    
    private var isInitializing = false
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
        // Start initialization immediately but don't block
        Task.detached(priority: .userInitiated) {
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
        let key = String(describing: T.self)
        
        let dependency = queue.sync { 
            return dependencies[key] as? T 
        }
        
        if let dependency = dependency {
            return dependency
        }
        
        // Check initialization status
        let initialized = initializationQueue.sync { 
            return isInitialized 
        }
        
        if !initialized {
            fatalError("Dependency \(key) requested before container initialized")
        }
        fatalError("Dependency \(key) not registered")
    }

    // ✅ FIXED: Safe resolve that waits for full initialization
    func resolveSafe<T>() async -> T? {
        let key = String(describing: T.self)
        
        // If already available, return immediately
        if let dependency = queue.sync(execute: { self.dependencies[key] as? T }) {
            return dependency
        }
        
        // Wait for full initialization with timeout (30 seconds max)
        let timeoutDeadline = Date().addingTimeInterval(30.0)
        while !isFullyInitialized && Date() < timeoutDeadline {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Return dependency if found, nil if timeout
        if isFullyInitialized {
            return queue.sync(execute: { self.dependencies[key] as? T })
        }
        
        print("⚠️ WARNING: resolveSafe timed out waiting for \(key) initialization")
        return nil
    }

    // ✅ FIXED: Safe async resolve - replaces broken double-resume version
    // No longer uses nested CheckedContinuation which caused double-resume crashes
    func resolveAsync<T>() async throws -> T {
        let key = String(describing: T.self)
        
        // ✅ SAFE POLLING: Wait for initialization using pure async/await
        // Continues polling through entire timeout, even after isInitialized becomes true
        // This ensures Stage 2 services that load asynchronously are properly waited for
        let maxWaitTime: TimeInterval = 30.0 // 30 second timeout
        let timeoutDeadline = Date().addingTimeInterval(maxWaitTime)
        
        while Date() < timeoutDeadline {
            // Try to resolve the dependency (works if already registered)
            if let dependency = queue.sync(execute: { self.dependencies[key] as? T }) {
                return dependency
            }
            
            // Check if we should continue polling
            let initialized = initializationQueue.sync { self.isInitialized }
            let fullyInitialized = self.isFullyInitialized
            
            // If fully initialized and still not found, something is wrong
            if fullyInitialized {
                throw DependencyContainerError.initializationFailed
            }
            
            // Wait before checking again - using pure async/await, not continuations
            // Shorter sleep (50ms) for better responsiveness once initialization completes
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms checks
        }
        
        // Timeout occurred
        print("❌ ERROR: Timeout waiting for dependency \(key) - initialization took >30s")
        throw DependencyContainerError.initializationFailed
    }
    
    // MARK: - ✅ OPTIMIZED: Two-Stage Initialization
    @MainActor
    private func setupDefaultDependencies() async {
        let startTime = Date()
        print("⚡ FAST STARTUP: Stage 1 - Essential Services Only")
        
        var firebaseService: FirebaseServiceProtocol!
        
        // ========== STAGE 1: ESSENTIAL SERVICES (Fast) ==========
        // These are needed for UI to function
        
        // 1. Firebase (needed for auth)
        do {
            firebaseService = FirebaseService()
            register(firebaseService, for: FirebaseServiceProtocol.self)
            print("✅ FirebaseService ready")
        }
        
        // 2. Authentication (needed for login/signup)
        do {
            let userViewModel = UserViewModel()
            let authService = AuthenticationService(firebaseService: firebaseService, userViewModel: userViewModel)
            register(authService, for: AuthenticationServiceProtocol.self)
            register(userViewModel, for: UserViewModel.self)
            print("✅ AuthenticationService ready")
        }
        
        // 3. Storage (needed for user preferences)
        do {
            let localStorage = UserDefaultsStorage()
            register(localStorage, for: LocalStorageProtocol.self)
            print("✅ Storage ready")
        }
        
        // 4. Subscriptions (needed for paywall)
        do {
            let subscriptionService = SubscriptionService()
            register(subscriptionService, for: SubscriptionServiceProtocol.self)
            
            let localStorage: LocalStorageProtocol = resolve()
            let subscriptionManager = SubscriptionManager(
                subscriptionService: subscriptionService,
                localStorage: localStorage
            )
            register(subscriptionManager, for: SubscriptionManagerProtocol.self)
            
            // ✅ NEW: Register SubscriptionStateManager in Stage 1 (needed for Settings and onboarding)
            let subscriptionStateManager = SubscriptionStateManager(subscriptionService: subscriptionService)
            register(subscriptionStateManager, for: SubscriptionStateManager.self)
            
            print("✅ Subscription services ready")
        }
        
        // 5. Alarms (using AlarmKit for reliable alarm functionality)
        do {
            let alarmRepository = AlarmRepository()
            register(alarmRepository, for: AlarmRepositoryProtocol.self)
            
            print("✅ Alarm services ready (AlarmKit)")
        }
        
        // ✅ MARK STAGE 1 COMPLETE - UI CAN PROCEED
        let stage1Time = Date().timeIntervalSince(startTime)
        initializationQueue.sync {
            self.isInitialized = true
            self.isInitializing = false
        }
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("⚡ STAGE 1 COMPLETE in \(Int(stage1Time * 1000))ms - UI READY")
        print("🔄 Starting Stage 2 in background...")
        
        // ========== STAGE 2: HEAVY SERVICES (Background) ==========
        // These load while user interacts with UI
        
        Task.detached(priority: .userInitiated) {
            let stage2Start = Date()
            
            // AI Services (Grok4, ElevenLabs)
            await self.initializeAIServices(firebaseService: firebaseService)
            
            // Audio Services (cache, playback, pipeline)
            await self.initializeAudioServices()
            
            // Gamification (streaks, social)
            await self.initializeGamificationServices()
            
            let stage2Time = Date().timeIntervalSince(stage2Start)
            
            // ✅ FIXED: Mark fully initialized on main thread
            await MainActor.run {
                self.isFullyInitialized = true
                self.objectWillChange.send()
            }
            
            let totalTime = Date().timeIntervalSince(startTime)
            print("✅ STAGE 2 COMPLETE in \(Int(stage2Time * 1000))ms")
            print("🎉 ALL SERVICES LOADED - Total time: \(Int(totalTime * 1000))ms")
        }
    }
    
    // MARK: - Background Service Initialization
    @MainActor
    private func initializeAIServices(firebaseService: FirebaseServiceProtocol) async {
        do {
            let grok4Service = Grok4Service(apiKey: ServiceConfiguration.APIKeys.grok4)
            register(grok4Service, for: Grok4ServiceProtocol.self)
            
            let elevenLabsService = ElevenLabsService(apiKey: ServiceConfiguration.APIKeys.elevenLabs)
            register(elevenLabsService, for: ElevenLabsServiceProtocol.self)
            
            let contentService = ContentGenerationService(
                    aiService: grok4Service,
                    ttsService: elevenLabsService
                )
            register(contentService, for: ContentGenerationServiceProtocol.self)
            
            print("✅ AI services ready")
        }
    }
    
    @MainActor
    private func initializeAudioServices() async {
        do {
            let audioCacheService = try AudioCacheService()
            register(audioCacheService, for: AudioCacheServiceProtocol.self)
            
            let audioPlaybackService = AudioPlaybackService()
            register(audioPlaybackService, for: AudioPlaybackServiceProtocol.self)
            
            let grok4Service: Grok4ServiceProtocol = resolve()
            let elevenLabsService: ElevenLabsServiceProtocol = resolve()
            let audioPipelineService = AudioPipelineService(
                    aiService: grok4Service,
                    ttsService: elevenLabsService,
                    cacheService: audioCacheService
                )
            register(audioPipelineService, for: AudioPipelineServiceProtocol.self)
            
            let alarmAudioService = AlarmAudioService(
                    audioPipelineService: audioPipelineService,
                    intentRepository: IntentRepository(),
                    alarmRepository: AlarmRepository()
                )
            register(alarmAudioService, for: AlarmAudioServiceProtocol.self)
            
            let speechRecognitionService = SpeechRecognitionService()
            register(speechRecognitionService, for: SpeechRecognitionServiceProtocol.self)
            
            print("✅ Audio services ready")
        } catch {
            print("❌ ERROR: Audio Services - \(error)")
        }
    }
    
    @MainActor
    private func initializeGamificationServices() async {
        do {
            let localStorage: LocalStorageProtocol = resolve()
            
            let streakTrackingService = StreakTrackingService(storage: localStorage)
            register(streakTrackingService, for: StreakTrackingServiceProtocol.self)
            
            let socialSharingService = SocialSharingService(storage: localStorage)
            register(socialSharingService, for: SocialSharingServiceProtocol.self)
            
            print("✅ Gamification services ready")
        }
    }
}

// MARK: - Convenience Properties
extension DependencyContainer {
    var streakTrackingService: StreakTrackingServiceProtocol {
        resolve()
    }
    
    var socialSharingService: SocialSharingServiceProtocol {
        resolve()
    }
    
    var userViewModel: UserViewModel {
        resolve()
    }
    
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
        let text = try await aiService.generateMotivationalScript(
            userIntent: userIntent,
            tone: tone,
            context: context
        )
        
        let voiceId = "21m00Tcm4TlvDq8ikWAM"
        let audioData = try await ttsService.generateSpeech(text: text, voiceId: voiceId)
        
        let metadata = AlarmContentMetadata(
            generatedAt: Date(),
            wordCount: text.split(separator: " ").count,
            estimatedDuration: TimeInterval(text.count / 10),
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
        currentStatus = .generating(intentId: intent.id, progress: 0.0)
        
        do {
            currentStatus = .generating(intentId: intent.id, progress: 0.2)
            let textContent = try await aiService.generateContentForIntent(intent)
            
            currentStatus = .generating(intentId: intent.id, progress: 0.6)
            
            let voiceId = "21m00Tcm4TlvDq8ikWAM"
            let audioData = try await ttsService.generateSpeech(text: textContent, voiceId: voiceId)
            
            currentStatus = .generating(intentId: intent.id, progress: 0.9)
            
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
            
            Task {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                if case .completed = currentStatus {
                    currentStatus = .idle
                }
            }
            
            return generatedContent
            
        } catch {
            currentStatus = .failed(intentId: intent.id, error: error)
            
            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                if case .failed = currentStatus {
                    currentStatus = .idle
                }
            }
            
            throw ContentGenerationError.generationFailed(intent.id, error)
        }
    }
    
    func processIntentQueue() async throws {
        currentStatus = .idle
    }
    
    func getGenerationStatus() -> ContentGenerationStatus {
        return currentStatus
    }
}
