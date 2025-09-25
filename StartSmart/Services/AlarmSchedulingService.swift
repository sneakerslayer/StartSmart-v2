import Foundation
import UserNotifications
import Combine

// MARK: - Alarm Scheduling Service Protocol
protocol AlarmSchedulingServiceProtocol {
    func scheduleAlarm(_ alarm: Alarm) async throws
    func updateScheduledAlarm(_ alarm: Alarm) async throws
    func removeScheduledAlarm(_ alarm: Alarm) async
    func removeScheduledAlarms(_ alarms: [Alarm]) async
    func removeAllScheduledAlarms() async
    func getScheduledAlarms() async -> [ScheduledAlarmInfo]
    func validateAlarmScheduling(_ alarm: Alarm) async -> AlarmSchedulingValidationResult
    func refreshAllScheduledAlarms(_ alarms: [Alarm]) async throws
    func handleTimeZoneChange() async throws
}

// MARK: - Scheduled Alarm Info
struct ScheduledAlarmInfo: Identifiable, Codable {
    let id: UUID
    let alarmId: UUID
    let notificationIdentifier: String
    let scheduledDate: Date
    let isRepeating: Bool
    let repeatDay: WeekDay?
    let status: ScheduledAlarmStatus
    
    enum ScheduledAlarmStatus: String, Codable {
        case scheduled
        case pending
        case triggered
        case failed
        case cancelled
    }
}

// MARK: - Alarm Scheduling Validation Result
struct AlarmSchedulingValidationResult {
    let isValid: Bool
    let issues: [AlarmSchedulingIssue]
    let warnings: [AlarmSchedulingWarning]
    
    var hasErrors: Bool { !issues.isEmpty }
    var hasWarnings: Bool { !warnings.isEmpty }
}

enum AlarmSchedulingIssue: LocalizedError {
    case timeInPast
    case invalidTimeConfiguration
    case notificationPermissionDenied
    case systemLimitExceeded
    case conflictingSchedule
    
    var errorDescription: String? {
        switch self {
        case .timeInPast:
            return "Alarm time is in the past"
        case .invalidTimeConfiguration:
            return "Invalid time configuration"
        case .notificationPermissionDenied:
            return "Notification permission is required"
        case .systemLimitExceeded:
            return "System notification limit exceeded"
        case .conflictingSchedule:
            return "Conflicting alarm schedule detected"
        }
    }
}

enum AlarmSchedulingWarning: LocalizedError {
    case scheduledFarInFuture
    case duplicateTime
    case timezoneAmbiguity
    case performanceImpact
    
    var errorDescription: String? {
        switch self {
        case .scheduledFarInFuture:
            return "Alarm scheduled far in the future"
        case .duplicateTime:
            return "Similar alarm time already exists"
        case .timezoneAmbiguity:
            return "Time may be affected by timezone changes"
        case .performanceImpact:
            return "Multiple alarms may impact performance"
        }
    }
}

// MARK: - Alarm Scheduling Service Error
enum AlarmSchedulingServiceError: LocalizedError {
    case notificationServiceUnavailable
    case invalidAlarmConfiguration
    case schedulingFailed(String)
    case notificationLimitExceeded
    case timezoneConflict
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .notificationServiceUnavailable:
            return "Notification service is not available"
        case .invalidAlarmConfiguration:
            return "Invalid alarm configuration provided"
        case .schedulingFailed(let reason):
            return "Failed to schedule alarm: \(reason)"
        case .notificationLimitExceeded:
            return "Maximum number of notifications exceeded"
        case .timezoneConflict:
            return "Timezone change conflicts with alarm schedule"
        case .permissionDenied:
            return "Notification permission is required for alarms"
        }
    }
}

