import Foundation
import Combine

// MARK: - Content Generation Manager
/// Manages the complete AI content generation pipeline, coordinating between
/// IntentRepository, ContentGenerationService, and providing reactive updates
@MainActor
class ContentGenerationManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isGenerating = false
    @Published private(set) var generationProgress: Double = 0.0
    @Published private(set) var currentlyGeneratingIntent: UUID?
    @Published private(set) var generationStatus: ContentGenerationStatus = .idle
    @Published private(set) var recentlyCompleted: [UUID] = []
    @Published private(set) var failedGenerations: [UUID: String] = [:]
    
    // MARK: - Dependencies
    private let intentRepository: IntentRepositoryProtocol
    private let contentService: ContentGenerationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let autoGenerationEnabled: Bool
    private let preGenerationWindowHours: Int
    private let maxRetries: Int
    
    init(
        intentRepository: IntentRepositoryProtocol,
        contentService: ContentGenerationServiceProtocol,
        autoGenerationEnabled: Bool = true,
        preGenerationWindowHours: Int = 1,
        maxRetries: Int = 3
    ) {
        self.intentRepository = intentRepository
        self.contentService = contentService
        self.autoGenerationEnabled = autoGenerationEnabled
        self.preGenerationWindowHours = preGenerationWindowHours
        self.maxRetries = maxRetries
        
        setupAutoGeneration()
        setupStatusMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Generate content for a specific intent
    func generateContent(for intentId: UUID) async throws -> GeneratedContent {
        guard let intent = try await intentRepository.getIntent(by: intentId) else {
            throw ContentGenerationManagerError.intentNotFound(intentId)
        }
        
        return try await generateContent(for: intent)
    }
    
    /// Generate content for an intent object
    func generateContent(for intent: Intent) async throws -> GeneratedContent {
        // Check if already generating
        if isGenerating && currentlyGeneratingIntent == intent.id {
            throw ContentGenerationManagerError.alreadyGenerating(intent.id)
        }
        
        // Mark as generating
        await updateGenerationState(isGenerating: true, intentId: intent.id, progress: 0.0)
        
        do {
            // Mark intent as generating in repository
            try await intentRepository.markIntentAsGenerating(intent.id)
            
            // Generate content
            let generatedContent = try await contentService.generateContentForIntent(intent)
            
            // Save generated content to repository
            try await intentRepository.setGeneratedContent(for: intent.id, content: generatedContent)
            
            // Update completion state
            await updateGenerationState(isGenerating: false, intentId: nil, progress: 1.0)
            recentlyCompleted.append(intent.id)
            
            // Remove from failed if it was there
            failedGenerations.removeValue(forKey: intent.id)
            
            return generatedContent
            
        } catch {
            // Mark as failed in repository
            try await intentRepository.markIntentAsFailed(intent.id, error: error.localizedDescription)
            
            // Update failure state
            await updateGenerationState(isGenerating: false, intentId: nil, progress: 0.0)
            failedGenerations[intent.id] = error.localizedDescription
            
            throw ContentGenerationManagerError.generationFailed(intent.id, error)
        }
    }
    
    /// Process all intents that need content generation
    func processQueuedIntents() async throws {
        guard !isGenerating else {
            throw ContentGenerationManagerError.alreadyGenerating(nil)
        }
        
        let intentsNeedingGeneration = try await intentRepository.getIntentsNeedingGeneration()
        
        for intent in intentsNeedingGeneration {
            do {
                _ = try await generateContent(for: intent)
            } catch {
                print("Failed to generate content for intent \(intent.id): \(error)")
                continue
            }
        }
    }
    
    /// Retry failed generation for a specific intent
    func retryGeneration(for intentId: UUID) async throws -> GeneratedContent {
        guard var intent = try await intentRepository.getIntent(by: intentId) else {
            throw ContentGenerationManagerError.intentNotFound(intentId)
        }
        
        // Reset intent status
        intent.retry()
        try await intentRepository.updateIntent(intent)
        
        // Clear from failed list
        failedGenerations.removeValue(forKey: intentId)
        
        return try await generateContent(for: intent)
    }
    
    /// Get generation statistics
    func getGenerationStatistics() async throws -> GenerationStatistics {
        let intentStats = try await intentRepository.getIntentStatistics()
        
        return GenerationStatistics(
            totalIntents: intentStats.totalIntents,
            pendingGeneration: intentStats.pendingIntents,
            successfullyGenerated: intentStats.readyIntents + intentStats.usedIntents,
            failedGeneration: intentStats.failedIntents,
            currentlyGenerating: isGenerating ? 1 : 0,
            averageGenerationTime: intentStats.averageGenerationTime,
            successRate: intentStats.successRate,
            recentlyCompletedCount: recentlyCompleted.count,
            queuedForRetry: failedGenerations.count
        )
    }
    
    /// Clear completed and failed lists
    func clearHistory() {
        recentlyCompleted.removeAll()
        failedGenerations.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupAutoGeneration() {
        guard autoGenerationEnabled else { return }
        
        // Setup timer for automatic content generation
        Timer.publish(every: 900, on: .main, in: .common) // Every 15 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkAndGenerateContent()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupStatusMonitoring() {
        // Monitor content service status
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateGenerationStatus()
            }
            .store(in: &cancellables)
    }
    
    private func checkAndGenerateContent() async {
        guard !isGenerating else { return }
        
        do {
            let intentsNeedingGeneration = try await intentRepository.getIntentsNeedingGeneration()
            
            // Filter to intents within the pre-generation window
            let now = Date()
            let windowStart = now
            let windowEnd = Calendar.current.date(byAdding: .hour, value: preGenerationWindowHours, to: now) ?? now
            
            let urgentIntents = intentsNeedingGeneration.filter { intent in
                intent.scheduledFor >= windowStart && intent.scheduledFor <= windowEnd
            }
            
            for intent in urgentIntents.prefix(3) { // Limit to 3 at a time
                try await generateContent(for: intent)
            }
            
        } catch {
            print("Auto-generation check failed: \(error)")
        }
    }
    
    private func updateGenerationStatus() {
        let serviceStatus = contentService.getGenerationStatus()
        
        switch serviceStatus {
        case .idle:
            if isGenerating && currentlyGeneratingIntent != nil {
                // Service finished, update our state
                Task {
                    await updateGenerationState(isGenerating: false, intentId: nil, progress: 1.0)
                }
            }
            
        case .generating(let intentId, let progress):
            if !isGenerating || currentlyGeneratingIntent != intentId {
                Task {
                    await updateGenerationState(isGenerating: true, intentId: intentId, progress: progress)
                }
            } else {
                generationProgress = progress
            }
            
        case .completed(let intentId):
            if currentlyGeneratingIntent == intentId {
                Task {
                    await updateGenerationState(isGenerating: false, intentId: nil, progress: 1.0)
                    recentlyCompleted.append(intentId)
                }
            }
            
        case .failed(let intentId, let error):
            if currentlyGeneratingIntent == intentId {
                Task {
                    await updateGenerationState(isGenerating: false, intentId: nil, progress: 0.0)
                    failedGenerations[intentId] = error.localizedDescription
                }
            }
        }
        
        generationStatus = serviceStatus
    }
    
    private func updateGenerationState(isGenerating: Bool, intentId: UUID?, progress: Double) async {
        self.isGenerating = isGenerating
        self.currentlyGeneratingIntent = intentId
        self.generationProgress = progress
    }
}

