//
//  MotivationSelectionView.swift
//  StartSmart
//
//  Interactive Motivation Selection Cards
//  Beautiful tappable cards with animations and icons
//

import SwiftUI

/// Interactive motivation selection step with animated cards
struct MotivationSelectionView: View {
    @ObservedObject var onboardingState: OnboardingState
    let onMotivationSelected: ((MotivationCategory) -> Void)?
    @State private var animateCards = false
    @State private var showInstructions = false
    
    init(onboardingState: OnboardingState, onMotivationSelected: ((MotivationCategory) -> Void)? = nil) {
        self.onboardingState = onboardingState
        self.onMotivationSelected = onMotivationSelected
    }
    
    // Grid layout configuration
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    headerSection
                        .opacity(showInstructions ? 1 : 0)
                        .offset(y: showInstructions ? 0 : -20)
                    
                    // Motivation cards grid
                    motivationCardsGrid
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 30)
                    
                    // Bottom spacing to ensure content doesn't get cut off
                    Spacer()
                        .frame(height: 20) // Reduced to minimize dead space
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
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
        VStack(spacing: 12) {
            // Question icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Main question
            Text("What drives you right now?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .tracking(-1)
            
            // Subtitle
            Text("Choose what motivates you most to help us create your perfect wake-up message")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 16)
        }
        .padding(.top, -10)
    }
    
    // MARK: - Motivation Cards Grid
    
    private var motivationCardsGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(Array(MotivationCategory.allCases.enumerated()), id: \.element) { index, motivation in
                MotivationCard(
                    motivation: motivation,
                    isSelected: onboardingState.selectedMotivation == motivation,
                    onTap: {
                        handleMotivationSelection(motivation)
                    }
                )
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.7)
                    .delay(Double(index) * 0.1),
                    value: animateCards
                )
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            showInstructions = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            animateCards = true
        }
    }
    
    // MARK: - Selection Handler
    
    private func handleMotivationSelection(_ motivation: MotivationCategory) {
        print("🎯 handleMotivationSelection called with: \(motivation.rawValue)")
        
        // Call the callback if provided
        onMotivationSelected?(motivation)
        
        // Also update the onboarding state for backward compatibility
        onboardingState.selectMotivation(motivation)
    }
}

// MARK: - Motivation Card Component

struct MotivationCard: View {
    let motivation: MotivationCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var showContent = false
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(spacing: 16) {
                // Icon with animated background
                ZStack {
                    Circle()
                        .fill(motivation.iconColor.opacity(isSelected ? 0.3 : 0.15))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(
                                    motivation.iconColor.opacity(isSelected ? 0.6 : 0.0),
                                    lineWidth: 2
                                )
                        )
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                    
                    Image(systemName: motivation.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(motivation.iconColor)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
                
                // Text content
                VStack(spacing: 8) {
                    Text(motivation.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(motivation.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isSelected ?
                                Color.white.opacity(0.4) :
                                Color.white.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ?
                        motivation.iconColor.opacity(0.3) :
                        Color.black.opacity(0.1),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                showContent = true
            }
        }
    }
}

// MARK: - Selection Animation Modifier

struct SelectionAnimationModifier: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // Selection indicator
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white, lineWidth: 3)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isSelected)
            )
            .overlay(
                // Checkmark indicator
                VStack {
                    HStack {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1.0 : 0.5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
                    }
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                    
                    Spacer()
                }
            )
    }
}

extension View {
    func selectionAnimation(isSelected: Bool) -> some View {
        modifier(SelectionAnimationModifier(isSelected: isSelected))
    }
}

// MARK: - Preview

#if DEBUG
struct MotivationSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode
            MotivationSelectionView(onboardingState: OnboardingState())
                .background(
                    LinearGradient(
                        colors: [.orange.opacity(0.7), .pink.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .preferredColorScheme(.light)
            
            // Dark mode
            MotivationSelectionView(onboardingState: OnboardingState())
                .background(
                    LinearGradient(
                        colors: [.orange.opacity(0.7), .pink.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .preferredColorScheme(.dark)
            
            // Single card preview
            MotivationCard(
                motivation: .fitness,
                isSelected: false,
                onTap: { print("Fitness selected") }
            )
            .frame(width: 160, height: 160)
            .background(Color.black)
        }
    }
}
#endif
