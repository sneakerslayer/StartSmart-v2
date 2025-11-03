//
//  PermissionPrimingView.swift
//  StartSmart
//
//  Onboarding Step 6: Permission Priming
//  Updated to match PremiumLandingPageV2 theme
//

import SwiftUI
import UserNotifications

/// Permission priming screen with premium design that educates users before system prompts
struct PermissionPrimingView: View {
    @ObservedObject var onboardingState: OnboardingState
    @State private var animateElements = false
    @State private var showFeatures = false
    @State private var isRequestingPermission = false
    
    var body: some View {
        ZStack {
            // Background - matching landing page theme
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
                        DesignSystem.purple.opacity(0.15),
                        Color.clear
                    ]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 300
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        DesignSystem.indigo.opacity(0.15),
                        Color.clear
                    ]),
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 300
                )
            }
            .ignoresSafeArea()
            
            // Content
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignSystem.spacing3) {
                        // Header section
                        headerSection
                            .opacity(animateElements ? 1 : 0)
                            .offset(y: animateElements ? 0 : 20)
                        
                        // Permission explanation
                        permissionExplanation
                            .opacity(showFeatures ? 1 : 0)
                            .offset(y: showFeatures ? 0 : 20)
                        
                        // Features that require notifications
                        notificationFeatures
                            .opacity(showFeatures ? 1 : 0)
                            .offset(y: showFeatures ? 0 : 30)
                        
                        // Permission request button
                        permissionRequestButton
                            .opacity(showFeatures ? 1 : 0)
                            .offset(y: showFeatures ? 0 : 20)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, DesignSystem.spacing4)
                    .padding(.top, 0)
                    .padding(.bottom, DesignSystem.spacing3)
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.spacing3) {
            // Notification bell icon with animation
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                // Animated ring effect
                Circle()
                    .stroke(DesignSystem.purple.opacity(0.3), lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .scaleEffect(animateElements ? 1.2 : 1.0)
                    .opacity(animateElements ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false),
                        value: animateElements
                    )
                
                Image(systemName: "bell.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.purple)
                    .scaleEffect(animateElements ? 1.0 : 0.95)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animateElements)
            }
            
            VStack(spacing: 12) {
                // Title
                Text("Enable notifications to\nwake up inspired")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .tracking(-0.5)
                
                // Subtitle
                Text("StartSmart needs permission to play your personalized motivational alarms, even when the app is closed")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.top, 60)
    }
    
    // MARK: - Permission Explanation
    
    private var permissionExplanation: some View {
        VStack(spacing: 16) {
            // Visual explanation card
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Phone illustration
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 40, height: 60)
                        
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DesignSystem.purple)
                                .frame(width: 30, height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 30, height: 2)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 20, height: 2)
                        }
                    }
                    
                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    // Sound waves animation
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(DesignSystem.purple.opacity(0.8))
                                .frame(width: 3, height: CGFloat(8 + index * 4))
                                .offset(y: showFeatures ? 0 : 5)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.1),
                                    value: showFeatures
                                )
                        }
                    }
                    
                    // Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Alarm")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Plays even when closed")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .cornerRadius(16)
            
            // Why this matters
            VStack(spacing: 8) {
                Text("Why this matters:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.purple)
                
                Text("Without notification permission, your AI-generated alarms won't work reliably. iOS needs this permission to play custom audio when the app isn't actively open.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }
        }
    }
    
    // MARK: - Notification Features
    
    private var notificationFeatures: some View {
        VStack(spacing: 16) {
            Text("What you'll get:")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ForEach(Array(notificationFeaturesList.enumerated()), id: \.offset) { index, feature in
                    PremiumNotificationFeatureRow(
                        icon: feature.icon,
                        title: feature.title,
                        description: feature.description,
                        iconColor: feature.color
                    )
                    .opacity(showFeatures ? 1 : 0)
                    .offset(x: showFeatures ? 0 : -30)
                    .animation(
                        .easeOut(duration: 0.6).delay(Double(index) * 0.1),
                        value: showFeatures
                    )
                }
            }
        }
    }
    
    private var notificationFeaturesList: [(icon: String, title: String, description: String, color: Color)] {
        [
            (
                icon: "alarm.waves.left.and.right",
                title: "Reliable Wake-Ups",
                description: "Your alarms work even when the app is closed",
                color: DesignSystem.purple
            ),
            (
                icon: "waveform.path",
                title: "Custom Audio",
                description: "Hear your personalized AI messages every morning",
                color: DesignSystem.indigo
            ),
            (
                icon: "moon.zzz.fill",
                title: "Sleep Friendly",
                description: "No unexpected notifications - only your scheduled alarms",
                color: DesignSystem.purple
            ),
            (
                icon: "lock.shield.fill",
                title: "Privacy Protected",
                description: "All processing happens on your device",
                color: DesignSystem.green
            )
        ]
    }
    
    // MARK: - Permission Request Button
    
    private var permissionRequestButton: some View {
        VStack(spacing: 16) {
            // Main permission button
            Button(action: {
                requestNotificationPermission()
            }) {
                HStack(spacing: 12) {
                    if isRequestingPermission {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    Text(isRequestingPermission ? "Requesting Permission..." : "Enable Notifications")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [DesignSystem.purple, DesignSystem.indigo]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: DesignSystem.purple.opacity(0.4), radius: 24, x: 0, y: 8)
            }
            .disabled(isRequestingPermission)
            .scaleEffect(isRequestingPermission ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isRequestingPermission)
            
            // Skip option (with warning)
            Button(action: {
                handlePermissionSkip()
            }) {
                VStack(spacing: 4) {
                    Text("Skip for now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("(Alarms may not work reliably)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .disabled(isRequestingPermission)
            
            // Privacy note
            Text("Your notification preferences can be changed anytime in Settings")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Permission Handling
    
    private func requestNotificationPermission() {
        guard !isRequestingPermission else { return }
        
        isRequestingPermission = true
        
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
            DispatchQueue.main.async {
                isRequestingPermission = false
                
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                    onboardingState.setNotificationPermission(false)
                } else {
                    print("✅ Notification permission granted: \(granted)")
                    onboardingState.setNotificationPermission(granted)
                    
                    // Provide success feedback
                    if granted {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                }
            }
        }
    }
    
    private func handlePermissionSkip() {
        // Show a confirmation alert before skipping
        let alert = UIAlertController(
            title: "Skip Notifications?",
            message: "Without notification permission, your alarms may not work when the app is closed. You can enable this later in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Go Back", style: .cancel))
        alert.addAction(UIAlertAction(title: "Skip Anyway", style: .destructive) { _ in
            onboardingState.setNotificationPermission(false)
        })
        
        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateElements = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            showFeatures = true
        }
    }
}

// MARK: - Premium Notification Feature Row

struct PremiumNotificationFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(iconColor.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview

#if DEBUG
struct PermissionPrimingView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionPrimingView(onboardingState: OnboardingState())
            .preferredColorScheme(.dark)
    }
}
#endif
