import Foundation
import AVFoundation
import Combine

// MARK: - ElevenLabs API Models
struct ElevenLabsRequest: Codable {
    let text: String
    let modelId: String
    let voiceSettings: VoiceSettings
    
    enum CodingKeys: String, CodingKey {
        case text
        case modelId = "model_id"
        case voiceSettings = "voice_settings"
    }
}

struct VoiceSettings: Codable {
    let stability: Double
    let similarityBoost: Double
    let style: Double
    let useSpeakerBoost: Bool
    
    enum CodingKeys: String, CodingKey {
        case stability
        case similarityBoost = "similarity_boost"
        case style
        case useSpeakerBoost = "use_speaker_boost"
    }
}

struct Voice: Codable, Identifiable {
    let voiceId: String
    let name: String
    let category: String
    let description: String?
    
    var id: String { voiceId }
    
    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
        case name
        case category
        case description
    }
}

// MARK: - Audio Quality Settings
struct AudioQualitySettings {
    let sampleRate: Int
    let bitRate: Int
    let channels: Int
}

// MARK: - TTS Generation Options
struct TTSGenerationOptions {
    let maxRetries: Int
    let timeout: TimeInterval
    let quality: AudioQualitySettings
    
    static let `default` = TTSGenerationOptions(
        maxRetries: 3,
        timeout: 30.0,
        quality: AudioQualitySettings(sampleRate: 44100, bitRate: 128000, channels: 1)
    )
}

// MARK: - ElevenLabs Error Types
enum ElevenLabsError: Error, LocalizedError {
    case invalidInput(String)
    case invalidURL
    case invalidAudioData
    case apiError(statusCode: Int, message: String)
    case networkError(Error)
    case rateLimitExceeded
    case quotaExceeded
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .invalidURL:
            return "Invalid URL"
        case .invalidAudioData:
            return "Invalid audio data received"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .quotaExceeded:
            return "Monthly quota exceeded. Please upgrade your plan."
        case .unknownError:
            return "An unknown error occurred"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidInput:
            return "Please check your input text and try again."
        case .invalidAudioData:
            return "The generated audio data is corrupted. Please try again."
        case .apiError(let statusCode, _):
            switch statusCode {
            case 401:
                return "Please check your API key."
            case 429:
                return "You've exceeded the rate limit. Please wait before trying again."
            case 500...599:
                return "ElevenLabs is experiencing issues. Please try again later."
            default:
                return "Please try again or contact support if the issue persists."
            }
        case .rateLimitExceeded:
            return "Wait for a few minutes before making more requests."
        case .quotaExceeded:
            return "Upgrade your ElevenLabs plan to continue using the service."
        case .networkError:
            return "Check your internet connection and try again."
        default:
            return nil
        }
    }
}

// MARK: - ElevenLabs Service Protocol
protocol ElevenLabsServiceProtocol {
    func generateSpeech(text: String, voiceId: String) async throws -> Data
    func generateSpeech(text: String, voiceId: String, options: TTSGenerationOptions) async throws -> Data
    func generateVoicePreview(text: String, voiceName: String) async throws -> Data
    func getAvailableVoices() async throws -> [Voice]
    func testAPIConnection() async throws -> Bool
}

