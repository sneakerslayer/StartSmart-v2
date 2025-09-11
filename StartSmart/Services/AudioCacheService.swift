import Foundation
import AVFoundation
import Combine

// MARK: - Audio Cache Service Protocol
protocol AudioCacheServiceProtocol {
    func cacheAudio(data: Data, forKey key: String, metadata: SimpleAudioMetadata) async throws -> String
    func getCachedAudio(forKey key: String) async throws -> CachedAudioResult?
    func removeCachedAudio(forKey key: String) async throws
    func clearCache() async throws
    func getCacheStatistics() async -> AudioCacheStatistics
    func performMaintenance() async throws
}

// MARK: - Simple Audio Metadata (Self-contained)
struct SimpleAudioMetadata {
    let intentId: String
    let voiceId: String
    let duration: TimeInterval?
    let format: String // "mp3", "wav", "flac"
    let quality: String // "standard", "high", "premium"
    let generatedAt: Date
    
    init(
        intentId: String,
        voiceId: String,
        duration: TimeInterval? = nil,
        format: String = "mp3",
        quality: String = "standard",
        generatedAt: Date = Date()
    ) {
        self.intentId = intentId
        self.voiceId = voiceId
        self.duration = duration
        self.format = format
        self.quality = quality
        self.generatedAt = generatedAt
    }
}

// MARK: - Simple Cached Audio Item (Self-contained)
struct SimpleCachedAudioItem: Codable {
    let filePath: String
    let sizeKB: Double
    let duration: TimeInterval
    let createdAt: Date
    let intentId: String
    let voiceId: String
    let format: String
    let quality: String
    
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 72 * 3600 // 72 hours
    }
}

// MARK: - Simple Audio Cache (Self-contained)
struct SimpleAudioCache: Codable {
    var cachedAudio: [String: SimpleCachedAudioItem]
    var totalSizeMB: Double
    var lastCleanupDate: Date?
    
    init() {
        self.cachedAudio = [:]
        self.totalSizeMB = 0.0
        self.lastCleanupDate = nil
    }
    
    mutating func addAudioItem(_ item: SimpleCachedAudioItem, forKey key: String) {
        cachedAudio[key] = item
        recalculateSize()
    }
    
    mutating func cleanup(maxSizeMB: Int, expirationHours: Int) {
        let expirationDate = Date().addingTimeInterval(-TimeInterval(expirationHours * 3600))
        
        // Remove expired items
        cachedAudio = cachedAudio.filter { $0.value.createdAt > expirationDate }
        
        // Remove oldest items if still over size limit
        while totalSizeMB > Double(maxSizeMB) && !cachedAudio.isEmpty {
            let oldestKey = cachedAudio.min { $0.value.createdAt < $1.value.createdAt }?.key
            if let key = oldestKey {
                cachedAudio.removeValue(forKey: key)
            }
        }
        
        recalculateSize()
        lastCleanupDate = Date()
    }
    
    private mutating func recalculateSize() {
        totalSizeMB = cachedAudio.values.reduce(0) { $0 + $1.sizeKB } / 1024.0
    }
}

// MARK: - Cached Audio Result
struct CachedAudioResult {
    let filePath: String
    let metadata: SimpleAudioMetadata
    let item: SimpleCachedAudioItem
    let isValid: Bool
    
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
}

// MARK: - Audio Cache Statistics
struct AudioCacheStatistics {
    let totalItems: Int
    let totalSizeMB: Double
    let oldestItemDate: Date?
    let newestItemDate: Date?
    let averageFileSizeKB: Double
    let expiredItemsCount: Int
    let availableStorageGB: Double
    let cacheHitRate: Double
    
    var formattedTotalSize: String {
        if totalSizeMB < 1.0 {
            return String(format: "%.1f KB", totalSizeMB * 1024)
        } else {
            return String(format: "%.1f MB", totalSizeMB)
        }
    }
    
    var healthStatus: CacheHealthStatus {
        if totalSizeMB > 200 {
            return .critical
        } else if totalSizeMB > 100 {
            return .warning
        } else if expiredItemsCount > 20 {
            return .warning
        } else {
            return .healthy
        }
    }
}

enum CacheHealthStatus {
    case healthy
    case warning
    case critical
    
    var description: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Needs Attention"
        case .critical: return "Critical - Cleanup Required"
        }
    }
}

// MARK: - Simple Local Storage for Audio Cache
class SimpleAudioCacheStorage {
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "audio_cache_data"
    
    func saveCache(_ cache: SimpleAudioCache) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cache)
        userDefaults.set(data, forKey: cacheKey)
    }
    
    func loadCache() -> SimpleAudioCache? {
        guard let data = userDefaults.data(forKey: cacheKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SimpleAudioCache.self, from: data)
        } catch {
            print("Error loading audio cache: \(error)")
            return nil
        }
    }
    
    func deleteCache() {
        userDefaults.removeObject(forKey: cacheKey)
    }
}

