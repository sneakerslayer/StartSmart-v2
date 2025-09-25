import Foundation
import Combine
import SwiftUI

// MARK: - Achievement Types
enum StreakAchievement: String, CaseIterable, Codable, Equatable {
    case firstWakeUp = "first_wake_up"
    case threeDayStreak = "three_day_streak"
    case weekStreak = "week_streak"
    case twoWeekStreak = "two_week_streak"
    case monthStreak = "month_streak"
    case perfectWeek = "perfect_week"
    case earlyBird = "early_bird"
    case consistent = "consistent"
    case noSnooze = "no_snooze"
    case weekendWarrior = "weekend_warrior"
    
    var title: String {
        switch self {
        case .firstWakeUp: return "First Success"
        case .threeDayStreak: return "Getting Started"
        case .weekStreak: return "Week Warrior"
        case .twoWeekStreak: return "Two Week Champion"
        case .monthStreak: return "Month Master"
        case .perfectWeek: return "Perfect Week"
        case .earlyBird: return "Early Bird"
        case .consistent: return "Consistency King"
        case .noSnooze: return "No Snooze Hero"
        case .weekendWarrior: return "Weekend Warrior"
        }
    }
    
    var description: String {
        switch self {
        case .firstWakeUp: return "Successfully wake up to your first alarm!"
        case .threeDayStreak: return "Maintain a 3-day wake-up streak"
        case .weekStreak: return "Achieve a 7-day wake-up streak"
        case .twoWeekStreak: return "Maintain a 14-day wake-up streak"
        case .monthStreak: return "Achieve a 30-day wake-up streak"
        case .perfectWeek: return "Wake up on time every day for a week"
        case .earlyBird: return "Wake up before 7 AM for 5 consecutive days"
        case .consistent: return "Wake up within 15 minutes of alarm time for 10 days"
        case .noSnooze: return "Go 7 days without hitting snooze"
        case .weekendWarrior: return "Wake up on time every weekend for a month"
        }
    }
    
    var iconName: String {
        switch self {
        case .firstWakeUp: return "sun.rise"
        case .threeDayStreak: return "flame"
        case .weekStreak: return "flame.fill"
        case .twoWeekStreak: return "star"
        case .monthStreak: return "crown"
        case .perfectWeek: return "checkmark.seal"
        case .earlyBird: return "bird"
        case .consistent: return "clock"
        case .noSnooze: return "bolt"
        case .weekendWarrior: return "party.popper"
        }
    }
    
    var requiredValue: Int {
        switch self {
        case .firstWakeUp: return 1
        case .threeDayStreak: return 3
        case .weekStreak: return 7
        case .twoWeekStreak: return 14
        case .monthStreak: return 30
        case .perfectWeek: return 7
        case .earlyBird: return 5
        case .consistent: return 10
        case .noSnooze: return 7
        case .weekendWarrior: return 4 // 4 weekends
        }
    }
}

// MARK: - Streak Event Types
enum StreakEvent: Codable, Equatable {
    case alarmDismissed(alarmId: UUID, method: DismissMethod, time: Date)
    case alarmSnoozed(alarmId: UUID, count: Int, time: Date)
    case alarmMissed(alarmId: UUID, time: Date)
    
    enum DismissMethod: String, Codable, Equatable {
        case voice = "voice"
        case button = "button"
        case notification = "notification"
    }
    
    var timestamp: Date {
        switch self {
        case .alarmDismissed(_, _, let time),
             .alarmSnoozed(_, _, let time),
             .alarmMissed(_, let time):
            return time
        }
    }
}

// MARK: - Enhanced User Statistics
struct EnhancedUserStats: Codable, Equatable {
    // Basic stats (from existing UserStats)
    var totalAlarmsCreated: Int = 0
    var successfulWakeUps: Int = 0
    var totalSnoozes: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastWakeUpDate: Date?
    var averageWakeUpTime: TimeInterval?
    var streakStartDate: Date?
    
    // Enhanced streak tracking
    var recentEvents: [StreakEvent] = []
    var unlockedAchievements: Set<StreakAchievement> = []
    var streakMilestones: [Date] = []
    var earlyBirdDays: Int = 0
    var noSnoozeDays: Int = 0
    var consistentDays: Int = 0
    var weekendSuccesses: Int = 0
    var totalMissedAlarms: Int = 0
    
    // Weekly stats
    var thisWeekSuccesses: Int = 0
    var thisWeekMisses: Int = 0
    var lastWeekStart: Date?
    
    // Monthly stats
    var thisMonthSuccesses: Int = 0
    var thisMonthMisses: Int = 0
    var lastMonthStart: Date?
    
