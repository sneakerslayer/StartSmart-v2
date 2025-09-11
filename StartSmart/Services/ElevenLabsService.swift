import Foundation
import AVFoundation

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

// MARK: - ElevenLabs Service
protocol ElevenLabsServiceProtocol {
    func generateSpeech(text: String, voiceId: String) async throws -> Data
    func getAvailableVoices() async throws -> [Voice]
}

class ElevenLabsService: ElevenLabsServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.elevenlabs.io/v1"
    private let session = URLSession.shared
    
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
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generateSpeech(text: String, voiceId: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/text-to-speech/\(voiceId)") else {
            throw ElevenLabsError.invalidURL
        }
        
        let voiceSettings = Self.voiceConfigurations[voiceId]?.settings ?? 
                           Self.voiceConfigurations["default"]!.settings
        
        let request = ElevenLabsRequest(
            text: text,
            modelId: "eleven_monolingual_v1",
            voiceSettings: voiceSettings
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "xi-api-key")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("audio/mpeg", forHTTPHeaderField: "Accept")
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
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
}

// MARK: - Supporting Types
private struct VoicesResponse: Codable {
    let voices: [Voice]
}

// MARK: - ElevenLabs Errors
enum ElevenLabsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid ElevenLabs API URL"
        case .invalidResponse:
            return "Invalid response from ElevenLabs server"
        case .apiError(let statusCode, let message):
            return "ElevenLabs API Error \(statusCode): \(message)"
        case .decodingError(let error):
            return "Failed to decode ElevenLabs response: \(error.localizedDescription)"
        }
    }
}
