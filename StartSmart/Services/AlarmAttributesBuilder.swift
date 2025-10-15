import Foundation
import AlarmKit

/// Builder for creating AlarmAttributes for StartSmart alarms
/// This maps StartSmart alarm preferences to AlarmKit attributes
/// Based on Apple's AlarmKit documentation for iOS 26+
class AlarmAttributesBuilder {
    private var title: String = "Wake up"
    private var sound: String = "Classic.caf"
    private var isRepeating: Bool = false
    private var repeatDays: Set<WeekDay> = []
    private var snoozeEnabled: Bool = true
    private var snoozeDuration: TimeInterval = 300 // 5 minutes
    private var customSound: String?
    private var interruptionLevel: AlarmInterruptionLevel = .timeSensitive
    private var bypassSilentMode: Bool = true
    
    init() {}
    
    // MARK: - Builder Methods
    
    func title(_ title: String) -> AlarmAttributesBuilder {
        self.title = title
        return self
    }
    
    func sound(_ sound: String) -> AlarmAttributesBuilder {
        self.sound = sound
        return self
    }
    
    func isRepeating(_ isRepeating: Bool) -> AlarmAttributesBuilder {
        self.isRepeating = isRepeating
        return self
    }
    
    func repeatDays(_ repeatDays: Set<WeekDay>) -> AlarmAttributesBuilder {
        self.repeatDays = repeatDays
        return self
    }
    
    func snoozeEnabled(_ snoozeEnabled: Bool) -> AlarmAttributesBuilder {
        self.snoozeEnabled = snoozeEnabled
        return self
    }
    
    func snoozeDuration(_ snoozeDuration: TimeInterval) -> AlarmAttributesBuilder {
        self.snoozeDuration = snoozeDuration
        return self
    }
    
    func customSound(_ customSound: String) -> AlarmAttributesBuilder {
        self.customSound = customSound
        return self
    }
    
    func interruptionLevel(_ level: AlarmInterruptionLevel) -> AlarmAttributesBuilder {
        self.interruptionLevel = level
        return self
    }
    
    func bypassSilentMode(_ bypass: Bool) -> AlarmAttributesBuilder {
        self.bypassSilentMode = bypass
        return self
    }
    
    // MARK: - Build Method
    
    func build() throws -> AlarmAttributes {
        // Create AlarmAttributes using the AlarmKit API
        // Based on Apple's documentation, AlarmAttributes is created with required parameters
        let attributes = AlarmAttributes(
            title: title,
            sound: customSound ?? sound,
            isRepeating: isRepeating,
            snoozeEnabled: snoozeEnabled,
            snoozeDuration: snoozeDuration,
            interruptionLevel: interruptionLevel,
            bypassSilentMode: bypassSilentMode
        )
        
        // Set repeat days if repeating
        if isRepeating && !repeatDays.isEmpty {
            attributes.repeatDays = convertWeekDaysToAlarmKit(repeatDays)
        }
        
        // Validate the attributes
        try validateAttributes(attributes)
        
        return attributes
    }
    
    // MARK: - Helper Methods
    
    private func convertWeekDaysToAlarmKit(_ weekDays: Set<WeekDay>) -> Set<AlarmKit.WeekDay> {
        return Set(weekDays.map { weekDay in
            switch weekDay {
            case .sunday: return AlarmKit.WeekDay.sunday
            case .monday: return AlarmKit.WeekDay.monday
            case .tuesday: return AlarmKit.WeekDay.tuesday
            case .wednesday: return AlarmKit.WeekDay.wednesday
            case .thursday: return AlarmKit.WeekDay.thursday
            case .friday: return AlarmKit.WeekDay.friday
            case .saturday: return AlarmKit.WeekDay.saturday
            }
        })
    }
    
    private func validateAttributes(_ attributes: AlarmAttributes) throws {
        // Validate title is not empty
        guard !attributes.title.isEmpty else {
            throw AlarmKitError.invalidAlarmConfiguration
        }
        
        // Validate snooze duration is reasonable
        guard attributes.snoozeDuration > 0 && attributes.snoozeDuration <= 3600 else {
            throw AlarmKitError.invalidAlarmConfiguration
        }
        
        // Validate repeat days if repeating
        if attributes.isRepeating && attributes.repeatDays.isEmpty {
            throw AlarmKitError.invalidAlarmConfiguration
        }
    }
}
