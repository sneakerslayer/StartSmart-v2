import Foundation

// MARK: - Intent Model
struct Intent: Identifiable, Codable, Equatable {
    let id: UUID
    var userGoal: String
    var tone: AlarmTone
    var context: IntentContext
    var scheduledFor: Date
    var alarmId: UUID?
    var status: IntentStatus
    var generatedContent: GeneratedContent?
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        userGoal: String,
        tone: AlarmTone = .energetic,
        context: IntentContext = IntentContext(),
        scheduledFor: Date,
        alarmId: UUID? = nil
    ) {
        self.id = id
        self.userGoal = userGoal
        self.tone = tone
        self.context = context
        self.scheduledFor = scheduledFor
        self.alarmId = alarmId
        self.status = .pending
        self.generatedContent = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    var isReady: Bool {
        status == .ready && generatedContent != nil
    }
    
    var isExpired: Bool {
        scheduledFor < Date()
    }
    
    var shouldAutoGenerate: Bool {
        status == .pending && scheduledFor.timeIntervalSinceNow <= 3600 // 1 hour before
    }
    
    var contextForAI: [String: String] {
        return [
            "weather": context.weather ?? "unknown",
            "timeOfDay": context.timeOfDay.rawValue,
            "dayOfWeek": context.dayOfWeek,
            "calendarEvents": context.calendarEvents.joined(separator: ", "),
            "location": context.location ?? "unknown"
        ]
    }
    
    // MARK: - Mutating Methods
    mutating func updateGoal(_ newGoal: String) {
        userGoal = newGoal
        status = .pending // Reset status when goal changes
        generatedContent = nil // Clear old content
        updatedAt = Date()
    }
    
    mutating func updateTone(_ newTone: AlarmTone) {
        tone = newTone
        if generatedContent != nil {
            status = .pending // Regenerate if tone changes
            generatedContent = nil
        }
        updatedAt = Date()
    }
    
    mutating func updateContext(_ newContext: IntentContext) {
        context = newContext
        updatedAt = Date()
    }
    
    mutating func markAsGenerating() {
        status = .generating
        updatedAt = Date()
    }
    
    mutating func setGeneratedContent(_ content: GeneratedContent) {
        generatedContent = content
        status = .ready
        updatedAt = Date()
    }
    
    mutating func markAsUsed() {
        status = .used
        updatedAt = Date()
    }
    
    mutating func markAsFailed(error: String) {
        status = .failed(error)
        updatedAt = Date()
    }
    
    mutating func retry() {
        status = .pending
        generatedContent = nil
        updatedAt = Date()
    }
}

// MARK: - Intent Context
struct IntentContext: Codable, Equatable {
    var weather: String?
    var temperature: Double?
    var timeOfDay: TimeOfDay
    var dayOfWeek: String
    var calendarEvents: [String]
    var location: String?
    var customNote: String?
    
    init(
        weather: String? = nil,
        temperature: Double? = nil,
        timeOfDay: TimeOfDay = .morning,
        dayOfWeek: String = "",
        calendarEvents: [String] = [],
        location: String? = nil,
        customNote: String? = nil
    ) {
        self.weather = weather
        self.temperature = temperature
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek.isEmpty ? Self.currentDayOfWeek() : dayOfWeek
        self.calendarEvents = calendarEvents
        self.location = location
        self.customNote = customNote
    }
    
    private static func currentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
    
    // MARK: - Context Enrichment
    mutating func enrichWithCurrentData() {
        // Update day of week if not explicitly set
        if dayOfWeek.isEmpty {
            dayOfWeek = Self.currentDayOfWeek()
        }
        
        // Determine time of day from scheduled time
        let hour = Calendar.current.component(.hour, from: Date())
        timeOfDay = TimeOfDay.from(hour: hour)
    }
}

// MARK: - Time of Day
enum TimeOfDay: String, Codable, CaseIterable {
    case earlyMorning = "early_morning"
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
    
    static func from(hour: Int) -> TimeOfDay {
        switch hour {
        case 5..<8:
            return .earlyMorning
        case 8..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }
    
    var displayName: String {
        switch self {
        case .earlyMorning: return "Early Morning"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }
}

// MARK: - Intent Status
enum IntentStatus: Codable, Equatable {
    case pending
    case generating
    case ready
    case used
    case failed(String)
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .generating: return "Generating..."
        case .ready: return "Ready"
        case .used: return "Used"
        case .failed: return "Failed"
        }
    }
    
    var isFailure: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

// MARK: - Generated Content
struct GeneratedContent: Codable, Equatable {
    let textContent: String
    let audioURL: String? // Local file path or URL
    let audioData: Data? // For immediate playback
    let voiceId: String
    let generatedAt: Date
    let metadata: ContentMetadata
    
    init(
        textContent: String,
        audioURL: String? = nil,
        audioData: Data? = nil,
        voiceId: String,
        metadata: ContentMetadata
    ) {
        self.textContent = textContent
        self.audioURL = audioURL
        self.audioData = audioData
        self.voiceId = voiceId
        self.generatedAt = Date()
        self.metadata = metadata
    }
    
    var hasAudio: Bool {
        audioURL != nil || audioData != nil
    }
    
    var estimatedDuration: TimeInterval {
        metadata.estimatedDuration
    }
    
    var wordCount: Int {
        metadata.wordCount
    }
}

// MARK: - Content Metadata
struct ContentMetadata: Codable, Equatable {
    let wordCount: Int
    let characterCount: Int
    let estimatedDuration: TimeInterval
    let tone: AlarmTone
    let aiModel: String
    let ttsModel: String?
    let generationTime: TimeInterval
    
    init(
        textContent: String,
        tone: AlarmTone,
        aiModel: String = "grok4",
        ttsModel: String? = "elevenlabs",
        generationTime: TimeInterval = 0
    ) {
        self.wordCount = textContent.split(separator: " ").count
        self.characterCount = textContent.count
        self.estimatedDuration = Self.calculateDuration(for: textContent)
        self.tone = tone
        self.aiModel = aiModel
        self.ttsModel = ttsModel
        self.generationTime = generationTime
    }
    
    private static func calculateDuration(for text: String) -> TimeInterval {
        // Average speaking rate: ~150-200 words per minute
        // Using 175 WPM as baseline
        let words = text.split(separator: " ").count
        let wordsPerSecond = 175.0 / 60.0 // ~2.9 words per second
        return TimeInterval(Double(words) / wordsPerSecond)
    }
}

// MARK: - Intent Extensions
extension Intent {
    // Helper for creating quick intents
    static func quickIntent(
        goal: String,
        tone: AlarmTone = .energetic,
        scheduledFor: Date
    ) -> Intent {
        var context = IntentContext()
        context.enrichWithCurrentData()
        
        return Intent(
            userGoal: goal,
            tone: tone,
            context: context,
            scheduledFor: scheduledFor
        )
    }
    
    // Helper for creating intent from alarm
    static func from(alarm: Alarm, goal: String) -> Intent {
        return Intent(
            userGoal: goal,
            tone: alarm.tone,
            scheduledFor: alarm.nextTriggerDate ?? alarm.time,
            alarmId: alarm.id
        )
    }
}
