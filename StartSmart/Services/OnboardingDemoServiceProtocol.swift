//
//  OnboardingDemoServiceProtocol.swift
//  StartSmart
//
//  Protocol definition for Onboarding Demo Service
//

import Foundation
import SwiftUI

// MARK: - OnboardingDemoService Protocol

@MainActor
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
