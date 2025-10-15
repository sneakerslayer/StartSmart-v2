import Foundation
import SwiftUI
import os.log

// MARK: - Advanced Alarm Customization Service

/// Service for managing advanced alarm customization options
@MainActor
class AdvancedAlarmCustomizationService: ObservableObject {
    static let shared = AdvancedAlarmCustomizationService()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "AdvancedAlarmCustomizationService")
    
    // MARK: - Customization Options
    
    @Published var availableThemes: [AlarmTheme] = []
    @Published var availableSounds: [AlarmSound] = []
    @Published var availableAnimations: [AlarmAnimation] = []
    @Published var availableGestures: [AlarmGesture] = []
    @Published var availableEffects: [AlarmEffect] = []
    
    // MARK: - User Preferences
    
    @Published var selectedTheme: AlarmTheme?
    @Published var selectedSound: AlarmSound?
    @Published var selectedAnimation: AlarmAnimation?
    @Published var selectedGesture: AlarmGesture?
    @Published var selectedEffects: Set<AlarmEffect> = []
    
    // MARK: - Customization Settings
    
    @Published var enableHapticFeedback: Bool = true
    @Published var enableVisualEffects: Bool = true
    @Published var enableSoundEffects: Bool = true
    @Published var enableGestureControl: Bool = true
    @Published var enableSmartWakeUp: Bool = true
    
    private init() {
        logger.info("🎨 AdvancedAlarmCustomizationService initialized")
        loadDefaultCustomizations()
        loadUserPreferences()
    }
    
    // MARK: - Default Customizations
    
    private func loadDefaultCustomizations() {
        loadDefaultThemes()
        loadDefaultSounds()
        loadDefaultAnimations()
        loadDefaultGestures()
        loadDefaultEffects()
    }
    
    private func loadDefaultThemes() {
        availableThemes = [
            AlarmTheme(
                id: "classic",
                name: "Classic",
                description: "Traditional alarm clock appearance",
                primaryColor: .blue,
                secondaryColor: .white,
                backgroundColor: .black,
                textColor: .white,
                iconName: "clock.fill"
            ),
            AlarmTheme(
                id: "modern",
                name: "Modern",
                description: "Sleek contemporary design",
                primaryColor: .purple,
                secondaryColor: .white,
                backgroundColor: .gray,
                textColor: .white,
                iconName: "bell.fill"
            ),
            AlarmTheme(
                id: "minimalist",
                name: "Minimalist",
                description: "Clean and simple design",
                primaryColor: .gray,
                secondaryColor: .white,
                backgroundColor: .white,
                textColor: .black,
                iconName: "circle.fill"
            ),
            AlarmTheme(
                id: "nature",
                name: "Nature",
                description: "Calming natural colors",
                primaryColor: .green,
                secondaryColor: .white,
                backgroundColor: .mint,
                textColor: .white,
                iconName: "leaf.fill"
            ),
            AlarmTheme(
                id: "sunset",
                name: "Sunset",
                description: "Warm sunset colors",
                primaryColor: .orange,
                secondaryColor: .white,
                backgroundColor: .red,
                textColor: .white,
                iconName: "sun.max.fill"
            )
        ]
    }
    
    private func loadDefaultSounds() {
        availableSounds = [
            AlarmSound(
                id: "classic",
                name: "Classic",
                description: "Traditional alarm sound",
                fileName: "Classic.caf",
                category: .traditional,
                duration: 30.0,
                volume: 1.0
            ),
            AlarmSound(
                id: "gentle",
                name: "Gentle",
                description: "Soft and gentle wake-up sound",
                fileName: "Gentle.caf",
                category: .gentle,
                duration: 45.0,
                volume: 0.8
            ),
            AlarmSound(
                id: "energetic",
                name: "Energetic",
                description: "High-energy wake-up sound",
                fileName: "Energetic.caf",
                category: .energetic,
                duration: 25.0,
                volume: 1.0
            ),
            AlarmSound(
                id: "nature",
                name: "Nature",
                description: "Natural sounds for peaceful wake-up",
                fileName: "Nature.caf",
                category: .nature,
                duration: 60.0,
                volume: 0.9
            ),
            AlarmSound(
                id: "melodic",
                name: "Melodic",
                description: "Musical wake-up sound",
                fileName: "Melodic.caf",
                category: .melodic,
                duration: 40.0,
                volume: 0.9
            )
        ]
    }
    
    private func loadDefaultAnimations() {
        availableAnimations = [
            AlarmAnimation(
                id: "fade",
                name: "Fade",
                description: "Smooth fade in/out animation",
                type: .fade,
                duration: 1.0,
                easing: .easeInOut
            ),
            AlarmAnimation(
                id: "slide",
                name: "Slide",
                description: "Slide animation from edges",
                type: .slide,
                duration: 0.8,
                easing: .easeOut
            ),
            AlarmAnimation(
                id: "scale",
                name: "Scale",
                description: "Scale animation for emphasis",
                type: .scale,
                duration: 0.6,
                easing: .easeInOut
            ),
            AlarmAnimation(
                id: "bounce",
                name: "Bounce",
                description: "Bouncy animation for attention",
                type: .bounce,
                duration: 1.2,
                easing: .easeOut
            ),
            AlarmAnimation(
                id: "pulse",
                name: "Pulse",
                description: "Pulsing animation for urgency",
                type: .pulse,
                duration: 2.0,
                easing: .easeInOut
            )
        ]
    }
    
    private func loadDefaultGestures() {
        availableGestures = [
            AlarmGesture(
                id: "swipe",
                name: "Swipe",
                description: "Swipe to dismiss alarm",
                type: .swipe,
                direction: .right,
                sensitivity: 0.8
            ),
            AlarmGesture(
                id: "tap",
                name: "Tap",
                description: "Tap to snooze alarm",
                type: .tap,
                direction: .none,
                sensitivity: 1.0
            ),
            AlarmGesture(
                id: "shake",
                name: "Shake",
                description: "Shake device to dismiss",
                type: .shake,
                direction: .none,
                sensitivity: 0.7
            ),
            AlarmGesture(
                id: "double-tap",
                name: "Double Tap",
                description: "Double tap to snooze",
                type: .doubleTap,
                direction: .none,
                sensitivity: 1.0
            ),
            AlarmGesture(
                id: "long-press",
                name: "Long Press",
                description: "Long press to dismiss",
                type: .longPress,
                direction: .none,
                sensitivity: 0.9
            )
        ]
    }
    
    private func loadDefaultEffects() {
        availableEffects = [
            AlarmEffect(
                id: "haptic",
                name: "Haptic Feedback",
                description: "Vibration feedback for interactions",
                type: .haptic,
                intensity: 0.8,
                duration: 0.5
            ),
            AlarmEffect(
                id: "light",
                name: "Light Effect",
                description: "Screen brightness changes",
                type: .light,
                intensity: 0.6,
                duration: 2.0
            ),
            AlarmEffect(
                id: "sound",
                name: "Sound Effect",
                description: "Additional sound effects",
                type: .sound,
                intensity: 0.7,
                duration: 1.0
            ),
            AlarmEffect(
                id: "visual",
                name: "Visual Effect",
                description: "Screen visual effects",
                type: .visual,
                intensity: 0.9,
                duration: 3.0
            ),
            AlarmEffect(
                id: "ambient",
                name: "Ambient Effect",
                description: "Ambient lighting changes",
                type: .ambient,
                intensity: 0.5,
                duration: 5.0
            )
        ]
    }
    
    // MARK: - User Preferences Management
    
    private func loadUserPreferences() {
        // Load saved preferences from UserDefaults
        if let themeData = UserDefaults.standard.data(forKey: "selectedTheme"),
           let theme = try? JSONDecoder().decode(AlarmTheme.self, from: themeData) {
            selectedTheme = theme
        }
        
        if let soundData = UserDefaults.standard.data(forKey: "selectedSound"),
           let sound = try? JSONDecoder().decode(AlarmSound.self, from: soundData) {
            selectedSound = sound
        }
        
        if let animationData = UserDefaults.standard.data(forKey: "selectedAnimation"),
           let animation = try? JSONDecoder().decode(AlarmAnimation.self, from: animationData) {
            selectedAnimation = animation
        }
        
        if let gestureData = UserDefaults.standard.data(forKey: "selectedGesture"),
           let gesture = try? JSONDecoder().decode(AlarmGesture.self, from: gestureData) {
            selectedGesture = gesture
        }
        
        if let effectsData = UserDefaults.standard.data(forKey: "selectedEffects"),
           let effects = try? JSONDecoder().decode(Set<AlarmEffect>.self, from: effectsData) {
            selectedEffects = effects
        }
        
        // Load boolean preferences
        enableHapticFeedback = UserDefaults.standard.bool(forKey: "enableHapticFeedback")
        enableVisualEffects = UserDefaults.standard.bool(forKey: "enableVisualEffects")
        enableSoundEffects = UserDefaults.standard.bool(forKey: "enableSoundEffects")
        enableGestureControl = UserDefaults.standard.bool(forKey: "enableGestureControl")
        enableSmartWakeUp = UserDefaults.standard.bool(forKey: "enableSmartWakeUp")
        
        logger.info("🎨 User preferences loaded successfully")
    }
    
    func saveUserPreferences() {
        // Save preferences to UserDefaults
        if let theme = selectedTheme,
           let themeData = try? JSONEncoder().encode(theme) {
            UserDefaults.standard.set(themeData, forKey: "selectedTheme")
        }
        
        if let sound = selectedSound,
           let soundData = try? JSONEncoder().encode(sound) {
            UserDefaults.standard.set(soundData, forKey: "selectedSound")
        }
        
        if let animation = selectedAnimation,
           let animationData = try? JSONEncoder().encode(animation) {
            UserDefaults.standard.set(animationData, forKey: "selectedAnimation")
        }
        
        if let gesture = selectedGesture,
           let gestureData = try? JSONEncoder().encode(gesture) {
            UserDefaults.standard.set(gestureData, forKey: "selectedGesture")
        }
        
        if let effectsData = try? JSONEncoder().encode(selectedEffects) {
            UserDefaults.standard.set(effectsData, forKey: "selectedEffects")
        }
        
        // Save boolean preferences
        UserDefaults.standard.set(enableHapticFeedback, forKey: "enableHapticFeedback")
        UserDefaults.standard.set(enableVisualEffects, forKey: "enableVisualEffects")
        UserDefaults.standard.set(enableSoundEffects, forKey: "enableSoundEffects")
        UserDefaults.standard.set(enableGestureControl, forKey: "enableGestureControl")
        UserDefaults.standard.set(enableSmartWakeUp, forKey: "enableSmartWakeUp")
        
        logger.info("🎨 User preferences saved successfully")
    }
    
    // MARK: - Customization Application
    
    func applyCustomization(to alarm: StartSmart.Alarm) -> StartSmart.Alarm {
        var customizedAlarm = alarm
        
        // Apply theme
        if let theme = selectedTheme {
            customizedAlarm.customTheme = theme
        }
        
        // Apply sound
        if let sound = selectedSound {
            customizedAlarm.customSound = sound
        }
        
        // Apply animation
        if let animation = selectedAnimation {
            customizedAlarm.customAnimation = animation
        }
        
        // Apply gesture
        if let gesture = selectedGesture {
            customizedAlarm.customGesture = gesture
        }
        
        // Apply effects
        customizedAlarm.customEffects = selectedEffects
        
        // Apply settings
        customizedAlarm.enableHapticFeedback = enableHapticFeedback
        customizedAlarm.enableVisualEffects = enableVisualEffects
        customizedAlarm.enableSoundEffects = enableSoundEffects
        customizedAlarm.enableGestureControl = enableGestureControl
        customizedAlarm.enableSmartWakeUp = enableSmartWakeUp
        
        logger.info("🎨 Customization applied to alarm: \(alarm.label)")
        return customizedAlarm
    }
    
    // MARK: - Customization Validation
    
    func validateCustomization() -> [String] {
        var issues: [String] = []
        
        // Check for conflicting settings
        if enableVisualEffects && selectedTheme?.id == "minimalist" {
            issues.append("Visual effects may conflict with minimalist theme")
        }
        
        if enableSoundEffects && selectedSound?.category == .gentle {
            issues.append("Sound effects may be too loud for gentle sounds")
        }
        
        if enableGestureControl && selectedGesture?.type == .shake {
            issues.append("Shake gesture may interfere with device handling")
        }
        
        return issues
    }
    
    // MARK: - Customization Recommendations
    
    func getCustomizationRecommendations() -> [CustomizationRecommendation] {
        var recommendations: [CustomizationRecommendation] = []
        
        // Theme recommendations
        if selectedTheme?.id == "classic" {
            recommendations.append(CustomizationRecommendation(
                type: .theme,
                title: "Try Modern Theme",
                description: "The modern theme offers a more contemporary look",
                priority: .low
            ))
        }
        
        // Sound recommendations
        if selectedSound?.category == .traditional {
            recommendations.append(CustomizationRecommendation(
                type: .sound,
                title: "Try Gentle Sounds",
                description: "Gentle sounds provide a more peaceful wake-up experience",
                priority: .medium
            ))
        }
        
        // Animation recommendations
        if selectedAnimation?.type == .fade {
            recommendations.append(CustomizationRecommendation(
                type: .animation,
                title: "Try Bounce Animation",
                description: "Bounce animation adds energy to your wake-up routine",
                priority: .low
            ))
        }
        
        // Effect recommendations
        if !selectedEffects.contains(where: { $0.type == .haptic }) {
            recommendations.append(CustomizationRecommendation(
                type: .effect,
                title: "Enable Haptic Feedback",
                description: "Haptic feedback provides tactile confirmation of interactions",
                priority: .high
            ))
        }
        
        return recommendations
    }
}

