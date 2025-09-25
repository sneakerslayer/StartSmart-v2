import Foundation

// MARK: - User Model
struct User: Identifiable, Codable, Equatable {
    let id: UUID
    var email: String?
    var displayName: String?
    var profileImageURL: String?
    var preferences: UserPreferences
    var subscription: StartSmartSubscriptionStatus
    var stats: UserStats
    var createdAt: Date
    var updatedAt: Date
    var lastLoginAt: Date?
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        email: String? = nil,
        displayName: String? = nil,
        profileImageURL: String? = nil,
        preferences: UserPreferences = UserPreferences(),
        subscription: StartSmartSubscriptionStatus = .free
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.preferences = preferences
        self.subscription = subscription
        self.stats = UserStats()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastLoginAt = nil
    }
    
    // MARK: - Computed Properties
    var isAnonymous: Bool {
        email == nil
    }
    
    var canAccessPremiumFeatures: Bool {
        subscription.isPremium
    }
    
    var displayNameOrEmail: String {
        displayName ?? email ?? "Anonymous User"
    }
    
    // MARK: - Mutating Methods
    mutating func updateProfile(displayName: String?, profileImageURL: String?) {
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.updatedAt = Date()
    }
    
    mutating func updatePreferences(_ newPreferences: UserPreferences) {
        self.preferences = newPreferences
        self.updatedAt = Date()
    }
    
    mutating func updateSubscription(_ newSubscription: StartSmartSubscriptionStatus) {
        self.subscription = newSubscription
        self.updatedAt = Date()
    }
    
    mutating func recordLogin() {
        self.lastLoginAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func incrementAlarmCount() {
        stats.totalAlarmsCreated += 1
        updatedAt = Date()
    }
    
    mutating func recordSuccessfulWakeUp() {
        stats.successfulWakeUps += 1
        stats.updateStreak()
        updatedAt = Date()
    }
    
    mutating func recordSnooze() {
        stats.totalSnoozes += 1
        updatedAt = Date()
    }
    
    // MARK: - Firebase Integration
    func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    static func fromDictionary(_ data: [String: Any]) throws -> User {
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(User.self, from: jsonData)
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable, Equatable {
    var defaultAlarmTone: AlarmTone
    var notificationsEnabled: Bool
    var soundEnabled: Bool
    var vibrationEnabled: Bool
    var snoozeEnabled: Bool
    var defaultSnoozeDuration: TimeInterval
    var maxSnoozeCount: Int
    var shareToSocialMediaEnabled: Bool
    var analyticsEnabled: Bool
    var toneSliderPosition: Double // 0.0 (gentle) to 1.0 (tough love)
    
    init(
        defaultAlarmTone: AlarmTone = .energetic,
        notificationsEnabled: Bool = true,
        soundEnabled: Bool = true,
        vibrationEnabled: Bool = true,
        snoozeEnabled: Bool = true,
        defaultSnoozeDuration: TimeInterval = 300, // 5 minutes
        maxSnoozeCount: Int = 3,
        shareToSocialMediaEnabled: Bool = false,
        analyticsEnabled: Bool = false,
        toneSliderPosition: Double = 0.5
    ) {
        self.defaultAlarmTone = defaultAlarmTone
        self.notificationsEnabled = notificationsEnabled
        self.soundEnabled = soundEnabled
        self.vibrationEnabled = vibrationEnabled
        self.snoozeEnabled = snoozeEnabled
        self.defaultSnoozeDuration = defaultSnoozeDuration
        self.maxSnoozeCount = maxSnoozeCount
        self.shareToSocialMediaEnabled = shareToSocialMediaEnabled
        self.analyticsEnabled = analyticsEnabled
        self.toneSliderPosition = toneSliderPosition
    }
    
    // Convert slider position to tone
    var computedTone: AlarmTone {
        switch toneSliderPosition {
        case 0.0..<0.25:
            return .gentle
        case 0.25..<0.5:
            return .storyteller
        case 0.5..<0.75:
            return .energetic
        default:
            return .toughLove
        }
    }
}

// MARK: - Subscription Status
enum SubscriptionStatus: String, Codable, CaseIterable {
    case free = "free"
    case proWeekly = "pro_weekly"
    case proMonthly = "pro_monthly"
    case proAnnual = "pro_annual"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .proWeekly: return "Pro Weekly"
        case .proMonthly: return "Pro Monthly"
        case .proAnnual: return "Pro Annual"
        }
    }
    
    var isPremium: Bool {
        self != .free
    }
    
    var monthlyAlarmLimit: Int? {
        switch self {
        case .free: return 15
        case .proWeekly, .proMonthly, .proAnnual: return nil // Unlimited
        }
    }
    
    var hasAdvancedAnalytics: Bool {
        isPremium
    }
    
    var hasAllVoices: Bool {
        isPremium
    }
    
    var hasEarlyAccess: Bool {
        self == .proAnnual
    }
}

// MARK: - User Statistics
struct UserStats: Codable, Equatable {
    var totalAlarmsCreated: Int
    var successfulWakeUps: Int
    var totalSnoozes: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastWakeUpDate: Date?
    var averageWakeUpTime: TimeInterval? // Seconds since midnight
    var streakStartDate: Date?
    
    init() {
        self.totalAlarmsCreated = 0
        self.successfulWakeUps = 0
        self.totalSnoozes = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastWakeUpDate = nil
        self.averageWakeUpTime = nil
        self.streakStartDate = nil
    }
    
    // MARK: - Computed Properties
    var successRate: Double {
        guard totalAlarmsCreated > 0 else { return 0.0 }
        return Double(successfulWakeUps) / Double(totalAlarmsCreated)
    }
    
    var snoozeRate: Double {
        guard successfulWakeUps > 0 else { return 0.0 }
        return Double(totalSnoozes) / Double(successfulWakeUps)
    }
    
    // MARK: - Mutating Methods
    mutating func updateStreak() {
        let calendar = Calendar.current
        let today = Date()
        
        if let lastWakeUp = lastWakeUpDate {
            let daysBetween = calendar.dateComponents([.day], from: lastWakeUp, to: today).day ?? 0
            
            if daysBetween == 1 {
                // Consecutive day - continue streak
                currentStreak += 1
            } else if daysBetween == 0 {
                // Same day - no change to streak
                return
            } else {
                // Broke streak
                currentStreak = 1
                streakStartDate = today
            }
        } else {
            // First wake up
            currentStreak = 1
            streakStartDate = today
        }
        
        // Update longest streak
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        
        lastWakeUpDate = today
        
        // Update average wake up time
        updateAverageWakeUpTime(for: today)
    }
    
    private mutating func updateAverageWakeUpTime(for date: Date) {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hours = timeComponents.hour ?? 0
        let minutes = timeComponents.minute ?? 0
        let seconds = timeComponents.second ?? 0
        
        let secondsSinceMidnight = TimeInterval(
            hours * 3600 + minutes * 60 + seconds
        )
        
        if let currentAverage = averageWakeUpTime {
            // Simple moving average (could be improved with weighted average)
            averageWakeUpTime = (currentAverage + secondsSinceMidnight) / 2
        } else {
            averageWakeUpTime = secondsSinceMidnight
        }
    }
    
    mutating func resetStreak() {
        currentStreak = 0
        streakStartDate = nil
    }
}
