import Foundation
import Combine
import AlarmKit
import os.log
import NotificationCenter

/// Coordinates AlarmKit alarm events with the app UI
/// Handles alarm presentations and user interactions
@MainActor
class AlarmNotificationCoordinator: ObservableObject {
    static let shared = AlarmNotificationCoordinator()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "AlarmNotificationCoordinator")
    private let alarmKitManager = AlarmKitManager.shared
    
    @Published var pendingAlarmId: String?
    @Published var shouldShowDismissalSheet = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        logger.info("🔔 AlarmNotificationCoordinator initialized")
        setupAlarmKitObservers()
    }
    
    private func setupAlarmKitObservers() {
        // Observe AlarmKit alarm updates
        Task {
            for await _ in alarmKitManager.alarmManager.alarmUpdates {
                // Handle alarm events (alert, snooze, dismiss)
                await handleAlarmKitUpdates()
            }
        }
        
        // Observe alarm dismissal notifications
        NotificationCenter.default.addObserver(
            forName: .startSmartAlarmDismissed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let alarmId = notification.userInfo?["alarmId"] as? String {
                    self?.showAlarmDismissal(for: alarmId)
                }
            }
        }
    }
    
    private func handleAlarmKitUpdates() async {
        // This will be called when AlarmKit alarms trigger
        // We can show the dismissal sheet when needed
        logger.info("🔔 AlarmKit alarm update received")
    }
    
    func showAlarmDismissal(for alarmId: String) {
        logger.info("🔔 Showing alarm dismissal for: \(alarmId)")
        
        // Store dismissal state for app launch detection
        AlarmDismissalStateManager.shared.storePendingDismissal(alarmId: alarmId)
        
        pendingAlarmId = alarmId
        shouldShowDismissalSheet = true
    }
    
    func clearPendingAlarm() {
        logger.info("🗑️ Clearing pending alarm")
        if let alarmId = pendingAlarmId {
            AlarmDismissalStateManager.shared.clearPendingDismissal()
        }
        pendingAlarmId = nil
        shouldShowDismissalSheet = false
    }
}

