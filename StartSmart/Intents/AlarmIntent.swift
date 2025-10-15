import Foundation
import AppIntents
import AlarmKit

// MARK: - Wake Up Intent for Reliable Alarm Dismissal
// Note: WakeUpIntent is defined in WakeUpIntent.swift

// MARK: - Legacy Dismiss Intent (kept for compatibility)

/// App Intent for dismissing StartSmart alarms
@available(iOS 26.0, *)
struct DismissAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Dismiss Alarm"
    static var description: IntentDescription = IntentDescription("Dismiss a StartSmart alarm")
    
    @Parameter(title: "Alarm ID")
    var alarmId: String
    
    func perform() async throws -> some IntentResult {
        do {
            // Dismiss the alarm using AlarmKit Manager
            try await AlarmKitManager.shared.dismissAlarm(withId: alarmId)
            
            // Trigger the dismissal flow in our app
            await MainActor.run {
                AlarmNotificationCoordinator.shared.showAlarmDismissal(for: alarmId)
            }
            
            return .result()
        } catch {
            throw IntentError.failedToDismissAlarm(error.localizedDescription)
        }
    }
}

/// App Intent for snoozing StartSmart alarms
@available(iOS 26.0, *)
struct SnoozeAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Snooze Alarm"
    static var description: IntentDescription = IntentDescription("Snooze a StartSmart alarm")
    
    @Parameter(title: "Alarm ID")
    var alarmId: String
    
    @Parameter(title: "Snooze Duration", default: 300)
    var snoozeDuration: TimeInterval
    
    func perform() async throws -> some IntentResult {
        do {
            // Snooze the alarm using AlarmKit Manager
            try await AlarmKitManager.shared.snoozeAlarm(withId: alarmId, duration: snoozeDuration)
            
            return .result()
        } catch {
            throw IntentError.failedToSnoozeAlarm(error.localizedDescription)
        }
    }
}

/// App Intent for creating StartSmart alarms
@available(iOS 26.0, *)
struct CreateAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Alarm"
    static var description: IntentDescription = IntentDescription("Create a new StartSmart alarm")
    
    @Parameter(title: "Alarm Label")
    var alarmLabel: String
    
    @Parameter(title: "Alarm Time")
    var alarmTime: Date
    
    @Parameter(title: "Is Repeating", default: false)
    var isRepeating: Bool
    
    @Parameter(title: "Snooze Duration", default: 300)
    var snoozeDuration: TimeInterval
    
    func perform() async throws -> some IntentResult {
        do {
            // Create a new StartSmart alarm
            let alarm = StartSmart.Alarm(
                time: alarmTime,
                label: alarmLabel,
                snoozeEnabled: true,
                snoozeDuration: snoozeDuration
            )
            
            // Schedule the alarm using AlarmKit Manager
            try await AlarmKitManager.shared.scheduleAlarm(for: alarm)
            
            return .result()
        } catch {
            throw IntentError.failedToCreateAlarm(error.localizedDescription)
        }
    }
}

/// App Intent for listing StartSmart alarms
@available(iOS 26.0, *)
struct ListAlarmsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Alarms"
    static var description: IntentDescription = IntentDescription("List all StartSmart alarms")
    
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        // Get all alarms from AlarmKit Manager
        let alarms = await AlarmKitManager.shared.alarms
        
        // Convert to string array for display
        let alarmStrings = alarms.map { alarm in
            "\(alarm.id.uuidString): Scheduled alarm"
        }
        
        return .result(value: alarmStrings)
    }
}

// MARK: - Intent Error Handling

enum IntentError: Error, LocalizedError {
    case failedToDismissAlarm(String)
    case failedToSnoozeAlarm(String)
    case failedToCreateAlarm(String)
    case failedToListAlarms(String)
    
    var errorDescription: String? {
        switch self {
        case .failedToDismissAlarm(let message):
            return "Failed to dismiss alarm: \(message)"
        case .failedToSnoozeAlarm(let message):
            return "Failed to snooze alarm: \(message)"
        case .failedToCreateAlarm(let message):
            return "Failed to create alarm: \(message)"
        case .failedToListAlarms(let message):
            return "Failed to list alarms: \(message)"
        }
    }
}

// MARK: - App Intents Configuration
// Note: App Intents are automatically discovered by the system
// No additional configuration struct is needed