// MARK: - Customization Models

struct AlarmTheme: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let primaryColor: Color
    let secondaryColor: Color
    let backgroundColor: Color
    let textColor: Color
    let iconName: String
}

struct AlarmSound: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let fileName: String
    let category: SoundCategory
    let duration: TimeInterval
    let volume: Float
    
    enum SoundCategory: String, Codable, CaseIterable {
        case traditional = "traditional"
        case gentle = "gentle"
        case energetic = "energetic"
        case nature = "nature"
        case melodic = "melodic"
    }
}

struct AlarmAnimation: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let type: AnimationType
    let duration: TimeInterval
    let easing: EasingType
    
    enum AnimationType: String, Codable, CaseIterable {
        case fade = "fade"
        case slide = "slide"
        case scale = "scale"
        case bounce = "bounce"
        case pulse = "pulse"
    }
    
    enum EasingType: String, Codable, CaseIterable {
        case easeIn = "easeIn"
        case easeOut = "easeOut"
        case easeInOut = "easeInOut"
        case linear = "linear"
    }
}

struct AlarmGesture: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let type: GestureType
    let direction: GestureDirection
    let sensitivity: Float
    
    enum GestureType: String, Codable, CaseIterable {
        case swipe = "swipe"
        case tap = "tap"
        case shake = "shake"
        case doubleTap = "doubleTap"
        case longPress = "longPress"
    }
    
    enum GestureDirection: String, Codable, CaseIterable {
        case left = "left"
        case right = "right"
        case up = "up"
        case down = "down"
        case none = "none"
    }
}

