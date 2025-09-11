import Foundation

// MARK: - Grok4 API Models
struct Grok4Request: Codable {
    let prompt: String
    let maxTokens: Int
    let temperature: Double
    let model: String
    
    enum CodingKeys: String, CodingKey {
        case prompt
        case maxTokens = "max_tokens"
        case temperature
        case model
    }
}

struct Grok4Response: Codable {
    let id: String
    let object: String
    let created: Int
    let choices: [Grok4Choice]
    let usage: Grok4Usage
}

struct Grok4Choice: Codable {
    let index: Int
    let message: Grok4Message
    let finishReason: String
    
    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

struct Grok4Message: Codable {
    let role: String
    let content: String
}

struct Grok4Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Grok4 Service
protocol Grok4ServiceProtocol {
    func generateMotivationalScript(
        userIntent: String,
        tone: String,
        context: [String: String]
    ) async throws -> String
}

class Grok4Service: Grok4ServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.x.ai/v1"
    private let session = URLSession.shared
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generateMotivationalScript(
        userIntent: String,
        tone: String,
        context: [String: String]
    ) async throws -> String {
        let prompt = buildPrompt(userIntent: userIntent, tone: tone, context: context)
        
        let request = Grok4Request(
            prompt: prompt,
            maxTokens: 200,
            temperature: 0.7,
            model: "grok-beta"
        )
        
        let response = try await sendRequest(request)
        
        guard let choice = response.choices.first else {
            throw Grok4Error.noResponse
        }
        
        return choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func buildPrompt(userIntent: String, tone: String, context: [String: String]) -> String {
        let weather = context["weather"] ?? ""
        let timeOfDay = context["timeOfDay"] ?? "morning"
        let dayOfWeek = context["dayOfWeek"] ?? ""
        
        let toneGuidance = getToneGuidance(for: tone)
        
        return """
        Create a personalized 60-90 second motivational wake-up message for a Gen Z user.
        
        User's Goal: \(userIntent)
        Tone: \(tone) - \(toneGuidance)
        Time: \(timeOfDay), \(dayOfWeek)
        Weather: \(weather)
        
        Requirements:
        - Sound natural and authentic, not corporate or cheesy
        - Include their specific goal
        - Reference the weather if relevant
        - Keep it under 200 words
        - End with an actionable call to action
        - Use language that feels like a supportive friend
        
        Generate only the speech content, no extra text or formatting.
        """
    }
    
    private func getToneGuidance(for tone: String) -> String {
        switch tone.lowercased() {
        case "gentle":
            return "Warm, encouraging, soft-spoken, like a caring friend"
        case "energetic":
            return "Upbeat, enthusiastic, high-energy, motivating"
        case "tough love":
            return "Direct, firm but caring, no-nonsense, challenging"
        case "storyteller":
            return "Narrative style, using metaphors and imagery"
        default:
            return "Balanced, encouraging, and motivating"
        }
    }
    
    private func sendRequest(_ request: Grok4Request) async throws -> Grok4Response {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw Grok4Error.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert our request to the proper format for the API
        let apiRequest: [String: Any] = [
            "messages": [
                ["role": "user", "content": request.prompt]
            ],
            "model": request.model,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature
        ]
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: apiRequest)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Grok4Error.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Grok4Error.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        do {
            return try JSONDecoder().decode(Grok4Response.self, from: data)
        } catch {
            throw Grok4Error.decodingError(error)
        }
    }
}

// MARK: - Grok4 Errors
enum Grok4Error: LocalizedError {
    case invalidURL
    case invalidResponse
    case noResponse
    case apiError(statusCode: Int, message: String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .noResponse:
            return "No response received from Grok4 API"
        case .apiError(let statusCode, let message):
            return "API Error \(statusCode): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
