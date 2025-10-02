//
//  ToneSelectionView.swift
//  StartSmart
//
//  Interactive Tone Selection Slider
//  Dynamic text feedback and beautiful animations
//

import SwiftUI

/// Interactive tone selection with dynamic slider and text feedback
struct ToneSelectionView: View {
    @ObservedObject var onboardingState: OnboardingState
    @State private var animateElements = false
    @State private var showSlider = false
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) { // Reduced spacing from 24 to 16
                    // Header section
                    headerSection
                        .opacity(animateElements ? 1 : 0)
                        .offset(y: animateElements ? 0 : -20)
                    
                    // Dynamic text display
                    dynamicTextDisplay
                        .opacity(showSlider ? 1 : 0)
                        .offset(y: showSlider ? 0 : 10)
                    
                    // Examples section - moved above slider
                    examplesSection
                        .opacity(showSlider ? 1 : 0)
                        .offset(y: showSlider ? 0 : 20)
                    
                    // Tone slider
                    toneSliderSection
                        .opacity(showSlider ? 1 : 0)
                        .offset(y: showSlider ? 0 : 30)
                    
                    Spacer(minLength: 20) // Further reduced to minimize dead space
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20) // Reduced bottom padding to minimize dead space
                .frame(minHeight: geometry.size.height) // Ensure content takes at least full screen height
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
            // Tone icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50) // Standardized size
                
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 24, weight: .medium)) // Standardized size
                    .foregroundColor(.white)
            }
            
            // Main question
            Text("How do you like your motivation?")
                .font(.system(size: 28, weight: .bold, design: .rounded)) // Standardized size
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .tracking(-1) // Standardized tracking
            
            // Subtitle
            Text("Slide to find your perfect motivational style")
                .font(.system(size: 14, weight: .medium)) // Standardized size
                .foregroundColor(.white.opacity(0.85)) // Standardized opacity
                .multilineTextAlignment(.center)
                .lineSpacing(2) // Standardized line spacing
                .padding(.horizontal, 10) // Standardized padding
        }
        .padding(.top, 10) // Standardized top padding
    }
    
    // MARK: - Dynamic Text Display
    
    private var dynamicTextDisplay: some View {
        VStack(spacing: 16) {
            // Sample text that changes with slider
            Text(onboardingState.toneDisplayText)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 20)
                .frame(minHeight: 60)
                .animation(.easeInOut(duration: 0.3), value: onboardingState.toneDisplayText)
            
            // Current tone indicator
            ToneIndicator(
                tone: onboardingState.computedTone,
                position: onboardingState.toneSliderPosition
            )
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Tone Slider Section
    
    private var toneSliderSection: some View {
        VStack(spacing: 16) { // Reduced spacing from 24 to 16
            // Slider labels
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gentle & Nurturing")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Warm, encouraging")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Tough Love & Assertive")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Direct, no-nonsense")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Custom slider
            CustomToneSlider(
                value: $onboardingState.toneSliderPosition,
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
            .frame(height: 60)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Examples Section
    
    private var examplesSection: some View {
        VStack(spacing: 12) { // Reduced spacing from 16 to 12
            Text("Examples by tone")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) { // Reduced spacing from 12 to 10
                ForEach(AlarmTone.allCases, id: \.self) { tone in
                    ToneExampleCard(
                        tone: tone,
                        isHighlighted: tone == onboardingState.computedTone
                    )
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            animateElements = true
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            showSlider = true
        }
    }
}

// MARK: - Custom Tone Slider

struct CustomToneSlider: View {
    @Binding var value: Double
    @Binding var isDragging: Bool
    let onValueChanged: (Double) -> Void
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            let sliderWidth = geometry.size.width
            let thumbSize: CGFloat = 32
            let trackHeight: CGFloat = 8
            
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: trackHeight)
                
                // Track fill (gradient based on position)
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(
                        LinearGradient(
                            colors: gradientColors(for: value),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: (sliderWidth - thumbSize) * value + thumbSize,
                        height: trackHeight
                    )
                    .animation(.easeOut(duration: 0.2), value: value)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .overlay(
                        Circle()
                            .stroke(
                                gradientColors(for: value).last ?? .blue,
                                lineWidth: 3
                            )
                            .opacity(isDragging ? 1 : 0.7)
                    )
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                    .offset(x: (sliderWidth - thumbSize) * value)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isDragging)
                    .gesture(
                        DragGesture()
                            .onChanged { drag in
                                if !isDragging {
                                    isDragging = true
                                }
                                
                                let newValue = min(max(0, (drag.location.x - thumbSize/2) / (sliderWidth - thumbSize)), 1)
                                onValueChanged(newValue)
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
    
    private func gradientColors(for position: Double) -> [Color] {
        switch position {
        case 0.0..<0.25:
            return [.mint, .green]
        case 0.25..<0.5:
            return [.purple, .blue]
        case 0.5..<0.75:
            return [.orange, .red]
        default:
            return [.red, .black]
        }
    }
}

// MARK: - Tone Indicator

struct ToneIndicator: View {
    let tone: AlarmTone
    let position: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tone.iconName)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tone.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(tone.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Position indicator
            Text("\(Int(position * 100))%")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                )
        }
    }
    
    private var iconColor: Color {
        switch tone {
        case .gentle: return .mint
        case .storyteller: return .purple
        case .energetic: return .orange
        case .toughLove: return .red
        }
    }
}

// MARK: - Tone Example Card

struct ToneExampleCard: View {
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
        VStack(spacing: 8) {
            HStack {
                Image(systemName: tone.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isHighlighted ? .white : .white.opacity(0.7))
                
                Text(tone.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isHighlighted ? .white : .white.opacity(0.7))
                
                Spacer()
            }
            
            Text(exampleText)
                .font(.system(size: 10))
                .foregroundColor(isHighlighted ? .white.opacity(0.9) : .white.opacity(0.6))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isHighlighted ?
                    Color.white.opacity(0.25) :
                    Color.white.opacity(0.1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isHighlighted ?
                            Color.white.opacity(0.5) :
                            Color.white.opacity(0.2),
                            lineWidth: isHighlighted ? 2 : 1
                        )
                )
        )
        .scaleEffect(isHighlighted ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isHighlighted)
    }
}

// MARK: - Preview

#if DEBUG
struct ToneSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ToneSelectionView(onboardingState: OnboardingState())
                .background(
                    LinearGradient(
                        colors: [.mint.opacity(0.7), .green.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .preferredColorScheme(.dark)
            
            // Slider component preview
            VStack {
                CustomToneSlider(
                    value: .constant(0.5),
                    isDragging: .constant(false),
                    onValueChanged: { _ in }
                )
                .frame(height: 60)
                .padding()
            }
            .background(Color.black)
        }
    }
}
#endif
