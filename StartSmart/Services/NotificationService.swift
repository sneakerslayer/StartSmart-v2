import Foundation
import UserNotifications
import Combine

// MARK: - Notification Permission Status
enum NotificationPermissionStatus {
    case notDetermined
    case denied
    case authorized
    case provisional
}

// MARK: - Notification Service Protocol
protocol NotificationServiceProtocol {
    func requestPermission() async throws -> NotificationPermissionStatus
    func getPermissionStatus() async -> NotificationPermissionStatus
    func scheduleNotification(for alarm: Alarm) async throws
    func removeNotification(with identifier: String) async
    func removeAllNotifications() async
    func getPendingNotifications() async -> [UNNotificationRequest]
}

// MARK: - Notification Service Errors
enum NotificationServiceError: LocalizedError {
    case permissionDenied
    case schedulingFailed(String)
    case invalidAlarm
    case notificationNotFound
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission was denied. Please enable notifications in Settings to receive alarms."
        case .schedulingFailed(let reason):
            return "Failed to schedule alarm: \(reason)"
        case .invalidAlarm:
            return "Invalid alarm configuration. Please check your alarm settings."
        case .notificationNotFound:
            return "The specified notification could not be found."
        }
    }
}

// MARK: - Notification Service Implementation
final class NotificationService: NotificationServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published var permissionStatus: NotificationPermissionStatus = .notDetermined
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    // MARK: - Private Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupNotificationDelegate()
        Task {
            await updatePermissionStatus()
        }
    }
    
    // MARK: - Permission Management
    func requestPermission() async throws -> NotificationPermissionStatus {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
        
        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)
            let status = granted ? NotificationPermissionStatus.authorized : .denied
            
            await MainActor.run {
                self.permissionStatus = status
            }
            
            if !granted {
                throw NotificationServiceError.permissionDenied
            }
            
            return status
        } catch {
            await MainActor.run {
                self.permissionStatus = .denied
            }
            throw NotificationServiceError.permissionDenied
        }
    }
    
    func getPermissionStatus() async -> NotificationPermissionStatus {
        let settings = await notificationCenter.notificationSettings()
        let status = mapAuthorizationStatus(settings.authorizationStatus)
        
        await MainActor.run {
            self.permissionStatus = status
        }
        
        return status
    }
    
    // MARK: - Notification Scheduling
    func scheduleNotification(for alarm: Alarm) async throws {
        guard alarm.isEnabled else {
            throw NotificationServiceError.invalidAlarm
        }
        
        // Check permission first
        let permissionStatus = await getPermissionStatus()
        guard permissionStatus == .authorized else {
            throw NotificationServiceError.permissionDenied
        }
        
        // Remove existing notification for this alarm
        await removeNotification(with: alarm.id.uuidString)
        
        // Schedule new notification
        if alarm.isRepeating {
            try await scheduleRepeatingNotification(for: alarm)
        } else {
            try await scheduleOneTimeNotification(for: alarm)
        }
        
        await updatePendingNotifications()
    }
    
    private func scheduleOneTimeNotification(for alarm: Alarm) async throws {
        guard let triggerDate = alarm.nextTriggerDate else {
            throw NotificationServiceError.invalidAlarm
        }
        
        let content = createNotificationContent(for: alarm)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: triggerDate.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            throw NotificationServiceError.schedulingFailed(error.localizedDescription)
        }
    }
    
    private func scheduleRepeatingNotification(for alarm: Alarm) async throws {
        let content = createNotificationContent(for: alarm)
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: alarm.time)
        
        // Schedule notification for each repeat day
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
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            do {
                try await notificationCenter.add(request)
            } catch {
                throw NotificationServiceError.schedulingFailed(error.localizedDescription)
            }
        }
    }
    
    private func createNotificationContent(for alarm: Alarm) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "StartSmart Alarm"
        content.body = alarm.label.isEmpty ? "Time to wake up!" : alarm.label
        
        // Set audio - use traditional sound for Phase 1 alarm
        if alarm.useTraditionalSound {
            // Use the selected traditional alarm sound
            content.sound = alarm.traditionalSound.systemSound
        } else if let audioURL = alarm.audioFileURL, FileManager.default.fileExists(atPath: audioURL.path) {
            // Fallback to custom AI-generated audio if traditional sound is disabled
            let soundName = audioURL.lastPathComponent
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        } else {
            // Final fallback to default critical alarm sound
            content.sound = .defaultCritical
        }
        
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.interruptionLevel = .critical // Ensures alarm sounds even in Do Not Disturb
        
        // Add custom data for alarm handling
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "alarmTone": alarm.tone.rawValue,
            "traditionalSound": alarm.traditionalSound.rawValue,
            "useTraditionalSound": alarm.useTraditionalSound,
            "useAIScript": alarm.useAIScript,
            "canSnooze": alarm.snoozeEnabled,
            "maxSnoozeCount": alarm.maxSnoozeCount,
            "snoozeDuration": alarm.snoozeDuration,
            "hasCustomAudio": alarm.hasCustomAudio,
            "audioFilePath": alarm.audioFileURL?.path ?? ""
        ]
        
        return content
    }
    
    // MARK: - Notification Removal
    func removeNotification(with identifier: String) async {
        // Remove both the main identifier and any repeat day variations
        var identifiersToRemove = [identifier]
        
        // Add potential repeat day identifiers
        for day in WeekDay.allCases {
            identifiersToRemove.append("\(identifier)-\(day.rawValue)")
        }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        await updatePendingNotifications()
    }
    
    func removeAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        await updatePendingNotifications()
    }
    
    // MARK: - Notification Querying
    func getPendingNotifications() async -> [UNNotificationRequest] {
        let notifications = await notificationCenter.pendingNotificationRequests()
        
        await MainActor.run {
            self.pendingNotifications = notifications
        }
        
        return notifications
    }
    
    // MARK: - Private Helper Methods
    private func setupNotificationDelegate() {
        notificationCenter.delegate = NotificationDelegate.shared
    }
    
    private func updatePermissionStatus() async {
        _ = await getPermissionStatus()
    }
    
    private func updatePendingNotifications() async {
        _ = await getPendingNotifications()
    }
    
    private func mapAuthorizationStatus(_ status: UNAuthorizationStatus) -> NotificationPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .provisional
        @unknown default:
            return .notDetermined
        }
    }
}

