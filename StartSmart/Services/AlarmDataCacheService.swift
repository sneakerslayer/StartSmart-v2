import Foundation
import AlarmKit
import os.log

// MARK: - Alarm Data Caching Service

/// High-performance caching service for alarm data and configurations
@MainActor
class AlarmDataCacheService: ObservableObject {
    static let shared = AlarmDataCacheService()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "AlarmDataCacheService")
    
    // MARK: - Cache Storage
    
    /// Cache for alarm configurations
    private var alarmConfigurationCache: [String: AlarmManager.AlarmConfiguration] = [:]
    
    /// Cache for alarm metadata
    private var alarmMetadataCache: [String: StartSmartAlarmMetadata] = [:]
    
    /// Cache for alarm presentation data
    private var alarmPresentationCache: [String: AlarmPresentation] = [:]
    
    /// Cache for alarm schedule data
    private var alarmScheduleCache: [String: AlarmKit.Alarm.Schedule] = [:]
    
    /// Cache for weekday conversions
    private var weekdayConversionCache: [Set<WeekDay>: [Locale.Weekday]] = [:]
    
    /// Cache for alarm list data
    private var alarmListCache: [AlarmKit.Alarm] = []
    private var alarmListCacheTimestamp: Date?
    
    // MARK: - Cache Configuration
    
    private let maxCacheSize = 100
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private let alarmListCacheExpirationTime: TimeInterval = 60 // 1 minute
    
    // MARK: - Cache Statistics
    
    private var cacheHits = 0
    private var cacheMisses = 0
    private var cacheEvictions = 0
    
    private init() {
        logger.info("📦 AlarmDataCacheService initialized")
        setupCacheMaintenance()
    }
    
    // MARK: - Cache Maintenance
    
    private func setupCacheMaintenance() {
        // Periodic cache cleanup
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCacheMaintenance()
            }
        }
        
        // Memory pressure monitoring
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }
    }
    
    private func performCacheMaintenance() {
        logger.info("🧹 Performing cache maintenance")
        
        // Clean expired entries
        cleanExpiredEntries()
        
        // Evict least recently used entries if cache is too large
        if alarmConfigurationCache.count > maxCacheSize {
            evictLeastRecentlyUsed()
        }
        
        // Log cache statistics
        logCacheStatistics()
    }
    
    private func handleMemoryPressure() {
        logger.info("⚠️ Memory pressure detected, clearing cache")
        
        // Clear all caches except critical ones
        alarmConfigurationCache.removeAll()
        alarmPresentationCache.removeAll()
        alarmScheduleCache.removeAll()
        
        // Keep metadata cache as it's small and frequently accessed
        // Keep weekday conversion cache as it's small and stable
        
        cacheEvictions += alarmConfigurationCache.count + alarmPresentationCache.count + alarmScheduleCache.count
    }
    
    // MARK: - Alarm Configuration Caching
    
    func getCachedAlarmConfiguration(for alarmId: String) -> AlarmManager.AlarmConfiguration? {
        if let config = alarmConfigurationCache[alarmId] {
            cacheHits += 1
            logger.debug("📦 Cache HIT: Alarm configuration for \(alarmId)")
            return config
        } else {
            cacheMisses += 1
            logger.debug("📦 Cache MISS: Alarm configuration for \(alarmId)")
            return nil
        }
    }
    
    func cacheAlarmConfiguration(_ config: AlarmManager.AlarmConfiguration, for alarmId: String) {
        alarmConfigurationCache[alarmId] = config
        logger.debug("📦 Cached alarm configuration for \(alarmId)")
        
        // Evict oldest entries if cache is too large
        if alarmConfigurationCache.count > maxCacheSize {
            evictOldestConfiguration()
        }
    }
    
    private func evictOldestConfiguration() {
        // Simple FIFO eviction for now
        if let firstKey = alarmConfigurationCache.keys.first {
            alarmConfigurationCache.removeValue(forKey: firstKey)
            cacheEvictions += 1
            logger.debug("📦 Evicted oldest alarm configuration: \(firstKey)")
        }
    }
    
    // MARK: - Alarm Metadata Caching
    
    func getCachedAlarmMetadata(for alarmId: String) -> StartSmartAlarmMetadata? {
        return alarmMetadataCache[alarmId]
    }
    
    func cacheAlarmMetadata(_ metadata: StartSmartAlarmMetadata, for alarmId: String) {
        alarmMetadataCache[alarmId] = metadata
        logger.debug("📦 Cached alarm metadata for \(alarmId)")
    }
    
    // MARK: - Alarm Presentation Caching
    
    func getCachedAlarmPresentation(for alarmId: String) -> AlarmPresentation? {
        return alarmPresentationCache[alarmId]
    }
    
    func cacheAlarmPresentation(_ presentation: AlarmPresentation, for alarmId: String) {
        alarmPresentationCache[alarmId] = presentation
        logger.debug("📦 Cached alarm presentation for \(alarmId)")
    }
    
    // MARK: - Alarm Schedule Caching
    
    func getCachedAlarmSchedule(for alarmId: String) -> AlarmKit.Alarm.Schedule? {
        return alarmScheduleCache[alarmId]
    }
    
    func cacheAlarmSchedule(_ schedule: AlarmKit.Alarm.Schedule, for alarmId: String) {
        alarmScheduleCache[alarmId] = schedule
        logger.debug("📦 Cached alarm schedule for \(alarmId)")
    }
    
    // MARK: - Weekday Conversion Caching
    
    func getCachedWeekdayConversion(for weekDays: Set<WeekDay>) -> [Locale.Weekday]? {
        return weekdayConversionCache[weekDays]
    }
    
    func cacheWeekdayConversion(_ weekDays: Set<WeekDay>, _ alarmKitWeekdays: [Locale.Weekday]) {
        weekdayConversionCache[weekDays] = alarmKitWeekdays
        logger.debug("📦 Cached weekday conversion for \(weekDays.count) days")
    }
    
    // MARK: - Alarm List Caching
    
    func getCachedAlarmList() -> [AlarmKit.Alarm]? {
        guard let timestamp = alarmListCacheTimestamp else { return nil }
        
        if Date().timeIntervalSince(timestamp) < alarmListCacheExpirationTime {
            cacheHits += 1
            logger.debug("📦 Cache HIT: Alarm list (\(alarmListCache.count) alarms)")
            return alarmListCache
        } else {
            cacheMisses += 1
            logger.debug("📦 Cache MISS: Alarm list expired")
            return nil
        }
    }
    
    func cacheAlarmList(_ alarms: [AlarmKit.Alarm]) {
        alarmListCache = alarms
        alarmListCacheTimestamp = Date()
        logger.debug("📦 Cached alarm list (\(alarms.count) alarms)")
    }
    
    // MARK: - Cache Invalidation
    
    func invalidateAlarmCache(for alarmId: String) {
        alarmConfigurationCache.removeValue(forKey: alarmId)
        alarmMetadataCache.removeValue(forKey: alarmId)
        alarmPresentationCache.removeValue(forKey: alarmId)
        alarmScheduleCache.removeValue(forKey: alarmId)
        
        logger.debug("📦 Invalidated cache for alarm: \(alarmId)")
    }
    
    func invalidateAllCaches() {
        alarmConfigurationCache.removeAll()
        alarmMetadataCache.removeAll()
        alarmPresentationCache.removeAll()
        alarmScheduleCache.removeAll()
        alarmListCache.removeAll()
        alarmListCacheTimestamp = nil
        
        logger.info("📦 Invalidated all caches")
    }
    
    // MARK: - Cache Statistics
    
    private func logCacheStatistics() {
        let hitRate = cacheHits + cacheMisses > 0 ? Double(cacheHits) / Double(cacheHits + cacheMisses) * 100 : 0
        
        logger.info("📊 Cache Statistics:")
        logger.info("   Hit Rate: \(String(format: "%.1f", hitRate))%")
        logger.info("   Hits: \(cacheHits), Misses: \(cacheMisses), Evictions: \(cacheEvictions)")
        logger.info("   Configuration Cache: \(alarmConfigurationCache.count) entries")
        logger.info("   Metadata Cache: \(alarmMetadataCache.count) entries")
        logger.info("   Presentation Cache: \(alarmPresentationCache.count) entries")
        logger.info("   Schedule Cache: \(alarmScheduleCache.count) entries")
        logger.info("   Weekday Cache: \(weekdayConversionCache.count) entries")
    }
    
    func getCacheStatistics() -> CacheStatistics {
        let hitRate = cacheHits + cacheMisses > 0 ? Double(cacheHits) / Double(cacheHits + cacheMisses) * 100 : 0
        
        return CacheStatistics(
            hitRate: hitRate,
            hits: cacheHits,
            misses: cacheMisses,
            evictions: cacheEvictions,
            configurationCacheSize: alarmConfigurationCache.count,
            metadataCacheSize: alarmMetadataCache.count,
            presentationCacheSize: alarmPresentationCache.count,
            scheduleCacheSize: alarmScheduleCache.count,
            weekdayCacheSize: weekdayConversionCache.count
        )
    }
    
    // MARK: - Cache Cleanup
    
    private func cleanExpiredEntries() {
        // For now, we use simple size-based eviction
        // In a more sophisticated implementation, we would track access times
        // and evict based on expiration timestamps
        
        let currentTime = Date()
        
        // Clean alarm list cache if expired
        if let timestamp = alarmListCacheTimestamp,
           currentTime.timeIntervalSince(timestamp) > alarmListCacheExpirationTime {
            alarmListCache.removeAll()
            alarmListCacheTimestamp = nil
            logger.debug("📦 Cleaned expired alarm list cache")
        }
    }
    
    private func evictLeastRecentlyUsed() {
        // Simple implementation: evict oldest entries
        // In a production app, you'd implement proper LRU with access timestamps
        
        let evictionCount = alarmConfigurationCache.count - maxCacheSize + 10 // Evict 10 extra
        
        for _ in 0..<evictionCount {
            if let firstKey = alarmConfigurationCache.keys.first {
                alarmConfigurationCache.removeValue(forKey: firstKey)
                cacheEvictions += 1
            }
        }
        
        logger.debug("📦 Evicted \(evictionCount) least recently used entries")
    }
}

