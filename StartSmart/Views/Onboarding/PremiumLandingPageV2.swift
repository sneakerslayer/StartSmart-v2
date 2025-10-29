//
//  PremiumLandingPageV2.swift
//  StartSmart
//
//  New Premium Landing Page Design
//

import SwiftUI

// MARK: - Design System
struct DesignSystem {
    // Colors
    static let darkBg = Color(red: 0.06, green: 0.06, blue: 0.11)
    static let purple = Color(red: 139/255, green: 92/255, blue: 246/255)
    static let indigo = Color(red: 99/255, green: 102/255, blue: 241/255)
    static let green = Color(red: 0.067, green: 0.722, blue: 0.506) // #10b981
    
    // Spacing
    static let spacing1: CGFloat = 8
    static let spacing2: CGFloat = 16
    static let spacing3: CGFloat = 24
    static let spacing4: CGFloat = 32
    static let spacing5: CGFloat = 40
    
    // Radius
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 20
    
    // Responsive sizing
    static func responsiveFontSize(_ baseSize: CGFloat) -> CGFloat {
        let isLargeScreen = UIScreen.main.bounds.width > 600
        return isLargeScreen ? baseSize * 0.85 : baseSize
    }
    
    static func responsiveSpacing(_ baseSpacing: CGFloat) -> CGFloat {
        let isLargeScreen = UIScreen.main.bounds.width > 600
        return isLargeScreen ? baseSpacing * 1.2 : baseSpacing
    }
}

// MARK: - Main View
struct PremiumLandingPageV2: View {
    @State private var animationStarted = false
    @State private var currentActivityIndex = 0
    @State private var showSignIn = false
    var onGetStarted: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.06, green: 0.06, blue: 0.12),
                        Color(red: 0.10, green: 0.10, blue: 0.18)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Radial gradients for depth
                ZStack {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.54, green: 0.39, blue: 0.82).opacity(0.15),
                            Color.clear
                        ]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 300
                    )
                    
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.15),
                            Color.clear
                        ]),
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 300
                    )
                }
                .ignoresSafeArea()
                
                // Content - No status bar, compact layout
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .center, spacing: 12) {
                            // Logo Section
                            VStack(spacing: 12) {
                                ZStack {
                                    LinearGradient(gradient: Gradient(colors: [DesignSystem.purple.opacity(0.3), DesignSystem.indigo.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                    
                                    // New animated icon
                                    SunriseIcon()
                                }
                                .frame(width: UIScreen.main.bounds.width > 600 ? 100 : 88, height: UIScreen.main.bounds.width > 600 ? 100 : 88)
                                .cornerRadius(UIScreen.main.bounds.width > 600 ? 28 : 22)
                                .shadow(color: DesignSystem.purple.opacity(0.4), radius: 24, x: 0, y: 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: UIScreen.main.bounds.width > 600 ? 28 : 22)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                
                                Text("StartSmart")
                                    .font(.system(size: DesignSystem.responsiveFontSize(40), weight: .heavy, design: .default))
                                    .foregroundColor(.white)
                                    .tracking(-1.5)
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 12)
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                            
                            // Headlines - More compact spacing
                            VStack(spacing: 8) {
                                Text("Stop hitting snooze.\nStart crushing goals.")
                                    .font(.system(size: DesignSystem.responsiveFontSize(32), weight: .bold, design: .default))
                                    .foregroundColor(.white)
                                    .lineSpacing(2)
                                    .tracking(-0.5)
                                
                                Text("AI-powered wake-up messages personalized for your daily goals")
                                    .font(.system(size: DesignSystem.responsiveFontSize(15), weight: .medium, design: .default))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineSpacing(1.5)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignSystem.spacing4)
                            .padding(.bottom, 12)
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                            
                            // Live Activity Feed - Single item, scrolling
                            LiveActivityFeedViewSingle(currentIndex: $currentActivityIndex)
                                .frame(height: 100)
                                .padding(.horizontal, DesignSystem.spacing4)
                                .padding(.bottom, 12)
                                .opacity(animationStarted ? 1 : 0)
                                .offset(y: animationStarted ? 0 : 20)
                            
                            // Social Proof - Tighter spacing
                            HStack(spacing: DesignSystem.spacing2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: UIScreen.main.bounds.width > 600 ? 18 : 16))
                                        .foregroundColor(Color(red: 1, green: 0.72, blue: 0))
                                    
                                    Text("4.8")
                                        .font(.system(size: DesignSystem.responsiveFontSize(15), weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, DesignSystem.spacing2)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 100)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .cornerRadius(100)
                                
                                Divider()
                                    .frame(height: 16)
                                    .opacity(0.1)
                                
                                Text("50,000+ users")
                                    .font(.system(size: DesignSystem.responsiveFontSize(15), weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            .padding(.horizontal, DesignSystem.spacing4)
                            .padding(.bottom, 12)
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                            
                            // Trust Section
                            HStack(spacing: DesignSystem.spacing2) {
                                TrustItem(icon: "shield.fill", label: "Private &\nsecure")
                                TrustItem(icon: "xmark", label: "No ads\never")
                                TrustItem(icon: "wifi", label: "Works\noffline")
                            }
                            .padding(.horizontal, DesignSystem.spacing4)
                            .padding(.bottom, 12)
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                            
                            // Bottom Section
                            VStack(spacing: DesignSystem.spacing2) {
                                // CTA Button
                                Button(action: {
                                    onGetStarted?()
                                }) {
                                    Text("Get Started")
                                        .font(.system(size: DesignSystem.responsiveFontSize(17), weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(17)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [DesignSystem.purple, DesignSystem.indigo]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(14)
                                        .shadow(color: DesignSystem.purple.opacity(0.4), radius: 24, x: 0, y: 8)
                                }
                                
                                // Legal
                                VStack(spacing: 2) {
                                    Text("By continuing, you agree to our")
                                        .font(.system(size: DesignSystem.responsiveFontSize(11), weight: .medium))
                                        .foregroundColor(.white.opacity(0.3))
                                    
                                    HStack(spacing: 2) {
                                        Link("Terms of Service", destination: URL(string: "https://www.startsmartmobile.com/support")!)
                                            .font(.system(size: DesignSystem.responsiveFontSize(11), weight: .medium))
                                            .foregroundColor(.white.opacity(0.4))
                                        
                                        Text("and")
                                            .font(.system(size: DesignSystem.responsiveFontSize(11), weight: .medium))
                                            .foregroundColor(.white.opacity(0.3))
                                        
                                        Link("Privacy Policy", destination: URL(string: "https://www.startsmartmobile.com/support")!)
                                            .font(.system(size: DesignSystem.responsiveFontSize(11), weight: .medium))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.spacing4)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                    animationStarted = true
                }
                startActivityRotation()
            }
        }
    }
    
    private func startActivityRotation() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentActivityIndex = (currentActivityIndex + 1) % 3
            }
        }
    }
}

// MARK: - Person Waking Icon
struct SunriseIcon: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Horizon line
            VStack {
                Spacer()
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 2)
            }
            
            // Sun rays (animated)
            ZStack {
                // Outer rays - fade in/out
                ForEach(0..<8, id: \.self) { index in
                    let angle = Double(index) * 45
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.7, blue: 0.2).opacity(0.6),
                                    Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.2)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 1.5, height: 12)
                        .offset(y: -14)
                        .rotationEffect(.degrees(angle))
                        .opacity(isAnimating ? 0.8 : 0.3)
                }
            }
            
            // Sun circle (main)
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.4),
                                Color(red: 1.0, green: 0.7, blue: 0.2).opacity(0.1)
                            ]),
                            center: .center,
                            startRadius: 4,
                            endRadius: 10
                        )
                    )
                    .frame(width: 20, height: 20)
                
                // Sun body
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.75, blue: 0.0),
                                Color(red: 1.0, green: 0.55, blue: 0.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 12, height: 12)
            }
            .offset(y: isAnimating ? -2 : 0)
        }
        .frame(width: 32, height: 32)
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Animated Morning Icon (Old - removed)
// Replaced with PersonWakingIcon above

