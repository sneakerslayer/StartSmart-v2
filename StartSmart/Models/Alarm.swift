import Foundation

// MARK: - Alarm Generated Content
struct AlarmGeneratedContent: Codable, Equatable {
    let textContent: String
    let audioFilePath: String
    let voiceId: String
    let generatedAt: Date
    let duration: TimeInterval?
    let intentId: String?
    
    var audioURL: URL {
        URL(fileURLWithPath: audioFilePath)
    }
    
    var isExpired: Bool {
        // Consider content expired after 7 days
        Date().timeIntervalSince(generatedAt) > 7 * 24 * 60 * 60
    }
}

// MARK: - Alarm Model
struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    var time: Date
    var label: String
    var isEnabled: Bool
    var repeatDays: Set<WeekDay>
    var tone: AlarmTone
    var snoozeEnabled: Bool
    var snoozeDuration: TimeInterval
    var maxSnoozeCount: Int
    var currentSnoozeCount: Int
    var lastTriggered: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Custom Audio Content
    var customAudioPath: String?
    var generatedContent: AlarmGeneratedContent?
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        time: Date,
        label: String = "Wake up",
        isEnabled: Bool = true,
        repeatDays: Set<WeekDay> = [],
        tone: AlarmTone = .energetic,
        snoozeEnabled: Bool = true,
        snoozeDuration: TimeInterval = 300, // 5 minutes
        maxSnoozeCount: Int = 3,
        customAudioPath: String? = nil,
        generatedContent: AlarmGeneratedContent? = nil
    ) {
        self.id = id
        self.time = time
        self.label = label
        self.isEnabled = isEnabled
        self.repeatDays = repeatDays
        self.tone = tone
        self.snoozeEnabled = snoozeEnabled
        self.snoozeDuration = snoozeDuration
        self.maxSnoozeCount = maxSnoozeCount
        self.currentSnoozeCount = 0
        self.lastTriggered = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.customAudioPath = customAudioPath
        self.generatedContent = generatedContent
    }
    
    // MARK: - Computed Properties
    var isRepeating: Bool {
        !repeatDays.isEmpty
    }
    
    var nextTriggerDate: Date? {
        guard isEnabled else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        
        if isRepeating {
            return calculateNextRepeatingTrigger(from: now, calendar: calendar)
        } else {
            // One-time alarm
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            let todayWithAlarmTime = calendar.nextDate(
                after: now,
                matching: timeComponents,
                matchingPolicy: .nextTime
            )
            return todayWithAlarmTime
        }
    }
    
    var timeDisplayString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var repeatDaysDisplayString: String {
        if repeatDays.isEmpty {
            return "Once"
        } else if repeatDays.count == 7 {
            return "Every day"
        } else if Set([.monday, .tuesday, .wednesday, .thursday, .friday]).isSubset(of: repeatDays) && repeatDays.count == 5 {
            return "Weekdays"
        } else if Set([.saturday, .sunday]).isSubset(of: repeatDays) && repeatDays.count == 2 {
            return "Weekends"
        } else {
            return repeatDays.sorted().map(\.shortName).joined(separator: ", ")
        }
    }
    
    var canSnooze: Bool {
        snoozeEnabled && currentSnoozeCount < maxSnoozeCount
    }
    
    var hasCustomAudio: Bool {
        customAudioPath != nil || generatedContent != nil
    }
    
    var needsAudioGeneration: Bool {
        generatedContent == nil || (generatedContent?.isExpired == true)
    }
    
    var audioFileURL: URL? {
        if let customPath = customAudioPath {
            return URL(fileURLWithPath: customPath)
        } else if let generated = generatedContent {
            return generated.audioURL
        }
        return nil
    }
    
    // MARK: - Helper Methods
    private func calculateNextRepeatingTrigger(from date: Date, calendar: Calendar) -> Date? {
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        for dayOffset in 0..<8 { // Check next 7 days + today
            let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: date)!
            let weekday = WeekDay(from: calendar.component(.weekday, from: checkDate))
            
            if repeatDays.contains(weekday) {
                if let alarmTime = calendar.nextDate(
                    after: dayOffset == 0 ? date : calendar.startOfDay(for: checkDate),
                    matching: timeComponents,
                    matchingPolicy: .nextTime
                ) {
                    let alarmDay = calendar.component(.weekday, from: alarmTime)
                    if WeekDay(from: alarmDay) == weekday {
                        return alarmTime
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Mutating Methods
    mutating func toggle() {
        isEnabled.toggle()
        updatedAt = Date()
    }
    
    mutating func snooze() {
        guard canSnooze else { return }
        currentSnoozeCount += 1
        updatedAt = Date()
    }
    
    mutating func resetSnooze() {
        currentSnoozeCount = 0
        updatedAt = Date()
    }
    
    mutating func markTriggered() {
        lastTriggered = Date()
        if !isRepeating {
            isEnabled = false
        }
        updatedAt = Date()
    }
    
    mutating func updateTime(_ newTime: Date) {
        time = newTime
        updatedAt = Date()
    }
    
    mutating func setGeneratedContent(_ content: AlarmGeneratedContent) {
        generatedContent = content
        customAudioPath = content.audioFilePath
        updatedAt = Date()
    }
    
    mutating func clearGeneratedContent() {
        generatedContent = nil
        customAudioPath = nil
        updatedAt = Date()
    }
}

// MARK: - Supporting Enums
enum WeekDay: Int, CaseIterable, Codable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    init(from calendarWeekday: Int) {
        self = WeekDay(rawValue: calendarWeekday) ?? .sunday
    }
    
    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
    
    static func < (lhs: WeekDay, rhs: WeekDay) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum AlarmTone: String, CaseIterable, Codable {
    case gentle = "gentle"
    case energetic = "energetic"
    case toughLove = "tough_love"
    case storyteller = "storyteller"
    
    var displayName: String {
        switch self {
        case .gentle: return "Gentle"
        case .energetic: return "Energetic"
        case .toughLove: return "Tough Love"
        case .storyteller: return "Storyteller"
        }
    }
    
    var description: String {
        switch self {
        case .gentle: return "Warm, encouraging, like a caring friend"
        case .energetic: return "Upbeat, enthusiastic, high-energy"
        case .toughLove: return "Direct, firm but caring, no-nonsense"
        case .storyteller: return "Narrative style with metaphors and imagery"
        }
    }
    
    var voiceId: String {
        return self.rawValue
    }
}
