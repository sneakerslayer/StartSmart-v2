import Foundation
import os.log

/// Manages alarm dismissal state persistence for app launch detection
@MainActor
class AlarmDismissalStateManager {
    static let shared = AlarmDismissalStateManager()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "AlarmDismissalStateManager")
    private let userDefaults = UserDefaults.standard
    private let pendingDismissalKey = "pending_alarm_dismissal"
    private let dismissalTimestampKey = "alarm_dismissal_timestamp"
    private let dismissalTimeout: TimeInterval = 60 // 60 seconds timeout
    
    private init() {
        logger.info("🔔 AlarmDismissalStateManager initialized")
    }
    
    /// Store pending alarm dismissal state
    func storePendingDismissal(alarmId: String, userGoal: String? = nil) {
        logger.info("💾 Storing pending dismissal for alarm: \(alarmId)")
        var dismissalData: [String: Any] = [
            "alarmID": alarmId,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Only store userGoal if it's not nil and not empty
        if let userGoal = userGoal, !userGoal.isEmpty {
            dismissalData["userGoal"] = userGoal
        }
        
        userDefaults.set(dismissalData, forKey: pendingDismissalKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: dismissalTimestampKey)
        logger.info("✅ Pending dismissal stored")
    }
    
    /// Get pending dismissal state if valid
    func getPendingDismissal() -> (alarmId: String, userGoal: String?)? {
        guard let dismissalData = userDefaults.dictionary(forKey: pendingDismissalKey),
              let alarmId = dismissalData["alarmID"] as? String else {
            logger.info("ℹ️ No pending dismissal found")
            return nil
        }
        
        // Check if dismissal is still valid (not expired)
        let timestamp = dismissalData["timestamp"] as? TimeInterval ?? 0
        let dismissalDate = Date(timeIntervalSince1970: timestamp)
        let timeSinceDismissal = Date().timeIntervalSince(dismissalDate)
        
        if timeSinceDismissal > dismissalTimeout {
            logger.warning("⚠️ Pending dismissal expired (\(Int(timeSinceDismissal))s ago)")
            clearPendingDismissal()
            return nil
        }
        
        // Retrieve userGoal - return nil if key doesn't exist or value is empty string
        let userGoal: String? = {
            guard let storedGoal = dismissalData["userGoal"] as? String,
                  !storedGoal.isEmpty else {
                return nil
            }
            return storedGoal
        }()
        
        logger.info("✅ Found valid pending dismissal for alarm: \(alarmId)")
        return (alarmId: alarmId, userGoal: userGoal)
    }
    
    /// Clear pending dismissal state
    func clearPendingDismissal() {
        logger.info("🗑️ Clearing pending dismissal")
        userDefaults.removeObject(forKey: pendingDismissalKey)
        userDefaults.removeObject(forKey: dismissalTimestampKey)
    }
    
    /// Check if there's a pending dismissal
    var hasPendingDismissal: Bool {
        getPendingDismissal() != nil
    }
}

