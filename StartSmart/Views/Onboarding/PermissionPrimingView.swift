//
//  PermissionPrimingView.swift
//  StartSmart
//
//  Permission Priming Implementation
//  Educational permission request before iOS system prompts
//

import SwiftUI
import UserNotifications

/// Permission priming screen that educates users before system prompts
struct PermissionPrimingView: View {
    @ObservedObject var onboardingState: OnboardingState
    @State private var animateElements = false
    @State private var showFeatures = false
    @State private var isRequestingPermission = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) { // Reduced spacing from 32 to 24
                    // Header section
                    headerSection
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : -20)
                    
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
                    
                    // Add space for navigation buttons
                    Spacer(minLength: 20) // Reduced to minimize dead space
                }
                .padding(.horizontal, 24)
                .padding(.top, 10) // Reduced from 40 to 10 to prevent cutoff
                .padding(.bottom, 20) // Reduced to minimize dead space
                .frame(minHeight: geometry.size.height)
            }
            .scrollContentBackground(.hidden) // Hide default background for better bounce effect
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) { // Standardized spacing
            // Notification bell icon with animation
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50) // Standardized size
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    )
                    .scaleEffect(animateElements ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: animateElements
                    )
                
                Image(systemName: "bell.fill")
                    .font(.system(size: 24, weight: .medium)) // Standardized size
                    .foregroundColor(.white)
                    .scaleEffect(animateElements ? 1.0 : 0.95)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animateElements)
            }
            
            // Title
            Text("Enable notifications to wake up inspired")
                .font(.system(size: 28, weight: .bold, design: .rounded)) // Standardized size
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .tracking(-1) // Standardized tracking
                .lineSpacing(2) // Standardized line spacing
                .padding(.horizontal, 10) // Standardized padding
            
            // Subtitle
            Text("StartSmart needs permission to play your personalized motivational alarms, even when the app is closed")
                .font(.system(size: 14, weight: .medium)) // Standardized size
                .foregroundColor(.white.opacity(0.85)) // Standardized opacity
                .multilineTextAlignment(.center)
                .lineSpacing(2) // Standardized line spacing
                .padding(.horizontal, 10) // Standardized padding
        }
        .padding(.top, 10) // Standardized top padding
    }
    
    // MARK: - Permission Explanation
    
    private var permissionExplanation: some View {
        VStack(spacing: 16) {
            // Visual explanation card
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Phone illustration
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 40, height: 60)
                        
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
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
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Sound waves
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 3, height: CGFloat(8 + index * 4))
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.1),
                                    value: showFeatures
                                )
                        }
                    }
                    
                    // Text
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your Alarm")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Plays even when closed")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Why this matters
            VStack(spacing: 8) {
                Text("Why this matters:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("Without notification permission, your AI-generated alarms won't work reliably. iOS needs this permission to play custom audio when the app isn't actively open.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
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
                    NotificationFeatureRow(
                        icon: feature.icon,
                        title: feature.title,
                        description: feature.description
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
    
    private var notificationFeaturesList: [(icon: String, title: String, description: String)] {
        [
            (
                icon: "alarm.waves.left.and.right",
                title: "Reliable Wake-Ups",
                description: "Your alarms work even when the app is closed"
            ),
            (
                icon: "waveform.path",
                title: "Custom Audio",
                description: "Hear your personalized AI messages every morning"
            ),
            (
                icon: "moon.zzz.fill",
                title: "Sleep Friendly",
                description: "No unexpected notifications - only your scheduled alarms"
            ),
            (
                icon: "lock.shield.fill",
                title: "Privacy Protected",
                description: "All processing happens on your device"
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
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
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
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("(Alarms may not work reliably)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .disabled(isRequestingPermission)
            
            // Privacy note
            Text("Your notification preferences can be changed anytime in Settings")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
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
        
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            showFeatures = true
        }
    }
}

// MARK: - Notification Feature Row

struct NotificationFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 24)
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
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
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.7), .cyan.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .preferredColorScheme(.dark)
    }
}

#endif
