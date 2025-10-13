import Foundation
import Combine

/// Coordinates alarm notifications between the system and the app UI
/// This ensures notification taps are handled even if the app wasn't running
@MainActor
class AlarmNotificationCoordinator: ObservableObject {
    static let shared = AlarmNotificationCoordinator()
    
    @Published var pendingAlarmId: String?
    @Published var shouldShowDismissalSheet = false
    
    private init() {
        // Listen for alarm notifications from NotificationDelegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAlarmTriggered(_:)),
            name: .alarmTriggered,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAlarmDismissed(_:)),
            name: .alarmDismissed,
            object: nil
        )
    }
    
    @objc private func handleAlarmTriggered(_ notification: Notification) {
        guard let alarmId = notification.userInfo?["alarmId"] as? String else { return }
        print("🔔 AlarmNotificationCoordinator: Alarm triggered: \(alarmId)")
        
        pendingAlarmId = alarmId
        shouldShowDismissalSheet = true
    }
    
    @objc private func handleAlarmDismissed(_ notification: Notification) {
        guard let alarmId = notification.userInfo?["alarmId"] as? String else { return }
        print("🔔 AlarmNotificationCoordinator: Alarm dismissed: \(alarmId)")
        
        pendingAlarmId = alarmId
        shouldShowDismissalSheet = true
    }
    
    func clearPendingAlarm() {
        pendingAlarmId = nil
        shouldShowDismissalSheet = false
    }
}

