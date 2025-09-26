//
//  OnboardingDemoService.swift
//  StartSmart
//
//  Demo Content Generation Service for Onboarding
//  Fast AI integration with Grok4 and fallback content
//

import Foundation
import Combine

// MARK: - OnboardingDemoService Implementation

// MARK: - Demo Generation Error

enum DemoGenerationError: LocalizedError {
    case motivationRequired
    case voicePersonaRequired
    case generationTimeout
    case apiRateLimitExceeded
    case contentValidationFailed(String)
    case networkUnavailable
    case fallbackUnavailable
    
    var errorDescription: String? {
        switch self {
        case .motivationRequired:
            return "Please select what drives you to continue"
        case .voicePersonaRequired:
            return "Please choose a voice persona to continue"
        case .generationTimeout:
            return "Demo generation took too long. Using a sample instead."
        case .apiRateLimitExceeded:
            return "Too many requests. Please try again in a moment."
        case .contentValidationFailed(let reason):
            return "Content validation failed: \(reason)"
        case .networkUnavailable:
            return "Network unavailable. Using offline demo content."
        case .fallbackUnavailable:
            return "Unable to generate demo content at this time"
        }
    }
}

// MARK: - OnboardingDemoService Implementation

@MainActor
class OnboardingDemoService: OnboardingDemoServiceProtocol {
    
    // MARK: - Dependencies
    private let grok4Service: Grok4ServiceProtocol
    private let elevenLabsService: ElevenLabsServiceProtocol
    
    // MARK: - Configuration
    private let timeoutDuration: TimeInterval = 8.0 // Generous timeout for onboarding
    private let maxRetries = 2
    
    // MARK: - Fallback Content Cache
    private lazy var fallbackContentCache: [String: GeneratedContent] = {
        createFallbackContentCache()
    }()
    
    // MARK: - Initialization
    init(
        grok4Service: Grok4ServiceProtocol? = nil,
        elevenLabsService: ElevenLabsServiceProtocol? = nil
    ) {
        self.grok4Service = grok4Service ?? DependencyContainer.shared.resolve()
        self.elevenLabsService = elevenLabsService ?? DependencyContainer.shared.resolve()
    }
    
    // MARK: - Demo Content Generation
    
