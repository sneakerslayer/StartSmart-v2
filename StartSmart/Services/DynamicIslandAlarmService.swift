import Foundation
import ActivityKit
import WidgetKit
import os.log

// MARK: - Dynamic Island Alarm Service

/// Service for managing Dynamic Island integration with AlarmKit alarms
@MainActor
class DynamicIslandAlarmService: ObservableObject {
    static let shared = DynamicIslandAlarmService()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "DynamicIslandAlarmService")
    
    // MARK: - Dynamic Island State
    
    @Published var isDynamicIslandSupported: Bool = false
    @Published var activeAlarmActivity: Activity<AlarmActivityAttributes>?
    @Published var dynamicIslandState: DynamicIslandState = .inactive
    
    // MARK: - Dynamic Island Configuration
    
    private let dynamicIslandExpirationTime: TimeInterval = 300 // 5 minutes
    private var alarmActivityTimer: Timer?
    
    private init() {
        logger.info("🏝️ DynamicIslandAlarmService initialized")
        checkDynamicIslandSupport()
        setupObservers()
    }
    
    // MARK: - Dynamic Island Support Check
    
    private func checkDynamicIslandSupport() {
        // Check if device supports Dynamic Island (iPhone 14 Pro and later)
        if #available(iOS 16.1, *) {
            isDynamicIslandSupported = ActivityKit.isSupported
            logger.info("🏝️ Dynamic Island support: \(isDynamicIslandSupported)")
        } else {
            isDynamicIslandSupported = false
            logger.info("🏝️ Dynamic Island not supported on this iOS version")
        }
    }
    
    // MARK: - Dynamic Island Alarm Management
    
    func startAlarmActivity(for alarm: StartSmart.Alarm) async {
        guard isDynamicIslandSupported else {
            logger.info("🏝️ Dynamic Island not supported, skipping activity creation")
            return
        }
        
        logger.info("🏝️ Starting Dynamic Island activity for alarm: \(alarm.label)")
        
        do {
            let attributes = AlarmActivityAttributes(
                alarmId: alarm.id.uuidString,
                alarmLabel: alarm.label,
                alarmTime: alarm.time,
                isRepeating: alarm.isRepeating
            )
            
            let content = ActivityContent(
                state: AlarmActivityState(
                    alarmLabel: alarm.label,
                    timeRemaining: timeRemainingUntilAlarm(alarm.time),
                    isActive: true,
                    snoozeCount: 0
                ),
                staleDate: Date().addingTimeInterval(dynamicIslandExpirationTime)
            )
            
            let activity = try Activity<AlarmActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            
            activeAlarmActivity = activity
            dynamicIslandState = .active
            
            // Set up timer to update the activity
            setupActivityUpdateTimer(for: alarm)
            
            logger.info("✅ Dynamic Island activity started successfully")
            
        } catch {
            logger.error("❌ Failed to start Dynamic Island activity: \(error.localizedDescription)")
        }
    }
    
    func updateAlarmActivity(for alarm: StartSmart.Alarm, snoozeCount: Int = 0) async {
        guard let activity = activeAlarmActivity else {
            logger.warning("⚠️ No active alarm activity to update")
            return
        }
        
        logger.info("🏝️ Updating Dynamic Island activity for alarm: \(alarm.label)")
        
        let updatedContent = ActivityContent(
            state: AlarmActivityState(
                alarmLabel: alarm.label,
                timeRemaining: timeRemainingUntilAlarm(alarm.time),
                isActive: true,
                snoozeCount: snoozeCount
            ),
            staleDate: Date().addingTimeInterval(dynamicIslandExpirationTime)
        )
        
        await activity.update(updatedContent)
        logger.info("✅ Dynamic Island activity updated successfully")
    }
    
    func endAlarmActivity() async {
        guard let activity = activeAlarmActivity else {
            logger.info("🏝️ No active alarm activity to end")
            return
        }
        
        logger.info("🏝️ Ending Dynamic Island activity")
        
        let finalContent = ActivityContent(
            state: AlarmActivityState(
                alarmLabel: activity.attributes.alarmLabel,
                timeRemaining: 0,
                isActive: false,
                snoozeCount: 0
            ),
            staleDate: Date().addingTimeInterval(60) // 1 minute
        )
        
        await activity.end(finalContent, dismissalPolicy: .immediate)
        
        activeAlarmActivity = nil
        dynamicIslandState = .inactive
        alarmActivityTimer?.invalidate()
        alarmActivityTimer = nil
        
        logger.info("✅ Dynamic Island activity ended successfully")
    }
    
    // MARK: - Dynamic Island Interactions
    
    func handleDynamicIslandTap() async {
        logger.info("🏝️ Dynamic Island tapped")
        
        // Open the app to the alarms tab
        await MainActor.run {
            // This would typically trigger app opening
            // For now, we'll just log the interaction
        }
        
        logger.info("✅ Dynamic Island tap handled")
    }
    
    func handleDynamicIslandSnooze() async {
        logger.info("🏝️ Dynamic Island snooze action")
        
        guard let activity = activeAlarmActivity else { return }
        
        // Snooze the alarm
        let alarmId = activity.attributes.alarmId
        try? await AlarmKitManager.shared.snoozeAlarm(withId: alarmId, duration: 300) // 5 minutes
        
        // Update the activity with snooze count
        let currentSnoozeCount = activity.content.state.snoozeCount + 1
        await updateAlarmActivity(for: createAlarmFromActivity(activity), snoozeCount: currentSnoozeCount)
        
        logger.info("✅ Dynamic Island snooze handled")
    }
    
    func handleDynamicIslandDismiss() async {
        logger.info("🏝️ Dynamic Island dismiss action")
        
        guard let activity = activeAlarmActivity else { return }
        
        // Dismiss the alarm
        let alarmId = activity.attributes.alarmId
        try? await AlarmKitManager.shared.dismissAlarm(withId: alarmId)
        
        // End the activity
        await endAlarmActivity()
        
        logger.info("✅ Dynamic Island dismiss handled")
    }
    
    // MARK: - Dynamic Island UI Components
    
    func createDynamicIslandContent(for alarm: StartSmart.Alarm) -> ActivityContent<AlarmActivityAttributes> {
        let attributes = AlarmActivityAttributes(
            alarmId: alarm.id.uuidString,
            alarmLabel: alarm.label,
            alarmTime: alarm.time,
            isRepeating: alarm.isRepeating
        )
        
        let content = ActivityContent(
            state: AlarmActivityState(
                alarmLabel: alarm.label,
                timeRemaining: timeRemainingUntilAlarm(alarm.time),
                isActive: true,
                snoozeCount: 0
            ),
            staleDate: Date().addingTimeInterval(dynamicIslandExpirationTime)
        )
        
        return content
    }
    
    // MARK: - Helper Methods
    
    private func timeRemainingUntilAlarm(_ alarmTime: Date) -> TimeInterval {
        let now = Date()
        let timeRemaining = alarmTime.timeIntervalSince(now)
        return max(0, timeRemaining)
    }
    
    private func setupActivityUpdateTimer(for alarm: StartSmart.Alarm) {
        alarmActivityTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateAlarmActivity(for: alarm)
            }
        }
    }
    
    private func createAlarmFromActivity(_ activity: Activity<AlarmActivityAttributes>) -> StartSmart.Alarm {
        return StartSmart.Alarm(
            label: activity.attributes.alarmLabel,
            time: activity.attributes.alarmTime,
            isRepeating: activity.attributes.isRepeating,
            snoozeEnabled: true,
            snoozeDuration: 300
        )
    }
    
    private func setupObservers() {
        // Observe alarm state changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AlarmDidFire"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleAlarmFired(notification)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AlarmWasDismissed"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleAlarmDismissed(notification)
            }
        }
    }
    
    private func handleAlarmFired(_ notification: Notification) {
        logger.info("🏝️ Alarm fired, updating Dynamic Island")
        
        if let alarmId = notification.userInfo?["alarmId"] as? String,
           let alarm = findAlarmById(alarmId) {
            Task {
                await updateAlarmActivity(for: alarm)
            }
        }
    }
    
    private func handleAlarmDismissed(_ notification: Notification) {
        logger.info("🏝️ Alarm dismissed, ending Dynamic Island activity")
        
        Task {
            await endAlarmActivity()
        }
    }
    
    private func findAlarmById(_ alarmId: String) -> StartSmart.Alarm? {
        // This would typically fetch from AlarmRepository
        // For now, return nil as this is a placeholder
        return nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        alarmActivityTimer?.invalidate()
    }
}

