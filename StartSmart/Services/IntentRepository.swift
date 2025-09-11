import Foundation
import Combine

// MARK: - Intent Repository Protocol
protocol IntentRepositoryProtocol {
    func getAllIntents() async throws -> [Intent]
    func getIntent(by id: UUID) async throws -> Intent?
    func getIntentsForAlarm(_ alarmId: UUID) async throws -> [Intent]
    func getUpcomingIntents() async throws -> [Intent]
    func getTodaysIntents() async throws -> [Intent]
    func saveIntent(_ intent: Intent) async throws
    func updateIntent(_ intent: Intent) async throws
    func deleteIntent(_ intent: Intent) async throws
    func deleteIntent(by id: UUID) async throws
    func deleteExpiredIntents() async throws
    func deleteUsedIntents() async throws
    func exportIntents() async throws -> Data
    func importIntents(_ data: Data) async throws
}

// MARK: - Intent Repository
@MainActor
class IntentRepository: IntentRepositoryProtocol {
    private let storageManager: StorageManager
    private let cacheKey = "UserIntents"
    private var cachedIntents: [Intent] = []
    private let maxIntentsLimit = 1000 // Prevent unlimited growth
    
    // Publishers for reactive updates
    @Published private(set) var intents: [Intent] = []
    private var intentUpdateSubject = PassthroughSubject<[Intent], Never>()
    
    var intentsPublisher: AnyPublisher<[Intent], Never> {
        $intents.eraseToAnyPublisher()
    }
    
    init(storageManager: StorageManager = StorageManager()) {
        self.storageManager = storageManager
        Task {
            await loadIntents()
        }
    }
    
    // MARK: - Public Methods
    func getAllIntents() async throws -> [Intent] {
        if cachedIntents.isEmpty {
            await loadIntents()
        }
        return cachedIntents.sorted { $0.scheduledFor < $1.scheduledFor }
    }
    
    func getIntent(by id: UUID) async throws -> Intent? {
        let allIntents = try await getAllIntents()
        return allIntents.first { $0.id == id }
    }
    
    func getIntentsForAlarm(_ alarmId: UUID) async throws -> [Intent] {
        let allIntents = try await getAllIntents()
        return allIntents.filter { $0.alarmId == alarmId && !$0.isExpired }
    }
    
    func getUpcomingIntents() async throws -> [Intent] {
        let allIntents = try await getAllIntents()
        return allIntents.filter { 
            !$0.isExpired && $0.status != .used 
        }.sorted { $0.scheduledFor < $1.scheduledFor }
    }
    
    func getTodaysIntents() async throws -> [Intent] {
        let allIntents = try await getAllIntents()
        let calendar = Calendar.current
        let today = Date()
        
        return allIntents.filter { intent in
            calendar.isDate(intent.scheduledFor, inSameDayAs: today)
        }
    }
    
    func saveIntent(_ intent: Intent) async throws {
        var allIntents = try await getAllIntents()
        
        // Check for duplicates
        if allIntents.contains(where: { $0.id == intent.id }) {
            throw IntentRepositoryError.duplicateIntent
        }
        
        // Enforce limits
        if allIntents.count >= maxIntentsLimit {
            await cleanupOldIntents()
            allIntents = try await getAllIntents()
        }
        
        allIntents.append(intent)
        try await saveIntents(allIntents)
    }
    
    func updateIntent(_ intent: Intent) async throws {
        var allIntents = try await getAllIntents()
        
        guard let index = allIntents.firstIndex(where: { $0.id == intent.id }) else {
            throw IntentRepositoryError.intentNotFound
        }
        
        allIntents[index] = intent
        try await saveIntents(allIntents)
    }
    
    func deleteIntent(_ intent: Intent) async throws {
        try await deleteIntent(by: intent.id)
    }
    
    func deleteIntent(by id: UUID) async throws {
        var allIntents = try await getAllIntents()
        
        guard let index = allIntents.firstIndex(where: { $0.id == id }) else {
            throw IntentRepositoryError.intentNotFound
        }
        
        allIntents.remove(at: index)
        try await saveIntents(allIntents)
    }
    
    func deleteExpiredIntents() async throws {
        let allIntents = try await getAllIntents()
        let nonExpiredIntents = allIntents.filter { !$0.isExpired }
        try await saveIntents(nonExpiredIntents)
    }
    
    func deleteUsedIntents() async throws {
        let allIntents = try await getAllIntents()
        let unusedIntents = allIntents.filter { $0.status != .used }
        try await saveIntents(unusedIntents)
    }
    
    func exportIntents() async throws -> Data {
        let allIntents = try await getAllIntents()
        return try JSONEncoder().encode(allIntents)
    }
    
    func importIntents(_ data: Data) async throws {
        let importedIntents = try JSONDecoder().decode([Intent].self, from: data)
        let existingIntents = try await getAllIntents()
        
        // Merge, avoiding duplicates
        var mergedIntents = existingIntents
        for intent in importedIntents {
            if !mergedIntents.contains(where: { $0.id == intent.id }) {
                mergedIntents.append(intent)
            }
        }
        
        try await saveIntents(mergedIntents)
    }
    
