import Foundation

// MARK: - Local Storage Protocol
protocol LocalStorageProtocol {
    func save<T: Codable>(_ object: T, forKey key: String) throws
    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
    func delete(forKey key: String)
    func exists(forKey key: String) -> Bool
    func clear()
}

// MARK: - UserDefaults Storage Implementation
class UserDefaultsStorage: LocalStorageProtocol {
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        // Configure date encoding strategy
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func save<T: Codable>(_ object: T, forKey key: String) throws {
        let data = try encoder.encode(object)
        userDefaults.set(data, forKey: key)
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        return try decoder.decode(type, from: data)
    }
    
    func delete(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    func exists(forKey key: String) -> Bool {
        return userDefaults.object(forKey: key) != nil
    }
    
    func clear() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: bundleIdentifier)
        }
    }
}

// MARK: - Storage Keys
struct StorageKeys {
    static let currentUser = "current_user"
    static let alarms = "alarms"
    static let intents = "intents"
    static let userPreferences = "user_preferences"
    static let appSettings = "app_settings"
    static let onboardingCompleted = "onboarding_completed"
    static let lastAppVersion = "last_app_version"
    static let apiKeyValidation = "api_key_validation"
    static let contentCache = "content_cache"
}

// MARK: - Typed Storage Manager
class StorageManager: ObservableObject {
    private let storage: LocalStorageProtocol
    
    init(storage: LocalStorageProtocol = UserDefaultsStorage()) {
        self.storage = storage
    }
    
    // MARK: - User Management
    func saveCurrentUser(_ user: User) throws {
        try storage.save(user, forKey: StorageKeys.currentUser)
    }
    
    func loadCurrentUser() throws -> User? {
        return try storage.load(User.self, forKey: StorageKeys.currentUser)
    }
    
    func deleteCurrentUser() {
        storage.delete(forKey: StorageKeys.currentUser)
    }
    
    // MARK: - Alarm Management
    func saveAlarms(_ alarms: [Alarm]) throws {
        try storage.save(alarms, forKey: StorageKeys.alarms)
    }
    
    func loadAlarms() throws -> [Alarm] {
        return try storage.load([Alarm].self, forKey: StorageKeys.alarms) ?? []
    }
    
    func deleteAlarms() {
        storage.delete(forKey: StorageKeys.alarms)
    }
    
    // MARK: - Intent Management
    func saveIntents(_ intents: [Intent]) throws {
        try storage.save(intents, forKey: StorageKeys.intents)
    }
    
    func loadIntents() throws -> [Intent] {
        return try storage.load([Intent].self, forKey: StorageKeys.intents) ?? []
    }
    
    func deleteIntents() {
        storage.delete(forKey: StorageKeys.intents)
    }
    
    // MARK: - Preferences Management
    func saveUserPreferences(_ preferences: UserPreferences) throws {
        try storage.save(preferences, forKey: StorageKeys.userPreferences)
    }
    
    func loadUserPreferences() throws -> UserPreferences? {
        return try storage.load(UserPreferences.self, forKey: StorageKeys.userPreferences)
    }
    
    // MARK: - App Settings
    func saveAppSettings(_ settings: AppSettings) throws {
        try storage.save(settings, forKey: StorageKeys.appSettings)
    }
    
    func loadAppSettings() throws -> AppSettings {
        return try storage.load(AppSettings.self, forKey: StorageKeys.appSettings) ?? AppSettings()
    }
    
    // MARK: - Onboarding & App State
    func markOnboardingCompleted() {
        try? storage.save(true, forKey: StorageKeys.onboardingCompleted)
    }
    
    func isOnboardingCompleted() -> Bool {
        return (try? storage.load(Bool.self, forKey: StorageKeys.onboardingCompleted)) ?? false
    }
    
    func saveLastAppVersion(_ version: String) {
        try? storage.save(version, forKey: StorageKeys.lastAppVersion)
    }
    
    func getLastAppVersion() -> String? {
        return try? storage.load(String.self, forKey: StorageKeys.lastAppVersion)
    }
    
    // MARK: - Content Caching
    func saveContentCache(_ cache: ContentCache) throws {
        try storage.save(cache, forKey: StorageKeys.contentCache)
    }
    
