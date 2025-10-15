import Foundation
import os.log
import UIKit

// MARK: - Performance Monitoring Service

/// Comprehensive performance monitoring service for AlarmKit operations
@MainActor
class PerformanceMonitoringService: ObservableObject {
    static let shared = PerformanceMonitoringService()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "PerformanceMonitoringService")
    
    // MARK: - Performance Metrics
    
    @Published var currentMemoryUsage: Double = 0.0
    @Published var peakMemoryUsage: Double = 0.0
    @Published var averageCPUUsage: Double = 0.0
    @Published var batteryLevel: Float = 0.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    
    // MARK: - Operation Metrics
    
    private var operationMetrics: [String: OperationMetrics] = [:]
    private var performanceHistory: [PerformanceSnapshot] = []
    
    // MARK: - Monitoring Configuration
    
    private let monitoringInterval: TimeInterval = 5.0 // 5 seconds
    private let maxHistorySize = 100
    private var monitoringTimer: Timer?
    
    // MARK: - Performance Thresholds
    
    private let memoryWarningThreshold: Double = 100.0 // MB
    private let cpuWarningThreshold: Double = 80.0 // %
    private let batteryWarningThreshold: Float = 0.2 // 20%
    
    private init() {
        logger.info("📊 PerformanceMonitoringService initialized")
        setupMonitoring()
        setupBatteryMonitoring()
    }
    
    // MARK: - Setup Methods
    
    private func setupMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.collectPerformanceMetrics()
            }
        }
        
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryWarning()
            }
        }
        
        // Monitor app state changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppBackgrounded()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppForegrounded()
            }
        }
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Monitor battery state changes
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.updateBatteryInfo()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.updateBatteryInfo()
            }
        }
    }
    
    // MARK: - Performance Collection
    
    private func collectPerformanceMetrics() async {
        let memoryUsage = getMemoryUsage()
        let cpuUsage = getCPUUsage()
        
        await MainActor.run {
            self.currentMemoryUsage = memoryUsage
            self.averageCPUUsage = cpuUsage
            
            if memoryUsage > self.peakMemoryUsage {
                self.peakMemoryUsage = memoryUsage
            }
        }
        
        // Create performance snapshot
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            batteryLevel: batteryLevel,
            batteryState: batteryState
        )
        
        await MainActor.run {
            self.performanceHistory.append(snapshot)
            
            // Keep only recent history
            if self.performanceHistory.count > self.maxHistorySize {
                self.performanceHistory.removeFirst()
            }
        }
        
        // Check for performance warnings
        checkPerformanceWarnings(memoryUsage: memoryUsage, cpuUsage: cpuUsage)
        
        logger.debug("📊 Performance metrics collected: Memory: \(String(format: "%.2f", memoryUsage))MB, CPU: \(String(format: "%.1f", cpuUsage))%")
    }
    
    private func updateBatteryInfo() async {
        let device = UIDevice.current
        
        await MainActor.run {
            self.batteryLevel = device.batteryLevel
            self.batteryState = device.batteryState
        }
        
        logger.debug("🔋 Battery info updated: Level: \(String(format: "%.1f", device.batteryLevel * 100))%, State: \(device.batteryState)")
    }
    
    // MARK: - Operation Tracking
    
    func startOperation(_ operationName: String) -> OperationTracker {
        let tracker = OperationTracker(operationName: operationName, startTime: Date())
        
        Task { @MainActor in
            self.operationMetrics[operationName] = OperationMetrics(
                operationName: operationName,
                startTime: tracker.startTime,
                endTime: nil,
                duration: nil,
                memoryBefore: self.currentMemoryUsage,
                memoryAfter: nil,
                cpuBefore: self.averageCPUUsage,
                cpuAfter: nil
            )
        }
        
        logger.debug("⏱️ Started operation: \(operationName)")
        return tracker
    }
    
    func endOperation(_ tracker: OperationTracker) {
        let endTime = Date()
        let duration = endTime.timeIntervalSince(tracker.startTime)
        
        Task { @MainActor in
            if var metrics = self.operationMetrics[tracker.operationName] {
                metrics.endTime = endTime
                metrics.duration = duration
                metrics.memoryAfter = self.currentMemoryUsage
                metrics.cpuAfter = self.averageCPUUsage
                
                self.operationMetrics[tracker.operationName] = metrics
                
                // Log performance impact
                self.logOperationPerformance(metrics)
            }
        }
        
        logger.debug("⏱️ Completed operation: \(tracker.operationName) in \(String(format: "%.3f", duration))s")
    }
    
    private func logOperationPerformance(_ metrics: OperationMetrics) {
        let memoryDelta = (metrics.memoryAfter ?? 0) - metrics.memoryBefore
        let cpuDelta = (metrics.cpuAfter ?? 0) - metrics.cpuBefore
        
        logger.info("📊 Operation Performance: \(metrics.operationName)")
        logger.info("   Duration: \(String(format: "%.3f", metrics.duration ?? 0))s")
        logger.info("   Memory Delta: \(String(format: "%.2f", memoryDelta))MB")
        logger.info("   CPU Delta: \(String(format: "%.1f", cpuDelta))%")
        
        // Check for performance issues
        if metrics.duration ?? 0 > 2.0 {
            logger.warning("⚠️ Slow operation detected: \(metrics.operationName)")
        }
        
        if abs(memoryDelta) > 10.0 {
            logger.warning("⚠️ High memory usage operation: \(metrics.operationName)")
        }
    }
    
    // MARK: - Performance Warnings
    
    private func checkPerformanceWarnings(memoryUsage: Double, cpuUsage: Double) {
        if memoryUsage > memoryWarningThreshold {
            logger.warning("⚠️ High memory usage detected: \(String(format: "%.2f", memoryUsage))MB")
        }
        
        if cpuUsage > cpuWarningThreshold {
            logger.warning("⚠️ High CPU usage detected: \(String(format: "%.1f", cpuUsage))%")
        }
        
        if batteryLevel < batteryWarningThreshold && batteryLevel > 0 {
            logger.warning("⚠️ Low battery level detected: \(String(format: "%.1f", batteryLevel * 100))%")
        }
    }
    
    private func handleMemoryWarning() async {
        logger.warning("⚠️ Memory warning received")
        
        // Trigger cache cleanup
        await AlarmDataCacheService.shared.handleMemoryPressure()
        
        // Log current memory usage
        let memoryUsage = getMemoryUsage()
        logger.info("📊 Memory usage after warning: \(String(format: "%.2f", memoryUsage))MB")
    }
    
    private func handleAppBackgrounded() async {
        logger.info("📱 App backgrounded, reducing monitoring frequency")
        
        // Reduce monitoring frequency when backgrounded
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.collectPerformanceMetrics()
            }
        }
    }
    
    private func handleAppForegrounded() async {
        logger.info("📱 App foregrounded, resuming normal monitoring")
        
        // Resume normal monitoring frequency
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.collectPerformanceMetrics()
            }
        }
    }
    
    // MARK: - System Metrics Collection
    
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
    
    private func getCPUUsage() -> Double {
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(THREAD_BASIC_INFO_COUNT)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                thread_info(mach_thread_self(),
                           thread_flavor_t(THREAD_BASIC_INFO),
                           $0,
                           &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
        } else {
            return 0.0
        }
    }
    
    // MARK: - Performance Reports
    
    func generatePerformanceReport() -> PerformanceReport {
        let recentSnapshots = Array(performanceHistory.suffix(20))
        
        let averageMemory = recentSnapshots.isEmpty ? 0 : recentSnapshots.map { $0.memoryUsage }.reduce(0, +) / Double(recentSnapshots.count)
        let averageCPU = recentSnapshots.isEmpty ? 0 : recentSnapshots.map { $0.cpuUsage }.reduce(0, +) / Double(recentSnapshots.count)
        
        let operationCounts = Dictionary(grouping: operationMetrics.values) { $0.operationName }
            .mapValues { $0.count }
        
        return PerformanceReport(
            timestamp: Date(),
            currentMemoryUsage: currentMemoryUsage,
            peakMemoryUsage: peakMemoryUsage,
            averageMemoryUsage: averageMemory,
            averageCPUUsage: averageCPU,
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            operationCounts: operationCounts,
            performanceHistory: recentSnapshots
        )
    }
    
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if peakMemoryUsage > 150.0 {
            recommendations.append("Consider implementing more aggressive memory management")
            recommendations.append("Review alarm data caching strategies")
        }
        
        if averageCPUUsage > 50.0 {
            recommendations.append("Optimize CPU-intensive operations")
            recommendations.append("Consider background processing for heavy tasks")
        }
        
        if batteryLevel < 0.3 && batteryLevel > 0 {
            recommendations.append("Implement battery-aware features")
            recommendations.append("Reduce background processing when battery is low")
        }
        
        // Check for slow operations
        let slowOperations = operationMetrics.values.filter { ($0.duration ?? 0) > 2.0 }
        if !slowOperations.isEmpty {
            recommendations.append("Optimize slow operations: \(slowOperations.map { $0.operationName }.joined(separator: ", "))")
        }
        
        return recommendations
    }
    
    // MARK: - Cleanup
    
    deinit {
        monitoringTimer?.invalidate()
    }
}

