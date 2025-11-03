//
//  MotivationSelectionView.swift
//  StartSmart
//
//  Onboarding Step 2: What Drives You
//  Premium themed motivation selection with enhanced visual design
//

import SwiftUI

/// Interactive motivation selection step with premium design matching landing page
struct MotivationSelectionView: View {
    @ObservedObject var onboardingState: OnboardingState
    let onMotivationSelected: ((MotivationCategory) -> Void)?
    @State private var animationStarted = false
    
    init(onboardingState: OnboardingState, onMotivationSelected: ((MotivationCategory) -> Void)? = nil) {
        self.onboardingState = onboardingState
        self.onMotivationSelected = onMotivationSelected
    }
    
    // Grid layout configuration
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            // Background - matching landing page
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header with Icon
                    VStack(spacing: 16) {
                        // Question Icon
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            
                            Image(systemName: "target")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.purple)
                        }
                        
                        // Question Text
                        VStack(spacing: 12) {
                            Text("What drives you\nright now?")
                                .font(.system(size: 32, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .tracking(-0.5)
                            
                            Text("Choose what motivates you most to help us create your perfect wake-up message")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 8)
                    .opacity(animationStarted ? 1 : 0)
                    .offset(y: animationStarted ? 0 : 20)
                    
                    // Options Grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(MotivationCategory.allCases.enumerated()), id: \.element) { index, motivation in
                            PremiumMotivationCard(
                                motivation: motivation,
                                isSelected: onboardingState.selectedMotivation == motivation,
                                onTap: {
                                    handleMotivationSelection(motivation)
                                }
                            )
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.8)
                                .delay(Double(index) * 0.08),
                                value: animationStarted
                            )
                        }
                    }
                    .opacity(animationStarted ? 1 : 0)
                    .offset(y: animationStarted ? 0 : 20)
                    
                    // Bottom spacing for navigation buttons
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, DesignSystem.spacing4)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animationStarted = true
            }
        }
    }
    
    // MARK: - Selection Handler
    
    private func handleMotivationSelection(_ motivation: MotivationCategory) {
        print("🎯 handleMotivationSelection called with: \(motivation.rawValue)")
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Call the callback if provided
        onMotivationSelected?(motivation)
        
        // Also update the onboarding state for backward compatibility
        onboardingState.selectMotivation(motivation)
    }
}

// MARK: - Premium Motivation Card Component

struct PremiumMotivationCard: View {
    let motivation: MotivationCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Selection indicator
                if isSelected {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(DesignSystem.purple)
                                .frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding([.top, .trailing], 12)
                    .frame(height: 24)
                } else {
                    Spacer()
                        .frame(height: 36)
                }
                
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(motivation.iconColor.opacity(isSelected ? 0.25 : 0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: motivation.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(motivation.iconColor)
                }
                .padding(.bottom, 16)
                
                // Text
                VStack(spacing: 8) {
                    Text(motivation.displayName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Text(motivation.description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)
                
                Spacer(minLength: 16)
            }
            .frame(minHeight: 180)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Color.white.opacity(isSelected ? 0.06 : 0.04)
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                DesignSystem.purple.opacity(0.1),
                                DesignSystem.indigo.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? DesignSystem.purple : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(20)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(
                color: isSelected ? DesignSystem.purple.opacity(0.3) : Color.black.opacity(0.1),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview

#if DEBUG
struct MotivationSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        MotivationSelectionView(onboardingState: OnboardingState())
            .preferredColorScheme(.dark)
    }
}
#endif
