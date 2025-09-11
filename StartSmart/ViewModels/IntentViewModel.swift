import Foundation
import Combine

// MARK: - Intent View Model
@MainActor
class IntentViewModel: ObservableObject {
    @Published var intents: [Intent] = []
    @Published var currentIntent: Intent?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var contentGenerationProgress: Double = 0.0
    
    private let storageManager: StorageManager
    private var cancellables = Set<AnyCancellable>()
    
    @Injected private var contentService: ContentGenerationServiceProtocol
    
    init(storageManager: StorageManager = StorageManager()) {
        self.storageManager = storageManager
        loadIntents()
        setupContentGenerationTimer()
    }
    
    // MARK: - Public Methods
    func loadIntents() {
        isLoading = true
        errorMessage = nil
        
        do {
            intents = try storageManager.loadIntents()
            cleanupExpiredIntents()
            isLoading = false
        } catch {
            errorMessage = "Failed to load intents: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func createIntent(userGoal: String, tone: AlarmTone, scheduledFor: Date, alarmId: UUID? = nil) -> Intent {
        let intent = Intent(
            userGoal: userGoal,
            tone: tone,
            scheduledFor: scheduledFor,
            alarmId: alarmId
        )
        
        addIntent(intent)
        return intent
    }
    
    func createQuickIntent(goal: String, scheduledFor: Date) -> Intent {
        let intent = Intent.quickIntent(
            goal: goal,
            tone: .energetic,
            scheduledFor: scheduledFor
        )
        
        addIntent(intent)
        return intent
    }
    
    func addIntent(_ intent: Intent) {
        intents.append(intent)
        saveIntents()
        
        // Auto-generate content if scheduled soon
        if intent.shouldAutoGenerate {
            Task {
                await generateContentForIntent(intent.id)
            }
        }
    }
    
    func updateIntent(_ intent: Intent) {
        if let index = intents.firstIndex(where: { $0.id == intent.id }) {
            intents[index] = intent
            saveIntents()
        }
    }
    
    func deleteIntent(_ intent: Intent) {
        intents.removeAll { $0.id == intent.id }
        saveIntents()
    }
    
    func deleteIntent(at indexSet: IndexSet) {
        intents.remove(atOffsets: indexSet)
        saveIntents()
    }
    
    // MARK: - Content Generation Methods
    func generateContentForIntent(_ intentId: UUID) async {
        guard let index = intents.firstIndex(where: { $0.id == intentId }) else {
            errorMessage = "Intent not found"
            return
        }
        
        var intent = intents[index]
        intent.markAsGenerating()
        intents[index] = intent
        
        isLoading = true
        contentGenerationProgress = 0.0
        errorMessage = nil
        
        do {
            // Simulate progress updates
            contentGenerationProgress = 0.2
            
            let startTime = Date()
            let content = try await contentService.generateAlarmContent(
                userIntent: intent.userGoal,
                tone: intent.tone.rawValue,
                context: intent.contextForAI
            )
            let generationTime = Date().timeIntervalSince(startTime)
            
            contentGenerationProgress = 0.8
            
            // Create generated content with metadata
            let metadata = ContentMetadata(
                textContent: content.text,
                tone: intent.tone,
                generationTime: generationTime
            )
            
            let generatedContent = GeneratedContent(
                textContent: content.text,
                audioData: content.audioData,
                voiceId: content.metadata.voiceId,
                metadata: metadata
            )
            
            // Update intent with generated content
            intent.setGeneratedContent(generatedContent)
            intents[index] = intent
            
            contentGenerationProgress = 1.0
            
        } catch {
            intent.markAsFailed(error: error.localizedDescription)
            intents[index] = intent
            errorMessage = "Failed to generate content: \(error.localizedDescription)"
        }
        
        saveIntents()
        isLoading = false
        
        // Reset progress after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.contentGenerationProgress = 0.0
        }
    }
    
    func regenerateContent(for intent: Intent) async {
        if let index = intents.firstIndex(where: { $0.id == intent.id }) {
            intents[index].retry()
            saveIntents()
            await generateContentForIntent(intent.id)
        }
    }
    
    func markIntentAsUsed(_ intent: Intent) {
        if let index = intents.firstIndex(where: { $0.id == intent.id }) {
            intents[index].markAsUsed()
            saveIntents()
        }
    }
    
    // MARK: - Computed Properties
    var pendingIntents: [Intent] {
        intents.filter { $0.status == .pending }
    }
    
    var readyIntents: [Intent] {
        intents.filter { $0.status == .ready }
    }
    
    var generatingIntents: [Intent] {
        intents.filter { $0.status == .generating }
    }
    
    var upcomingIntents: [Intent] {
        intents
            .filter { !$0.isExpired && $0.status != .used }
            .sorted { $0.scheduledFor < $1.scheduledFor }
    }
    
    var todaysIntents: [Intent] {
        let calendar = Calendar.current
        let today = Date()
        
        return intents.filter { intent in
            calendar.isDate(intent.scheduledFor, inSameDayAs: today)
        }
    }
    
