import AppIntents
import AlarmKit
import Foundation

/// Intent that fires when user taps "I'm Awake!" button on alarm
struct WakeUpIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Wake Up"
    
    static var description: IntentDescription = IntentDescription(
        "Confirms wake-up and opens StartSmart with AI motivation"
    )
    
    // CRITICAL: This makes the app open when intent runs
    static var openAppWhenRun: Bool = true
    
    // CRITICAL: Make intent isEligibleForPrediction false to prevent Siri suggestions
    static var isDiscoverable: Bool = false
    
    @Parameter(title: "Alarm ID")
    var alarmID: String
    
    @Parameter(title: "User Goal")
    var userGoal: String?
    
    // Required initializer
    init() {
        self.alarmID = ""
        self.userGoal = nil
    }
    
    init(alarmID: String, userGoal: String?) {
        self.alarmID = alarmID
        self.userGoal = userGoal
    }
    
    func perform() async throws -> some IntentResult {
        print("🎯 WakeUpIntent triggered for alarm: \(alarmID)")
        
        // Post notification to main app to show AlarmTriggeredView
        await MainActor.run {
            NotificationCenter.default.post(
                name: .showAlarmView,
                object: nil,
                userInfo: [
                    "alarmID": alarmID,
                    "userGoal": userGoal ?? "",
                    "wakeupMethod": "explicit_button"
                ]
            )
        }
        
        // Log to analytics immediately
        await logWakeUpSuccess()
        
        return .result()
    }
    
    private func logWakeUpSuccess() async {
        // TODO: Implement Firestore logging
        // This will track:
        // - alarmID
        // - timestamp
        // - method: "explicit_button"
        // - User opened app explicitly
        
        print("✅ Wake-up logged for alarm: \(alarmID)")
    }
}

// MARK: - Notification Name Extension
extension Notification.Name {
    static let showAlarmView = Notification.Name("showAlarmView")
}