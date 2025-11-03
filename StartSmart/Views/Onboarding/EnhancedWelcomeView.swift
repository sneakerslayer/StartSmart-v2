//
//  EnhancedWelcomeView.swift
//  StartSmart
//
//  Enhanced Welcome Screen for Onboarding
//  Refined messaging and better conversion-focused CTAs
//

import SwiftUI

/// Enhanced welcome screen with refined messaging and better CTAs
struct EnhancedWelcomeView: View {
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void
    
    @State private var animateElements = false
    @State private var showFeatures = false
    
    var body: some View {
        GeometryReader { geometry in
            // Detect if we're on iPad for layout adjustments
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            let headerHeight = isIPad ? min(geometry.size.height * 0.3, 300) : geometry.size.height * 0.35
            
            VStack(spacing: 0) {
                // Header Section with refined messaging - adjusted for iPad
                headerSection
                    .frame(height: headerHeight)
                    .opacity(animateElements ? 1 : 0)
                    .offset(y: animateElements ? 0 : -30)
                
                // Content Section with better CTAs - scrollable for iPad
                ScrollView(.vertical, showsIndicators: false) {
                    contentSection
                        .padding(.top, isIPad ? 40 : 20)
                        .padding(.bottom, isIPad ? 60 : 40)
                }
                .background(Color(.systemBackground))
                .clipShape(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                )
                .offset(y: -20)
                .opacity(showFeatures ? 1 : 0)
                .offset(y: showFeatures ? -20 : 0)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) { // Standardized spacing
            // App Icon - static, positioned higher
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2)) // Standardized opacity
                    .frame(width: 50, height: 50) // Standardized size
                
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 24, weight: .medium)) // Standardized weight
                    .foregroundColor(.white)
            }
            
            // Refined App Title - right underneath with minimal spacing
            Text("StartSmart")
                .font(.system(size: 32, weight: .bold, design: .rounded)) // Increased from 28 to 32
                .foregroundColor(.white)
                .tracking(-1) // Standardized tracking
                .multilineTextAlignment(.center)
            
            // Benefit-oriented tagline from vision statement
            Text("Wake up with purpose.")
                .font(.system(size: 18, weight: .medium)) // Increased by 10% from 16 to 18
                .foregroundColor(.white.opacity(0.85)) // Standardized opacity
                .multilineTextAlignment(.center)
                .lineSpacing(2) // Standardized line spacing
                .padding(.horizontal, 10) // Standardized padding
            
            // Value proposition - shortened
            Text("Transform your mornings with AI-powered motivation")
                .font(.system(size: 14, weight: .regular)) // Increased by 10% from 13 to 14
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .padding(.horizontal, 10) // Standardized padding
        }
        .padding(.top, -20) // Move header up further on screen
        .padding(.horizontal, 24) // Standardized horizontal padding
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let maxWidth: CGFloat = isIPad ? 600 : .infinity
        
        return VStack(spacing: 16) {
            VStack(spacing: 8) {
                // Main heading - adjusted for iPad
                Text("Your Personal Morning Coach")
                    .font(.system(size: isIPad ? 28 : 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                // Quick value props - adjusted for iPad
                Text("Personalized motivational messages created just for your goals.")
                    .font(.system(size: isIPad ? 16 : 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
            }
            .padding(.top, isIPad ? 20 : 16)
            
            // Enhanced features with animations
            enhancedFeaturesSection
            
            // Enhanced CTA buttons
            enhancedCTAButtons
            
            // Secondary action for existing users
            secondaryActionSection
        }
        .frame(maxWidth: maxWidth)
        .padding(.horizontal, isIPad ? 40 : 30)
        .padding(.bottom, isIPad ? 20 : 5)
    }
    
    // MARK: - Enhanced Features Section
    
    private var enhancedFeaturesSection: some View {
        VStack(spacing: 8) {
            ForEach(Array(enhancedFeatures.enumerated()), id: \.offset) { index, feature in
                EnhancedFeatureRow(
                    icon: feature.icon,
                    title: feature.title,
                    description: feature.description,
                    color: feature.color
                )
                .opacity(showFeatures ? 1 : 0)
                .offset(x: showFeatures ? 0 : -50)
                .animation(
                    .easeOut(duration: 0.6).delay(Double(index) * 0.15),
                    value: showFeatures
                )
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var enhancedFeatures: [(icon: String, title: String, description: String, color: Color)] {
        [
            (
                icon: "brain.head.profile",
                title: "AI-Crafted Content",
                description: "Personalized motivational speeches that adapt to your goals",
                color: .blue
            ),
            (
                icon: "speaker.wave.3.fill",
                title: "Your Perfect Voice",
                description: "Choose from coaching styles that resonate with you",
                color: .green
            ),
            (
                icon: "target",
                title: "Goal-Focused",
                description: "Every message is crafted around what matters to you most",
                color: .orange
            )
        ]
    }
    
    // MARK: - Enhanced CTA Buttons
    
    private var enhancedCTAButtons: some View {
        VStack(spacing: 16) {
            // Primary CTA - more engaging language
            Button(action: {
                print("🔘 Primary button tapped")
                // Add haptic feedback for better user experience
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Execute action immediately
                onPrimaryAction()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .medium))
                    
                    Text("Design My Wake-Up")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle()) // Ensure proper tap handling
            .contentShape(Rectangle()) // Explicitly define tappable area
            .scaleEffect(animateElements ? 1.0 : 0.95)
            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateElements)
            
            
            // Social proof hint
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Join thousands starting their days with purpose")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Secondary Action Section
    
    private var secondaryActionSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                print("🔘 Sign in button tapped")
                onSecondaryAction()
            }) {
                Text("Already have an account? Sign In")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            
            // Terms and privacy
            VStack(spacing: 4) {
                Text("By continuing, you agree to our")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 2) {
                    Link("Terms of Service", destination: URL(string: "https://www.startsmartmobile.com/support")!)
                        .font(.system(size: 10, weight: .medium))
                    
                    Text("and")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Link("Privacy Policy", destination: URL(string: "https://www.startsmartmobile.com/support")!)
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateElements = true
        }
        
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            showFeatures = true
        }
    }
}

// MARK: - Enhanced Feature Row Component

struct EnhancedFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon with colored background - smaller
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Preview

#if DEBUG
struct EnhancedWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedWelcomeView(
            onPrimaryAction: { print("Primary action tapped") },
            onSecondaryAction: { print("Secondary action tapped") }
        )
        .preferredColorScheme(.light)
        
        EnhancedWelcomeView(
            onPrimaryAction: { print("Primary action tapped") },
            onSecondaryAction: { print("Secondary action tapped") }
        )
        .preferredColorScheme(.dark)
    }
}
#endif
