import SwiftUI

struct ContentView: View {
    @State private var hasCompletedOnboarding = false
    @State private var hasSeenPaywall = false
    @State private var showPaywall = false
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                // Show onboarding flow
                OnboardingFlowView(onComplete: {
                    hasCompletedOnboarding = true
                    showPaywall = true
                })
            } else if showPaywall && !hasSeenPaywall {
                // Show paywall after onboarding
                PaywallView(source: "onboarding")
                    .onDisappear {
                        hasSeenPaywall = true
                        showPaywall = false
                    }
            } else {
                // Show main app
                MainAppView()
            }
        }
        .onAppear {
            checkOnboardingStatus()
        }
    }
    
    private func checkOnboardingStatus() {
        // Check if user has completed onboarding
        if let data = UserDefaults.standard.data(forKey: "onboarding_completion_data"),
           let _ = try? JSONDecoder().decode(OnboardingCompletionData.self, from: data) {
            hasCompletedOnboarding = true
            
            // Check if user has seen paywall
            hasSeenPaywall = UserDefaults.standard.bool(forKey: "has_seen_paywall")
            
            if !hasSeenPaywall {
                showPaywall = true
            }
        }
    }
}

#Preview {
    ContentView()
}