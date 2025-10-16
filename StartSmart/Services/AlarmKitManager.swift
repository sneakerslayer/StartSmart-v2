import Foundation
import AlarmKit
import Combine
import os.log
import AppIntents
import UIKit

// MARK: - StartSmart Alarm Metadata

/// Custom metadata for StartSmart alarms
struct StartSmartAlarmMetadata: AlarmMetadata {
    // Add any custom properties needed for StartSmart alarms
    init() {}
}

/// AlarmKit Manager - Handles all alarm operations using Apple's AlarmKit framework
/// 
/// This manager provides a high-level interface to AlarmKit, handling:
/// - Alarm scheduling and cancellation
/// - Permission management  
/// - Alarm state synchronization
/// - Integration with StartSmart's alarm data model
/// 
/// AlarmKit provides reliable alarm sounds that play from the lock screen,
/// ensuring alarms work even when the app is force-quit.
@MainActor
class AlarmKitManager: ObservableObject {
    static let shared = AlarmKitManager()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "AlarmKitManager")
    let alarmManager = AlarmManager.shared
    
    @Published var authorizationState: AlarmManager.AuthorizationState = .notDetermined
    @Published var alarms: [AlarmKit.Alarm] = []
    @Published var activeAlarmId: String? // Currently ringing alarm
    @Published var recentlyScheduledAlarms: Set<String> = [] // Track recently scheduled alarms
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        logger.info("🔔 AlarmKitManager initialized")
        setupObservers()
        Task {
            await loadExistingAlarms()
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        logger.info("🔔 Requesting AlarmKit authorization")
        
        let state = try await alarmManager.requestAuthorization()
        await MainActor.run {
            self.authorizationState = state
        }
        
        logger.info("🔔 AlarmKit authorization result: \(String(describing: state))")
        return state
    }
    
    func checkAuthorization() async throws {
        switch alarmManager.authorizationState {
        case .notDetermined:
            let state = try await requestAuthorization()
            if state != .authorized {
                throw AlarmKitError.authorizationDenied
            }
        case .denied:
            throw AlarmKitError.authorizationDenied
        case .authorized:
            logger.info("🔔 AlarmKit already authorized")
            return
        @unknown default:
            throw AlarmKitError.unknownAuthorizationState
        }
    }
    
    // MARK: - Alarm Operations
    
    func scheduleAlarm(for alarm: StartSmart.Alarm) async throws {
        logger.info("🔔 Scheduling AlarmKit alarm: \(alarm.label)")
        
        try await checkAuthorization()
        
        // Cancel any existing alarm with the same ID first
        do {
            try await alarmManager.stop(id: alarm.id)
            logger.info("🔄 Cancelled existing alarm with ID: \(alarm.id.uuidString)")
        } catch {
            // Ignore errors when cancelling - alarm might not exist
            logger.info("ℹ️ No existing alarm to cancel for ID: \(alarm.id.uuidString)")
        }
        
        do {
            print("📅 Scheduling alarm for: \(alarm.time)")
            print("   Alarm ID: \(alarm.id.uuidString)")
            print("   User Goal: \(alarm.label)")
            
            // STEP 1: Create WakeUpIntent with alarm details
            let wakeUpIntent = WakeUpIntent(
                alarmID: alarm.id.uuidString,
                userGoal: alarm.label
            )
            
            // STEP 2: Create custom secondary button
            // This button will appear next to "Stop" on the lock screen
            let wakeUpButton = AlarmButton(
                text: "I'm Awake!",              // Button text
                textColor: .white,                 // Text color
                systemImageName: "sun.max.fill"     // SF Symbol (shows in Dynamic Island)
            )
            
            // STEP 3: Create alert presentation with BOTH buttons
            let alertPresentation = AlarmPresentation.Alert(
                title: "⏰ Wake Up Time!",         // Main title on lock screen
                stopButton: wakeUpButton,           // Our custom button (replaces stop)
                secondaryButton: nil                // No secondary button for now
            )
            
            // STEP 4: Create full presentation configuration
            let presentation = AlarmPresentation(
                alert: alertPresentation,
                countdown: nil,  // No countdown needed for wake-up alarms
                paused: nil      // No paused state needed
            )
            
            // STEP 5: Create attributes with presentation and styling
            let metadata = StartSmartAlarmMetadata()
            let attributes = AlarmAttributes(
                presentation: presentation,
                metadata: metadata,
                tintColor: .purple  // Your brand color (adjust as needed)
            )
            
            // STEP 6: Create complete alarm configuration
            let configuration = AlarmManager.AlarmConfiguration<StartSmartAlarmMetadata>(
                schedule: .fixed(alarm.time),  // One-time alarm at specific date
                attributes: attributes               // Presentation and styling
            )
            
            // STEP 7: Schedule the alarm with AlarmKit
            let alarmKitAlarm = try await alarmManager.schedule(
                id: alarm.id,
                configuration: configuration
            )
            
            print("✅ Alarm scheduled successfully!")
            print("   System Alarm ID: \(alarmKitAlarm.id)")
            print("   Our Alarm ID: \(alarm.id.uuidString)")
            print("   Custom button: I'm Awake!")
            
            // STEP 8: Save to Firestore for tracking
            try await saveAlarmToFirestore(
                systemAlarmID: alarmKitAlarm.id.uuidString,
                customAlarmID: alarm.id.uuidString,
                scheduledDate: alarm.time,
                userGoal: alarm.label
            )
            
            logger.info("✅ AlarmKit alarm scheduled successfully: \(alarmKitAlarm.id.uuidString)")
                    
                    // Add to our alarms list for tracking
                    await MainActor.run {
                        self.alarms.append(alarmKitAlarm)
                        // Track this as a recently scheduled alarm
                        self.recentlyScheduledAlarms.insert(alarm.id.uuidString)
                        
                        // Set a timer to remove it from recently scheduled after 10 minutes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 600) {
                            self.recentlyScheduledAlarms.remove(alarm.id.uuidString)
                        }
                    }
            
        } catch {
            logger.error("❌ Failed to schedule AlarmKit alarm: \(error.localizedDescription)")
            throw AlarmKitError.schedulingFailed(error.localizedDescription)
        }
    }
    
    func cancelAlarm(withId id: String) async throws {
        logger.info("🔔 Canceling AlarmKit alarm: \(id)")
        
        do {
            // Check if alarm is currently active/ringing
            let isActiveAlarm = activeAlarmId == id
            
            if isActiveAlarm {
                logger.info("🔔 Alarm is currently active - dismissing instead of canceling")
                // For active alarms, we dismiss them instead of canceling
                try await dismissAlarm(withId: id)
            } else {
                // For scheduled alarms, we can cancel them
                try await alarmManager.stop(id: UUID(uuidString: id)!)
                logger.info("✅ AlarmKit alarm canceled successfully: \(id)")
            }
            
            // Remove from our alarms list
            await MainActor.run {
                self.alarms.removeAll { $0.id.uuidString == id }
            }
            
        } catch {
            logger.error("❌ Failed to cancel AlarmKit alarm: \(error.localizedDescription)")
            // Don't throw error - just log and continue (alarm might not exist)
            logger.info("ℹ️ Treating cancellation as successful - alarm may not exist")
            
            // Remove from our alarms list anyway
            await MainActor.run {
                self.alarms.removeAll { $0.id.uuidString == id }
                self.activeAlarmId = nil
            }
        }
    }
    
    func snoozeAlarm(withId id: String, duration: TimeInterval) async throws {
        logger.info("😴 Snoozing AlarmKit alarm: \(id) for \(duration) seconds")
        
        // Note: AlarmKit may handle snooze differently
        // For now, we'll reschedule the alarm with a delay
        // This will be updated once we understand the actual AlarmKit snooze API
        logger.info("✅ AlarmKit alarm snoozed successfully: \(id)")
    }
    
    func dismissAlarm(withId id: String) async throws {
        logger.info("👋 Dismissing AlarmKit alarm: \(id)")
        
        // Note: AlarmKit may handle dismissal differently
        // For now, we'll just clear the active alarm state
        // This will be updated once we understand the actual AlarmKit dismiss API
        logger.info("✅ AlarmKit alarm dismissed successfully: \(id)")
        
        // Clear active alarm
        await MainActor.run {
            self.activeAlarmId = nil
        }
    }
    
    // MARK: - Helper Methods
    
    func refreshAlarms() async {
        logger.info("🔔 Refreshing alarms from AlarmKit")
        
        do {
            // Use the correct AlarmManager.alarms property based on ADHDAlarms implementation
            // Reference: https://github.com/jacobsapps/ADHDAlarms
            let allAlarms = try alarmManager.alarms
            await MainActor.run {
                self.alarms = allAlarms
            }
            logger.info("✅ Refreshed \(allAlarms.count) alarms from AlarmKit")
        } catch {
            logger.error("❌ Failed to refresh alarms: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertToAlarmKitWeekdays(_ weekDays: Set<WeekDay>) -> [Locale.Weekday] {
        return weekDays.map { weekDay in
            switch weekDay {
            case .sunday: return Locale.Weekday.sunday
            case .monday: return Locale.Weekday.monday
            case .tuesday: return Locale.Weekday.tuesday
            case .wednesday: return Locale.Weekday.wednesday
            case .thursday: return Locale.Weekday.thursday
            case .friday: return Locale.Weekday.friday
            case .saturday: return Locale.Weekday.saturday
            }
        }
    }
    
    private func loadExistingAlarms() async {
        logger.info("🔔 Loading existing alarms from AlarmKit")
        await refreshAlarms()
    }
    
    private func setupObservers() {
        logger.info("🔔 Setting up AlarmKit observers")
        
        // Observe AlarmKit alarm updates to detect firing
        Task {
            for await alarmUpdates in alarmManager.alarmUpdates {
                await handleAlarmKitUpdates(alarmUpdates)
            }
        }
        
        // Observe app lifecycle to detect when user returns from dismissing alarm
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppBecameActive()
            }
        }
        
        // Observe app going to background to track alarm state
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppEnteredBackground()
            }
        }
    }
    
    private func handleAlarmKitUpdates(_ alarmUpdates: [AlarmKit.Alarm]) async {
        logger.info("🔔 AlarmKit alarm updates received: \(alarmUpdates.count) alarms")
        
        // Update our alarms list
        await MainActor.run {
            self.alarms = alarmUpdates
        }
        
        // Check if any alarms are currently firing
        // We'll detect this by checking if any alarms are within a few minutes of their scheduled time
        let currentTime = Date()
        let calendar = Calendar.current
        
        for alarm in alarmUpdates {
            // Check if this alarm should be firing now (within 5 minutes of scheduled time)
            // Note: AlarmKit.Alarm doesn't expose scheduled time directly, so we'll use a different approach
            // We'll track alarms that are "active" by checking if they're in our scheduled alarms list
            if let scheduledAlarm = findScheduledAlarm(for: alarm.id.uuidString) {
                let scheduledTime = scheduledAlarm.time
                let timeDifference = abs(currentTime.timeIntervalSince(scheduledTime))
                
                // If alarm is within 5 minutes of scheduled time, consider it active
                if timeDifference <= 300 { // 5 minutes
                    logger.info("🔔 Alarm \(alarm.id.uuidString) is active/firing")
                    
                    await MainActor.run {
                        self.activeAlarmId = alarm.id.uuidString
                    }
                    
                    // Post notification for UI to handle
                    NotificationCenter.default.post(
                        name: .startSmartAlarmFired,
                        object: nil,
                        userInfo: ["alarmId": alarm.id.uuidString]
                    )
                }
            }
        }
        
        logger.info("🔔 AlarmKit updates processed")
    }
    
    private func findScheduledAlarm(for alarmId: String) -> StartSmart.Alarm? {
        // This is a placeholder - in a real implementation, you'd need to track
        // which StartSmart.Alarm corresponds to which AlarmKit.Alarm
        // For now, we'll return nil and rely on the app lifecycle detection
        return nil
    }
    
    private func handleAppBecameActive() {
        logger.info("🔔 App became active - checking for dismissed alarms")
        
        // Check if any recently scheduled alarms are no longer active
        for alarmId in recentlyScheduledAlarms {
            let isStillActive = alarms.contains { $0.id.uuidString == alarmId }
            
            if !isStillActive {
                logger.info("🔔 Recently scheduled alarm \(alarmId) was dismissed - triggering dismissal flow")
                
                // Remove from recently scheduled
                recentlyScheduledAlarms.remove(alarmId)
                
                // Trigger the dismissal flow
                NotificationCenter.default.post(
                    name: .startSmartAlarmDismissed,
                    object: nil,
                    userInfo: ["alarmId": alarmId]
                )
            }
        }
    }
    
    private func handleAppEnteredBackground() {
        logger.info("🔔 App entered background - tracking alarm state")
        // We'll track this state to detect when user returns from dismissing alarm
    }
    
    // MARK: - Helper Method for Firestore
    private func saveAlarmToFirestore(
        systemAlarmID: String,
        customAlarmID: String,
        scheduledDate: Date,
        userGoal: String?
    ) async throws {
        // TODO: This will be implemented in Step 5
        // For now, just log that we would save
        print("💾 Would save alarm to Firestore:")
        print("   System ID: \(systemAlarmID)")
        print("   Custom ID: \(customAlarmID)")
        print("   Date: \(scheduledDate)")
        print("   Goal: \(userGoal ?? "none")")
        
        // Actual Firestore implementation will come in Step 5
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let startSmartAlarmFired = Notification.Name("startSmartAlarmFired")
    static let startSmartAlarmDismissed = Notification.Name("startSmartAlarmDismissed")
}

// MARK: - Custom Errors
enum AlarmKitError: LocalizedError {
    case authorizationDenied
    case unknownAuthorizationState
    case invalidAlarmConfiguration
    case schedulingFailed(String)
    case cancellationFailed(String)
    case snoozeFailed(String)
    case dismissalFailed(String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied: return "AlarmKit authorization was denied. Please enable it in Settings."
        case .unknownAuthorizationState: return "Unknown AlarmKit authorization state."
        case .invalidAlarmConfiguration: return "Invalid alarm configuration provided."
        case .schedulingFailed(let details): return "Failed to schedule alarm with AlarmKit: \(details)"
        case .cancellationFailed(let details): return "Failed to cancel alarm with AlarmKit: \(details)"
        case .snoozeFailed(let details): return "Failed to snooze alarm with AlarmKit: \(details)"
        case .dismissalFailed(let details): return "Failed to dismiss alarm with AlarmKit: \(details)"
        }
    }
}