// MARK: - Audio Cache Service Implementation
@MainActor
class AudioCacheService: AudioCacheServiceProtocol, ObservableObject {
    
    private let fileManager = FileManager.default
    private let storage = SimpleAudioCacheStorage()
    private let cacheDirectory: URL
    private let maxCacheSizeMB: Int
    private let expirationHours: Int
    
    @Published var cacheStatistics = AudioCacheStatistics(
        totalItems: 0,
        totalSizeMB: 0.0,
        oldestItemDate: nil,
        newestItemDate: nil,
        averageFileSizeKB: 0.0,
        expiredItemsCount: 0,
        availableStorageGB: 0.0,
        cacheHitRate: 0.0
    )
    
    private var cacheHits: Int = 0
    private var cacheRequests: Int = 0
    
    init(
        maxCacheSizeMB: Int = 150,
        expirationHours: Int = 72
    ) throws {
        self.maxCacheSizeMB = maxCacheSizeMB
        self.expirationHours = expirationHours
        
        // Create cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentsPath.appendingPathComponent("AudioCache")
        
        try createCacheDirectoryIfNeeded()
        
        // Initialize cache statistics
        Task {
            await updateCacheStatistics()
        }
    }
    
    // MARK: - Cache Operations
    
    func cacheAudio(data: Data, forKey key: String, metadata: SimpleAudioMetadata) async throws -> String {
        // Validate input
        guard !data.isEmpty else {
            throw AudioCacheError.invalidData("Audio data is empty")
        }
        
        guard !key.isEmpty else {
            throw AudioCacheError.invalidKey("Cache key cannot be empty")
        }
        
        // Create file path
        let fileName = sanitizeFileName(key) + ".\(metadata.format)"
        let filePath = cacheDirectory.appendingPathComponent(fileName)
        
        // Calculate file size
        let sizeKB = Double(data.count) / 1024.0
        
        // Check if caching this file would exceed limits
        try await enforeCacheLimits(additionalSizeKB: sizeKB)
        
        // Write audio data to file
        try data.write(to: filePath)
        
        // Create cached audio item
        let audioItem = SimpleCachedAudioItem(
            filePath: filePath.path,
            sizeKB: sizeKB,
            duration: metadata.duration ?? 0.0,
            createdAt: metadata.generatedAt,
            intentId: metadata.intentId,
            voiceId: metadata.voiceId,
            format: metadata.format,
            quality: metadata.quality
        )
        
        // Update content cache
        var contentCache = loadContentCache()
        contentCache.addAudioItem(audioItem, forKey: key)
        try saveContentCache(contentCache)
        
        await updateCacheStatistics()
        
        return filePath.path
    }
    
    func getCachedAudio(forKey key: String) async throws -> CachedAudioResult? {
        cacheRequests += 1
        
        let contentCache = loadContentCache()
        
        guard let audioItem = contentCache.cachedAudio[key] else {
            return nil
        }
        
        // Check if file still exists
        guard fileManager.fileExists(atPath: audioItem.filePath) else {
            // Remove stale entry
            var updatedCache = contentCache
            updatedCache.cachedAudio.removeValue(forKey: key)
            try saveContentCache(updatedCache)
            return nil
        }
        
        // Check if expired
        if audioItem.isExpired {
            // Remove expired entry
            try await removeCachedAudio(forKey: key)
            return nil
        }
        
        cacheHits += 1
        
        // Create metadata from cached item
        let metadata = SimpleAudioMetadata(
            intentId: audioItem.intentId,
            voiceId: audioItem.voiceId,
            duration: audioItem.duration,
            format: audioItem.format,
            quality: audioItem.quality,
            generatedAt: audioItem.createdAt
        )
        
        return CachedAudioResult(
            filePath: audioItem.filePath,
            metadata: metadata,
            item: audioItem,
            isValid: true
        )
    }
    
    func removeCachedAudio(forKey key: String) async throws {
        var contentCache = loadContentCache()
        
        if let audioItem = contentCache.cachedAudio[key] {
            // Remove file from disk
            let fileURL = URL(fileURLWithPath: audioItem.filePath)
            try? fileManager.removeItem(at: fileURL)
            
            // Remove from cache
            contentCache.cachedAudio.removeValue(forKey: key)
            try saveContentCache(contentCache)
        }
        
        await updateCacheStatistics()
    }
    
    func clearCache() async throws {
        // Remove all files from cache directory
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
        
        // Clear content cache
        let emptyCache = SimpleAudioCache()
        try saveContentCache(emptyCache)
        
        // Reset cache statistics
        cacheHits = 0
        cacheRequests = 0
        
        await updateCacheStatistics()
    }
    
    func getCacheStatistics() async -> AudioCacheStatistics {
        await updateCacheStatistics()
        return cacheStatistics
    }
    
