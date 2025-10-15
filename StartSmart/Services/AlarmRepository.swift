import Foundation
import Combine

// MARK: - Alarm Repository Protocol
@MainActor
protocol AlarmRepositoryProtocol {
    var alarms: Published<[Alarm]>.Publisher { get }
    var alarmsValue: [Alarm] { get }
    
    func loadAlarms() async throws
    func saveAlarm(_ alarm: Alarm) async throws
    func updateAlarm(_ alarm: Alarm) async throws
    func deleteAlarm(withId id: UUID) async throws
    func deleteAlarm(_ alarm: Alarm) async throws
    func deleteAllAlarms() async throws
    func getAlarm(withId id: UUID) async -> Alarm?
    func getEnabledAlarms() async -> [Alarm]
    func getNextAlarm() async -> Alarm?
    func toggleAlarm(withId id: UUID) async throws
    func snoozeAlarm(withId id: UUID) async throws
    func dismissAlarm(withId id: UUID) async throws
    func markAlarmAsTriggered(withId id: UUID) async throws
}

// MARK: - Alarm Repository Error
enum AlarmRepositoryError: LocalizedError {
    case alarmNotFound
    case invalidAlarmData
    case storageError(String)
    case duplicateAlarm
    case maxAlarmsReached(Int)
    
    var errorDescription: String? {
        switch self {
        case .alarmNotFound:
            return "The specified alarm could not be found."
        case .invalidAlarmData:
            return "Invalid alarm data provided."
        case .storageError(let reason):
            return "Storage error: \(reason)"
        case .duplicateAlarm:
            return "An alarm with the same configuration already exists."
        case .maxAlarmsReached(let limit):
            return "Maximum number of alarms reached (\(limit)). Please delete an existing alarm first."
        }
    }
}

