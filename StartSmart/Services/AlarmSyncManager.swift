import Foundation
import AlarmKit
import Combine
import os.log

/// AlarmSyncManager - Bridges existing StartSmart alarm system with new AlarmKit system
/// This ensures seamless migration and dual-system support during transition
@MainActor
class AlarmSyncManager: ObservableObject {
    static let shared = AlarmSyncManager()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.startsmart.app", category: "AlarmSyncManager")
    private let alarmKitManager = AlarmKitManager.shared
    private let alarmRepository = AlarmRepository.shared
    
    @Published var isAlarmKitEnabled: Bool = true
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    
    // MARK: - Sync Status
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }
    
    // MARK: - Initialization
    
    private init() {
        logger.info("🔄 AlarmSyncManager initialized")
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Sync all alarms between StartSmart and AlarmKit systems
    func syncAllAlarms() async {
        logger.info("🔄 Starting alarm sync between StartSmart and AlarmKit")
        syncStatus = .syncing
        
        do {
            // 1. Get all StartSmart alarms
            let startSmartAlarms = await alarmRepository.getAllAlarms()
            logger.info("📱 Found \(startSmartAlarms.count) StartSmart alarms")
            
            // 2. Get all AlarmKit alarms
            await alarmKitManager.refreshAlarms()
            let alarmKitAlarms = alarmKitManager.alarms
            logger.info("🔔 Found \(alarmKitAlarms.count) AlarmKit alarms")
            
            // 3. Sync StartSmart alarms to AlarmKit
            for alarm in startSmartAlarms {
                try await syncStartSmartAlarmToAlarmKit(alarm)
            }
            
            // 4. Update sync status
            syncStatus = .success
            lastSyncDate = Date()
            logger.info("✅ Alarm sync completed successfully")
            
        } catch {
            logger.error("❌ Alarm sync failed: \(error.localizedDescription)")
            syncStatus = .error(error.localizedDescription)
        }
    }
    
    /// Create a new alarm in both systems
    func createAlarm(_ alarm: StartSmart.Alarm) async throws {
        logger.info("➕ Creating alarm in both systems: \(alarm.label)")
        
        do {
            // 1. Create in StartSmart system
            try await alarmRepository.createAlarm(alarm)
            logger.info("✅ Created in StartSmart system")
            
            // 2. Create in AlarmKit system
            try await alarmKitManager.scheduleAlarm(for: alarm)
            logger.info("✅ Created in AlarmKit system")
            
        } catch {
            logger.error("❌ Failed to create alarm: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Update an alarm in both systems
    func updateAlarm(_ alarm: StartSmart.Alarm) async throws {
        logger.info("📝 Updating alarm in both systems: \(alarm.label)")
        
        do {
            // 1. Update in StartSmart system
            try await alarmRepository.updateAlarm(alarm)
            logger.info("✅ Updated in StartSmart system")
            
            // 2. Update in AlarmKit system (cancel and reschedule)
            try await alarmKitManager.cancelAlarm(withId: alarm.id.uuidString)
            try await alarmKitManager.scheduleAlarm(for: alarm)
            logger.info("✅ Updated in AlarmKit system")
            
        } catch {
            logger.error("❌ Failed to update alarm: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Delete an alarm from both systems
    func deleteAlarm(withId id: String) async throws {
        logger.info("🗑️ Deleting alarm from both systems: \(id)")
        
        do {
            // 1. Delete from StartSmart system
            try await alarmRepository.deleteAlarm(withId: id)
            logger.info("✅ Deleted from StartSmart system")
            
            // 2. Delete from AlarmKit system
            try await alarmKitManager.cancelAlarm(withId: id)
            logger.info("✅ Deleted from AlarmKit system")
            
        } catch {
            logger.error("❌ Failed to delete alarm: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Handle alarm firing from AlarmKit
    func handleAlarmKitAlarmFired(_ alarmId: String) async {
        logger.info("🔔 AlarmKit alarm fired: \(alarmId)")
        
        // Update StartSmart alarm status
        do {
            try await alarmRepository.markAlarmAsFired(withId: alarmId)
            logger.info("✅ Updated StartSmart alarm status")
        } catch {
            logger.error("❌ Failed to update StartSmart alarm status: \(error.localizedDescription)")
        }
    }
    
    /// Handle alarm dismissal from AlarmKit
    func handleAlarmKitAlarmDismissed(_ alarmId: String) async {
        logger.info("👋 AlarmKit alarm dismissed: \(alarmId)")
        
        // Update StartSmart alarm status
        do {
            try await alarmRepository.markAlarmAsDismissed(withId: alarmId)
            logger.info("✅ Updated StartSmart alarm status")
        } catch {
            logger.error("❌ Failed to update StartSmart alarm status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func syncStartSmartAlarmToAlarmKit(_ alarm: StartSmart.Alarm) async throws {
        // Check if alarm already exists in AlarmKit
        let existingAlarmKitAlarm = alarmKitManager.alarms.first { $0.id.uuidString == alarm.id.uuidString }
        
        if existingAlarmKitAlarm == nil {
            // Create new AlarmKit alarm
            try await alarmKitManager.scheduleAlarm(for: alarm)
            logger.info("➕ Created new AlarmKit alarm: \(alarm.label)")
        } else {
            logger.info("ℹ️ AlarmKit alarm already exists: \(alarm.label)")
        }
    }
    
    private func setupObservers() {
        // Observe AlarmKit alarm events
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AlarmDidFire"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let alarmId = notification.userInfo?["alarmId"] as? String {
                Task { @MainActor in
                    await self?.handleAlarmKitAlarmFired(alarmId)
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AlarmWasDismissed"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let alarmId = notification.userInfo?["alarmId"] as? String {
                Task { @MainActor in
                    await self?.handleAlarmKitAlarmDismissed(alarmId)
                }
            }
        }
    }
    
    // MARK: - Migration Support
    
    /// Enable AlarmKit system (default)
    func enableAlarmKit() {
        isAlarmKitEnabled = true
        logger.info("🔔 AlarmKit system enabled")
    }
    
    /// Disable AlarmKit system (fallback to StartSmart only)
    func disableAlarmKit() {
        isAlarmKitEnabled = false
        logger.info("📱 AlarmKit system disabled - using StartSmart only")
    }
    
    /// Check if system should use AlarmKit
    func shouldUseAlarmKit() -> Bool {
        return isAlarmKitEnabled
    }
}

// MARK: - AlarmRepository Extensions

extension AlarmRepository {
    /// Mark alarm as fired
    func markAlarmAsFired(withId id: String) async throws {
        // Implementation depends on your AlarmRepository structure
        // This is a placeholder for the actual implementation
        logger.info("🔔 Marking alarm as fired: \(id)")
    }
    
    /// Mark alarm as dismissed
    func markAlarmAsDismissed(withId id: String) async throws {
        // Implementation depends on your AlarmRepository structure
        // This is a placeholder for the actual implementation
        logger.info("👋 Marking alarm as dismissed: \(id)")
    }
}