    // MARK: - Content Generation Helpers
    func getIntentsNeedingGeneration() async throws -> [Intent] {
        let allIntents = try await getAllIntents()
        return allIntents.filter { $0.shouldAutoGenerate }
    }
    
    func markIntentAsGenerating(_ intentId: UUID) async throws {
        guard var intent = try await getIntent(by: intentId) else {
            throw IntentRepositoryError.intentNotFound
        }
        
        intent.markAsGenerating()
        try await updateIntent(intent)
    }
    
    func setGeneratedContent(for intentId: UUID, content: GeneratedContent) async throws {
        guard var intent = try await getIntent(by: intentId) else {
            throw IntentRepositoryError.intentNotFound
        }
        
        intent.setGeneratedContent(content)
        try await updateIntent(intent)
    }
    
    func markIntentAsUsed(_ intentId: UUID) async throws {
        guard var intent = try await getIntent(by: intentId) else {
            throw IntentRepositoryError.intentNotFound
        }
        
        intent.markAsUsed()
        try await updateIntent(intent)
    }
    
    func markIntentAsFailed(_ intentId: UUID, error: String) async throws {
        guard var intent = try await getIntent(by: intentId) else {
            throw IntentRepositoryError.intentNotFound
        }
        
        intent.markAsFailed(error: error)
        try await updateIntent(intent)
    }
    
    // MARK: - Statistics and Analytics
    func getIntentStatistics() async throws -> IntentStatistics {
        let allIntents = try await getAllIntents()
        let today = Date()
        let calendar = Calendar.current
        
        let totalIntents = allIntents.count
        let pendingIntents = allIntents.filter { $0.status == .pending }.count
        let readyIntents = allIntents.filter { $0.status == .ready }.count
        let usedIntents = allIntents.filter { $0.status == .used }.count
        let failedIntents = allIntents.filter { $0.status.isFailure }.count
        
        let todaysIntents = allIntents.filter { intent in
            calendar.isDate(intent.scheduledFor, inSameDayAs: today)
        }.count
        
        let weekStartDate = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weeklyIntents = allIntents.filter { intent in
            intent.scheduledFor >= weekStartDate && intent.scheduledFor <= today
        }.count
        
        return IntentStatistics(
            totalIntents: totalIntents,
            pendingIntents: pendingIntents,
            readyIntents: readyIntents,
            usedIntents: usedIntents,
            failedIntents: failedIntents,
            todaysIntents: todaysIntents,
            weeklyIntents: weeklyIntents,
            averageGenerationTime: calculateAverageGenerationTime(from: allIntents),
            mostPopularTone: calculateMostPopularTone(from: allIntents)
        )
    }
    
    // MARK: - Private Methods
    private func loadIntents() async {
        do {
            cachedIntents = try storageManager.loadIntents()
            intents = cachedIntents
        } catch {
            print("Failed to load intents: \(error)")
            cachedIntents = []
            intents = []
        }
    }
    
    private func saveIntents(_ intents: [Intent]) async throws {
        try storageManager.saveIntents(intents)
        cachedIntents = intents
        self.intents = intents
    }
    
    private func cleanupOldIntents() async {
        do {
            let allIntents = try await getAllIntents()
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            
            let recentIntents = allIntents.filter { intent in
                intent.scheduledFor > cutoffDate || intent.status == .ready || intent.status == .pending
            }
            
            try await saveIntents(recentIntents)
        } catch {
            print("Failed to cleanup old intents: \(error)")
        }
    }
    
    private func calculateAverageGenerationTime(from intents: [Intent]) -> TimeInterval {
        let generatedIntents = intents.compactMap { $0.generatedContent }
        guard !generatedIntents.isEmpty else { return 0 }
        
        let totalTime = generatedIntents.reduce(0) { $0 + $1.metadata.generationTime }
        return totalTime / Double(generatedIntents.count)
    }
    
    private func calculateMostPopularTone(from intents: [Intent]) -> AlarmTone? {
        guard !intents.isEmpty else { return nil }
        
        let toneCounts = Dictionary(grouping: intents, by: { $0.tone })
            .mapValues { $0.count }
        
        return toneCounts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Intent Statistics
struct IntentStatistics {
    let totalIntents: Int
    let pendingIntents: Int
    let readyIntents: Int
    let usedIntents: Int
    let failedIntents: Int
    let todaysIntents: Int
    let weeklyIntents: Int
    let averageGenerationTime: TimeInterval
    let mostPopularTone: AlarmTone?
    
    var successRate: Double {
        guard totalIntents > 0 else { return 0 }
        return Double(readyIntents + usedIntents) / Double(totalIntents)
    }
    
    var failureRate: Double {
        guard totalIntents > 0 else { return 0 }
        return Double(failedIntents) / Double(totalIntents)
    }
}

// MARK: - Intent Repository Errors
enum IntentRepositoryError: LocalizedError {
    case intentNotFound
    case duplicateIntent
    case storageError(Error)
    case invalidData
    case limitExceeded
    
    var errorDescription: String? {
        switch self {
        case .intentNotFound:
            return "Intent not found"
        case .duplicateIntent:
            return "Intent already exists"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid intent data"
        case .limitExceeded:
            return "Maximum number of intents reached"
        }
    }
}
