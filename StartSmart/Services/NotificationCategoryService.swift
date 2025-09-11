import Foundation
import UserNotifications

// MARK: - Notification Category Service Protocol
protocol NotificationCategoryServiceProtocol {
    func setupAlarmNotificationCategories() async
    func getAlarmNotificationCategory() -> UNNotificationCategory
    func getSnoozeNotificationCategory() -> UNNotificationCategory
}

// MARK: - Notification Category Service
final class NotificationCategoryService: NotificationCategoryServiceProtocol {
    
    // MARK: - Category Identifiers
    enum CategoryIdentifier: String, CaseIterable {
        case alarm = "ALARM_CATEGORY"
        case snooze = "SNOOZE_CATEGORY"
        case reminder = "REMINDER_CATEGORY"
        
        var displayName: String {
            switch self {
            case .alarm: return "Alarm"
            case .snooze: return "Snooze"
            case .reminder: return "Reminder"
            }
        }
    }
    
    // MARK: - Action Identifiers
    enum ActionIdentifier: String, CaseIterable {
        case snooze = "SNOOZE_ACTION"
        case dismiss = "DISMISS_ACTION"
        case snooze5 = "SNOOZE_5_ACTION"
        case snooze10 = "SNOOZE_10_ACTION"
        case snooze15 = "SNOOZE_15_ACTION"
        case turnOff = "TURN_OFF_ACTION"
        
        var displayName: String {
            switch self {
            case .snooze: return "Snooze"
            case .dismiss: return "Dismiss"
            case .snooze5: return "5 min"
            case .snooze10: return "10 min"
            case .snooze15: return "15 min"
            case .turnOff: return "Turn Off"
            }
        }
        
        var isDestructive: Bool {
            switch self {
            case .dismiss, .turnOff: return true
            default: return false
            }
        }
        
        var options: UNNotificationActionOptions {
            var options: UNNotificationActionOptions = []
            
            if isDestructive {
                options.insert(.destructive)
            }
            
            // All alarm actions should bring app to foreground for better UX
            options.insert(.foreground)
            
            return options
        }
    }
    
    // MARK: - Dependencies
    private let notificationCenter: UNUserNotificationCenter
    