struct AlarmEffect: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let type: EffectType
    let intensity: Float
    let duration: TimeInterval
    
    enum EffectType: String, Codable, CaseIterable {
        case haptic = "haptic"
        case light = "light"
        case sound = "sound"
        case visual = "visual"
        case ambient = "ambient"
    }
}

struct CustomizationRecommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Priority
    
    enum RecommendationType: String, CaseIterable {
        case theme = "theme"
        case sound = "sound"
        case animation = "animation"
        case gesture = "gesture"
        case effect = "effect"
    }
    
    enum Priority: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
    }
}

// MARK: - Alarm Extensions

extension StartSmart.Alarm {
    var customTheme: AlarmTheme? {
        get { return nil } // Placeholder
        set { } // Placeholder
    }
    
    var customSound: AlarmSound? {
        get { return nil } // Placeholder
        set { } // Placeholder
    }
    
    var customAnimation: AlarmAnimation? {
        get { return nil } // Placeholder
        set { } // Placeholder
    }
    
    var customGesture: AlarmGesture? {
        get { return nil } // Placeholder
        set { } // Placeholder
    }
    
    var customEffects: Set<AlarmEffect> {
        get { return [] } // Placeholder
        set { } // Placeholder
    }
    
    var enableHapticFeedback: Bool {
        get { return true } // Placeholder
        set { } // Placeholder
    }
    
    var enableVisualEffects: Bool {
        get { return true } // Placeholder
        set { } // Placeholder
    }
    
    var enableSoundEffects: Bool {
        get { return true } // Placeholder
        set { } // Placeholder
    }
    
    var enableGestureControl: Bool {
        get { return true } // Placeholder
        set { } // Placeholder
    }
    
    var enableSmartWakeUp: Bool {
        get { return true } // Placeholder
        set { } // Placeholder
    }
}
