import SwiftUI
import Combine
import RevenueCat

struct ContentView: View {
    @State private var hasCompletedOnboarding = false
    @State private var hasSeenPaywall = false
    @State private var showPaywall = false
    @State private var isInitialized = false
    
    var body: some View {
        Group {
            if !isInitialized {
                // ✅ Shows almost immediately now!
                SplashView()
            } else if !hasCompletedOnboarding {
                OnboardingFlowView(onComplete: { completeOnboarding() })
            } else if showPaywall && !hasSeenPaywall {
                PaywallView(source: "onboarding", onDismiss: { completePaywall() })
            } else {
                MainAppView()
            }
        }
        .onAppear {
            checkOnboardingStatus()
        }
    }
    
    private func checkOnboardingStatus() {
        // Check onboarding completion
        if let data = UserDefaults.standard.data(forKey: "onboarding_completion_data"),
           let _ = try? JSONDecoder().decode(OnboardingCompletionData.self, from: data) {
            hasCompletedOnboarding = true
            hasSeenPaywall = UserDefaults.standard.bool(forKey: "has_seen_paywall")
            
            if !hasSeenPaywall {
                showPaywall = true
            }
        }
        
        isInitialized = true
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        hasSeenPaywall = UserDefaults.standard.bool(forKey: "has_seen_paywall")
        
        if !hasSeenPaywall {
            showPaywall = true
        }
    }
    
    private func completePaywall() {
        hasSeenPaywall = true
        showPaywall = false
        UserDefaults.standard.set(true, forKey: "has_seen_paywall")
    }
}

// ✅ Branded splash screen (shows while Stage 1 loads)
struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Your brand color
            Color(hex: "#1E40AF") // Blue - replace with your color
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App logo/icon
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("StartSmart")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                
                // Subtle loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Helper for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}