// MARK: - Alarm Scheduling Service Implementation
@MainActor
final class AlarmSchedulingService: AlarmSchedulingServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published var scheduledAlarms: [ScheduledAlarmInfo] = []
    @Published var isLoading = false
    @Published var lastError: AlarmSchedulingServiceError?
    
    // MARK: - Dependencies
    private let notificationService: NotificationServiceProtocol
    private let alarmRepository: AlarmRepositoryProtocol
    private let alarmAudioService: AlarmAudioServiceProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let maxScheduledNotifications: Int
    private let futureSchedulingLimitDays: Int
    private let timezoneMonitoringEnabled: Bool
    
    // MARK: - Private Properties
    private var currentTimeZone: TimeZone
    private var schedulingQueue = DispatchQueue(label: "alarm.scheduling", qos: .userInitiated)
    
    // MARK: - Initialization
    init(
        notificationService: NotificationServiceProtocol,
        alarmRepository: AlarmRepositoryProtocol,
        alarmAudioService: AlarmAudioServiceProtocol? = nil,
        maxScheduledNotifications: Int = 64, // iOS system limit
        futureSchedulingLimitDays: Int = 365,
        timezoneMonitoringEnabled: Bool = true
    ) {
        self.notificationService = notificationService
        self.alarmRepository = alarmRepository
        self.alarmAudioService = alarmAudioService
        self.maxScheduledNotifications = maxScheduledNotifications
        self.futureSchedulingLimitDays = futureSchedulingLimitDays
        self.timezoneMonitoringEnabled = timezoneMonitoringEnabled
        self.currentTimeZone = TimeZone.current
        
        setupNotifications()
    }
    
    // MARK: - Public Methods
    func scheduleAlarm(_ alarm: Alarm) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Validate alarm configuration
        let validation = await validateAlarmScheduling(alarm)
        if validation.hasErrors {
            let error = AlarmSchedulingServiceError.invalidAlarmConfiguration
            lastError = error
            throw error
        }
        
        // Ensure audio content is generated for the alarm
        var alarmWithAudio = alarm
        if let audioService = alarmAudioService, alarm.needsAudioGeneration {
            do {
                alarmWithAudio = try await audioService.ensureAudioForAlarm(alarm)
                // Update the alarm in repository with generated content
                try await alarmRepository.updateAlarm(alarmWithAudio)
            } catch {
                print("Warning: Failed to generate audio for alarm \(alarm.id): \(error)")
                // Continue with default audio - don't fail the entire scheduling
            }
        }
        
        // Remove existing notifications for this alarm
        await removeScheduledAlarm(alarmWithAudio)
        
        // Schedule new notifications
        if alarmWithAudio.isRepeating {
            try await scheduleRepeatingAlarm(alarmWithAudio)
        } else {
            try await scheduleOneTimeAlarm(alarmWithAudio)
        }
        
        // Update scheduled alarms list
        await updateScheduledAlarmsList()
    }
    
    func updateScheduledAlarm(_ alarm: Alarm) async throws {
        // This is essentially a reschedule operation
        try await scheduleAlarm(alarm)
    }
    
    func removeScheduledAlarm(_ alarm: Alarm) async {
        // Remove all notifications for this alarm (including repeat variations)
        var identifiersToRemove = [alarm.id.uuidString]
        
        // Add repeat day identifiers
        for day in WeekDay.allCases {
            identifiersToRemove.append("\(alarm.id.uuidString)-\(day.rawValue)")
        }
        
        // Remove from notification service
        for identifier in identifiersToRemove {
            await notificationService.removeNotification(with: identifier)
        }
        
        // Remove from scheduled alarms list
        scheduledAlarms.removeAll { $0.alarmId == alarm.id }
    }
    
    func removeScheduledAlarms(_ alarms: [Alarm]) async {
        for alarm in alarms {
            await removeScheduledAlarm(alarm)
        }
    }
    
    func removeAllScheduledAlarms() async {
        await notificationService.removeAllNotifications()
        scheduledAlarms.removeAll()
    }
    
    func getScheduledAlarms() async -> [ScheduledAlarmInfo] {
        await updateScheduledAlarmsList()
        return scheduledAlarms
    }
    
    func validateAlarmScheduling(_ alarm: Alarm) async -> AlarmSchedulingValidationResult {
        var issues: [AlarmSchedulingIssue] = []
        var warnings: [AlarmSchedulingWarning] = []
        
        // Check notification permission
        let permissionStatus = await notificationService.getPermissionStatus()
        if permissionStatus != .authorized {
            issues.append(.notificationPermissionDenied)
        }
        
        // Check if time is in the past for one-time alarms
        if !alarm.isRepeating {
            if let nextTrigger = alarm.nextTriggerDate, nextTrigger <= Date() {
                issues.append(.timeInPast)
            }
        }
        
        // Check system notification limits
        let pendingNotifications = await notificationService.getPendingNotifications()
        let estimatedNewNotifications = alarm.isRepeating ? alarm.repeatDays.count : 1
        
        if pendingNotifications.count + estimatedNewNotifications > maxScheduledNotifications {
            issues.append(.systemLimitExceeded)
        }
        
        // Check for conflicts with existing alarms
        let existingAlarms = alarmRepository.alarmsValue
        let conflictingAlarms = existingAlarms.filter { existingAlarm in
            existingAlarm.id != alarm.id &&
            existingAlarm.isEnabled &&
            areAlarmsConflicting(alarm, existingAlarm)
        }
        
        if !conflictingAlarms.isEmpty {
            warnings.append(.duplicateTime)
        }
        
        // Check if scheduled far in the future
        if let nextTrigger = alarm.nextTriggerDate {
            let daysInFuture = Calendar.current.dateComponents([.day], from: Date(), to: nextTrigger).day ?? 0
            if daysInFuture > futureSchedulingLimitDays {
                warnings.append(.scheduledFarInFuture)
            }
        }
        
        // Check for timezone ambiguity (DST transitions)
        if isTimeAmbiguousForTimezone(alarm.time) {
            warnings.append(.timezoneAmbiguity)
        }
        
        return AlarmSchedulingValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
    
    func refreshAllScheduledAlarms(_ alarms: [Alarm]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Remove all existing notifications
        await removeAllScheduledAlarms()
        
        // Schedule all enabled alarms
        for alarm in alarms where alarm.isEnabled {
            do {
                try await scheduleAlarm(alarm)
            } catch {
                print("Failed to schedule alarm \(alarm.id): \(error)")
                // Continue with other alarms even if one fails
            }
        }
    }
    
    func handleTimeZoneChange() async throws {
        let newTimeZone = TimeZone.current
        
        guard newTimeZone != currentTimeZone else { return }
        
        print("Timezone changed from \(currentTimeZone.identifier) to \(newTimeZone.identifier)")
        currentTimeZone = newTimeZone
        
        // Refresh all scheduled alarms to account for timezone change
        let alarms = alarmRepository.alarmsValue
        try await refreshAllScheduledAlarms(alarms)
    }
    
    // MARK: - Private Methods
    private func setupNotifications() {
        // Monitor timezone changes if enabled
        if timezoneMonitoringEnabled {
            NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        try? await self?.handleTimeZoneChange()
                    }
                }
                .store(in: &cancellables)
        }
        
        // Monitor alarm changes from repository
        alarmRepository.alarms
            .sink { [weak self] alarms in
                Task { @MainActor in
                    await self?.syncWithRepositoryChanges(alarms)
                }
            }
            .store(in: &cancellables)
    }
    
    private func scheduleOneTimeAlarm(_ alarm: Alarm) async throws {
        guard let triggerDate = alarm.nextTriggerDate else {
            throw AlarmSchedulingServiceError.invalidAlarmConfiguration
        }
        
        let content = createNotificationContent(for: alarm)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: triggerDate.timeIntervalSinceNow,
            repeats: false
        )
        
        _ = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationService.scheduleNotification(for: alarm)
            
            // Track scheduled alarm
            let scheduledInfo = ScheduledAlarmInfo(
                id: UUID(),
                alarmId: alarm.id,
                notificationIdentifier: alarm.id.uuidString,
                scheduledDate: triggerDate,
                isRepeating: false,
                repeatDay: nil,
                status: .scheduled
            )
            scheduledAlarms.append(scheduledInfo)
            
        } catch {
            throw AlarmSchedulingServiceError.schedulingFailed(error.localizedDescription)
        }
    }
    
    private func scheduleRepeatingAlarm(_ alarm: Alarm) async throws {
        let content = createNotificationContent(for: alarm)
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: alarm.time)
        
        for repeatDay in alarm.repeatDays {
            var dateComponents = DateComponents()
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            dateComponents.weekday = repeatDay.rawValue
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            
            let identifier = "\(alarm.id.uuidString)-\(repeatDay.rawValue)"
            _ = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            do {
                // Schedule via notification service
                try await notificationService.scheduleNotification(for: alarm)
                
                // Calculate next occurrence for this repeat day
                let nextOccurrence = calculateNextOccurrence(for: repeatDay, time: alarm.time)
                
                // Track scheduled alarm
                let scheduledInfo = ScheduledAlarmInfo(
                    id: UUID(),
                    alarmId: alarm.id,
                    notificationIdentifier: identifier,
                    scheduledDate: nextOccurrence,
                    isRepeating: true,
                    repeatDay: repeatDay,
                    status: .scheduled
                )
                scheduledAlarms.append(scheduledInfo)
                
            } catch {
                throw AlarmSchedulingServiceError.schedulingFailed(error.localizedDescription)
            }
        }
    }
    
    private func createNotificationContent(for alarm: Alarm) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "StartSmart Alarm"
        content.body = alarm.label.isEmpty ? "Time to wake up!" : alarm.label
        content.sound = .default
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.interruptionLevel = .critical // Ensures alarm sounds even in Do Not Disturb
        
        // Add custom data for alarm handling
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "alarmTone": alarm.tone.rawValue,
            "canSnooze": alarm.snoozeEnabled,
            "maxSnoozeCount": alarm.maxSnoozeCount,
            "snoozeDuration": alarm.snoozeDuration,
            "scheduledBy": "AlarmSchedulingService",
            "scheduledAt": Date().timeIntervalSince1970
        ]
        
        return content
    }
    
    private func updateScheduledAlarmsList() async {
        let pendingNotifications = await notificationService.getPendingNotifications()
        
        // Update status of scheduled alarms based on pending notifications
        for index in scheduledAlarms.indices {
            let scheduledAlarm = scheduledAlarms[index]
            let isStillPending = pendingNotifications.contains { notification in
                notification.identifier == scheduledAlarm.notificationIdentifier
            }
            
            if !isStillPending && scheduledAlarm.status == .scheduled {
                scheduledAlarms[index] = ScheduledAlarmInfo(
                    id: scheduledAlarm.id,
                    alarmId: scheduledAlarm.alarmId,
                    notificationIdentifier: scheduledAlarm.notificationIdentifier,
                    scheduledDate: scheduledAlarm.scheduledDate,
                    isRepeating: scheduledAlarm.isRepeating,
                    repeatDay: scheduledAlarm.repeatDay,
                    status: .triggered
                )
            }
        }
    }
    
    private func syncWithRepositoryChanges(_ alarms: [Alarm]) async {
        // This method can be used to automatically sync scheduling when alarms change
        // For now, we'll just update our tracking
        await updateScheduledAlarmsList()
    }
    
    private func areAlarmsConflicting(_ alarm1: Alarm, _ alarm2: Alarm) -> Bool {
        let calendar = Calendar.current
        let time1Components = calendar.dateComponents([.hour, .minute], from: alarm1.time)
        let time2Components = calendar.dateComponents([.hour, .minute], from: alarm2.time)
        
        // Check if times are within 1 minute of each other
        let timeDiff = abs((time1Components.hour! * 60 + time1Components.minute!) -
                          (time2Components.hour! * 60 + time2Components.minute!))
        
        if timeDiff > 1 { return false }
        
        // Check repeat pattern overlap
        if alarm1.isRepeating && alarm2.isRepeating {
            return !alarm1.repeatDays.isDisjoint(with: alarm2.repeatDays)
        } else if !alarm1.isRepeating && !alarm2.isRepeating {
            // Both one-time alarms on same day
            let date1 = calendar.startOfDay(for: alarm1.time)
            let date2 = calendar.startOfDay(for: alarm2.time)
            return date1 == date2
        }
        
        return false
    }
    
    private func isTimeAmbiguousForTimezone(_ time: Date) -> Bool {
        // Check if the time falls during DST transition
        let calendar = Calendar.current
        let timeZone = TimeZone.current
        
        // Get the day of the alarm
        let alarmDay = calendar.startOfDay(for: time)
        
        // Check for DST transitions on this day
        let nextDay = calendar.date(byAdding: .day, value: 1, to: alarmDay)!
        let dstOffsetStart = timeZone.daylightSavingTimeOffset(for: alarmDay)
        let dstOffsetEnd = timeZone.daylightSavingTimeOffset(for: nextDay)
        
        return dstOffsetStart != dstOffsetEnd
    }
    
    private func calculateNextOccurrence(for weekDay: WeekDay, time: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        // Find next occurrence of this weekday
        for dayOffset in 0..<8 {
            let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: now)!
            let checkWeekday = WeekDay(from: calendar.component(.weekday, from: checkDate))
            
            if checkWeekday == weekDay {
                if let nextOccurrence = calendar.nextDate(
                    after: dayOffset == 0 ? now : calendar.startOfDay(for: checkDate),
                    matching: timeComponents,
                    matchingPolicy: .nextTime
                ) {
                    return nextOccurrence
                }
            }
        }
        
        // Fallback to next week
        return calendar.date(byAdding: .day, value: 7, to: time) ?? time
    }
}