    // MARK: - Initialization
    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }
    
    // MARK: - Public Methods
    func setupAlarmNotificationCategories() async {
        let categories: Set<UNNotificationCategory> = [
            getAlarmNotificationCategory(),
            getSnoozeNotificationCategory()
        ]
        
        await notificationCenter.setNotificationCategories(categories)
    }
    
    func getAlarmNotificationCategory() -> UNNotificationCategory {
        let snoozeAction = UNNotificationAction(
            identifier: ActionIdentifier.snooze.rawValue,
            title: ActionIdentifier.snooze.displayName,
            options: ActionIdentifier.snooze.options
        )
        
        let dismissAction = UNNotificationAction(
            identifier: ActionIdentifier.dismiss.rawValue,
            title: ActionIdentifier.dismiss.displayName,
            options: ActionIdentifier.dismiss.options
        )
        
        let turnOffAction = UNNotificationAction(
            identifier: ActionIdentifier.turnOff.rawValue,
            title: ActionIdentifier.turnOff.displayName,
            options: ActionIdentifier.turnOff.options
        )
        
        return UNNotificationCategory(
            identifier: CategoryIdentifier.alarm.rawValue,
            actions: [snoozeAction, dismissAction, turnOffAction],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay]
        )
    }
    
    func getSnoozeNotificationCategory() -> UNNotificationCategory {
        let snooze5Action = UNNotificationAction(
            identifier: ActionIdentifier.snooze5.rawValue,
            title: ActionIdentifier.snooze5.displayName,
            options: ActionIdentifier.snooze5.options
        )
        
        let snooze10Action = UNNotificationAction(
            identifier: ActionIdentifier.snooze10.rawValue,
            title: ActionIdentifier.snooze10.displayName,
            options: ActionIdentifier.snooze10.options
        )
        
        let snooze15Action = UNNotificationAction(
            identifier: ActionIdentifier.snooze15.rawValue,
            title: ActionIdentifier.snooze15.displayName,
            options: ActionIdentifier.snooze15.options
        )
        
        let dismissAction = UNNotificationAction(
            identifier: ActionIdentifier.dismiss.rawValue,
            title: ActionIdentifier.dismiss.displayName,
            options: ActionIdentifier.dismiss.options
        )
        
        return UNNotificationCategory(
            identifier: CategoryIdentifier.snooze.rawValue,
            actions: [snooze5Action, snooze10Action, snooze15Action, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }
}

// MARK: - Enhanced Notification Delegate
final class EnhancedNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = EnhancedNotificationDelegate()
    
    // MARK: - Dependencies
    private let alarmRepository: AlarmRepositoryProtocol?
    private let schedulingService: AlarmSchedulingServiceProtocol?
    
    // MARK: - Initialization
    init(
        alarmRepository: AlarmRepositoryProtocol? = nil,
        schedulingService: AlarmSchedulingServiceProtocol? = nil
    ) {
        self.alarmRepository = alarmRepository
        self.schedulingService = schedulingService
        super.init()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Always show alarm notifications with critical presentation
        if notification.request.content.categoryIdentifier == NotificationCategoryService.CategoryIdentifier.alarm.rawValue {
            completionHandler([.alert, .sound, .badge])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        guard let alarmIdString = userInfo["alarmId"] as? String,
              let alarmId = UUID(uuidString: alarmIdString) else {
            completionHandler()
            return
        }
        
        Task {
            await handleNotificationResponse(response, alarmId: alarmId, userInfo: userInfo)
            completionHandler()
        }
    }
    
    // MARK: - Private Methods
    private func handleNotificationResponse(
        _ response: UNNotificationResponse,
        alarmId: UUID,
        userInfo: [AnyHashable: Any]
    ) async {
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            await handleAlarmTap(alarmId: alarmId)
            
        case NotificationCategoryService.ActionIdentifier.snooze.rawValue:
            await handleSnoozeAction(alarmId: alarmId, userInfo: userInfo)
            
        case NotificationCategoryService.ActionIdentifier.snooze5.rawValue:
            await handleCustomSnoozeAction(alarmId: alarmId, minutes: 5)
            
        case NotificationCategoryService.ActionIdentifier.snooze10.rawValue:
            await handleCustomSnoozeAction(alarmId: alarmId, minutes: 10)
            
        case NotificationCategoryService.ActionIdentifier.snooze15.rawValue:
            await handleCustomSnoozeAction(alarmId: alarmId, minutes: 15)
            
        case NotificationCategoryService.ActionIdentifier.dismiss.rawValue:
            await handleDismissAction(alarmId: alarmId)
            
        case NotificationCategoryService.ActionIdentifier.turnOff.rawValue:
            await handleTurnOffAction(alarmId: alarmId)
            
        case UNNotificationDismissActionIdentifier:
            await handleNotificationDismiss(alarmId: alarmId)
            
        default:
            break
        }
    }
    
    private func handleAlarmTap(alarmId: UUID) async {
        // Post notification for app to handle alarm presentation
        await MainActor.run {
            NotificationCenter.default.post(
                name: .alarmTriggered,
                object: nil,
                userInfo: ["alarmId": alarmId.uuidString, "source": "tap"]
            )
        }
    }
    
    private func handleSnoozeAction(alarmId: UUID, userInfo: [AnyHashable: Any]) async {
        guard let snoozeDuration = userInfo["snoozeDuration"] as? TimeInterval else {
            await handleCustomSnoozeAction(alarmId: alarmId, minutes: 5) // Default fallback
            return
        }
        
        await scheduleSnoozeNotification(
            alarmId: alarmId,
            snoozeDuration: snoozeDuration,
            userInfo: userInfo
        )
        
        // Update alarm repository
        if let alarmRepository = alarmRepository {
            try? await alarmRepository.snoozeAlarm(withId: alarmId)
        }
        
        await MainActor.run {
            NotificationCenter.default.post(
                name: .alarmSnoozed,
                object: nil,
                userInfo: ["alarmId": alarmId.uuidString, "duration": snoozeDuration]
            )
        }
    }
    
    private func handleCustomSnoozeAction(alarmId: UUID, minutes: Int) async {
        let snoozeDuration = TimeInterval(minutes * 60)
        
        await scheduleSnoozeNotification(
            alarmId: alarmId,
            snoozeDuration: snoozeDuration,
            userInfo: ["alarmId": alarmId.uuidString]
        )
        
        // Update alarm repository
        if let alarmRepository = alarmRepository {
            try? await alarmRepository.snoozeAlarm(withId: alarmId)
        }
        
        await MainActor.run {
            NotificationCenter.default.post(
                name: .alarmSnoozed,
                object: nil,
                userInfo: ["alarmId": alarmId.uuidString, "duration": snoozeDuration]
            )
        }
    }
    
    private func handleDismissAction(alarmId: UUID) async {
        // Mark alarm as triggered
        if let alarmRepository = alarmRepository {
            try? await alarmRepository.markAlarmAsTriggered(withId: alarmId)
        }
        
        await MainActor.run {
            NotificationCenter.default.post(
                name: .alarmDismissed,
                object: nil,
                userInfo: ["alarmId": alarmId.uuidString, "method": "dismiss"]
            )
        }
    }
    
    private func handleTurnOffAction(alarmId: UUID) async {
        // Turn off the alarm entirely
        if let alarmRepository = alarmRepository {
            try? await alarmRepository.toggleAlarm(withId: alarmId)
        }
        
        await MainActor.run {
            NotificationCenter.default.post(
                name: .alarmTurnedOff,
                object: nil,
                userInfo: ["alarmId": alarmId.uuidString]
            )
        }
    }
    
    private func handleNotificationDismiss(alarmId: UUID) async {
        // User dismissed notification without action - still trigger alarm
        await handleAlarmTap(alarmId: alarmId)
    }
    
    private func scheduleSnoozeNotification(
        alarmId: UUID,
        snoozeDuration: TimeInterval,
        userInfo: [AnyHashable: Any]
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "StartSmart Alarm (Snoozed)"
        content.body = "Time to wake up!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryService.CategoryIdentifier.snooze.rawValue
        content.interruptionLevel = .critical
        content.userInfo = userInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: snoozeDuration,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "\(alarmId.uuidString)-snooze-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Notification Names Extension
extension Notification.Name {
    static let alarmTurnedOff = Notification.Name("alarmTurnedOff")
}
