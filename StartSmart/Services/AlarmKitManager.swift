import Foundation
import AlarmKit
import Combine
import os.log

/// AlarmKit Manager - Handles all alarm operations using Apple's AlarmKit framework
/// This provides reliable alarm sounds that play from the lock screen
@MainActor
class AlarmKitManager: ObservableObject {
    static let shared = AlarmKitManager()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "AlarmKitManager")
    private let alarmManager = AlarmManager.shared
    
    @Published var authorizationState: AlarmAuthorizationState = .notDetermined
    @Published var alarms: [AlarmKit.Alarm] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        logger.info("🔔 AlarmKitManager initialized")
        setupObservers()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws -> AlarmAuthorizationState {
        logger.info("🔔 Requesting AlarmKit authorization")
        
        let state = try await alarmManager.requestAuthorization()
        await MainActor.run {
            self.authorizationState = state
        }
        
        logger.info("🔔 AlarmKit authorization result: \(state)")
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
        
        // Create AlarmConfiguration
        let configuration = try createAlarmConfiguration(for: alarm)
        
        // Schedule the alarm
        try await alarmManager.schedule(id: alarm.id.uuidString, configuration: configuration)
        
        logger.info("🔔 AlarmKit alarm scheduled successfully: \(alarm.id.uuidString)")
        
        // Refresh alarms list
        await refreshAlarms()
    }
    
    func cancelAlarm(withId id: String) async throws {
        logger.info("🔔 Canceling AlarmKit alarm: \(id)")
        
        try await alarmManager.cancel(id: id)
        
        logger.info("🔔 AlarmKit alarm canceled: \(id)")
        
        // Refresh alarms list
        await refreshAlarms()
    }
    
    func snoozeAlarm(withId id: String, duration: TimeInterval) async throws {
        logger.info("🔔 Snoozing AlarmKit alarm: \(id) for \(duration) seconds")
        
        try await alarmManager.snooze(id: id, duration: duration)
        
        logger.info("🔔 AlarmKit alarm snoozed: \(id)")
        
        // Refresh alarms list
        await refreshAlarms()
    }
    
    func dismissAlarm(withId id: String) async throws {
        logger.info("🔔 Dismissing AlarmKit alarm: \(id)")
        
        try await alarmManager.dismiss(id: id)
        
        logger.info("🔔 AlarmKit alarm dismissed: \(id)")
        
        // Refresh alarms list
        await refreshAlarms()
    }
    
    // MARK: - Alarm Queries
    
    func refreshAlarms() async {
        let currentAlarms = alarmManager.alarms
        await MainActor.run {
            self.alarms = Array(currentAlarms)
        }
        logger.info("🔔 Refreshed AlarmKit alarms: \(currentAlarms.count) active")
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe authorization changes
        Task {
            for await _ in alarmManager.authorizationUpdates {
                await MainActor.run {
                    self.authorizationState = self.alarmManager.authorizationState
                }
            }
        }
        
        // Observe alarm updates
        Task {
            for await _ in alarmManager.alarmUpdates {
                await refreshAlarms()
            }
        }
    }
    
    private func createAlarmConfiguration(for alarm: StartSmart.Alarm) throws -> AlarmConfiguration {
        logger.info("🔔 Creating AlarmConfiguration for: \(alarm.label)")
        
        // Create schedule
        let schedule: AlarmSchedule
        if alarm.isRepeating {
            // Create repeating schedule
            let weekdays = alarm.repeatDays.map { $0.rawValue }
            schedule = .repeating(weekdays: weekdays, time: alarm.time)
        } else {
            // Create one-time schedule
            guard let triggerDate = alarm.nextTriggerDate else {
                throw AlarmKitError.invalidAlarmConfiguration
            }
            schedule = .oneTime(triggerDate)
        }
        
        // Create presentation configuration
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: "🔔 StartSmart Alarm",
                subtitle: alarm.label.isEmpty ? "Time to wake up!" : alarm.label,
                tintColor: .blue,
                stopButton: AlarmButton(
                    title: "Stop",
                    systemImageName: "stop.fill",
                    textColor: .red
                ),
                secondaryButton: alarm.snoozeEnabled ? AlarmButton(
                    title: "Snooze",
                    systemImageName: "clock.arrow.circlepath",
                    textColor: .blue
                ) : nil
            ),
            countdown: AlarmPresentation.Countdown(
                tintColor: .blue,
                pauseButton: AlarmButton(
                    title: "Pause",
                    systemImageName: "pause.fill",
                    textColor: .blue
                )
            ),
            paused: AlarmPresentation.Paused(
                tintColor: .orange,
                resumeButton: AlarmButton(
                    title: "Resume",
                    systemImageName: "play.fill",
                    textColor: .green
                )
            )
        )
        
        // Create metadata with our custom alarm data
        let metadata = AlarmMetadata(
            traditionalSound: alarm.traditionalSound.rawValue,
            useTraditionalSound: alarm.useTraditionalSound,
            useAIScript: alarm.useAIScript,
            hasCustomAudio: alarm.hasCustomAudio,
            audioFilePath: alarm.audioFileURL?.path ?? ""
        )
        
        // Create configuration
        let configuration = AlarmConfiguration(
            schedule: schedule,
            presentation: presentation,
            metadata: metadata
        )
        
        logger.info("🔔 AlarmConfiguration created successfully")
        return configuration
    }
}

// MARK: - Supporting Types

struct AlarmMetadata: Codable {
    let traditionalSound: String
    let useTraditionalSound: Bool
    let useAIScript: Bool
    let hasCustomAudio: Bool
    let audioFilePath: String
}

enum AlarmKitError: Error, LocalizedError {
    case authorizationDenied
    case unknownAuthorizationState
    case invalidAlarmConfiguration
    case alarmNotFound
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "AlarmKit authorization was denied"
        case .unknownAuthorizationState:
            return "Unknown AlarmKit authorization state"
        case .invalidAlarmConfiguration:
            return "Invalid alarm configuration"
        case .alarmNotFound:
            return "Alarm not found"
        }
    }
}