// MARK: - Dynamic Island Activity Attributes

struct AlarmActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var alarmLabel: String
        var timeRemaining: TimeInterval
        var isActive: Bool
        var snoozeCount: Int
    }
    
    var alarmId: String
    var alarmLabel: String
    var alarmTime: Date
    var isRepeating: Bool
}

// MARK: - Dynamic Island State

enum DynamicIslandState {
    case inactive
    case active
    case updating
    case error(String)
}

// MARK: - Dynamic Island Widget Extension

/// Widget extension for Dynamic Island alarm display
@available(iOS 16.1, *)
struct AlarmDynamicIslandWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            // Dynamic Island expanded view
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.blue)
                    Text(context.attributes.alarmLabel)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatTimeRemaining(context.state.timeRemaining))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Button("Snooze") {
                        Task {
                            await DynamicIslandAlarmService.shared.handleDynamicIslandSnooze()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        Task {
                            await DynamicIslandAlarmService.shared.handleDynamicIslandDismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
        } dynamicIsland: { context in
            // Dynamic Island compact view
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.blue)
                Text(context.attributes.alarmLabel)
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
                Text(formatTimeRemaining(context.state.timeRemaining))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
        } minimal: { context in
            // Dynamic Island minimal view
            Image(systemName: "bell.fill")
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Helper Functions

private func formatTimeRemaining(_ timeRemaining: TimeInterval) -> String {
    let hours = Int(timeRemaining) / 3600
    let minutes = Int(timeRemaining) % 3600 / 60
    let seconds = Int(timeRemaining) % 60
    
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%d:%02d", minutes, seconds)
    }
}