// MARK: - Supporting Types

struct OperationTracker {
    let operationName: String
    let startTime: Date
}

struct OperationMetrics {
    let operationName: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval?
    let memoryBefore: Double
    var memoryAfter: Double?
    let cpuBefore: Double
    var cpuAfter: Double?
}

struct PerformanceSnapshot {
    let timestamp: Date
    let memoryUsage: Double
    let cpuUsage: Double
    let batteryLevel: Float
    let batteryState: UIDevice.BatteryState
}

struct PerformanceReport {
    let timestamp: Date
    let currentMemoryUsage: Double
    let peakMemoryUsage: Double
    let averageMemoryUsage: Double
    let averageCPUUsage: Double
    let batteryLevel: Float
    let batteryState: UIDevice.BatteryState
    let operationCounts: [String: Int]
    let performanceHistory: [PerformanceSnapshot]
    
    var description: String {
        return """
        Performance Report (\(timestamp)):
        Memory: Current \(String(format: "%.2f", currentMemoryUsage))MB, Peak \(String(format: "%.2f", peakMemoryUsage))MB, Avg \(String(format: "%.2f", averageMemoryUsage))MB
        CPU: Average \(String(format: "%.1f", averageCPUUsage))%
        Battery: \(String(format: "%.1f", batteryLevel * 100))% (\(batteryState))
        Operations: \(operationCounts)
        """
    }
}

// MARK: - Extension for Cache Service

extension AlarmDataCacheService {
    func handleMemoryPressure() async {
        logger.info("⚠️ Handling memory pressure in cache service")
        
        // Clear non-essential caches
        alarmConfigurationCache.removeAll()
        alarmPresentationCache.removeAll()
        alarmScheduleCache.removeAll()
        
        // Keep essential caches
        // alarmMetadataCache and weekdayConversionCache are kept as they're small and frequently accessed
        
        logger.info("📦 Cache service memory pressure handled")
    }
}