// MARK: - Mock Alarm Scheduling Service
class MockAlarmSchedulingService: AlarmSchedulingServiceProtocol, ObservableObject {
    @Published var scheduledAlarms: [ScheduledAlarmInfo] = []
    @Published var shouldThrowError = false
    @Published var errorToThrow: AlarmSchedulingServiceError = .schedulingFailed("Mock error")
    
    func scheduleAlarm(_ alarm: Alarm) async throws {
        if shouldThrowError { throw errorToThrow }
        
        let scheduledInfo = ScheduledAlarmInfo(
            id: UUID(),
            alarmId: alarm.id,
            notificationIdentifier: alarm.id.uuidString,
            scheduledDate: alarm.nextTriggerDate ?? Date(),
            isRepeating: alarm.isRepeating,
            repeatDay: alarm.repeatDays.first,
            status: .scheduled
        )
        scheduledAlarms.append(scheduledInfo)
    }
    
    func updateScheduledAlarm(_ alarm: Alarm) async throws {
        if shouldThrowError { throw errorToThrow }
        try await scheduleAlarm(alarm)
    }
    
    func removeScheduledAlarm(_ alarm: Alarm) async {
        scheduledAlarms.removeAll { $0.alarmId == alarm.id }
    }
    
    func removeScheduledAlarms(_ alarms: [Alarm]) async {
        let alarmIds = Set(alarms.map { $0.id })
        scheduledAlarms.removeAll { alarmIds.contains($0.alarmId) }
    }
    
    func removeAllScheduledAlarms() async {
        scheduledAlarms.removeAll()
    }
    
    func getScheduledAlarms() async -> [ScheduledAlarmInfo] {
        return scheduledAlarms
    }
    
    func validateAlarmScheduling(_ alarm: Alarm) async -> AlarmSchedulingValidationResult {
        return AlarmSchedulingValidationResult(
            isValid: !shouldThrowError,
            issues: shouldThrowError ? [.invalidTimeConfiguration] : [],
            warnings: []
        )
    }
    
    func refreshAllScheduledAlarms(_ alarms: [Alarm]) async throws {
        if shouldThrowError { throw errorToThrow }
        scheduledAlarms.removeAll()
        for alarm in alarms where alarm.isEnabled {
            try await scheduleAlarm(alarm)
        }
    }
    
    func handleTimeZoneChange() async throws {
        if shouldThrowError { throw errorToThrow }
        // Mock timezone change handling
    }
}