    func loadContentCache() throws -> ContentCache {
        return try storage.load(ContentCache.self, forKey: StorageKeys.contentCache) ?? ContentCache()
    }
    
    // MARK: - Utility Methods
    func clearAllData() {
        storage.clear()
    }
    
    func exportUserData() throws -> Data {
        let userData = UserDataExport(
            user: try loadCurrentUser(),
            alarms: try loadAlarms(),
            intents: try loadIntents(),
            preferences: try loadUserPreferences(),
            settings: try loadAppSettings(),
            exportedAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(userData)
    }
    
    func importUserData(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let userData = try decoder.decode(UserDataExport.self, from: data)
        
        if let user = userData.user {
            try saveCurrentUser(user)
        }
        try saveAlarms(userData.alarms)
        try saveIntents(userData.intents)
        if let preferences = userData.preferences {
            try saveUserPreferences(preferences)
        }
        try saveAppSettings(userData.settings)
    }
}

// MARK: - App Settings
struct AppSettings: Codable {
    var debugMode: Bool
    var analyticsEnabled: Bool
    var crashReportingEnabled: Bool
    var apiKeyValidated: Bool
    var lastSyncDate: Date?
    var cacheExpirationHours: Int
    var maxCacheSizeMB: Int
    
    init(
        debugMode: Bool = false,
        analyticsEnabled: Bool = false,
        crashReportingEnabled: Bool = true,
        apiKeyValidated: Bool = false,
        lastSyncDate: Date? = nil,
        cacheExpirationHours: Int = 72,
        maxCacheSizeMB: Int = 100
    ) {
        self.debugMode = debugMode
        self.analyticsEnabled = analyticsEnabled
        self.crashReportingEnabled = crashReportingEnabled
        self.apiKeyValidated = apiKeyValidated
        self.lastSyncDate = lastSyncDate
        self.cacheExpirationHours = cacheExpirationHours
        self.maxCacheSizeMB = maxCacheSizeMB
    }
}

// MARK: - Content Cache
struct ContentCache: Codable {
    var cachedAudio: [String: CachedAudioItem]
    var cachedTexts: [String: CachedTextItem]
    var totalSizeMB: Double
    var lastCleanupDate: Date?
    
    init() {
        self.cachedAudio = [:]
        self.cachedTexts = [:]
        self.totalSizeMB = 0.0
        self.lastCleanupDate = nil
    }
    
    mutating func addAudioItem(_ item: CachedAudioItem, forKey key: String) {
        cachedAudio[key] = item
        recalculateSize()
    }
    
    mutating func addTextItem(_ item: CachedTextItem, forKey key: String) {
        cachedTexts[key] = item
    }
    
    mutating func cleanup(maxSizeMB: Int, expirationHours: Int) {
        let expirationDate = Date().addingTimeInterval(-TimeInterval(expirationHours * 3600))
        
        // Remove expired items
        cachedAudio = cachedAudio.filter { $0.value.createdAt > expirationDate }
        cachedTexts = cachedTexts.filter { $0.value.createdAt > expirationDate }
        
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

struct CachedAudioItem: Codable {
    let filePath: String
    let sizeKB: Double
    let duration: TimeInterval
    let createdAt: Date
    let intentId: String
    
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 72 * 3600 // 72 hours
    }
}

struct CachedTextItem: Codable {
    let content: String
    let hash: String
    let createdAt: Date
    let intentId: String
    
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 24 * 3600 // 24 hours
    }
}

// MARK: - Data Export Structure
struct UserDataExport: Codable {
    let user: User?
    let alarms: [Alarm]
    let intents: [Intent]
    let preferences: UserPreferences?
    let settings: AppSettings
    let exportedAt: Date
    let appVersion: String
    
    init(
        user: User?,
        alarms: [Alarm],
        intents: [Intent],
        preferences: UserPreferences?,
        settings: AppSettings,
        exportedAt: Date
    ) {
        self.user = user
        self.alarms = alarms
        self.intents = intents
        self.preferences = preferences
        self.settings = settings
        self.exportedAt = exportedAt
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
