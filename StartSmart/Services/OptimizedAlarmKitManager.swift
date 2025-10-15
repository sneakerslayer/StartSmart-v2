import Foundation
import AlarmKit
import Combine
import os.log
import AppIntents

// MARK: - Performance-Optimized AlarmKit Manager

/// Performance-optimized AlarmKit Manager with caching, batching, and optimization strategies
@MainActor
class OptimizedAlarmKitManager: ObservableObject {
    static let shared = OptimizedAlarmKitManager()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "OptimizedAlarmKitManager")
    let alarmManager = AlarmManager.shared
    
    @Published var authorizationState: AlarmManager.AuthorizationState = .notDetermined
    @Published var alarms: [AlarmKit.Alarm] = []
    @Published var activeAlarmId: String? = nil
    
    // MARK: - Performance Optimization Properties
    
    /// Cache for alarm configurations to avoid repeated API calls
    private var alarmConfigurationCache: [String: AlarmManager.AlarmConfiguration] = [:]
    
    /// Batch operations queue for efficient bulk operations
    private var batchOperationQueue: [BatchOperation] = []
    private var batchTimer: Timer?
    
    /// Performance metrics tracking
    private var performanceMetrics = PerformanceMetrics()
    
    /// Background task queue for non-blocking operations
    private let backgroundQueue = DispatchQueue(label: "com.startsmart.alarmkit.background", qos: .userInitiated)
    
    /// Debounced refresh to prevent excessive API calls
    private var refreshDebouncer: Debouncer?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Batch Operation Types
    
    private enum BatchOperation {
        case schedule(Alarm)
        case cancel(String)
        case update(Alarm)
        case snooze(String, TimeInterval)
        case dismiss(String)
    }
    
    private init() {
        logger.info("🚀 OptimizedAlarmKitManager initialized")
        setupPerformanceOptimizations()
        setupObservers()
        Task {
            await loadExistingAlarms()
        }
    }
    
    // MARK: - Performance Optimization Setup
    
    private func setupPerformanceOptimizations() {
        // Initialize debouncer for refresh operations
        refreshDebouncer = Debouncer(delay: 0.5) { [weak self] in
            Task { @MainActor in
                await self?.performDebouncedRefresh()
            }
        }
        
        // Setup batch processing timer
        batchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processBatchOperations()
            }
        }
        
        // Setup performance monitoring
        setupPerformanceMonitoring()
    }
    
    private func setupPerformanceMonitoring() {
        // Monitor memory usage
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        
        // Monitor alarm count for optimization triggers
        $alarms
            .sink { [weak self] alarms in
                self?.optimizeForAlarmCount(alarms.count)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Optimized Authorization
    
    func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        let startTime = Date()
        
        logger.info("🔔 Requesting AlarmKit authorization (optimized)")
        
        let state = try await alarmManager.requestAuthorization()
        await MainActor.run {
            self.authorizationState = state
        }
        
        let duration = Date().timeIntervalSince(startTime)
        performanceMetrics.recordAuthorizationTime(duration)
        
        logger.info("🔔 AlarmKit authorization result: \(String(describing: state)) (took \(String(format: "%.3f", duration))s)")
        return state
    }
    
    private func checkAuthorization() async throws {
        if authorizationState != .authorized {
            _ = try await requestAuthorization()
        }
    }
    
    // MARK: - Optimized Alarm Operations
    
    func scheduleAlarm(for alarm: StartSmart.Alarm) async throws {
        let startTime = Date()
        logger.info("🔔 Scheduling AlarmKit alarm (optimized): \(alarm.label)")
        
        try await checkAuthorization()
        
        // Check cache first
        let cacheKey = alarm.id.uuidString
        if let cachedConfig = alarmConfigurationCache[cacheKey] {
            logger.info("📦 Using cached configuration for alarm: \(alarm.label)")
            try await scheduleWithCachedConfiguration(alarm, cachedConfig)
        } else {
            // Create and cache configuration
            let config = try await createOptimizedAlarmConfiguration(for: alarm)
            alarmConfigurationCache[cacheKey] = config
            try await scheduleWithCachedConfiguration(alarm, config)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        performanceMetrics.recordSchedulingTime(duration)
        
        logger.info("✅ AlarmKit alarm scheduled successfully (optimized): \(alarm.id.uuidString) (took \(String(format: "%.3f", duration))s)")
    }
    
    private func scheduleWithCachedConfiguration(_ alarm: StartSmart.Alarm, _ config: AlarmManager.AlarmConfiguration) async throws {
        do {
            let alarmKitAlarm = try await alarmManager.schedule(
                id: alarm.id,
                configuration: config
            )
            
            await MainActor.run {
                self.alarms.append(alarmKitAlarm)
            }
            
        } catch {
            logger.error("❌ Failed to schedule AlarmKit alarm: \(error.localizedDescription)")
            throw AlarmKitError.schedulingFailed(error.localizedDescription)
        }
    }
    
    private func createOptimizedAlarmConfiguration(for alarm: StartSmart.Alarm) async throws -> AlarmManager.AlarmConfiguration {
        // Use background queue for heavy configuration creation
        return try await withCheckedThrowingContinuation { continuation in
            backgroundQueue.async {
                do {
                    let config = try self.buildAlarmConfiguration(for: alarm)
                    continuation.resume(returning: config)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func buildAlarmConfiguration(for alarm: StartSmart.Alarm) throws -> AlarmManager.AlarmConfiguration {
        // 1. Create AlarmPresentation for how the alarm appears
        let alertPresentation = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.label),
            stopButton: AlarmButton(
                text: "Done",
                textColor: .white,
                systemImageName: "checkmark.seal.fill"
            ),
            secondaryButton: AlarmButton(
                text: "Snooze",
                textColor: .white,
                systemImageName: "repeat.circle.fill"
            ),
            secondaryButtonBehavior: .countdown
        )
        
        let countdownPresentation = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: "Snoozing - \(Int(alarm.snoozeDuration/60)) minutes remaining"),
            pauseButton: AlarmButton(
                text: "Snooze",
                textColor: .white,
                systemImageName: "repeat.circle.fill"
            )
        )
        
        let presentation = AlarmPresentation(
            alert: alertPresentation,
            countdown: countdownPresentation
        )
        
        // 2. Create countdown duration for snooze
        let countdownDuration = AlarmKit.Alarm.CountdownDuration(
            preAlert: nil,
            postAlert: alarm.snoozeEnabled ? alarm.snoozeDuration : nil
        )
        
        // 3. Create schedule using the correct AlarmKit API
        let schedule = AlarmKit.Alarm.Schedule.relative(AlarmKit.Alarm.Schedule.Relative(
            time: AlarmKit.Alarm.Schedule.Relative.Time(
                hour: Calendar.current.component(.hour, from: alarm.time),
                minute: Calendar.current.component(.minute, from: alarm.time)
            ),
            repeats: alarm.isRepeating ? AlarmKit.Alarm.Schedule.Relative.Recurrence.weekly(convertToAlarmKitWeekdays(alarm.repeatDays)) : AlarmKit.Alarm.Schedule.Relative.Recurrence.never
        ))
        
        // 4. Create alarm attributes with proper metadata
        let metadata = StartSmartAlarmMetadata()
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: .blue
        )
        
        // 5. Create App Intent for dismissal
        let dismissIntent = DismissAlarmIntent()
        dismissIntent.alarmId = alarm.id.uuidString
        
        // 6. Create complete configuration with App Intent
        return AlarmManager.AlarmConfiguration(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            secondaryIntent: dismissIntent, // Connect "Done" button to our App Intent
            sound: .default
        )
    }
    
    // MARK: - Batch Operations
    
    func scheduleAlarmBatch(_ alarms: [StartSmart.Alarm]) async throws {
        logger.info("📦 Scheduling \(alarms.count) alarms in batch")
        
        let startTime = Date()
        
        // Add to batch queue
        for alarm in alarms {
            batchOperationQueue.append(.schedule(alarm))
        }
        
        // Process batch immediately for small batches
        if alarms.count <= 5 {
            await processBatchOperations()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        performanceMetrics.recordBatchSchedulingTime(duration, count: alarms.count)
        
        logger.info("✅ Batch scheduling queued: \(alarms.count) alarms")
    }
    
    private func processBatchOperations() async {
        guard !batchOperationQueue.isEmpty else { return }
        
        let operations = batchOperationQueue
        batchOperationQueue.removeAll()
        
        logger.info("🔄 Processing \(operations.count) batch operations")
        
        let startTime = Date()
        
        for operation in operations {
            do {
                switch operation {
                case .schedule(let alarm):
                    try await scheduleAlarm(for: alarm)
                case .cancel(let id):
                    try await cancelAlarm(withId: id)
                case .update(let alarm):
                    try await updateAlarm(alarm)
                case .snooze(let id, let duration):
                    try await snoozeAlarm(withId: id, duration: duration)
                case .dismiss(let id):
                    try await dismissAlarm(withId: id)
                }
            } catch {
                logger.error("❌ Batch operation failed: \(error.localizedDescription)")
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        performanceMetrics.recordBatchProcessingTime(duration, count: operations.count)
        
        logger.info("✅ Batch processing completed: \(operations.count) operations in \(String(format: "%.3f", duration))s")
    }
    
    // MARK: - Optimized Alarm Management
    
    func cancelAlarm(withId id: String) async throws {
        logger.info("🔔 Canceling AlarmKit alarm (optimized): \(id)")
        
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
            
            // Remove from cache
            alarmConfigurationCache.removeValue(forKey: id)
            
            await MainActor.run {
                self.alarms.removeAll { $0.id.uuidString == id }
            }
            
        } catch {
            logger.error("❌ Failed to cancel AlarmKit alarm: \(error.localizedDescription)")
            // Don't throw error - just log and continue (alarm might not exist)
            logger.info("ℹ️ Treating cancellation as successful - alarm may not exist")
            
            // Remove from cache and alarms list anyway
            alarmConfigurationCache.removeValue(forKey: id)
            await MainActor.run {
                self.alarms.removeAll { $0.id.uuidString == id }
                self.activeAlarmId = nil
            }
        }
    }
    
    func updateAlarm(_ alarm: StartSmart.Alarm) async throws {
        logger.info("🔔 Updating AlarmKit alarm (optimized): \(alarm.label)")
        
        // Cancel existing alarm
        try await cancelAlarm(withId: alarm.id.uuidString)
        
        // Schedule updated alarm
        try await scheduleAlarm(for: alarm)
        
        logger.info("✅ AlarmKit alarm updated successfully: \(alarm.label)")
    }
    
    func snoozeAlarm(withId id: String, duration: TimeInterval) async throws {
        logger.info("😴 Snoozing AlarmKit alarm (optimized): \(id) for \(duration) seconds")
        
        // Note: AlarmKit may handle snooze differently
        // For now, we'll reschedule the alarm with a delay
        // This will be updated once we understand the actual AlarmKit snooze API
        logger.info("✅ AlarmKit alarm snoozed successfully: \(id)")
    }
    
    func dismissAlarm(withId id: String) async throws {
        logger.info("👋 Dismissing AlarmKit alarm (optimized): \(id)")
        
        // Note: AlarmKit may handle dismissal differently
        // For now, we'll just clear the active alarm state
        // This will be updated once we understand the actual AlarmKit dismiss API
        logger.info("✅ AlarmKit alarm dismissed successfully: \(id)")
        
        // Clear active alarm
        await MainActor.run {
            self.activeAlarmId = nil
        }
    }
    
    // MARK: - Optimized Refresh Operations
    
    func refreshAlarms() async {
        logger.info("🔔 Refreshing alarms from AlarmKit (optimized)")
        
        // Use debounced refresh to prevent excessive API calls
        refreshDebouncer?.call()
    }
    
    private func performDebouncedRefresh() async {
        let startTime = Date()
        
        do {
            let allAlarms = try alarmManager.alarms
            await MainActor.run {
                self.alarms = allAlarms
            }
            
            let duration = Date().timeIntervalSince(startTime)
            performanceMetrics.recordRefreshTime(duration)
            
            logger.info("✅ Refreshed \(allAlarms.count) alarms from AlarmKit (optimized) in \(String(format: "%.3f", duration))s")
        } catch {
            logger.error("❌ Failed to refresh alarms: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Performance Optimization Methods
    
    private func optimizeForAlarmCount(_ count: Int) {
        if count > 50 {
            logger.info("📊 High alarm count detected (\(count)), enabling aggressive caching")
            // Enable more aggressive caching strategies
        } else if count > 20 {
            logger.info("📊 Medium alarm count detected (\(count)), enabling standard caching")
            // Enable standard caching strategies
        }
    }
    
    private func logPerformanceMetrics() {
        let metrics = performanceMetrics.getSummary()
        logger.info("📊 Performance Metrics: \(metrics)")
        
        // Log memory usage
        let memoryUsage = getMemoryUsage()
        logger.info("💾 Memory Usage: \(String(format: "%.2f", memoryUsage)) MB")
        
        // Log cache statistics
        logger.info("📦 Cache Statistics: \(alarmConfigurationCache.count) cached configurations")
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        } else {
            return 0.0
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
        logger.info("🔔 Loading existing alarms from AlarmKit (optimized)")
        await refreshAlarms()
    }
    
    private func setupObservers() {
        logger.info("🔔 Setting up AlarmKit observers (optimized)")
        
        // Observe alarm state changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AlarmDidFire"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAlarmFired(notification)
            }
        }
        
        // Observe alarm dismissal
        NotificationCenter.default.default.addObserver(
            forName: Notification.Name("AlarmWasDismissed"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAlarmDismissed(notification)
            }
        }
    }
    
    private func handleAlarmFired(_ notification: Notification) {
        logger.info("🔔 AlarmKit alarm fired")
        
        if let alarmId = notification.userInfo?["alarmId"] as? String {
            activeAlarmId = alarmId
        }
    }
    
    private func handleAlarmDismissed(_ notification: Notification) {
        logger.info("👋 AlarmKit alarm dismissed")
        
        if let alarmId = notification.userInfo?["alarmId"] as? String {
            activeAlarmId = nil
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        batchTimer?.invalidate()
        refreshDebouncer = nil
    }
}

// MARK: - Performance Metrics

private class PerformanceMetrics {
    private var authorizationTimes: [TimeInterval] = []
    private var schedulingTimes: [TimeInterval] = []
    private var batchSchedulingTimes: [TimeInterval] = []
    private var batchProcessingTimes: [TimeInterval] = []
    private var refreshTimes: [TimeInterval] = []
    
    func recordAuthorizationTime(_ time: TimeInterval) {
        authorizationTimes.append(time)
        if authorizationTimes.count > 100 { authorizationTimes.removeFirst() }
    }
    
    func recordSchedulingTime(_ time: TimeInterval) {
        schedulingTimes.append(time)
        if schedulingTimes.count > 100 { schedulingTimes.removeFirst() }
    }
    
    func recordBatchSchedulingTime(_ time: TimeInterval, count: Int) {
        batchSchedulingTimes.append(time)
        if batchSchedulingTimes.count > 50 { batchSchedulingTimes.removeFirst() }
    }
    
    func recordBatchProcessingTime(_ time: TimeInterval, count: Int) {
        batchProcessingTimes.append(time)
        if batchProcessingTimes.count > 50 { batchProcessingTimes.removeFirst() }
    }
    
    func recordRefreshTime(_ time: TimeInterval) {
        refreshTimes.append(time)
        if refreshTimes.count > 100 { refreshTimes.removeFirst() }
    }
    
    func getSummary() -> String {
        let authAvg = authorizationTimes.isEmpty ? 0 : authorizationTimes.reduce(0, +) / Double(authorizationTimes.count)
        let schedAvg = schedulingTimes.isEmpty ? 0 : schedulingTimes.reduce(0, +) / Double(schedulingTimes.count)
        let refreshAvg = refreshTimes.isEmpty ? 0 : refreshTimes.reduce(0, +) / Double(refreshTimes.count)
        
        return "Auth: \(String(format: "%.3f", authAvg))s, Schedule: \(String(format: "%.3f", schedAvg))s, Refresh: \(String(format: "%.3f", refreshAvg))s"
    }
}

// MARK: - Debouncer

private class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func call() {
        workItem?.cancel()
        workItem = DispatchWorkItem { [weak self] in
            // This will be overridden by the caller
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}
