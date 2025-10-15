import Foundation

// MARK: - Service Configuration
struct ServiceConfiguration {
    
    // MARK: - API Keys (These should be loaded from secure storage or environment)
    struct APIKeys {
        static let grok4: String = {
            // In production, load from Keychain or secure configuration
            if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
               let config = NSDictionary(contentsOfFile: path),
               let key = config["GROK4_API_KEY"] as? String {
                return key
            }
            
            // Fallback to environment variable for development
            return ProcessInfo.processInfo.environment["GROK4_API_KEY"] ?? ""
        }()
        
        static let elevenLabs: String = {
            if let path = Bundle.main.path(forResource: "Config", ofType: "plist") {
                if let config = NSDictionary(contentsOfFile: path) {
                    if let key = config["ELEVENLABS_API_KEY"] as? String {
                        return key
                    } else {
                    }
                } else {
                }
            } else {
            }
            
            let envKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] ?? ""
            return envKey
        }()
        
        static let revenueCat: String = {
            if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
               let config = NSDictionary(contentsOfFile: path),
               let key = config["REVENUECAT_API_KEY"] as? String {
                return key
            }
            
            return ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] ?? "appl_placeholder_key"
        }()
    }
    
    // MARK: - Service URLs
    struct URLs {
        static let grok4Base = "https://api.x.ai/v1"
        static let elevenLabsBase = "https://api.elevenlabs.io/v1"
    }
    
    // MARK: - Content Generation Settings
    struct ContentSettings {
        static let maxTokens = 200
        static let temperature: Double = 0.7
        static let maxRetries = 3
        static let timeoutInterval: TimeInterval = 30.0
    }
    
    // MARK: - Audio Settings
    struct AudioSettings {
        static let defaultQuality = "high"
        static let cacheExpirationHours = 72
        static let maxCacheSizeMB = 100
    }
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        static let enableOfflineMode = true
        static let enableAnalytics = false // Privacy-first approach
        static let enableVoicePreview = true
        static let enableContentCaching = true
    }
    
    // MARK: - Validation
    static func validateConfiguration() -> [String] {
        var issues: [String] = []
        
        if APIKeys.grok4.isEmpty {
            issues.append("Grok4 API key is not configured")
        }
        
        if APIKeys.elevenLabs.isEmpty {
            issues.append("ElevenLabs API key is not configured")
        }
        
        if APIKeys.revenueCat.isEmpty || APIKeys.revenueCat == "appl_placeholder_key" {
            issues.append("RevenueCat API key is not configured")
        }
        
        return issues
    }
    
    // MARK: - Debug Information
    static func debugInfo() -> [String: Any] {
        return [
            "grok4_configured": !APIKeys.grok4.isEmpty,
            "elevenlabs_configured": !APIKeys.elevenLabs.isEmpty,
            "revenuecat_configured": !APIKeys.revenueCat.isEmpty && APIKeys.revenueCat != "appl_placeholder_key",
            "offline_mode": FeatureFlags.enableOfflineMode,
            "content_caching": FeatureFlags.enableContentCaching,
            "max_tokens": ContentSettings.maxTokens,
            "temperature": ContentSettings.temperature,
            "grok4_key_length": APIKeys.grok4.count,
            "elevenlabs_key_length": APIKeys.elevenLabs.count
        ]
    }
}