// MARK: - Live Activity Feed (Single Item)
struct LiveActivityFeedViewSingle: View {
    @Binding var currentIndex: Int
    
    let activities = [
        ("M", "Marcus woke up for his 6AM workout", "Just now • New York", "Day 12"),
        ("S", "Sarah crushed her presentation prep", "2m ago • London", "Day 28"),
        ("J", "James started his study session", "5m ago • Tokyo", "Day 7"),
    ]
    
    @State private var isBlinking = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("RIGHT NOW")
                    .font(.system(size: DesignSystem.responsiveFontSize(13), weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(DesignSystem.green)
                        .frame(width: 6, height: 6)
                        .opacity(isBlinking ? 1 : 0.4)
                    
                    Text("Live")
                        .font(.system(size: DesignSystem.responsiveFontSize(12), weight: .semibold))
                        .foregroundColor(DesignSystem.green)
                }
            }
            .padding(.bottom, 8)
            
            // Single Activity Item
            if currentIndex < activities.count {
                let (avatar, text, time, badge) = activities[currentIndex]
                
                HStack(spacing: DesignSystem.spacing2) {
                    // Avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [DesignSystem.purple, DesignSystem.indigo]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: UIScreen.main.bounds.width > 600 ? 42 : 36, height: UIScreen.main.bounds.width > 600 ? 42 : 36)
                        .overlay(
                            Text(avatar)
                                .font(.system(size: DesignSystem.responsiveFontSize(14), weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(text)
                            .font(.system(size: DesignSystem.responsiveFontSize(14), weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Text(time)
                            .font(.system(size: DesignSystem.responsiveFontSize(12), weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    // Badge
                    Text(badge)
                        .font(.system(size: DesignSystem.responsiveFontSize(11), weight: .semibold))
                        .foregroundColor(DesignSystem.purple.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignSystem.purple.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DesignSystem.purple.opacity(0.3), lineWidth: 0.5)
                        )
                        .cornerRadius(6)
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .cornerRadius(DesignSystem.radiusMedium)
                .transition(.opacity)
            }
        }
        .padding(DesignSystem.spacing2)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(DesignSystem.radiusLarge)
        .onAppear {
            startBlinking()
        }
    }
    
    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                isBlinking.toggle()
            }
        }
    }
}

// MARK: - Trust Item
struct TrustItem: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: UIScreen.main.bounds.width > 600 ? 18 : 16))
                .foregroundColor(DesignSystem.purple)
                .frame(width: UIScreen.main.bounds.width > 600 ? 40 : 32, height: UIScreen.main.bounds.width > 600 ? 40 : 32)
                .background(DesignSystem.purple.opacity(0.1))
                .cornerRadius(8)
            
            Text(label)
                .font(.system(size: DesignSystem.responsiveFontSize(12), weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.spacing2)
        .background(Color.white.opacity(0.02))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(DesignSystem.radiusMedium)
    }
}

// MARK: - Preview
struct PremiumLandingPageV2_Previews: PreviewProvider {
    static var previews: some View {
        PremiumLandingPageV2(onGetStarted: {})
    }
}