    func generateDemoContent(
        motivation: MotivationCategory,
        tone: AlarmTone,
        voicePersona: VoicePersona
    ) async throws -> GeneratedContent {
        
        print("🎯 Starting demo generation for: \(motivation.displayName), tone: \(tone.displayName)")
        
        // Start timeout timer
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeoutDuration * 1_000_000_000))
            throw DemoGenerationError.generationTimeout
        }
        
        do {
            // Create optimized demo intent
            let demoIntent = createDemoIntent(motivation: motivation, tone: tone)
            
            // Generate content with timeout protection
            let generationTask = Task {
                return try await generateContentWithRetry(
                    intent: demoIntent,
                    voicePersona: voicePersona,
                    retryCount: maxRetries
                )
            }
            
            // Race between generation and timeout
            let result = try await withThrowingTaskGroup(of: GeneratedContent.self) { group in
                group.addTask { try await generationTask.value }
                group.addTask {
                    try await timeoutTask.value
                    throw DemoGenerationError.generationTimeout
                }
                
                // Return the first result (hopefully the generation, not the timeout)
                guard let result = try await group.next() else {
                    throw DemoGenerationError.generationTimeout
                }
                
                // Cancel the other task
                group.cancelAll()
                return result
            }
            
            print("✅ Demo generation completed successfully")
            return result
            
        } catch DemoGenerationError.generationTimeout {
            print("⏰ Demo generation timed out, using fallback")
            return getFallbackContent(motivation: motivation, tone: tone)
        } catch {
            print("❌ Demo generation failed: \(error.localizedDescription)")
            
            // Try fallback content
            let fallbackContent = getFallbackContent(motivation: motivation, tone: tone)
            
            // If fallback also fails, throw the original error
            guard fallbackContent.textContent.count > 0 else {
                throw error
            }
            
            return fallbackContent
        }
    }
    
    // MARK: - Content Generation with Retry
    
    private func generateContentWithRetry(
        intent: Intent,
        voicePersona: VoicePersona,
        retryCount: Int
    ) async throws -> GeneratedContent {
        
        var lastError: Error?
        
        for attempt in 0...retryCount {
            do {
                print("🔄 Generation attempt \(attempt + 1)/\(retryCount + 1)")
                
                // Generate text content
                let startTime = Date()
                let textContent = try await grok4Service.generateContentForIntent(intent)
                let generationTime = Date().timeIntervalSince(startTime)
                
                print("📝 Generated text in \(String(format: "%.2f", generationTime))s: \(textContent.prefix(50))...")
                
                // Validate content
                try validateDemoContent(textContent)
                
                // Create metadata
                let metadata = ContentMetadata(
                    textContent: textContent,
                    tone: intent.tone,
                    aiModel: "grok4",
                    ttsModel: "elevenlabs",
                    generationTime: generationTime
                )
                
                // For demo purposes, we'll skip actual TTS generation to keep it fast
                // In production, you might want to generate actual audio
                let generatedContent = GeneratedContent(
                    textContent: textContent,
                    audioURL: nil, // Skip TTS for speed
                    audioData: nil,
                    voiceId: voicePersona.voiceId,
                    metadata: metadata
                )
                
                return generatedContent
                
            } catch {
                lastError = error
                print("❌ Generation attempt \(attempt + 1) failed: \(error.localizedDescription)")
                
                // Wait before retry (exponential backoff)
                if attempt < retryCount {
                    let delay = TimeInterval(pow(2.0, Double(attempt))) * 0.5 // 0.5s, 1s, 2s
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed
        throw lastError ?? DemoGenerationError.contentValidationFailed("All retry attempts failed")
    }
    
    // MARK: - Demo Intent Creation
    
    private func createDemoIntent(motivation: MotivationCategory, tone: AlarmTone) -> Intent {
        // Create a focused, short intent for demo generation
        let goal = createDemoGoal(for: motivation)
        let scheduledFor = Date().addingTimeInterval(3600) // 1 hour from now
        
        var context = IntentContext()
        context.enrichWithCurrentData()
        
        // Add demo-specific context for better generation
        context.customNote = "This is a demo for onboarding. Keep it short, impactful, and inspiring."
        
        return Intent(
            userGoal: goal,
            tone: tone,
            context: context,
            scheduledFor: scheduledFor
        )
    }
    
    private func createDemoGoal(for motivation: MotivationCategory) -> String {
        switch motivation {
        case .fitness:
            return "Have an amazing workout and feel strong and energized"
        case .career:
            return "Excel in my work today and make meaningful progress on my career goals"
        case .studies:
            return "Stay focused on my studies and absorb new knowledge effectively"
        case .mindfulness:
            return "Approach the day with calm awareness and inner peace"
        case .personalProject:
            return "Make significant progress on my personal project with creativity and focus"
        case .other:
            return "Pursue my goals with passion and determination"
        }
    }
    
    // MARK: - Content Validation
    
    private func validateDemoContent(_ content: String) throws {
        // Length validation (should be concise for demo)
        guard content.count >= 50 else {
            throw DemoGenerationError.contentValidationFailed("Content too short")
        }
        
        guard content.count <= 500 else {
            throw DemoGenerationError.contentValidationFailed("Content too long for demo")
        }
        
        // Basic appropriateness check
        let inappropriate = ["hate", "violence", "inappropriate", "offensive"]
        let lowercaseContent = content.lowercased()
        
        for word in inappropriate {
            if lowercaseContent.contains(word) {
                throw DemoGenerationError.contentValidationFailed("Inappropriate content detected")
            }
        }
        
        // Ensure it's motivational (basic check)
        let motivationalWords = ["achieve", "success", "goal", "dream", "inspire", "motivate", "grow", "excel", "focus", "energy", "strength", "purpose", "passion"]
        let hasMotivationalContent = motivationalWords.contains { lowercaseContent.contains($0) }
        
        guard hasMotivationalContent else {
            throw DemoGenerationError.contentValidationFailed("Content not sufficiently motivational")
        }
    }
    
    // MARK: - Fallback Content
    
    func getFallbackContent(motivation: MotivationCategory, tone: AlarmTone) -> GeneratedContent {
        let key = "\(motivation.rawValue)_\(tone.rawValue)"
        
        if let cachedContent = fallbackContentCache[key] {
            print("📋 Using cached fallback content for \(key)")
            return cachedContent
        }
        
        // Generate fallback content on-demand
        let fallbackText = createFallbackText(motivation: motivation, tone: tone)
        let metadata = ContentMetadata(
            textContent: fallbackText,
            tone: tone,
            aiModel: "fallback",
            ttsModel: "none",
            generationTime: 0.0
        )
        
        let fallbackContent = GeneratedContent(
            textContent: fallbackText,
            audioURL: nil,
            audioData: nil,
            voiceId: tone.voiceId,
            metadata: metadata
        )
        
        // Cache for future use
        fallbackContentCache[key] = fallbackContent
        
        print("🔄 Generated new fallback content for \(key)")
        return fallbackContent
    }
    
    // MARK: - Fallback Content Creation
    
    private func createFallbackContentCache() -> [String: GeneratedContent] {
        var cache: [String: GeneratedContent] = [:]
        
        // Pre-generate some high-quality fallback content for common combinations
        let commonCombinations: [(MotivationCategory, AlarmTone)] = [
            (.fitness, .energetic),
            (.fitness, .toughLove),
            (.career, .energetic),
            (.career, .gentle),
            (.studies, .gentle),
            (.studies, .energetic),
            (.mindfulness, .gentle),
            (.personalProject, .storyteller)
        ]
        
        for (motivation, tone) in commonCombinations {
            let key = "\(motivation.rawValue)_\(tone.rawValue)"
            let text = createFallbackText(motivation: motivation, tone: tone)
            let metadata = ContentMetadata(
                textContent: text,
                tone: tone,
                aiModel: "fallback",
                ttsModel: "none",
                generationTime: 0.0
            )
            
            cache[key] = GeneratedContent(
                textContent: text,
                audioURL: nil,
                audioData: nil,
                voiceId: tone.voiceId,
                metadata: metadata
            )
        }
        
        return cache
    }
    
    private func createFallbackText(motivation: MotivationCategory, tone: AlarmTone) -> String {
        switch (motivation, tone) {
        case (.fitness, .gentle):
            return "Good morning, beautiful soul. Your body is ready to move with grace and strength. Today, honor your commitment to health with gentle determination. Every step forward is a victory worth celebrating."
            
        case (.fitness, .energetic):
            return "Rise and shine, champion! Your incredible body is ready to conquer this workout. Feel that energy building inside you - it's time to unleash your athletic potential and show the world what you're made of!"
            
        case (.fitness, .toughLove):
            return "Get up, warrior. That gym isn't going to conquer itself. You made a commitment to your health - now honor it. Stop making excuses and start making gains. Your future self is counting on you."
            
        case (.career, .gentle):
            return "Good morning, professional. Today brings fresh opportunities to grow and excel. Take a deep breath, center your focus, and step confidently into your potential. Your career journey unfolds one purposeful day at a time."
            
        case (.career, .energetic):
            return "Rise up, future leader! Today is your stage to showcase brilliance. That presentation, that meeting, that breakthrough idea - you're ready to shine. Let's make this a day of remarkable professional achievement!"
            
        case (.career, .toughLove):
            return "Time to get serious about your career. Success doesn't happen by accident - it's built through daily action and unwavering commitment. Stop dreaming and start executing. Your professional future depends on what you do today."
            
        case (.studies, .gentle):
            return "Good morning, lifelong learner. Today your mind is ready to absorb new knowledge and insights. Approach your studies with curiosity and patience. Every concept you master brings you closer to your educational goals."
            
        case (.studies, .energetic):
            return "Rise and learn, knowledge seeker! Your brain is primed for discovery today. Dive into those books, tackle those problems, and embrace the excitement of learning. Academic excellence is within your grasp!"
            
        case (.mindfulness, .gentle):
            return "Good morning, peaceful soul. Today offers countless moments to practice presence and awareness. Breathe deeply, move mindfully, and approach each experience with gentle attention. Inner peace begins with this very breath."
            
        case (.mindfulness, .storyteller):
            return "Like the morning mist that settles gently over still water, awareness awakens within you. Today is a canvas for mindful moments - each breath a brushstroke of consciousness, each step a meditation in motion."
            
        case (.personalProject, .storyteller):
            return "In the quiet hours before the world awakens, your creative spirit stirs. Today, your personal project calls to you like an unfinished symphony waiting for its next movement. Answer that call with passion and purpose."
            
        case (.personalProject, .energetic):
            return "Creative fire burns within you this morning! Your personal project is ready for another breakthrough. Channel that innovative energy, push through creative barriers, and make something extraordinary happen today!"
            
        default:
            // Generic fallback based on tone
            switch tone {
            case .gentle:
                return "Good morning, beautiful soul. Today holds infinite possibilities for growth and achievement. Approach your goals with gentle determination and trust in your journey. You have everything you need to succeed."
                
            case .energetic:
                return "Rise and shine, champion! Today is bursting with potential for amazing achievements. Your energy is powerful, your goals are within reach. Let's make this a day of remarkable progress and success!"
                
            case .toughLove:
                return "Time to get up and get serious. Your goals won't achieve themselves. Stop making excuses and start making progress. The only thing standing between you and success is action. Make it happen."
                
            case .storyteller:
                return "Like the sun breaking through the horizon, a new day of possibilities dawns. Your journey continues with this single step forward. Today, you write another chapter in your story of growth and achievement."
            }
        }
    }
}

// MARK: - Demo Content Quality Metrics

struct DemoContentMetrics {
    let generationTime: TimeInterval
    let contentLength: Int
    let wasSuccessful: Bool
    let usedFallback: Bool
    let errorReason: String?
    
    var qualityScore: Double {
        var score = 1.0
        
        // Deduct for slow generation
        if generationTime > 3.0 {
            score -= 0.2
        }
        
        // Deduct for fallback usage
        if usedFallback {
            score -= 0.3
        }
        
        // Deduct for errors
        if !wasSuccessful {
            score -= 0.5
        }
        
        return max(0.0, score)
    }
}

// MARK: - Preview Support

#if DEBUG
extension OnboardingDemoService {
    static func mock() -> OnboardingDemoService {
        return OnboardingDemoService()
    }
}
#endif