    // Analytics view specific properties
    var streakHistory: [StreakDataPoint] = []
    var wakeUpPatterns: [WakeUpPattern] = []
    var insights: [AnalyticsInsight] = []
    
    // MARK: - Computed Properties
    var successRate: Double {
        let totalAttempts = successfulWakeUps + totalMissedAlarms
        guard totalAttempts > 0 else { return 0.0 }
        return Double(successfulWakeUps) / Double(totalAttempts)
    }
    
    var snoozeRate: Double {
        guard successfulWakeUps > 0 else { return 0.0 }
        return Double(totalSnoozes) / Double(successfulWakeUps)
    }
    
    var averageWakeUpTimeFormatted: String {
        guard let avgTime = averageWakeUpTime else { return "No data" }
        
        let hours = Int(avgTime) / 3600
        let minutes = (Int(avgTime) % 3600) / 60
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hours, minute: minutes, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    var weeklySuccessRate: Double {
        let totalWeeklyAttempts = thisWeekSuccesses + thisWeekMisses
        guard totalWeeklyAttempts > 0 else { return 0.0 }
        return Double(thisWeekSuccesses) / Double(totalWeeklyAttempts)
    }
    
    var monthlySuccessRate: Double {
        let totalMonthlyAttempts = thisMonthSuccesses + thisMonthMisses
        guard totalMonthlyAttempts > 0 else { return 0.0 }
        return Double(thisMonthSuccesses) / Double(totalMonthlyAttempts)
    }
    
    // MARK: - Achievement Checking
    func checkAchievement(_ achievement: StreakAchievement) -> Bool {
        switch achievement {
        case .firstWakeUp:
            return successfulWakeUps >= 1
        case .threeDayStreak:
            return currentStreak >= 3
        case .weekStreak:
            return currentStreak >= 7
        case .twoWeekStreak:
            return currentStreak >= 14
        case .monthStreak:
            return currentStreak >= 30
        case .perfectWeek:
            return thisWeekSuccesses >= 7 && thisWeekMisses == 0
        case .earlyBird:
            return earlyBirdDays >= 5
        case .consistent:
            return consistentDays >= 10
        case .noSnooze:
            return noSnoozeDays >= 7
        case .weekendWarrior:
            return weekendSuccesses >= 4
        }
    }
}

// MARK: - Analytics Support Types
struct StreakDataPoint: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let streakLength: Int
    
    init(date: Date, streakLength: Int) {
        self.id = UUID()
        self.date = date
        self.streakLength = streakLength
    }
}

struct WakeUpPattern: Codable, Equatable {
    let hour: Int
    let frequency: Int
    let dayOfWeek: Int?
}

struct AnalyticsInsight: Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let type: InsightType
    let priority: Int
    
    enum InsightType: String, Codable, CaseIterable {
        case streak = "streak"
        case pattern = "pattern"
        case improvement = "improvement"
        case achievement = "achievement"
        
        var color: Color {
            switch self {
            case .streak: return .orange
            case .pattern: return .blue  
            case .improvement: return .yellow
            case .achievement: return .green
            }
        }
        
        var iconName: String {
            switch self {
            case .streak: return "flame.fill"
            case .pattern: return "chart.line.uptrend.xyaxis"
            case .improvement: return "lightbulb.fill"
            case .achievement: return "trophy.fill"
            }
        }
    }
}

// MARK: - Streak Tracking Service Protocol
protocol StreakTrackingServiceProtocol {
    var enhancedStats: AnyPublisher<EnhancedUserStats, Never> { get }
    var newAchievements: AnyPublisher<[StreakAchievement], Never> { get }
    
    func recordAlarmDismiss(alarmId: UUID, method: StreakEvent.DismissMethod, time: Date) async
    func recordAlarmSnooze(alarmId: UUID, count: Int, time: Date) async
    func recordAlarmMiss(alarmId: UUID, time: Date) async
    func loadStats() async
    func resetStats() async
    func getRecentActivity(days: Int) -> [StreakEvent]
    func getAchievementProgress() -> [StreakAchievement: Double]
}

// MARK: - Streak Tracking Service Implementation
@MainActor
class StreakTrackingService: ObservableObject, @preconcurrency StreakTrackingServiceProtocol {
    @Published private var _enhancedStats = EnhancedUserStats()
    @Published private var _newAchievements: [StreakAchievement] = []
    
    private let storage: LocalStorageProtocol
    private let storageKey = "enhanced_user_stats"
    private let maxRecentEvents = 100
    
