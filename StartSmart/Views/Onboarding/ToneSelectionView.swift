//
//  ToneSelectionView.swift
//  StartSmart
//
//  Onboarding Step 3: Choose Your Tone
//  Premium themed with dynamic backgrounds that respond to tone selection
//

import SwiftUI

/// Interactive tone selection with dynamic slider, premium design, and text feedback
struct ToneSelectionView: View {
    @ObservedObject var onboardingState: OnboardingState
    @State private var animationStarted = false
    @State private var isDragging = false
    
    // Computed current tone based on slider position
    private var currentToneType: ToneType {
        let position = onboardingState.toneSliderPosition
        if position <= 0.33 {
            return .gentle
        } else if position <= 0.66 {
            return .balanced
        } else {
            return .tough
        }
    }
    
    var body: some View {
        ZStack {
            // Dynamic Background that changes with tone
            currentToneType.backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: currentToneType)
            
            // Radial gradients for depth - animate with tone
            ZStack {
                RadialGradient(
                    gradient: Gradient(colors: [
                        currentToneType.color.opacity(0.15),
                        Color.clear
                    ]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 300
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        currentToneType.color.opacity(0.12),
                        Color.clear
                    ]),
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 300
                )
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: currentToneType)
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: DesignSystem.spacing3) {
                    // Header
                    VStack(spacing: DesignSystem.spacing3) {
                        // Tone Icon
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 24))
                                .foregroundColor(currentToneType.color)
                        }
                        .animation(.easeInOut(duration: 0.6), value: currentToneType.color)
                        
                        VStack(spacing: 12) {
                            Text("How do you like\nyour motivation?")
                                .font(.system(size: 32, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .tracking(-0.5)
                            
                            Text("Slide to find your perfect motivational style")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 60)
                    .opacity(animationStarted ? 1 : 0)
                    .offset(y: animationStarted ? 0 : 20)
                    
                    // Preview Card
                    VStack(spacing: 20) {
                        Text(onboardingState.toneDisplayText)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.top, 8)
                            .animation(.easeInOut(duration: 0.3), value: onboardingState.toneDisplayText)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentToneType.label)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(currentToneType.description)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            // Intensity Badge
                            Text("\(Int(onboardingState.toneSliderPosition * 100))%")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(currentToneType.color)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(currentToneType.color.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 100)
                                        .stroke(currentToneType.color.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(100)
                        }
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .cornerRadius(20)
                    .animation(.easeInOut(duration: 0.3), value: currentToneType)
                    .opacity(animationStarted ? 1 : 0)
                    .offset(y: animationStarted ? 0 : 20)
                    
                    // Slider Section - Sleek, centered, and balanced
                    VStack(spacing: 20) {
                        // Labels above slider (centered)
                        HStack {
                            Text("Gentle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                            Spacer()
                            Text("Tough Love")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12) // Padding to prevent cutoff
                        
                        // Slider with proper padding
                        HStack(spacing: 0) {
                            Spacer()
                                .frame(width: 12) // Left padding for thumb clearance
                            
                            PremiumToneSlider(
                                value: $onboardingState.toneSliderPosition,
                                toneColor: currentToneType.color,
                                isDragging: $isDragging,
                                onValueChanged: { newValue in
                                    onboardingState.updateTonePosition(newValue)
                                    
                                    // Haptic feedback during drag
                                    if isDragging {
                                        let feedbackGenerator = UISelectionFeedbackGenerator()
                                        feedbackGenerator.selectionChanged()
                                    }
                                }
                            )
                            .frame(height: 5)
                            
                            Spacer()
                                .frame(width: 12) // Right padding for thumb clearance
                        }
                        
                        // Labels below slider (centered and aligned)
                        HStack {
                            Text("Gentle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                            Spacer()
                            Text("Tough Love")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12) // Matching padding for symmetry
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24) // Consistent spacing before "Examples by tone"
                    .opacity(animationStarted ? 1 : 0)
                    .offset(y: animationStarted ? 0 : 20)
                    
                    // Example Cards
                    VStack(spacing: 12) {
                        Text("Examples by tone")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(AlarmTone.allCases, id: \.self) { tone in
                                PremiumExampleCard(
                                    tone: tone,
                                    isHighlighted: tone == onboardingState.computedTone
                                )
                            }
                        }
                    }
                    .opacity(animationStarted ? 1 : 0)
                    .offset(y: animationStarted ? 0 : 20)
                    
                    // Tone Spectrum Labels
                    HStack {
                        VStack(spacing: 4) {
                            Text("Gentle & Nurturing")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Warm, encouraging")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Tough Love & Assertive")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Direct, no-nonsense")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.vertical, DesignSystem.spacing2)
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
}

// MARK: - Tone Type Definition

enum ToneType {
    case gentle, balanced, tough
    
    var color: Color {
        switch self {
        case .gentle: return DesignSystem.green
        case .balanced: return DesignSystem.purple
        case .tough: return Color(red: 0.94, green: 0.27, blue: 0.27)
        }
    }
    
    var label: String {
        switch self {
        case .gentle: return "Gentle & Nurturing"
        case .balanced: return "Balanced"
        case .tough: return "Tough Love"
        }
    }
    
    var description: String {
        switch self {
        case .gentle: return "Warm, encouraging, supportive"
        case .balanced: return "Motivating, direct, encouraging"
        case .tough: return "Direct, firm but caring, no-nonsense"
        }
    }
    
    var backgroundGradient: LinearGradient {
        switch self {
        case .gentle:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.12, blue: 0.10),
                    Color(red: 0.10, green: 0.18, blue: 0.16)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .balanced:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.10, green: 0.10, blue: 0.18)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .tough:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.12, green: 0.06, blue: 0.06),
                    Color(red: 0.18, green: 0.10, blue: 0.10)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Premium Tone Slider

struct PremiumToneSlider: View {
    @Binding var value: Double
    let toneColor: Color
    @Binding var isDragging: Bool
    let onValueChanged: (Double) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track - sleek, subtle background
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 5)
                
                // Fill - smooth gradient with glow
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [toneColor.opacity(0.95), toneColor]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geometry.size.width * value), height: 5)
                    .shadow(color: toneColor.opacity(0.4), radius: 8, x: 0, y: 0)
                    .animation(.easeInOut(duration: 0.2), value: toneColor)
                
                // Thumb - sleek with clear depth shadow
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white,
                                Color.white.opacity(0.98)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                    .shadow(color: toneColor.opacity(0.4), radius: 12, x: 0, y: 0)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        toneColor.opacity(isDragging ? 1 : 0.7),
                                        toneColor.opacity(isDragging ? 0.9 : 0.5)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                    )
                    .scaleEffect(isDragging ? 1.15 : 1.0)
                    .offset(x: max(0, min(geometry.size.width - 26, geometry.size.width * value)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                    .animation(.easeInOut(duration: 0.2), value: toneColor)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if !isDragging {
                                    isDragging = true
                                }
                                // Account for thumb width (26) and padding (12 on each side)
                                let availableWidth = geometry.size.width
                                let newValue = ((gesture.location.x) / availableWidth)
                                onValueChanged(min(max(0, newValue), 1))
                            }
                            .onEnded { _ in
                                isDragging = false
                                
                                // Final haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                    )
            }
        }
    }
}

// MARK: - Premium Example Card

struct PremiumExampleCard: View {
    let tone: AlarmTone
    let isHighlighted: Bool
    
    private var exampleText: String {
        switch tone {
        case .gentle:
            return "Good morning, you've got this. Take a gentle breath..."
        case .storyteller:
            return "Like the sunrise breaking through darkness..."
        case .energetic:
            return "Rise and shine! Time to crush those goals!"
        case .toughLove:
            return "Get up! No excuses. That goal won't achieve itself!"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: tone.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(tone.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(exampleText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(2)
                .lineLimit(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(isHighlighted ? 0.06 : 0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(isHighlighted ? 0.12 : 0.06), lineWidth: isHighlighted ? 2 : 1)
        )
        .cornerRadius(16)
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHighlighted)
    }
}

// MARK: - Preview

#if DEBUG
struct ToneSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ToneSelectionView(onboardingState: OnboardingState())
            .preferredColorScheme(.dark)
    }
}
#endif
