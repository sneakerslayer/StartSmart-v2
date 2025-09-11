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

// MARK: - Grok4 Service Protocol
protocol Grok4ServiceProtocol {
    func generateMotivationalScript(
        userIntent: String,
        tone: String,
        context: [String: String]
    ) async throws -> String
    
    func generateContentForIntent(_ intent: Intent) async throws -> String
    func validateContent(_ content: String) throws -> ContentValidationResult
}

class Grok4Service: Grok4ServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.x.ai/v1"
    private let session = URLSession.shared
    private let maxRetries: Int
    private let timeoutInterval: TimeInterval
    
    init(apiKey: String, maxRetries: Int = 3, timeoutInterval: TimeInterval = 30.0) {
        self.apiKey = apiKey
        self.maxRetries = maxRetries
        self.timeoutInterval = timeoutInterval
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
    
    // MARK: - Enhanced Content Generation for Intent Model
    func generateContentForIntent(_ intent: Intent) async throws -> String {
        var retryCount = 0
        var lastError: Error?
        
        while retryCount < maxRetries {
            do {
                let prompt = buildAdvancedPrompt(for: intent)
                
                let request = Grok4Request(
                    prompt: prompt,
                    maxTokens: calculateTokensForTone(intent.tone),
                    temperature: getTemperatureForTone(intent.tone),
                    model: "grok-beta"
                )
                
                let response = try await sendRequestWithTimeout(request)
                
                guard let choice = response.choices.first else {
                    throw Grok4Error.noResponse
                }
                
                let content = choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Validate content before returning
                let validationResult = try validateContent(content)
                if validationResult.isValid {
                    return content
                } else {
                    throw Grok4Error.contentValidationFailed(validationResult.issues)
                }
                
            } catch {
                lastError = error
                retryCount += 1
                
                if retryCount < maxRetries {
                    // Exponential backoff
                    let delay = min(pow(2.0, Double(retryCount)), 10.0)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw Grok4Error.maxRetriesExceeded(lastError)
    }
    
    func validateContent(_ content: String) throws -> ContentValidationResult {
        var issues: [String] = []
        
        // Check length constraints
        let wordCount = content.split(separator: " ").count
        if wordCount < 30 {
            issues.append("Content too short (minimum 30 words)")
        }
        if wordCount > 250 {
            issues.append("Content too long (maximum 250 words)")
        }
        
        // Check for inappropriate content
        let inappropriateTerms = ["fuck", "shit", "damn", "hell", "crap"]
        let lowercaseContent = content.lowercased()
        for term in inappropriateTerms {
            if lowercaseContent.contains(term) {
                issues.append("Contains inappropriate language")
                break
            }
        }
        
        // Check for motivational language presence
        let motivationalKeywords = ["you", "today", "can", "will", "let's", "ready", "time", "achieve", "goal"]
        let hasMotivationalContent = motivationalKeywords.contains { lowercaseContent.contains($0) }
        if !hasMotivationalContent {
            issues.append("Lacks motivational language")
        }
        
        // Check for proper structure (should end with action or encouragement)
        let lastSentence = content.split(separator: ".").last?.trimmingCharacters(in: .whitespaces) ?? ""
        if lastSentence.isEmpty {
            issues.append("Missing proper conclusion")
        }
        
        return ContentValidationResult(
            isValid: issues.isEmpty,
            wordCount: wordCount,
            characterCount: content.count,
            issues: issues
        )
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
    
    // MARK: - Advanced Prompt Building
    private func buildAdvancedPrompt(for intent: Intent) -> String {
        let context = intent.contextForAI
        let toneGuidance = getToneGuidance(for: intent.tone.rawValue)
        let timeContext = buildTimeContext(from: intent)
        
        return """
        Create a personalized 60-90 second motivational wake-up message for a Gen Z user.
        
        User's Goal: \(intent.userGoal)
        Tone: \(intent.tone.displayName) - \(toneGuidance)
        \(timeContext)
        Weather: \(context["weather"] ?? "unknown")
        Location: \(context["location"] ?? "unknown")
        \(buildCalendarContext(from: intent))
        \(buildCustomNoteContext(from: intent))
        
        Requirements:
        - Sound natural and authentic, not corporate or cheesy
        - Include their specific goal meaningfully, not just as a tag-on
        - Reference the weather or time context if relevant
        - Keep it 50-200 words (optimal for 60-90 seconds)
        - End with a specific, actionable call to action
        - Use language that feels like a supportive friend or coach
        - Match the specified tone throughout the entire message
        - Be motivational but realistic - acknowledge potential challenges
        
        Generate only the speech content, no extra text, quotes, or formatting.
        """
    }
    
    private func buildTimeContext(from intent: Intent) -> String {
        let timeOfDay = intent.context.timeOfDay.displayName
        let dayOfWeek = intent.context.dayOfWeek
        let scheduledTime = DateFormatter.localizedString(from: intent.scheduledFor, dateStyle: .none, timeStyle: .short)
        
        return "Time: \(timeOfDay), \(dayOfWeek) at \(scheduledTime)"
    }
    
    private func buildCalendarContext(from intent: Intent) -> String {
        if !intent.context.calendarEvents.isEmpty {
            let events = intent.context.calendarEvents.prefix(3).joined(separator: ", ")
            return "Today's events: \(events)"
        }
        return ""
    }
    
    private func buildCustomNoteContext(from intent: Intent) -> String {
        if let note = intent.context.customNote, !note.isEmpty {
            return "Personal note: \(note)"
        }
        return ""
    }
    
    private func calculateTokensForTone(_ tone: AlarmTone) -> Int {
        switch tone {
        case .storyteller:
            return 250  // Storytellers need more words
        case .toughLove:
            return 150  // Tough love is more direct
        case .gentle, .energetic:
            return 200  // Standard motivational length
        }
    }
    
    private func getTemperatureForTone(_ tone: AlarmTone) -> Double {
        switch tone {
        case .storyteller:
            return 0.8  // More creative for stories
        case .toughLove:
            return 0.5  // More focused and direct
        case .gentle:
            return 0.6  // Slightly more conservative
        case .energetic:
            return 0.7  // Balanced creativity
        }
    }
    
    private func getToneGuidance(for tone: String) -> String {
        switch tone.lowercased() {
        case "gentle":
            return "Warm, encouraging, soft-spoken, like a caring friend"
        case "energetic":
            return "Upbeat, enthusiastic, high-energy, motivating"
        case "tough_love":
            return "Direct, firm but caring, no-nonsense, challenging"
        case "storyteller":
            return "Narrative style, using metaphors and imagery"
        default:
            return "Balanced, encouraging, and motivating"
        }
    }
    
    private func sendRequestWithTimeout(_ request: Grok4Request) async throws -> Grok4Response {
        return try await withThrowingTaskGroup(of: Grok4Response.self) { group in
            group.addTask {
                return try await self.sendRequest(request)
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.timeoutInterval * 1_000_000_000))
                throw Grok4Error.timeout
            }
            
            guard let result = try await group.next() else {
                throw Grok4Error.timeout
            }
            
            group.cancelAll()
            return result
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

// MARK: - Content Validation Result
struct ContentValidationResult {
    let isValid: Bool
    let wordCount: Int
    let characterCount: Int
    let issues: [String]
}

// MARK: - Grok4 Errors
enum Grok4Error: LocalizedError {
    case invalidURL
    case invalidResponse
    case noResponse
    case apiError(statusCode: Int, message: String)
    case decodingError(Error)
    case timeout
    case maxRetriesExceeded(Error?)
    case contentValidationFailed([String])
    
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
        case .timeout:
            return "Request timed out"
        case .maxRetriesExceeded(let underlyingError):
            if let error = underlyingError {
                return "Max retries exceeded. Last error: \(error.localizedDescription)"
            } else {
                return "Max retries exceeded"
            }
        case .contentValidationFailed(let issues):
            return "Content validation failed: \(issues.joined(separator: ", "))"
        }
    }
}
