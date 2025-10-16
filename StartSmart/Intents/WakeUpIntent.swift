import AppIntents
import AlarmKit
import Foundation
import FirebaseFirestore

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
        print("📊 Logging wake-up event to Firestore for alarm: \(alarmID)")
        
        do {
            // Get Firebase service from dependency container
            let firebaseService: FirebaseServiceProtocol = DependencyContainer.shared.resolve()
            
            // Get current user ID
            guard let userId = firebaseService.currentUser?.id.uuidString else {
                print("⚠️ No authenticated user - skipping wake-up logging")
                return
            }
            
            // Create wake-up event data
            let wakeUpData: [String: Any] = [
                "alarmID": alarmID,
                "userGoal": userGoal ?? "",
                "wakeupMethod": "explicit_button",
                "timestamp": Date(),
                "success": true,
                "appOpened": true
            ]
            
            // Save to Firestore in user's wake-up events collection
            let firestore = Firestore.firestore()
            let wakeUpRef = firestore
                .collection("users")
                .document(userId)
                .collection("wakeUpEvents")
                .document()
            
            try await wakeUpRef.setData(wakeUpData)
            
            // Update the alarm status to "completed"
            let alarmRef = firestore
                .collection("users")
                .document(userId)
                .collection("alarms")
                .document(alarmID)
            
            try await alarmRef.updateData([
                "status": "completed",
                "completedAt": Date(),
                "wakeupMethod": "explicit_button"
            ])
            
            // Update user streak
            await updateUserStreak(userId: userId)
            
            print("✅ Wake-up event logged successfully")
            
        } catch {
            print("❌ Failed to log wake-up event: \(error.localizedDescription)")
        }
    }
    
    private func updateUserStreak(userId: String) async {
        do {
            let firestore = Firestore.firestore()
            let userRef = firestore.collection("users").document(userId)
            
            // Get current streak data
            let userDoc = try await userRef.getDocument()
            var streakData: [String: Any] = [:]
            
            if let data = userDoc.data() {
                streakData = data
            }
            
            // Calculate new streak
            let lastWakeUpDate = streakData["lastWakeUpDate"] as? Timestamp
            let currentStreak = streakData["currentStreak"] as? Int ?? 0
            
            let today = Date()
            let calendar = Calendar.current
            
            var newStreak = currentStreak
            
            if let lastDate = lastWakeUpDate?.dateValue() {
                let daysDifference = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0
                
                if daysDifference == 1 {
                    // Consecutive day - increment streak
                    newStreak += 1
                } else if daysDifference > 1 {
                    // Gap in days - reset streak
                    newStreak = 1
                }
                // If daysDifference == 0, it's the same day - keep current streak
            } else {
                // First wake-up - start streak
                newStreak = 1
            }
            
            // Update user streak data
            try await userRef.updateData([
                "currentStreak": newStreak,
                "lastWakeUpDate": Timestamp(date: today),
                "totalWakeUps": (streakData["totalWakeUps"] as? Int ?? 0) + 1,
                "updatedAt": Timestamp(date: today)
            ])
            
            print("🎯 User streak updated: \(newStreak) days")
            
        } catch {
            print("❌ Failed to update user streak: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Name Extension
extension Notification.Name {
    static let showAlarmView = Notification.Name("showAlarmView")
}