// MARK: - Alarm Repository Implementation
@MainActor
final class AlarmRepository: AlarmRepositoryProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published private var _alarms: [Alarm] = []
    @Published var isLoading = false
    @Published var lastError: AlarmRepositoryError?
    
    // MARK: - Protocol Properties
    var alarms: Published<[Alarm]>.Publisher { $_alarms }
    var alarmsValue: [Alarm] { _alarms }
    
    // MARK: - Dependencies
    private let storageManager: StorageManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let maxAlarms: Int
    private let autoSyncEnabled: Bool
    
    // MARK: - Initialization
    init(
        storageManager: StorageManager = StorageManager(),
        maxAlarms: Int = 50,
        autoSyncEnabled: Bool = true
    ) {
        self.storageManager = storageManager
        self.maxAlarms = maxAlarms
        self.autoSyncEnabled = autoSyncEnabled
        
        Task {
            try await loadAlarms()
        }
    }
    
    // MARK: - Public Methods
    func loadAlarms() async throws {
        isLoading = true
        lastError = nil
        
        do {
            let loadedAlarms = try storageManager.loadAlarms()
            _alarms = loadedAlarms.sorted { $0.time < $1.time }
            isLoading = false
        } catch {
            isLoading = false
            let repositoryError = AlarmRepositoryError.storageError(error.localizedDescription)
            lastError = repositoryError
            throw repositoryError
        }
    }
    
    func saveAlarm(_ alarm: Alarm) async throws {
        // Validate alarm limit
        if _alarms.count >= maxAlarms {
            let error = AlarmRepositoryError.maxAlarmsReached(maxAlarms)
            lastError = error
            throw error
        }
        
        // Check for duplicates (same time and repeat pattern)
        if isDuplicateAlarm(alarm) {
            let error = AlarmRepositoryError.duplicateAlarm
            lastError = error
            throw error
        }
        
        // Add alarm to collection
        _alarms.append(alarm)
        _alarms.sort { $0.time < $1.time }
        
        try await persistAlarms()
        
        // Schedule notification if alarm is enabled
        if alarm.isEnabled {
            try await scheduleNotification(for: alarm)
        }
    }
    
    func updateAlarm(_ alarm: Alarm) async throws {
        guard let index = _alarms.firstIndex(where: { $0.id == alarm.id }) else {
            let error = AlarmRepositoryError.alarmNotFound
            lastError = error
            throw error
        }
        
        let oldAlarm = _alarms[index]
        _alarms[index] = alarm
        _alarms.sort { $0.time < $1.time }
        
        try await persistAlarms()
        
        // Update notification
        await removeNotification(for: oldAlarm)
        if alarm.isEnabled {
            try await scheduleNotification(for: alarm)
        }
    }
    
    func deleteAlarm(withId id: UUID) async throws {
        guard let index = _alarms.firstIndex(where: { $0.id == id }) else {
            let error = AlarmRepositoryError.alarmNotFound
            lastError = error
            throw error
        }
        
        let alarm = _alarms[index]
        _alarms.remove(at: index)
        
        try await persistAlarms()
        await removeNotification(for: alarm)
    }
    
    func deleteAlarm(_ alarm: Alarm) async throws {
        try await deleteAlarm(withId: alarm.id)
    }
    
    func deleteAllAlarms() async throws {
        let alarmIds = _alarms.map { $0.id }
        _alarms.removeAll()
        
        try await persistAlarms()
        
        // Remove all notifications - handled by AlarmKit
        // await notificationService?.removeAllNotifications()
    }
    
    func getAlarm(withId id: UUID) async -> Alarm? {
        return _alarms.first { $0.id == id }
    }
    
    func getEnabledAlarms() async -> [Alarm] {
        return _alarms.filter { $0.isEnabled }
    }
    
    func getNextAlarm() async -> Alarm? {
        let enabledAlarms = await getEnabledAlarms()
        let alarmDates: [(Alarm, Date)] = enabledAlarms.compactMap { alarm in
            guard let nextTrigger = alarm.nextTriggerDate else { return nil }
            return (alarm, nextTrigger)
        }
        let sortedAlarms: [(Alarm, Date)] = alarmDates.sorted(by: { $0.1 < $1.1 })
        return sortedAlarms.first?.0
    }
    
    func toggleAlarm(withId id: UUID) async throws {
        guard let index = _alarms.firstIndex(where: { $0.id == id }) else {
            let error = AlarmRepositoryError.alarmNotFound
            lastError = error
            throw error
        }
        
        var alarm = _alarms[index]
        alarm.toggle()
        _alarms[index] = alarm
        
        try await persistAlarms()
        
        // Update notification
        if alarm.isEnabled {
            try await scheduleNotification(for: alarm)
        } else {
            await removeNotification(for: alarm)
        }
    }
    
    func snoozeAlarm(withId id: UUID) async throws {
        guard let index = _alarms.firstIndex(where: { $0.id == id }) else {
            let error = AlarmRepositoryError.alarmNotFound
            lastError = error
            throw error
        }
        
        var alarm = _alarms[index]
        guard alarm.canSnooze else {
            let error = AlarmRepositoryError.invalidAlarmData
            lastError = error
            throw error
        }
        
        alarm.snooze()
        _alarms[index] = alarm
        
        try await persistAlarms()
        
        // Note: Snooze notification is handled by NotificationDelegate
        // This just updates the alarm state
    }
    
    func dismissAlarm(withId id: UUID) async throws {
        guard let index = _alarms.firstIndex(where: { $0.id == id }) else {
            let error = AlarmRepositoryError.alarmNotFound
            lastError = error
            throw error
        }
        
        var alarm = _alarms[index]
        alarm.markTriggered()
        alarm.resetSnooze() // Reset snooze count when dismissed
        _alarms[index] = alarm
        
        try await persistAlarms()
        
        // If it's a one-time alarm, it's now disabled - remove notification
        if !alarm.isEnabled {
            await removeNotification(for: alarm)
        }
    }
    
    func markAlarmAsTriggered(withId id: UUID) async throws {
        guard let index = _alarms.firstIndex(where: { $0.id == id }) else {
            let error = AlarmRepositoryError.alarmNotFound
            lastError = error
            throw error
        }
        
        var alarm = _alarms[index]
        alarm.markTriggered()
        _alarms[index] = alarm
        
        try await persistAlarms()
        
        // If it's a one-time alarm, it's now disabled - remove notification
        if !alarm.isEnabled {
            await removeNotification(for: alarm)
        }
    }
    
    // MARK: - Batch Operations
    func importAlarms(_ alarms: [Alarm]) async throws {
        // Validate total count
        if _alarms.count + alarms.count > maxAlarms {
            let error = AlarmRepositoryError.maxAlarmsReached(maxAlarms)
            lastError = error
            throw error
        }
        
        // Filter out duplicates
        let newAlarms = alarms.filter { newAlarm in
            !_alarms.contains { $0.id == newAlarm.id }
        }
        
        _alarms.append(contentsOf: newAlarms)
        _alarms.sort { $0.time < $1.time }
        
        try await persistAlarms()
        
        // Schedule notifications for enabled alarms
        for alarm in newAlarms where alarm.isEnabled {
            try await scheduleNotification(for: alarm)
        }
    }
    
    func exportAlarms() async -> [Alarm] {
        return _alarms
    }
    
    // MARK: - Statistics and Analytics
    func getAlarmStatistics() async -> AlarmStatistics {
        let enabledCount = _alarms.filter { $0.isEnabled }.count
        let disabledCount = _alarms.count - enabledCount
        let repeatingCount = _alarms.filter { $0.isRepeating }.count
        let oneTimeCount = _alarms.count - repeatingCount

        let toneDistribution = Dictionary(grouping: _alarms, by: { $0.tone })
            .mapValues { $0.count }

        let snoozeCounts = _alarms.compactMap { $0.lastTriggered != nil ? $0.currentSnoozeCount : nil }
        let avgSnoozeCount: Int = snoozeCounts.isEmpty ? 0 : snoozeCounts.reduce(0, +) / snoozeCounts.count

        return AlarmStatistics(
            totalAlarms: _alarms.count,
            enabledAlarms: enabledCount,
            disabledAlarms: disabledCount,
            repeatingAlarms: repeatingCount,
            oneTimeAlarms: oneTimeCount,
            toneDistribution: toneDistribution,
            averageSnoozeCount: avgSnoozeCount
        )
    }
    
    // MARK: - Private Methods
    private func persistAlarms() async throws {
        do {
            try storageManager.saveAlarms(_alarms)
        } catch {
            let repositoryError = AlarmRepositoryError.storageError(error.localizedDescription)
            lastError = repositoryError
            throw repositoryError
        }
    }
    
    private func isDuplicateAlarm(_ alarm: Alarm) -> Bool {
        return _alarms.contains { existingAlarm in
            existingAlarm.time == alarm.time &&
            existingAlarm.repeatDays == alarm.repeatDays &&
            existingAlarm.id != alarm.id
        }
    }
    
    private func scheduleNotification(for alarm: Alarm) async throws {
        // AlarmKit handles scheduling automatically - no manual scheduling needed
        print("AlarmKit will handle scheduling for alarm \(alarm.id)")
    }
    
    private func removeNotification(for alarm: Alarm) async {
        // AlarmKit handles removal automatically - no manual removal needed
        print("AlarmKit will handle removal for alarm \(alarm.id)")
    }
}