// MARK: - ElevenLabs Service Implementation
class ElevenLabsService: ElevenLabsServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.elevenlabs.io/v1"
    private let session: URLSession
    private let defaultOptions: TTSGenerationOptions
    
    // Default voice configurations for different tones
    static let voiceConfigurations: [String: (voiceId: String, settings: VoiceSettings)] = [
        "gentle": (
            voiceId: "21m00Tcm4TlvDq8ikWAM", // Rachel - Calm, pleasant
            settings: VoiceSettings(stability: 0.75, similarityBoost: 0.75, style: 0.4, useSpeakerBoost: true)
        ),
        "energetic": (
            voiceId: "AZnzlk1XvdvUeBnXmlld", // Domi - Energetic, upbeat
            settings: VoiceSettings(stability: 0.5, similarityBoost: 0.8, style: 0.8, useSpeakerBoost: true)
        ),
        "tough_love": (
            voiceId: "EXAVITQu4vr4xnSDxMaL", // Bella - Strong, motivational
            settings: VoiceSettings(stability: 0.6, similarityBoost: 0.7, style: 0.6, useSpeakerBoost: true)
        ),
        // New voice personas for previews
        "drill_sergeant_drew": (
            voiceId: "DGzg6RaUqxGRTHSBjfgF", // Drill Sergeant Drew - Strong, commanding
            settings: VoiceSettings(stability: 0.4, similarityBoost: 0.9, style: 0.9, useSpeakerBoost: true)
        ),
        "girl_bestie": (
            voiceId: "uYXf8XasLslADfZ2MB4u", // Girl Bestie - Warm, friendly
            settings: VoiceSettings(stability: 0.8, similarityBoost: 0.8, style: 0.3, useSpeakerBoost: true)
        ),
        "mrs_walker": (
            voiceId: "DLsHlh26Ugcm6ELvS0qi", // Mrs. Walker - Warm & caring Southern mom
            settings: VoiceSettings(stability: 0.9, similarityBoost: 0.7, style: 0.2, useSpeakerBoost: true)
        ),
        "motivational_mike": (
            voiceId: "84Fal4DSXWfp7nJ8emqQ", // Motivational Mike - High-energy
            settings: VoiceSettings(stability: 0.3, similarityBoost: 0.9, style: 0.9, useSpeakerBoost: true)
        ),
        "calm_kyle": (
            voiceId: "MpZY6e8MW2zHVi4Vtxrn", // Calm Kyle - Peaceful, zen
            settings: VoiceSettings(stability: 0.95, similarityBoost: 0.6, style: 0.1, useSpeakerBoost: true)
        ),
        "angry_allen": (
            voiceId: "KLZOWyG48RjZkAAjuM89", // Angry Allen - Intense, no-nonsense
            settings: VoiceSettings(stability: 0.3, similarityBoost: 0.95, style: 0.95, useSpeakerBoost: true)
        )
    ]
    
    init(apiKey: String) {
        self.apiKey = apiKey
        self.defaultOptions = TTSGenerationOptions.default
        print("DEBUG: ElevenLabsService init - API key length: \(apiKey.count)")
        print("DEBUG: ElevenLabsService init - API key starts with: \(String(apiKey.prefix(10)))")
        
        // Configure URLSession with appropriate timeout and retry policy
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0  // Reduced timeout
        config.timeoutIntervalForResource = 30.0  // Reduced timeout
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        self.session = URLSession(configuration: config)
    }
    
    convenience init() {
        let apiKey = ServiceConfiguration.APIKeys.elevenLabs
        print("DEBUG: ElevenLabsService convenience init - API key length: \(apiKey.count)")
        print("DEBUG: ElevenLabsService convenience init - API key starts with: \(String(apiKey.prefix(10)))")
        self.init(apiKey: apiKey)
    }
    
    func generateSpeech(text: String, voiceId: String) async throws -> Data {
        return try await generateSpeech(text: text, voiceId: voiceId, options: defaultOptions)
    }
    
    func generateSpeech(text: String, voiceId: String, options: TTSGenerationOptions) async throws -> Data {
        // Input validation
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ElevenLabsError.invalidInput("Text cannot be empty")
        }
        
        guard text.count <= 5000 else {
            throw ElevenLabsError.invalidInput("Text exceeds maximum length of 5000 characters")
        }
        
        return try await generateSpeechRequest(text: text, voiceId: voiceId, options: options)
    }
    
    private func generateSpeechRequest(text: String, voiceId: String, options: TTSGenerationOptions) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/text-to-speech/\(voiceId)") else {
            throw ElevenLabsError.invalidURL
        }
        
        // Check network connectivity first
        guard await isNetworkAvailable() else {
            throw ElevenLabsError.networkError(URLError(.notConnectedToInternet))
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        // Get voice settings for the given voice ID
        let voiceSettings = getVoiceSettings(for: voiceId)
        
        let request = ElevenLabsRequest(
            text: text,
            modelId: "eleven_multilingual_v2",
            voiceSettings: voiceSettings
        )
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw ElevenLabsError.invalidInput("Failed to encode request: \(error.localizedDescription)")
        }
        
        do {
            print("DEBUG: ElevenLabs API Request - URL: \(url)")
            print("DEBUG: ElevenLabs API Request - Voice ID: \(voiceId)")
            print("DEBUG: ElevenLabs API Request - Text length: \(text.count)")
            
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("DEBUG: ElevenLabs API Error - Invalid response type")
                throw ElevenLabsError.networkError(URLError(.badServerResponse))
            }
            
            print("DEBUG: ElevenLabs API Response - Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("DEBUG: ElevenLabs API Error Response: \(errorMessage)")
                
                switch httpResponse.statusCode {
                case 400:
                    if errorMessage.contains("max_character_limit_exceeded") {
                        throw ElevenLabsError.invalidInput("Text exceeds character limit. Please shorten your message.")
                    } else if errorMessage.contains("voice_not_found") {
                        throw ElevenLabsError.invalidInput("Voice not found. Please select a valid voice.")
                    } else {
                        throw ElevenLabsError.invalidInput("Invalid request: \(errorMessage)")
                    }
                case 401:
                    if errorMessage.contains("invalid_api_key") {
                        throw ElevenLabsError.apiError(statusCode: 401, message: "Invalid API key. Please check your configuration.")
                    } else {
                        throw ElevenLabsError.apiError(statusCode: 401, message: "Authentication failed: \(errorMessage)")
                    }
                case 403:
                    if errorMessage.contains("only_for_creator+") {
                        throw ElevenLabsError.apiError(statusCode: 403, message: "Professional voices require Creator+ subscription.")
                    } else {
                        throw ElevenLabsError.apiError(statusCode: 403, message: "Access forbidden: \(errorMessage)")
                    }
                case 429:
                    if errorMessage.contains("too_many_concurrent_requests") {
                        throw ElevenLabsError.rateLimitExceeded
                    } else if errorMessage.contains("system_busy") {
                        throw ElevenLabsError.apiError(statusCode: 429, message: "System busy. Please try again later.")
                    } else {
                        throw ElevenLabsError.rateLimitExceeded
                    }
                case 500...599:
                    throw ElevenLabsError.apiError(statusCode: httpResponse.statusCode, message: "Server error. Please try again later.")
                default:
                    throw ElevenLabsError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
                }
            }
            
            // Validate audio data
            let validationResult = validateAudioData(data)
            if !validationResult.isValid {
                throw ElevenLabsError.invalidAudioData
            }
            
            print("DEBUG: Audio validation passed - Format: \(validationResult.format?.rawValue ?? "unknown"), Size: \(data.count) bytes")
            print("DEBUG: ElevenLabs API Success - Generated \(data.count) bytes of audio data")
            return data
            
        } catch let error as ElevenLabsError {
            throw error
        } catch {
            throw ElevenLabsError.networkError(error)
        }
    }
    
    func getAvailableVoices() async throws -> [Voice] {
        return try await getAvailableVoicesRequest()
    }
    
    private func getAvailableVoicesRequest() async throws -> [Voice] {
        guard let url = URL(string: "\(baseURL)/voices") else {
            throw ElevenLabsError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ElevenLabsError.networkError(URLError(.badServerResponse))
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw ElevenLabsError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            let voicesResponse = try JSONDecoder().decode(VoicesResponse.self, from: data)
            return voicesResponse.voices
            
        } catch let error as ElevenLabsError {
            throw error
        } catch {
            throw ElevenLabsError.networkError(error)
        }
    }
    
    func testAPIConnection() async throws -> Bool {
        do {
            let _ = try await getAvailableVoices()
            return true
        } catch {
            print("DEBUG: ElevenLabs API test failed: \(error)")
            return false
        }
    }
    
    private func getVoiceSettings(for voiceId: String) -> VoiceSettings {
        // Find matching voice configuration
        for (_, config) in Self.voiceConfigurations {
            if config.voiceId == voiceId {
                return config.settings
            }
        }
        
        // Default settings if voice not found
        return VoiceSettings(
            stability: 0.5,
            similarityBoost: 0.75,
            style: 0.0,
            useSpeakerBoost: true
        )
    }
    
    private func validateAudioData(_ data: Data) -> AudioValidationResult {
        guard data.count > 0 else {
            return AudioValidationResult(isValid: false, format: nil, error: "Empty audio data")
        }
        
        // Check for common audio format headers
        if data.starts(with: [0xFF, 0xFB]) || data.starts(with: [0xFF, 0xF3]) || data.starts(with: [0xFF, 0xF2]) {
            return AudioValidationResult(isValid: true, format: .mp3, error: nil)
        }
        
        if data.starts(with: [0x52, 0x49, 0x46, 0x46]) && data.count > 8 && data.subdata(in: 8..<12) == Data([0x57, 0x41, 0x56, 0x45]) {
            return AudioValidationResult(isValid: true, format: .wav, error: nil)
        }
        
        if data.starts(with: [0x4F, 0x67, 0x67, 0x53]) {
            return AudioValidationResult(isValid: true, format: .ogg, error: nil)
        }
        
        // If we can't identify the format but data exists, assume it's valid
        return AudioValidationResult(isValid: true, format: .unknown, error: nil)
    }
    
    // MARK: - Network Connectivity Helper
    
    private func isNetworkAvailable() async -> Bool {
        // Simple connectivity check - try to reach a reliable endpoint
        guard let url = URL(string: "https://www.google.com") else { return false }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5.0
            
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("DEBUG: Network connectivity check failed: \(error)")
            return false
        }
    }
    
    // MARK: - Voice Name Mapping Helper
    
    static func getVoiceKey(from voiceName: String) -> String {
        switch voiceName.lowercased() {
        case "drill sergeant drew":
            return "drill_sergeant_drew"
        case "girl bestie":
            return "girl_bestie"
        case "mrs. walker":
            return "mrs_walker"
        case "motivational mike":
            return "motivational_mike"
        case "calm kyle":
            return "calm_kyle"
        case "angry allen":
            return "angry_allen"
        default:
            return "gentle" // Default fallback
        }
    }
    
    func generateVoicePreview(text: String, voiceName: String) async throws -> Data {
        let voiceKey = Self.getVoiceKey(from: voiceName)
        guard let config = Self.voiceConfigurations[voiceKey] else {
            throw ElevenLabsError.invalidInput("Voice configuration not found for: \(voiceName)")
        }
        
        print("DEBUG: Generating voice preview for: \(voiceName) (key: \(voiceKey), voiceId: \(config.voiceId))")
        return try await generateSpeech(text: text, voiceId: config.voiceId)
    }
}

// MARK: - Supporting Types
private struct VoicesResponse: Codable {
    let voices: [Voice]
}

// MARK: - Audio Validation Result
struct AudioValidationResult {
    let isValid: Bool
    let format: AudioFormat?
    let error: String?
    
    init(isValid: Bool, format: AudioFormat?, error: String?) {
        self.isValid = isValid
        self.format = format
        self.error = error
    }
}

enum AudioFormat: String {
    case mp3 = "mp3"
    case wav = "wav"
    case ogg = "ogg"
    case unknown = "unknown"
}