// MARK: - Cache Statistics Model

struct CacheStatistics {
    let hitRate: Double
    let hits: Int
    let misses: Int
    let evictions: Int
    let configurationCacheSize: Int
    let metadataCacheSize: Int
    let presentationCacheSize: Int
    let scheduleCacheSize: Int
    let weekdayCacheSize: Int
    
    var description: String {
        return """
        Cache Statistics:
        Hit Rate: \(String(format: "%.1f", hitRate))%
        Hits: \(hits), Misses: \(misses), Evictions: \(evictions)
        Configuration Cache: \(configurationCacheSize) entries
        Metadata Cache: \(metadataCacheSize) entries
        Presentation Cache: \(presentationCacheSize) entries
        Schedule Cache: \(scheduleCacheSize) entries
        Weekday Cache: \(weekdayCacheSize) entries
        """
    }
}

// MARK: - Cache Performance Monitor

/// Monitors cache performance and provides optimization recommendations
class CachePerformanceMonitor {
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "CachePerformanceMonitor")
    private var performanceHistory: [CacheStatistics] = []
    
    func recordStatistics(_ stats: CacheStatistics) {
        performanceHistory.append(stats)
        
        // Keep only last 100 records
        if performanceHistory.count > 100 {
            performanceHistory.removeFirst()
        }
        
        // Analyze performance trends
        analyzePerformanceTrends()
    }
    
    private func analyzePerformanceTrends() {
        guard performanceHistory.count >= 10 else { return }
        
        let recentStats = Array(performanceHistory.suffix(10))
        let averageHitRate = recentStats.map { $0.hitRate }.reduce(0, +) / Double(recentStats.count)
        
        if averageHitRate < 70.0 {
            logger.warning("⚠️ Low cache hit rate detected: \(String(format: "%.1f", averageHitRate))%")
            logger.info("💡 Consider increasing cache size or improving cache key strategy")
        } else if averageHitRate > 95.0 {
            logger.info("✅ Excellent cache performance: \(String(format: "%.1f", averageHitRate))%")
        }
        
        // Check for memory pressure
        let totalCacheSize = recentStats.last?.configurationCacheSize ?? 0
        if totalCacheSize > 80 {
            logger.warning("⚠️ High cache usage detected: \(totalCacheSize) entries")
            logger.info("💡 Consider implementing more aggressive eviction policies")
        }
    }
    
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        guard let latestStats = performanceHistory.last else { return recommendations }
        
        if latestStats.hitRate < 70.0 {
            recommendations.append("Increase cache size to improve hit rate")
            recommendations.append("Review cache key strategy for better distribution")
        }
        
        if latestStats.evictions > latestStats.hits / 2 {
            recommendations.append("Implement LRU eviction policy")
            recommendations.append("Consider cache warming strategies")
        }
        
        if latestStats.configurationCacheSize > 80 {
            recommendations.append("Implement more aggressive eviction policies")
            recommendations.append("Consider cache partitioning by alarm type")
        }
        
        return recommendations
    }
}
