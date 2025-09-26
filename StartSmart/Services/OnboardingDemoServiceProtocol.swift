//
//  OnboardingDemoServiceProtocol.swift
//  StartSmart
//
//  Protocol definition for Onboarding Demo Service
//

import Foundation

// MARK: - OnboardingDemoService Protocol

protocol OnboardingDemoServiceProtocol {
    func generateDemoContent(
        motivation: MotivationCategory,
        tone: AlarmTone,
        voicePersona: VoicePersona
    ) async throws -> GeneratedContent
    
    func getFallbackContent(
        motivation: MotivationCategory,
        tone: AlarmTone
    ) -> GeneratedContent
}