// MARK: - Generation Statistics
struct GenerationStatistics {
    let totalIntents: Int
    let pendingGeneration: Int
    let successfullyGenerated: Int
    let failedGeneration: Int
    let currentlyGenerating: Int
    let averageGenerationTime: TimeInterval
    let successRate: Double
    let recentlyCompletedCount: Int
    let queuedForRetry: Int
    
    var completionRate: Double {
        guard totalIntents > 0 else { return 0 }
        return Double(successfullyGenerated) / Double(totalIntents)
    }
    
    var failureRate: Double {
        guard totalIntents > 0 else { return 0 }
        return Double(failedGeneration) / Double(totalIntents)
    }
    
    var pendingRate: Double {
        guard totalIntents > 0 else { return 0 }
        return Double(pendingGeneration) / Double(totalIntents)
    }
}

// MARK: - Content Generation Manager Errors
enum ContentGenerationManagerError: LocalizedError {
    case intentNotFound(UUID)
    case alreadyGenerating(UUID?)
    case generationFailed(UUID, Error)
    case repositoryError(Error)
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .intentNotFound(let intentId):
            return "Intent not found: \(intentId.uuidString.prefix(8))"
        case .alreadyGenerating(let intentId):
            if let id = intentId {
                return "Already generating content for intent: \(id.uuidString.prefix(8))"
            } else {
                return "Content generation already in progress"
            }
        case .generationFailed(let intentId, let error):
            return "Content generation failed for intent \(intentId.uuidString.prefix(8)): \(error.localizedDescription)"
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .serviceUnavailable:
            return "Content generation service is unavailable"
        }
    }
}

// MARK: - Extension for Dependency Injection
extension ContentGenerationManager {
    static func create() -> ContentGenerationManager {
        let container = DependencyContainer.shared
        let intentRepository = IntentRepository()
        let contentService: ContentGenerationServiceProtocol = container.resolve()
        
        return ContentGenerationManager(
            intentRepository: intentRepository,
            contentService: contentService
        )
    }
}