    // MARK: - Publishers
    var enhancedStats: AnyPublisher<EnhancedUserStats, Never> {
        $_enhancedStats.eraseToAnyPublisher()
    }
    
    var newAchievements: AnyPublisher<[StreakAchievement], Never> {
        $_newAchievements.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(storage: LocalStorageProtocol = UserDefaultsStorage()) {
        self.storage = storage
        Task {
            await loadStats()
        }
    }
    
    // MARK: - Public Methods
    func recordAlarmDismiss(alarmId: UUID, method: StreakEvent.DismissMethod, time: Date) async {
        let event = StreakEvent.alarmDismissed(alarmId: alarmId, method: method, time: time)
        await processEvent(event)
        
        // Update basic stats
        _enhancedStats.successfulWakeUps += 1
        await updateStreak(for: time)
        
        // Update method-specific stats
        if isEarlyBird(time) {
            _enhancedStats.earlyBirdDays += 1
        }
        
        if method != .notification {
            _enhancedStats.consistentDays += 1
        }
        
        // Check for weekend success
        if isWeekend(time) {
            _enhancedStats.weekendSuccesses += 1
        }
        
        await updateWeeklyMonthlyStats(success: true, time: time)
        await checkAndUnlockAchievements()
        await saveStats()
    }
    
    func recordAlarmSnooze(alarmId: UUID, count: Int, time: Date) async {
        let event = StreakEvent.alarmSnoozed(alarmId: alarmId, count: count, time: time)
        await processEvent(event)
        
        _enhancedStats.totalSnoozes += count
        
        // Reset no-snooze counter
        _enhancedStats.noSnoozeDays = 0
        
        await saveStats()
    }
    
    func recordAlarmMiss(alarmId: UUID, time: Date) async {
        let event = StreakEvent.alarmMissed(alarmId: alarmId, time: time)
        await processEvent(event)
        
        _enhancedStats.totalMissedAlarms += 1
        
        // Break streak
        _enhancedStats.currentStreak = 0
        _enhancedStats.streakStartDate = nil
        
        // Reset daily counters
        _enhancedStats.earlyBirdDays = 0
        _enhancedStats.noSnoozeDays = 0
        _enhancedStats.consistentDays = 0
        
        await updateWeeklyMonthlyStats(success: false, time: time)
        await saveStats()
    }
    
    func loadStats() async {
        if let data = try? storage.load(EnhancedUserStats.self, forKey: storageKey) {
            _enhancedStats = data
        }
    }
    
    func resetStats() async {
        _enhancedStats = EnhancedUserStats()
        await saveStats()
    }
    
    func getRecentActivity(days: Int) -> [StreakEvent] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return _enhancedStats.recentEvents.filter { $0.timestamp >= cutoffDate }
    }
    
    func getAchievementProgress() -> [StreakAchievement: Double] {
        var progress: [StreakAchievement: Double] = [:]
        
        for achievement in StreakAchievement.allCases {
            let currentValue = getCurrentValueForAchievement(achievement)
            let requiredValue = Double(achievement.requiredValue)
            progress[achievement] = min(1.0, Double(currentValue) / requiredValue)
        }
        
        return progress
    }
    
    // MARK: - Private Methods
    private func processEvent(_ event: StreakEvent) async {
        _enhancedStats.recentEvents.append(event)
        
        // Keep only recent events
        if _enhancedStats.recentEvents.count > maxRecentEvents {
            _enhancedStats.recentEvents = Array(_enhancedStats.recentEvents.suffix(maxRecentEvents))
        }
    }
    
    private func updateStreak(for date: Date) async {
        let calendar = Calendar.current
        
        if let lastWakeUp = _enhancedStats.lastWakeUpDate {
            let daysBetween = calendar.dateComponents([.day], from: lastWakeUp, to: date).day ?? 0
            
            if daysBetween == 1 {
                // Consecutive day - continue streak
                _enhancedStats.currentStreak += 1
            } else if daysBetween == 0 {
                // Same day - no change to streak
                return
            } else {
                // Broke streak
                _enhancedStats.currentStreak = 1
                _enhancedStats.streakStartDate = date
            }
        } else {
            // First wake up
            _enhancedStats.currentStreak = 1
            _enhancedStats.streakStartDate = date
        }
        
        // Update longest streak
        if _enhancedStats.currentStreak > _enhancedStats.longestStreak {
            _enhancedStats.longestStreak = _enhancedStats.currentStreak
            _enhancedStats.streakMilestones.append(date)
        }
        
        _enhancedStats.lastWakeUpDate = date
        
        // Update average wake up time
        await updateAverageWakeUpTime(for: date)
    }
    
