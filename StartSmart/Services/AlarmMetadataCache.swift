import Foundation
import os.log

/// Caches alarm metadata in UserDefaults for immediate access on app launch
/// This allows AlarmView to access alarm data even before full repository load completes
@MainActor
class AlarmMetadataCache {
    static let shared = AlarmMetadataCache()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "AlarmMetadataCache")
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "cached_alarm_metadata"
    private let maxCacheAge: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {
        logger.info("📦 AlarmMetadataCache initialized")
    }
    
    /// Store alarm metadata for quick access
    func storeAlarmMetadata(_ alarms: [Alarm]) {
        logger.info("💾 Storing metadata for \(alarms.count) alarms")
        
        let metadataArray = alarms.map { alarm -> [String: Any] in
            var metadata: [String: Any] = [
                "id": alarm.id.uuidString,
                "label": alarm.label,
                "time": alarm.time.timeIntervalSince1970,
                "isEnabled": alarm.isEnabled,
                "tone": alarm.tone.rawValue,
                "hasCustomAudio": alarm.hasCustomAudio
            ]
            
            // Store audio file path if available
            if let audioURL = alarm.audioFileURL {
                metadata["audioFilePath"] = audioURL.path
            }
            
            // Store generated content info if available
            if let generated = alarm.generatedContent {
                metadata["generatedContent"] = [
                    "audioFilePath": generated.audioFilePath,
                    "voiceId": generated.voiceId,
                    "intentId": generated.intentId ?? "",
                    "generatedAt": generated.generatedAt.timeIntervalSince1970,
                    "textContent": generated.textContent
                ]
            }
            
            return metadata
        }
        
        let cacheData: [String: Any] = [
            "alarms": metadataArray,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        userDefaults.set(cacheData, forKey: cacheKey)
        logger.info("✅ Alarm metadata cached successfully")
    }
    
    /// Get cached alarm metadata by alarm ID (for quick access)
    func getCachedAlarmMetadata(for alarmId: String) -> AlarmMetadata? {
        guard let cacheData = userDefaults.dictionary(forKey: cacheKey),
              let timestamp = cacheData["timestamp"] as? TimeInterval else {
            logger.info("ℹ️ No alarm metadata cache found")
            return nil
        }
        
        // Check if cache is expired
        let cacheAge = Date().timeIntervalSince1970 - timestamp
        if cacheAge > maxCacheAge {
            logger.warning("⚠️ Alarm metadata cache expired (\(Int(cacheAge))s old)")
            userDefaults.removeObject(forKey: cacheKey)
            return nil
        }
        
        guard let alarmsArray = cacheData["alarms"] as? [[String: Any]] else {
            logger.warning("⚠️ Invalid alarm metadata cache format")
            return nil
        }
        
        // Find matching alarm
        if let alarmData = alarmsArray.first(where: { ($0["id"] as? String) == alarmId }) {
            logger.info("✅ Found cached metadata for alarm: \(alarmId)")
            return AlarmMetadata(from: alarmData)
        }
        
        logger.info("ℹ️ No cached metadata found for alarm: \(alarmId)")
        return nil
    }
    
    /// Try to create Alarm from cached metadata (for immediate display)
    func createAlarmFromCache(for alarmId: String) -> Alarm? {
        guard let metadata = getCachedAlarmMetadata(for: alarmId) else {
            return nil
        }
        
        // Create a basic alarm from cache
        var alarm = Alarm(
            id: UUID(uuidString: alarmId) ?? UUID(),
            time: metadata.time,
            label: metadata.label,
            isEnabled: metadata.isEnabled,
            repeatDays: [],
            tone: metadata.tone
        )
        
        // Restore generated content if available
        if let generated = metadata.generatedContent {
            let generatedContent = AlarmGeneratedContent(
                textContent: "",
                audioFilePath: generated.audioFilePath,
                voiceId: generated.voiceId,
                generatedAt: generated.generatedAt,
                duration: nil,
                intentId: generated.intentId
            )
            alarm.setGeneratedContent(generatedContent)
        }
        
        return alarm
    }
    
    /// Clear cached alarm metadata
    func clearCache() {
        logger.info("🗑️ Clearing alarm metadata cache")
        userDefaults.removeObject(forKey: cacheKey)
    }
    
    /// Check if cache exists and is valid
    var hasValidCache: Bool {
        guard let cacheData = userDefaults.dictionary(forKey: cacheKey),
              let timestamp = cacheData["timestamp"] as? TimeInterval else {
            return false
        }
        
        let cacheAge = Date().timeIntervalSince1970 - timestamp
        return cacheAge <= maxCacheAge
    }
}

/// Lightweight alarm metadata structure for caching
struct AlarmMetadata {
    let id: String
    let label: String
    let time: Date
    let isEnabled: Bool
    let tone: AlarmTone
    let hasCustomAudio: Bool
    let audioFilePath: String?
    let generatedContent: GeneratedContentMetadata?
    
    struct GeneratedContentMetadata {
        let audioFilePath: String
        let voiceId: String
        let intentId: String?
        let generatedAt: Date
    }
    
    init?(from dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let label = dictionary["label"] as? String,
              let timeInterval = dictionary["time"] as? TimeInterval,
              let isEnabled = dictionary["isEnabled"] as? Bool,
              let toneRaw = dictionary["tone"] as? String,
              let tone = AlarmTone(rawValue: toneRaw),
              let hasCustomAudio = dictionary["hasCustomAudio"] as? Bool else {
            return nil
        }
        
        self.id = id
        self.label = label
        self.time = Date(timeIntervalSince1970: timeInterval)
        self.isEnabled = isEnabled
        self.tone = tone
        self.hasCustomAudio = hasCustomAudio
        self.audioFilePath = dictionary["audioFilePath"] as? String
        
        if let generatedDict = dictionary["generatedContent"] as? [String: Any],
           let audioPath = generatedDict["audioFilePath"] as? String,
           let voiceId = generatedDict["voiceId"] as? String,
           let generatedAtInterval = generatedDict["generatedAt"] as? TimeInterval {
            self.generatedContent = GeneratedContentMetadata(
                audioFilePath: audioPath,
                voiceId: voiceId,
                intentId: generatedDict["intentId"] as? String,
                generatedAt: Date(timeIntervalSince1970: generatedAtInterval)
            )
        } else {
            self.generatedContent = nil
        }
    }
}

