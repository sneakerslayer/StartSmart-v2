import Foundation
import UserNotifications
import AVFoundation
import os.log

/// NotificationService - Handles alarm scheduling and notifications
/// Provides reliable alarm functionality using UNUserNotificationCenter
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "NotificationService")
    private let notificationCenter = UNUserNotificationCenter.current()
    
    @Published var authorizationState: UNAuthorizationStatus = .notDetermined
    
    private init() {
        logger.info("🔔 NotificationService initialized")
        setupNotificationDelegate()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws -> UNAuthorizationStatus {
        logger.info("🔔 Requesting notification authorization")
        
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .timeSensitive]
        let granted = try await notificationCenter.requestAuthorization(options: options)
        
        await MainActor.run {
            self.authorizationState = granted ? .authorized : .denied
        }
        
        logger.info("🔔 Notification authorization result: \(granted)")
        return granted ? .authorized : .denied
    }
    
    func getPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        await MainActor.run {
            self.authorizationState = settings.authorizationStatus
        }
        return settings.authorizationStatus
    }
    
    // MARK: - Alarm Scheduling
    
    func scheduleNotification(for alarm: StartSmart.Alarm) async throws {
        logger.info("🔔 Scheduling notification for alarm: \(alarm.label)")
        
        // Check authorization
        let status = await getPermissionStatus()
        guard status == .authorized else {
            throw NotificationError.authorizationDenied
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "🔔 StartSmart Alarm"
        content.subtitle = alarm.label.isEmpty ? "Time to wake up!" : alarm.label
        content.body = "Your personalized wake-up experience is ready!"
        content.sound = createNotificationSound(for: alarm)
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "ALARM_CATEGORY"
        
        // Add user info for alarm identification
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "useTraditionalSound": alarm.useTraditionalSound,
            "useAIScript": alarm.useAIScript,
            "audioFilePath": alarm.audioFileURL?.path ?? ""
        ]
        
        // Create trigger
        let trigger: UNNotificationTrigger
        if alarm.isRepeating {
            // Create repeating trigger
            var dateComponents = DateComponents()
            dateComponents.hour = alarm.time.hour
            dateComponents.minute = alarm.time.minute
            dateComponents.weekday = alarm.repeatDays.first?.rawValue ?? 1
            
            trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
        } else {
            // Create one-time trigger
            guard let triggerDate = Calendar.current.date(bySettingHour: alarm.time.hour, minute: alarm.time.minute, second: 0, of: Date()) else {
                throw NotificationError.invalidAlarmTime
            }
            
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: triggerDate.timeIntervalSinceNow,
                repeats: false
            )
        }
        
        // Create request
        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        try await notificationCenter.add(request)
        
        logger.info("🔔 Notification scheduled successfully: \(alarm.id.uuidString)")
    }
    
    func removeNotification(with identifier: String) async {
        logger.info("🔔 Removing notification: \(identifier)")
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func removeAllNotifications() async {
        logger.info("🔔 Removing all notifications")
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    // MARK: - Private Methods
    
    private func createNotificationSound(for alarm: StartSmart.Alarm) -> UNNotificationSound {
        if alarm.useTraditionalSound {
            // Use custom alarm sound
            let soundFileName = alarm.traditionalSound.soundFileName
            return UNNotificationSound(named: UNNotificationSoundName(soundFileName))
        } else {
            // Use default system sound
            return .default
        }
    }
    
    private func setupNotificationDelegate() {
        notificationCenter.delegate = NotificationDelegate.shared
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "NotificationDelegate")
    
    override init() {
        super.init()
        logger.info("🔔 NotificationDelegate initialized")
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        logger.info("🔔 Notification received in foreground: \(notification.request.identifier)")
        
        // Show notification with sound
        completionHandler([.banner, .sound, .badge])
        
        // Trigger alarm experience
        Task { @MainActor in
            await handleAlarmTriggered(notification)
        }
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        logger.info("🔔 Notification tapped: \(response.notification.request.identifier)")
        
        // Handle alarm dismissal
        Task { @MainActor in
            await handleAlarmTapped(response.notification)
        }
        
        completionHandler()
    }
    
    private func handleAlarmTriggered(_ notification: UNNotification) async {
        logger.info("🔔 Handling alarm trigger: \(notification.request.identifier)")
        
        // Post notification to coordinate with AlarmNotificationCoordinator
        NotificationCenter.default.post(
            name: Notification.Name("alarmTriggered"),
            object: nil,
            userInfo: ["alarmId": notification.request.identifier]
        )
    }
    
    private func handleAlarmTapped(_ notification: UNNotification) async {
        logger.info("🔔 Handling alarm tap: \(notification.request.identifier)")
        
        // Post notification to coordinate with AlarmNotificationCoordinator
        NotificationCenter.default.post(
            name: Notification.Name("alarmTapped"),
            object: nil,
            userInfo: ["alarmId": notification.request.identifier]
        )
    }
}

// MARK: - Custom Errors
enum NotificationError: LocalizedError {
    case authorizationDenied
    case invalidAlarmTime
    case schedulingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied: return "Notification authorization was denied. Please enable it in Settings."
        case .invalidAlarmTime: return "Invalid alarm time provided."
        case .schedulingFailed(let details): return "Failed to schedule notification: \(details)"
        }
    }
}
