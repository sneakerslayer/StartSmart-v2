import Foundation

struct OnboardingCompletionData: Codable {
    let motivation: MotivationCategory?
    let tonePosition: Double
    let selectedVoice: VoicePersona?
    let preferences: UserPreferences
    let completedAt: Date
}