    private func updateAverageWakeUpTime(for date: Date) async {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hours = timeComponents.hour ?? 0
        let minutes = timeComponents.minute ?? 0
        let seconds = timeComponents.second ?? 0
        
        let secondsSinceMidnight = TimeInterval(
            hours * 3600 + minutes * 60 + seconds
        )
        
        if let currentAverage = _enhancedStats.averageWakeUpTime {
            // Simple moving average
            _enhancedStats.averageWakeUpTime = (currentAverage + secondsSinceMidnight) / 2
        } else {
            _enhancedStats.averageWakeUpTime = secondsSinceMidnight
        }
    }
    
    private func updateWeeklyMonthlyStats(success: Bool, time: Date) async {
        let calendar = Calendar.current
        
        // Update weekly stats
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: time)?.start
        if _enhancedStats.lastWeekStart != weekStart {
            _enhancedStats.lastWeekStart = weekStart
            _enhancedStats.thisWeekSuccesses = 0
            _enhancedStats.thisWeekMisses = 0
        }
        
        if success {
            _enhancedStats.thisWeekSuccesses += 1
        } else {
            _enhancedStats.thisWeekMisses += 1
        }
        
        // Update monthly stats
        let monthStart = calendar.dateInterval(of: .month, for: time)?.start
        if _enhancedStats.lastMonthStart != monthStart {
            _enhancedStats.lastMonthStart = monthStart
            _enhancedStats.thisMonthSuccesses = 0
            _enhancedStats.thisMonthMisses = 0
        }
        
        if success {
            _enhancedStats.thisMonthSuccesses += 1
        } else {
            _enhancedStats.thisMonthMisses += 1
        }
    }
    
    private func checkAndUnlockAchievements() async {
        var newlyUnlocked: [StreakAchievement] = []
        
        for achievement in StreakAchievement.allCases {
            if !_enhancedStats.unlockedAchievements.contains(achievement) && 
               _enhancedStats.checkAchievement(achievement) {
                _enhancedStats.unlockedAchievements.insert(achievement)
                newlyUnlocked.append(achievement)
            }
        }
        
        if !newlyUnlocked.isEmpty {
            _newAchievements = newlyUnlocked
            
            // Clear new achievements after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self._newAchievements = []
            }
        }
    }
    
    private func getCurrentValueForAchievement(_ achievement: StreakAchievement) -> Int {
        switch achievement {
        case .firstWakeUp:
            return _enhancedStats.successfulWakeUps
        case .threeDayStreak, .weekStreak, .twoWeekStreak, .monthStreak:
            return _enhancedStats.currentStreak
        case .perfectWeek:
            return _enhancedStats.thisWeekSuccesses
        case .earlyBird:
            return _enhancedStats.earlyBirdDays
        case .consistent:
            return _enhancedStats.consistentDays
        case .noSnooze:
            return _enhancedStats.noSnoozeDays
        case .weekendWarrior:
            return _enhancedStats.weekendSuccesses
        }
    }
    
    private func isEarlyBird(_ time: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        return hour < 7
    }
    
    private func isWeekend(_ time: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: time)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
    
    private func saveStats() async {
        try? storage.save(_enhancedStats, forKey: storageKey)
    }
}

// MARK: - Mock Implementation
class MockStreakTrackingService: StreakTrackingServiceProtocol {
    @Published private var mockStats = EnhancedUserStats()
    @Published private var mockAchievements: [StreakAchievement] = []
    
    var enhancedStats: AnyPublisher<EnhancedUserStats, Never> {
        $mockStats.eraseToAnyPublisher()
    }
    
    var newAchievements: AnyPublisher<[StreakAchievement], Never> {
        $mockAchievements.eraseToAnyPublisher()
    }
    
    func recordAlarmDismiss(alarmId: UUID, method: StreakEvent.DismissMethod, time: Date) async {
        mockStats.successfulWakeUps += 1
        mockStats.currentStreak += 1
    }
    
    func recordAlarmSnooze(alarmId: UUID, count: Int, time: Date) async {
        mockStats.totalSnoozes += count
    }
    
    func recordAlarmMiss(alarmId: UUID, time: Date) async {
        mockStats.totalMissedAlarms += 1
        mockStats.currentStreak = 0
    }
    
    func loadStats() async {}
    
    func resetStats() async {
        mockStats = EnhancedUserStats()
    }
    
    func getRecentActivity(days: Int) -> [StreakEvent] {
        return []
    }
    
    func getAchievementProgress() -> [StreakAchievement: Double] {
        return [:]
    }
}
