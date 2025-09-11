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
    let bitrate: Int
    let format: AudioFormat
    
    static let standard = AudioQualitySettings(sampleRate: 22050, bitrate: 128, format: .mp3)
    static let high = AudioQualitySettings(sampleRate: 44100, bitrate: 256, format: .mp3)
    static let premium = AudioQualitySettings(sampleRate: 48000, bitrate: 320, format: .mp3)
}

enum AudioFormat: String, CaseIterable {
    case mp3 = "audio/mpeg"
    case wav = "audio/wav"
    case flac = "audio/flac"
}

// MARK: - TTS Generation Options
struct TTSGenerationOptions {
    let audioQuality: AudioQualitySettings
    let enableOptimizations: Bool
    let timeoutInterval: TimeInterval
    let maxRetries: Int
    
    static let `default` = TTSGenerationOptions(
        audioQuality: .standard,
        enableOptimizations: true,
        timeoutInterval: 30.0,
        maxRetries: 3
    )
    
    static let production = TTSGenerationOptions(
        audioQuality: .high,
        enableOptimizations: true,
        timeoutInterval: 45.0,
        maxRetries: 5
    )
}

// MARK: - ElevenLabs Service Protocol
protocol ElevenLabsServiceProtocol {
    func generateSpeech(text: String, voiceId: String) async throws -> Data
    func generateSpeech(text: String, voiceId: String, options: TTSGenerationOptions) async throws -> Data
    func getAvailableVoices() async throws -> [Voice]
    func validateAudioData(_ data: Data) throws -> AudioValidationResult
}

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
            voiceId: "pNInz6obpgDQGcFmaJgB", // Adam - Energetic, confident
            settings: VoiceSettings(stability: 0.5, similarityBoost: 0.8, style: 0.8, useSpeakerBoost: true)
        ),
        "tough_love": (
            voiceId: "VR6AewLTigWG4xSOukaG", // Arnold - Firm, motivational
            settings: VoiceSettings(stability: 0.8, similarityBoost: 0.9, style: 0.6, useSpeakerBoost: true)
        ),
        "storyteller": (
            voiceId: "CYw3kZ02Hs0563khs1Fj", // Dave - Narrative, engaging
            settings: VoiceSettings(stability: 0.7, similarityBoost: 0.7, style: 0.5, useSpeakerBoost: true)
        ),
        "default": (
            voiceId: "21m00Tcm4TlvDq8ikWAM",
            settings: VoiceSettings(stability: 0.7, similarityBoost: 0.75, style: 0.5, useSpeakerBoost: true)
        )
    ]
    
    init(apiKey: String, options: TTSGenerationOptions = .default) {
        self.apiKey = apiKey
        self.defaultOptions = options
        
        // Configure URLSession with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = options.timeoutInterval
        configuration.timeoutIntervalForResource = options.timeoutInterval * 2
        self.session = URLSession(configuration: configuration)
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
        
        return try await performWithRetry(maxRetries: options.maxRetries) {
            return try await self.generateSpeechRequest(text: text, voiceId: voiceId, options: options)
        }
    }
    
    private func generateSpeechRequest(text: String, voiceId: String, options: TTSGenerationOptions) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/text-to-speech/\(voiceId)") else {
            throw ElevenLabsError.invalidURL
        }
        
        let voiceSettings = Self.voiceConfigurations[voiceId]?.settings ?? 
                           Self.voiceConfigurations["default"]!.settings
        
        let request = ElevenLabsRequest(
            text: text,
            modelId: options.enableOptimizations ? "eleven_turbo_v2" : "eleven_monolingual_v1",
            voiceSettings: voiceSettings
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "xi-api-key")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(options.audioQuality.format.rawValue, forHTTPHeaderField: "Accept")
        
        // Add quality optimization headers
        if options.enableOptimizations {
            urlRequest.addValue("true", forHTTPHeaderField: "xi-optimize-streaming-latency")
        }
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Validate audio data
        let validationResult = try validateAudioData(data)
        if !validationResult.isValid {
            throw ElevenLabsError.invalidAudioData(validationResult.errorMessage ?? "Audio validation failed")
        }
        
        return data
    }
    
    func getAvailableVoices() async throws -> [Voice] {
        guard let url = URL(string: "\(baseURL)/voices") else {
            throw ElevenLabsError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.addValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        do {
            let voicesResponse = try JSONDecoder().decode(VoicesResponse.self, from: data)
            return voicesResponse.voices
        } catch {
            throw ElevenLabsError.decodingError(error)
        }
    }
    
    // Helper method to get voice ID for a tone
    func getVoiceId(for tone: String) -> String {
        let normalizedTone = tone.lowercased().replacingOccurrences(of: " ", with: "_")
        return Self.voiceConfigurations[normalizedTone]?.voiceId ?? 
               Self.voiceConfigurations["default"]!.voiceId
    }
    
    // MARK: - Audio Validation
    
    func validateAudioData(_ data: Data) throws -> AudioValidationResult {
        guard !data.isEmpty else {
            return AudioValidationResult(isValid: false, errorMessage: "Audio data is empty")
        }
        
        // Minimum size check (basic MP3 header is at least 32 bytes)
        guard data.count >= 32 else {
            return AudioValidationResult(isValid: false, errorMessage: "Audio data too small")
        }
        
        // Check for MP3 header signature
        let headerBytes = data.prefix(4)
        if headerBytes.count >= 3 {
            let header = Array(headerBytes)
            
            // MP3 frame header starts with 11111111 111xxxxx (0xFF 0xFB, 0xFF 0xFA, etc.)
            if header[0] == 0xFF && (header[1] & 0xE0) == 0xE0 {
                return AudioValidationResult(
                    isValid: true,
                    format: .mp3,
                    estimatedDuration: estimateMP3Duration(data),
                    fileSize: data.count
                )
            }
            
            // WAV header check ("RIFF" at start, "WAVE" at offset 8)
            if header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 {
                return AudioValidationResult(
                    isValid: true,
                    format: .wav,
                    estimatedDuration: estimateWAVDuration(data),
                    fileSize: data.count
                )
            }
        }
        
        // If we can't detect format but data seems reasonable, assume it's valid
        if data.count > 1000 {
            return AudioValidationResult(
                isValid: true,
                format: .mp3, // Default assumption
                estimatedDuration: nil,
                fileSize: data.count
            )
        }
        
        return AudioValidationResult(isValid: false, errorMessage: "Unrecognized audio format")
    }
    
    private func estimateMP3Duration(_ data: Data) -> TimeInterval? {
        // Basic estimation: assume 128kbps bitrate
        let estimatedBitrate: Double = 128 * 1000 / 8 // bytes per second
        return Double(data.count) / estimatedBitrate
    }
    
    private func estimateWAVDuration(_ data: Data) -> TimeInterval? {
        // WAV duration requires parsing the header for sample rate and data size
        // For now, return nil (would need full WAV parsing implementation)
        return nil
    }
    
    // MARK: - Retry Logic
    
    private func performWithRetry<T>(maxRetries: Int, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if case ElevenLabsError.invalidInput = error {
                    throw error
                }
                if case ElevenLabsError.invalidURL = error {
                    throw error
                }
                
                // Don't retry on final attempt
                if attempt == maxRetries {
                    break
                }
                
                // Exponential backoff
                let delay = pow(2.0, Double(attempt)) * 0.5
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? ElevenLabsError.unknownError
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
    let estimatedDuration: TimeInterval?
    let fileSize: Int
    let errorMessage: String?
    
    init(isValid: Bool, format: AudioFormat? = nil, estimatedDuration: TimeInterval? = nil, fileSize: Int = 0, errorMessage: String? = nil) {
        self.isValid = isValid
        self.format = format
        self.estimatedDuration = estimatedDuration
        self.fileSize = fileSize
        self.errorMessage = errorMessage
    }
}

// MARK: - ElevenLabs Errors
enum ElevenLabsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidInput(String)
    case invalidAudioData(String)
    case apiError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)
    case rateLimitExceeded
    case quotaExceeded
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid ElevenLabs API URL"
        case .invalidResponse:
            return "Invalid response from ElevenLabs server"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .invalidAudioData(let message):
            return "Invalid audio data: \(message)"
        case .apiError(let statusCode, let message):
            return "ElevenLabs API Error \(statusCode): \(message)"
        case .decodingError(let error):
            return "Failed to decode ElevenLabs response: \(error.localizedDescription)"
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