// MARK: - Alarm Statistics
struct AlarmStatistics: Codable {
    let totalAlarms: Int
    let enabledAlarms: Int
    let disabledAlarms: Int
    let repeatingAlarms: Int
    let oneTimeAlarms: Int
    let toneDistribution: [AlarmTone: Int]
    let averageSnoozeCount: Int
    
    var enabledPercentage: Double {
        guard totalAlarms > 0 else { return 0 }
        return Double(enabledAlarms) / Double(totalAlarms) * 100
    }
    
    var repeatingPercentage: Double {
        guard totalAlarms > 0 else { return 0 }
        return Double(repeatingAlarms) / Double(totalAlarms) * 100
    }
    
    var mostPopularTone: AlarmTone? {
        guard !toneDistribution.isEmpty else { return nil }
        let sorted: [(key: AlarmTone, value: Int)] = toneDistribution.sorted { $0.value > $1.value }
        return sorted.first?.key
    }
}

// MARK: - Mock Alarm Repository
@MainActor
class MockAlarmRepository: AlarmRepositoryProtocol, ObservableObject {
    @Published private var _alarms: [Alarm] = []
    @Published var shouldThrowError = false
    @Published var errorToThrow: AlarmRepositoryError = .storageError("Mock error")
    
    var alarms: Published<[Alarm]>.Publisher { $_alarms }
    var alarmsValue: [Alarm] { _alarms }
    
