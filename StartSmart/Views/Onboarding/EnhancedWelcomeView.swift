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
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section with refined messaging
                    headerSection
                        .frame(height: geometry.size.height * 0.5)
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : -30)
                    
                    // Content Section with better CTAs
                    contentSection
                        .frame(minHeight: geometry.size.height * 0.5)
                        .background(Color(.systemBackground))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                        )
                        .offset(y: -30)
                        .opacity(showFeatures ? 1 : 0)
                        .offset(y: showFeatures ? -30 : 0)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Icon with pulsing animation
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateElements ? 1.1 : 1.0)
                    .opacity(animateElements ? 0.3 : 0.7)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: animateElements
                    )
                
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.white)
                    .modifier(PulseAnimationModifier(animate: animateElements))
            }
            
            // Refined App Title
            VStack(spacing: 8) {
                Text("StartSmart")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(-2)
                
                // Benefit-oriented tagline from vision statement
                Text("Wake up with purpose.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
            }
            
            // Value proposition
            Text("Transform your mornings with AI-powered motivation\ntailored just for you")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(spacing: 32) {
            VStack(spacing: 20) {
                // Main heading
                Text("Your Personal Morning Coach")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                // Quick value props
                Text("Every morning, wake up to a personalized motivational message created just for your goals and delivered in your preferred style.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 40)
            
            // Enhanced features with animations
            enhancedFeaturesSection
            
            Spacer(minLength: 32)
            
            // Enhanced CTA buttons
            enhancedCTAButtons
            
            // Secondary action for existing users
            secondaryActionSection
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
    }
    
    // MARK: - Enhanced Features Section
    
    private var enhancedFeaturesSection: some View {
        VStack(spacing: 20) {
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
            Button(action: onPrimaryAction) {
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
            .scaleEffect(animateElements ? 1.0 : 0.95)
            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateElements)
            
            // Alternative CTA for variety
            Button(action: onPrimaryAction) {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .medium))
                    
                    Text("Find My Motivation")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray4), lineWidth: 1.5)
                        )
                )
            }
            .opacity(0.8)
            
            // Social proof hint
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Join thousands starting their days with purpose")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Secondary Action Section
    
    private var secondaryActionSection: some View {
        VStack(spacing: 12) {
            Button(action: onSecondaryAction) {
                Text("Already have an account? Sign In")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            // Terms and privacy
            VStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Button("Terms of Service") {
                        // Handle terms of service
                    }
                    .font(.system(size: 12, weight: .medium))
                    
                    Text("and")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Button("Privacy Policy") {
                        // Handle privacy policy
                    }
                    .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.top, 16)
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
        HStack(spacing: 16) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pulse Animation Modifier

struct PulseAnimationModifier: ViewModifier {
    let animate: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(animate ? 1.1 : 1.0)
            .opacity(animate ? 0.8 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: animate
            )
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