// MARK: - Notification Delegate
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Always show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification interaction
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let alarmId = userInfo["alarmId"] as? String {
            // Handle alarm response based on action
            switch response.actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                // User tapped the notification
                handleAlarmTap(alarmId: alarmId)
            case "SNOOZE_ACTION":
                // Handle snooze action
                handleSnoozeAction(alarmId: alarmId, userInfo: userInfo)
            case "DISMISS_ACTION":
                // Handle dismiss action
                handleDismissAction(alarmId: alarmId)
            default:
                break
            }
        }
        
        completionHandler()
    }
    
    private func handleAlarmTap(alarmId: String) {
        // Post notification for app to handle alarm presentation
        NotificationCenter.default.post(
            name: .alarmTriggered,
            object: nil,
            userInfo: ["alarmId": alarmId]
        )
    }
    
    private func handleSnoozeAction(alarmId: String, userInfo: [AnyHashable: Any]) {
        guard let snoozeDuration = userInfo["snoozeDuration"] as? TimeInterval else { return }
        
        // Schedule snooze notification
        let content = UNMutableNotificationContent()
        content.title = "StartSmart Alarm (Snoozed)"
        content.body = "Time to wake up!"
        content.sound = .default
        content.userInfo = userInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: snoozeDuration,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "\(alarmId)-snooze-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
        
        // Post notification for app to handle snooze
        NotificationCenter.default.post(
            name: .alarmSnoozed,
            object: nil,
            userInfo: ["alarmId": alarmId]
        )
    }
    
    private func handleDismissAction(alarmId: String) {
        // Post notification for app to handle dismissal
        NotificationCenter.default.post(
            name: .alarmDismissed,
            object: nil,
            userInfo: ["alarmId": alarmId]
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let alarmTriggered = Notification.Name("alarmTriggered")
    static let alarmSnoozed = Notification.Name("alarmSnoozed")
    static let alarmDismissed = Notification.Name("alarmDismissed")
}
