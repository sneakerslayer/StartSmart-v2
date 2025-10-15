import SwiftUI

// MARK: - Alarm Customization View

struct AlarmCustomizationView: View {
    @StateObject private var customizationService = AdvancedAlarmCustomizationService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Theme Selection
                    themeSection
                    
                    // Sound Selection
                    soundSection
                    
                    // Animation Selection
                    animationSection
                    
                    // Gesture Selection
                    gestureSection
                    
                    // Effect Selection
                    effectSection
                    
                    // Settings
                    settingsSection
                    
                    // Apply Button
                    applyButton
                }
                .padding()
            }
            .navigationTitle("Customize Alarm")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        customizationService.saveUserPreferences()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Customize Your Alarm Experience")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Personalize your alarm with themes, sounds, animations, and effects")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Theme Section
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Theme", icon: "paintpalette.fill")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(customizationService.availableThemes) { theme in
                    ThemeCard(
                        theme: theme,
                        isSelected: customizationService.selectedTheme?.id == theme.id
                    ) {
                        customizationService.selectedTheme = theme
                    }
                }
            }
        }
    }
    
    // MARK: - Sound Section
    
    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sound", icon: "speaker.wave.2.fill")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(customizationService.availableSounds) { sound in
                    SoundCard(
                        sound: sound,
                        isSelected: customizationService.selectedSound?.id == sound.id
                    ) {
                        customizationService.selectedSound = sound
                    }
                }
            }
        }
    }
    
    // MARK: - Animation Section
    
    private var animationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Animation", icon: "sparkles")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(customizationService.availableAnimations) { animation in
                    AnimationCard(
                        animation: animation,
                        isSelected: customizationService.selectedAnimation?.id == animation.id
                    ) {
                        customizationService.selectedAnimation = animation
                    }
                }
            }
        }
    }
    
    // MARK: - Gesture Section
    
    private var gestureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Gesture", icon: "hand.tap.fill")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(customizationService.availableGestures) { gesture in
                    GestureCard(
                        gesture: gesture,
                        isSelected: customizationService.selectedGesture?.id == gesture.id
                    ) {
                        customizationService.selectedGesture = gesture
                    }
                }
            }
        }
    }
    
    // MARK: - Effect Section
    
    private var effectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Effects", icon: "star.fill")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(customizationService.availableEffects) { effect in
                    EffectCard(
                        effect: effect,
                        isSelected: customizationService.selectedEffects.contains(effect)
                    ) {
                        if customizationService.selectedEffects.contains(effect) {
                            customizationService.selectedEffects.remove(effect)
                        } else {
                            customizationService.selectedEffects.insert(effect)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Settings", icon: "gearshape.fill")
            
            VStack(spacing: 16) {
                SettingToggle(
                    title: "Haptic Feedback",
                    description: "Vibration feedback for interactions",
                    isOn: $customizationService.enableHapticFeedback
                )
                
                SettingToggle(
                    title: "Visual Effects",
                    description: "Screen visual effects",
                    isOn: $customizationService.enableVisualEffects
                )
                
                SettingToggle(
                    title: "Sound Effects",
                    description: "Additional sound effects",
                    isOn: $customizationService.enableSoundEffects
                )
                
                SettingToggle(
                    title: "Gesture Control",
                    description: "Gesture-based alarm control",
                    isOn: $customizationService.enableGestureControl
                )
                
                SettingToggle(
                    title: "Smart Wake-up",
                    description: "AI-powered wake-up optimization",
                    isOn: $customizationService.enableSmartWakeUp
                )
            }
        }
    }
    
    // MARK: - Apply Button
    
    private var applyButton: some View {
        Button(action: {
            customizationService.saveUserPreferences()
            dismiss()
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Apply Customization")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: AlarmTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: theme.iconName)
                    .font(.system(size: 30))
                    .foregroundColor(theme.primaryColor)
                
                Text(theme.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(theme.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? theme.primaryColor.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? theme.primaryColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sound Card

struct SoundCard: View {
    let sound: AlarmSound
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                
                Text(sound.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(sound.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(sound.category.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Animation Card

struct AnimationCard: View {
    let animation: AlarmAnimation
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 30))
                    .foregroundColor(.purple)
                
                Text(animation.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(animation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Gesture Card

struct GestureCard: View {
    let gesture: AlarmGesture
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.green)
                
                Text(gesture.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(gesture.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Effect Card

struct EffectCard: View {
    let effect: AlarmEffect
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.orange)
                
                Text(effect.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(effect.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Setting Toggle

struct SettingToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Preview

#Preview {
    AlarmCustomizationView()
}