    func loadAlarms() async throws {
        if shouldThrowError { throw errorToThrow }
        // Mock data for testing
        _alarms = createMockAlarms()
    }
    
    func saveAlarm(_ alarm: Alarm) async throws {
        if shouldThrowError { throw errorToThrow }
        _alarms.append(alarm)
    }
    
    func updateAlarm(_ alarm: Alarm) async throws {
        if shouldThrowError { throw errorToThrow }
        if let index = _alarms.firstIndex(where: { $0.id == alarm.id }) {
            _alarms[index] = alarm
        }
    }
    
    func deleteAlarm(withId id: UUID) async throws {
        if shouldThrowError { throw errorToThrow }
        _alarms.removeAll { $0.id == id }
    }
    
    func deleteAlarm(_ alarm: Alarm) async throws {
        try await deleteAlarm(withId: alarm.id)
    }
    
    func deleteAllAlarms() async throws {
        if shouldThrowError { throw errorToThrow }
        _alarms.removeAll()
    }
    
    func getAlarm(withId id: UUID) async -> Alarm? {
        return _alarms.first { $0.id == id }
    }
    
    func getEnabledAlarms() async -> [Alarm] {
        return _alarms.filter { $0.isEnabled }
    }
    
    func getNextAlarm() async -> Alarm? {
        let enabledAlarms = await getEnabledAlarms()
        return enabledAlarms.first { $0.nextTriggerDate != nil }
    }
    
    func toggleAlarm(withId id: UUID) async throws {
        if shouldThrowError { throw errorToThrow }
        if let index = _alarms.firstIndex(where: { $0.id == id }) {
            _alarms[index].toggle()
        }
    }
    
    func snoozeAlarm(withId id: UUID) async throws {
        if shouldThrowError { throw errorToThrow }
        if let index = _alarms.firstIndex(where: { $0.id == id }) {
            _alarms[index].snooze()
        }
    }
    
    func markAlarmAsTriggered(withId id: UUID) async throws {
        if shouldThrowError { throw errorToThrow }
        if let index = _alarms.firstIndex(where: { $0.id == id }) {
            _alarms[index].markTriggered()
        }
    }
    
    func dismissAlarm(withId id: UUID) async throws {
        // Mock implementation: just mark as triggered and reset snooze
        if let index = _alarms.firstIndex(where: { $0.id == id }) {
            _alarms[index].markTriggered()
            _alarms[index].resetSnooze()
        }
    }
    
    private func createMockAlarms() -> [Alarm] {
        let calendar = Calendar.current
        let now = Date()
        return [
            Alarm(
                time: calendar.date(byAdding: .hour, value: 1, to: now)!,
                label: "Morning Workout",
                repeatDays: [.monday, .wednesday, .friday],
                tone: .energetic
            ),
            Alarm(
                time: calendar.date(byAdding: .hour, value: 8, to: now)!,
                label: "Work Meeting",
                isEnabled: false,
                repeatDays: [],
                tone: .gentle
            )
        ]
    }
}