    var hasContentGenerating: Bool {
        !generatingIntents.isEmpty
    }
    
    // MARK: - Intent Management Helpers
    func getIntent(for alarmId: UUID) -> Intent? {
        return intents.first { $0.alarmId == alarmId && !$0.isExpired }
    }
    
    func getReadyContent(for alarmId: UUID) -> GeneratedContent? {
        return getIntent(for: alarmId)?.generatedContent
    }
    
    func intentsForToday() -> [Intent] {
        todaysIntents
    }
    
    func intentsForTomorrow() -> [Intent] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        return intents.filter { intent in
            calendar.isDate(intent.scheduledFor, inSameDayAs: tomorrow)
        }
    }
    
    // MARK: - Auto-Generation Logic
    private func setupContentGenerationTimer() {
        // Check every 30 minutes for intents that need content generation
        Timer.publish(every: 1800, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkAndGenerateContent()
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkAndGenerateContent() async {
        let pendingIntents = intents.filter { $0.shouldAutoGenerate }
        
        for intent in pendingIntents {
            await generateContentForIntent(intent.id)
        }
    }
    
    // MARK: - Cleanup Methods
    private func cleanupExpiredIntents() {
        let expiredIntents = intents.filter { $0.isExpired }
        
        for expiredIntent in expiredIntents {
            if expiredIntent.status == .used || 
               Date().timeIntervalSince(expiredIntent.scheduledFor) > 86400 { // 24 hours
                deleteIntent(expiredIntent)
            }
        }
    }
    
    func deleteExpiredIntents() {
        cleanupExpiredIntents()
    }
    
    func deleteUsedIntents() {
        intents.removeAll { $0.status == .used }
        saveIntents()
    }
    
    // MARK: - Context Enrichment
    func enrichIntentContext(_ intent: Intent) -> Intent {
        var enrichedIntent = intent
        enrichedIntent.context.enrichWithCurrentData()
        
        // Add weather data (would integrate with weather API in real implementation)
        enrichedIntent.context.weather = "sunny"
        enrichedIntent.context.temperature = 72.0
        
        // Add location (would integrate with location services)
        enrichedIntent.context.location = "San Francisco"
        
        updateIntent(enrichedIntent)
        return enrichedIntent
    }
    
    // MARK: - Private Methods
    private func saveIntents() {
        do {
            try storageManager.saveIntents(intents)
        } catch {
            errorMessage = "Failed to save intents: \(error.localizedDescription)"
        }
    }
}

// MARK: - Intent Form View Model
@MainActor
class IntentFormViewModel: ObservableObject {
    @Published var userGoal = ""
    @Published var tone: AlarmTone = .energetic
    @Published var scheduledFor = Date()
    @Published var customNote = ""
    @Published var includeWeather = true
    @Published var includeCalendar = false
    
    @Published var isValid = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupValidation()
    }
    
    // MARK: - Public Methods
    func createIntent() -> Intent? {
        guard validate() else { return nil }
        
        var context = IntentContext()
        context.customNote = customNote.isEmpty ? nil : customNote
        context.enrichWithCurrentData()
        
        return Intent(
            userGoal: userGoal.trimmingCharacters(in: .whitespacesAndNewlines),
            tone: tone,
            context: context,
            scheduledFor: scheduledFor
        )
    }
    
    func reset() {
        userGoal = ""
        tone = .energetic
        scheduledFor = Date()
        customNote = ""
        includeWeather = true
        includeCalendar = false
        errorMessage = nil
    }
    
    func loadFromIntent(_ intent: Intent) {
        userGoal = intent.userGoal
        tone = intent.tone
        scheduledFor = intent.scheduledFor
        customNote = intent.context.customNote ?? ""
        includeWeather = intent.context.weather != nil
    }
    
    // MARK: - Validation
    private func validate() -> Bool {
        errorMessage = nil
        
        let trimmedGoal = userGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedGoal.isEmpty {
            errorMessage = "Please enter your goal for tomorrow"
            return false
        }
        
        if trimmedGoal.count < 3 {
            errorMessage = "Goal must be at least 3 characters long"
            return false
        }
        
        if trimmedGoal.count > 200 {
            errorMessage = "Goal must be less than 200 characters"
            return false
        }
        
        if scheduledFor <= Date() {
            errorMessage = "Scheduled time must be in the future"
            return false
        }
        
        return true
    }
    
    private func setupValidation() {
        Publishers.CombineLatest3($userGoal, $scheduledFor, $tone)
            .map { goal, date, _ in
                !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                date > Date()
            }
            .assign(to: &$isValid)
    }
    
    // MARK: - Computed Properties
    var goalCharacterCount: Int {
        userGoal.count
    }
    
    var remainingCharacters: Int {
        200 - goalCharacterCount
    }
    
    var timeUntilScheduled: String {
        let interval = scheduledFor.timeIntervalSinceNow
        
        if interval < 0 {
            return "Past"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "in \(minutes) minute\(minutes == 1 ? "" : "s")"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "in \(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let days = Int(interval / 86400)
            return "in \(days) day\(days == 1 ? "" : "s")"
        }
    }
}