    func performMaintenance() async throws {
        var contentCache = loadContentCache()
        
        // Remove expired items and cleanup based on size limits
        contentCache.cleanup(maxSizeMB: maxCacheSizeMB, expirationHours: expirationHours)
        
        // Remove orphaned files (files that exist on disk but not in cache metadata)
        try await removeOrphanedFiles(contentCache: contentCache)
        
        // Remove stale file references (cache entries that point to non-existent files)
        contentCache = try await removeStaleReferences(contentCache: contentCache)
        
        try saveContentCache(contentCache)
        await updateCacheStatistics()
    }
    
    // MARK: - Private Methods
    
    private func createCacheDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func loadContentCache() -> SimpleAudioCache {
        return storage.loadCache() ?? SimpleAudioCache()
    }
    
    private func saveContentCache(_ cache: SimpleAudioCache) throws {
        try storage.saveCache(cache)
    }
    
    private func enforeCacheLimits(additionalSizeKB: Double) async throws {
        let currentCache = loadContentCache()
        let currentSizeMB = currentCache.totalSizeMB
        let additionalSizeMB = additionalSizeKB / 1024.0
        
        if currentSizeMB + additionalSizeMB > Double(maxCacheSizeMB) {
            // Trigger cleanup
            var cleanedCache = currentCache
            cleanedCache.cleanup(maxSizeMB: Int(Double(maxCacheSizeMB) * 0.8), expirationHours: expirationHours) // Clean to 80% capacity
            try saveContentCache(cleanedCache)
        }
    }
    
    private func sanitizeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return fileName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .prefix(100) // Limit length
            .description
    }
    
    private func updateCacheStatistics() async {
        let contentCache = loadContentCache()
        let audioItems = Array(contentCache.cachedAudio.values)
        
        let totalItems = audioItems.count
        let totalSizeMB = contentCache.totalSizeMB
        let oldestItemDate = audioItems.min(by: { $0.createdAt < $1.createdAt })?.createdAt
        let newestItemDate = audioItems.max(by: { $0.createdAt < $1.createdAt })?.createdAt
        let averageFileSizeKB = totalItems > 0 ? audioItems.reduce(0) { $0 + $1.sizeKB } / Double(totalItems) : 0
        let expiredItemsCount = audioItems.filter { $0.isExpired }.count
        let availableStorageGB = getAvailableStorageGB()
        let cacheHitRate = cacheRequests > 0 ? Double(cacheHits) / Double(cacheRequests) : 0.0
        
        cacheStatistics = AudioCacheStatistics(
            totalItems: totalItems,
            totalSizeMB: totalSizeMB,
            oldestItemDate: oldestItemDate,
            newestItemDate: newestItemDate,
            averageFileSizeKB: averageFileSizeKB,
            expiredItemsCount: expiredItemsCount,
            availableStorageGB: availableStorageGB,
            cacheHitRate: cacheHitRate
        )
    }
    
    private func getAvailableStorageGB() -> Double {
        do {
            let systemAttributes = try fileManager.attributesOfFileSystem(forPath: cacheDirectory.path)
            if let freeSize = systemAttributes[.systemFreeSize] as? NSNumber {
                return freeSize.doubleValue / (1024 * 1024 * 1024) // Convert to GB
            }
        } catch {
            print("Error getting available storage: \(error)")
        }
        return 0.0
    }
    
    private func removeOrphanedFiles(contentCache: SimpleAudioCache) async throws {
        let cacheEntryPaths = Set(contentCache.cachedAudio.values.map { $0.filePath })
        let filesOnDisk = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        
        for fileURL in filesOnDisk {
            if !cacheEntryPaths.contains(fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    private func removeStaleReferences(contentCache: SimpleAudioCache) async throws -> SimpleAudioCache {
        var updatedCache = contentCache
        
        for (key, audioItem) in contentCache.cachedAudio {
            if !fileManager.fileExists(atPath: audioItem.filePath) {
                updatedCache.cachedAudio.removeValue(forKey: key)
            }
        }
        
        return updatedCache
    }
}

// MARK: - Audio Cache Errors
enum AudioCacheError: LocalizedError {
    case invalidData(String)
    case invalidKey(String)
    case fileWriteError(Error)
    case fileReadError(Error)
    case cacheLimitExceeded
    case diskSpaceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "Invalid audio data: \(message)"
        case .invalidKey(let message):
            return "Invalid cache key: \(message)"
        case .fileWriteError(let error):
            return "Failed to write audio file: \(error.localizedDescription)"
        case .fileReadError(let error):
            return "Failed to read audio file: \(error.localizedDescription)"
        case .cacheLimitExceeded:
            return "Cache size limit exceeded"
        case .diskSpaceUnavailable:
            return "Insufficient disk space available"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidData:
            return "Ensure the audio data is valid before caching."
        case .invalidKey:
            return "Provide a valid, non-empty cache key."
        case .fileWriteError, .fileReadError:
            return "Check file permissions and available disk space."
        case .cacheLimitExceeded:
            return "Clear old cache entries or increase cache limit."
        case .diskSpaceUnavailable:
            return "Free up disk space and try again."
        }
    }
}