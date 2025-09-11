import XCTest
import SwiftUI
@testable import StartSmart

// MARK: - Alarm UI Tests
final class AlarmUITests: XCTestCase {
    
    var mockAlarmRepository: MockAlarmRepository!
    var mockNotificationService: MockNotificationService!
    
    override func setUp() {
        super.setUp()
        mockAlarmRepository = MockAlarmRepository()
        mockNotificationService = MockNotificationService()
        mockNotificationService.permissionStatus = .authorized
    }
    
    override func tearDown() {
        mockNotificationService = nil
        mockAlarmRepository = nil
        super.tearDown()
    }
    
    // MARK: - AlarmFormViewModel Tests
    func testAlarmFormViewModel_Initialization() {
        // Given
        let viewModel = AlarmFormViewModel()
        
        // Then
        XCTAssertEqual(viewModel.label, "Wake up")
        XCTAssertTrue(viewModel.isEnabled)
        XCTAssertTrue(viewModel.repeatDays.isEmpty)
        XCTAssertEqual(viewModel.tone, .energetic)
        XCTAssertTrue(viewModel.snoozeEnabled)
        XCTAssertEqual(viewModel.snoozeDuration, 300) // 5 minutes
        XCTAssertEqual(viewModel.maxSnoozeCount, 3)
        XCTAssertFalse(viewModel.isEditing)
    }
    
    func testAlarmFormViewModel_InitializationWithAlarm() {
        // Given
        let alarm = createTestAlarm()
        let viewModel = AlarmFormViewModel(alarm: alarm)
        
        // Then
        XCTAssertEqual(viewModel.time, alarm.time)
        XCTAssertEqual(viewModel.label, alarm.label)
        XCTAssertEqual(viewModel.isEnabled, alarm.isEnabled)
        XCTAssertEqual(viewModel.repeatDays, alarm.repeatDays)
        XCTAssertEqual(viewModel.tone, alarm.tone)
        XCTAssertEqual(viewModel.snoozeEnabled, alarm.snoozeEnabled)
        XCTAssertEqual(viewModel.snoozeDuration, alarm.snoozeDuration)
        XCTAssertEqual(viewModel.maxSnoozeCount, alarm.maxSnoozeCount)
        XCTAssertTrue(viewModel.isEditing)
    }
    
    func testAlarmFormViewModel_CreateAlarm_NewAlarm() {
        // Given
        let viewModel = AlarmFormViewModel()
        viewModel.label = "Test Alarm"
        viewModel.tone = .gentle
        viewModel.repeatDays = [.monday, .friday]
        
        // When
        let alarm = viewModel.createAlarm()
        
        // Then
        XCTAssertEqual(alarm.label, "Test Alarm")
        XCTAssertEqual(alarm.tone, .gentle)
        XCTAssertEqual(alarm.repeatDays, [.monday, .friday])
        XCTAssertTrue(alarm.isEnabled)
    }
    
    func testAlarmFormViewModel_CreateAlarm_EditingExisting() {
        // Given
        let originalAlarm = createTestAlarm()
        let viewModel = AlarmFormViewModel(alarm: originalAlarm)
        viewModel.label = "Updated Label"
        viewModel.tone = .storyteller
        
        // When
        let updatedAlarm = viewModel.createAlarm()
        
        // Then
        XCTAssertEqual(updatedAlarm.id, originalAlarm.id) // Should keep same ID
        XCTAssertEqual(updatedAlarm.label, "Updated Label")
        XCTAssertEqual(updatedAlarm.tone, .storyteller)
    }
    
    func testAlarmFormViewModel_ToggleRepeatDay() {
        // Given
        let viewModel = AlarmFormViewModel()
        XCTAssertFalse(viewModel.repeatDays.contains(.monday))
        
        // When - Add day
        viewModel.toggleRepeatDay(.monday)
        
        // Then
        XCTAssertTrue(viewModel.repeatDays.contains(.monday))
        
        // When - Remove day
        viewModel.toggleRepeatDay(.monday)
        
        // Then
        XCTAssertFalse(viewModel.repeatDays.contains(.monday))
    }
    
    func testAlarmFormViewModel_Validation_Success() {
        // Given
        let viewModel = AlarmFormViewModel()
        viewModel.label = "Valid Alarm"
        viewModel.snoozeDuration = 600 // 10 minutes
        viewModel.maxSnoozeCount = 5
        
        // When
        let isValid = viewModel.validate()
        
        // Then
        XCTAssertTrue(isValid)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testAlarmFormViewModel_Validation_EmptyLabel() {
        // Given
        let viewModel = AlarmFormViewModel()
        viewModel.label = "   " // Empty/whitespace only
        
        // When
        let isValid = viewModel.validate()
        
        // Then
        XCTAssertFalse(isValid)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("empty"))
    }
    
    func testAlarmFormViewModel_Validation_InvalidSnoozeDuration() {
        // Given
        let viewModel = AlarmFormViewModel()
        viewModel.snoozeDuration = 30 // Too short (30 seconds)
        
        // When
        let isValid = viewModel.validate()
        
        // Then
        XCTAssertFalse(isValid)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("duration"))
    }
    
    func testAlarmFormViewModel_Validation_InvalidMaxSnoozeCount() {
        // Given
        let viewModel = AlarmFormViewModel()
        viewModel.maxSnoozeCount = 15 // Too high
        
        // When
        let isValid = viewModel.validate()
        
        // Then
        XCTAssertFalse(isValid)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("snooze count"))
    }
    
    func testAlarmFormViewModel_Reset() {
        // Given
        let viewModel = AlarmFormViewModel()
        viewModel.label = "Test"
        viewModel.repeatDays = [.monday]
        viewModel.tone = .toughLove
        viewModel.isEditing = true
        
        // When
        viewModel.reset()
        
        // Then
        XCTAssertEqual(viewModel.label, "Wake up")
        XCTAssertTrue(viewModel.repeatDays.isEmpty)
        XCTAssertEqual(viewModel.tone, .energetic)
        XCTAssertFalse(viewModel.isEditing)
    }
    
    // MARK: - Display String Tests
    func testAlarmFormViewModel_TimeDisplayString() {
        // Given
        let calendar = Calendar.current
        let components = DateComponents(hour: 7, minute: 30)
        let time = calendar.date(from: components)!
        
        let viewModel = AlarmFormViewModel()
        viewModel.time = time
        
        // When
        let displayString = viewModel.timeDisplayString
        
        // Then
        XCTAssertTrue(displayString.contains("7:30") || displayString.contains("7.30"))
    }
    
    func testAlarmFormViewModel_RepeatDaysDisplayString() {
        let viewModel = AlarmFormViewModel()
        
        // Test empty (Never)
        XCTAssertEqual(viewModel.repeatDaysDisplayString, "Never")
        
        // Test all days (Every day)
        viewModel.repeatDays = Set(WeekDay.allCases)
        XCTAssertEqual(viewModel.repeatDaysDisplayString, "Every day")
        
        // Test weekdays
        viewModel.repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
        XCTAssertEqual(viewModel.repeatDaysDisplayString, "Weekdays")
        
        // Test weekends
        viewModel.repeatDays = [.saturday, .sunday]
        XCTAssertEqual(viewModel.repeatDaysDisplayString, "Weekends")
        
        // Test custom selection
        viewModel.repeatDays = [.monday, .wednesday]
        let displayString = viewModel.repeatDaysDisplayString
        XCTAssertTrue(displayString.contains("Mon"))
        XCTAssertTrue(displayString.contains("Wed"))
    }
    
    func testAlarmFormViewModel_SnoozeDurationDisplayString() {
        let viewModel = AlarmFormViewModel()
        
        // Test singular
        viewModel.snoozeDuration = 60 // 1 minute
        XCTAssertEqual(viewModel.snoozeDurationDisplayString, "1 minute")
        
        // Test plural
        viewModel.snoozeDuration = 300 // 5 minutes
        XCTAssertEqual(viewModel.snoozeDurationDisplayString, "5 minutes")
    }
    
    // MARK: - Alarm Model Tests for UI
    func testAlarmModel_TimeDisplayString() {
        // Given
        let calendar = Calendar.current
        let components = DateComponents(hour: 14, minute: 45) // 2:45 PM
        let time = calendar.date(from: components)!
        let alarm = Alarm(time: time)
        
        // When
        let displayString = alarm.timeDisplayString
        
        // Then
        XCTAssertTrue(displayString.contains("2:45") || displayString.contains("14:45"))
    }
    
    func testAlarmModel_RepeatDaysDisplayString() {
        var alarm = Alarm(time: Date())
        
        // Test no repeat days
        XCTAssertEqual(alarm.repeatDaysDisplayString, "Once")
        
        // Test all days
        alarm.repeatDays = Set(WeekDay.allCases)
        XCTAssertEqual(alarm.repeatDaysDisplayString, "Every day")
        
        // Test weekdays
        alarm.repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
        XCTAssertEqual(alarm.repeatDaysDisplayString, "Weekdays")
        
        // Test weekends
        alarm.repeatDays = [.saturday, .sunday]
        XCTAssertEqual(alarm.repeatDaysDisplayString, "Weekends")
        
        // Test custom
        alarm.repeatDays = [.monday, .wednesday, .friday]
        let displayString = alarm.repeatDaysDisplayString
        XCTAssertTrue(displayString.contains("Mon"))
        XCTAssertTrue(displayString.contains("Wed"))
        XCTAssertTrue(displayString.contains("Fri"))
    }
    
    func testAlarmModel_NextTriggerDate() {
        let calendar = Calendar.current
        let now = Date()
        
        // Test one-time alarm in future
        let futureTime = calendar.date(byAdding: .hour, value: 2, to: now)!
        let alarm = Alarm(time: futureTime)
        
        XCTAssertNotNil(alarm.nextTriggerDate)
        XCTAssertTrue(alarm.nextTriggerDate! > now)
        
        // Test disabled alarm
        var disabledAlarm = alarm
        disabledAlarm.toggle()
        XCTAssertNil(disabledAlarm.nextTriggerDate)
    }
    
    func testAlarmModel_CanSnooze() {
        var alarm = createTestAlarm()
        
        // Test can snooze initially
        XCTAssertTrue(alarm.canSnooze)
        
        // Test after max snoozes
        for _ in 0..<alarm.maxSnoozeCount {
            alarm.snooze()
        }
        XCTAssertFalse(alarm.canSnooze)
        
        // Test with snooze disabled
        var noSnoozeAlarm = createTestAlarm()
        noSnoozeAlarm.snoozeEnabled = false
        XCTAssertFalse(noSnoozeAlarm.canSnooze)
    }
    
    // MARK: - WeekDay Tests
    func testWeekDay_Initialization() {
        // Test calendar weekday conversion
        XCTAssertEqual(WeekDay(from: 1), .sunday)
        XCTAssertEqual(WeekDay(from: 2), .monday)
        XCTAssertEqual(WeekDay(from: 7), .saturday)
        
        // Test invalid weekday defaults to sunday
        XCTAssertEqual(WeekDay(from: 8), .sunday)
        XCTAssertEqual(WeekDay(from: 0), .sunday)
    }
    
    func testWeekDay_DisplayNames() {
        XCTAssertEqual(WeekDay.monday.name, "Monday")
        XCTAssertEqual(WeekDay.monday.shortName, "Mon")
        
        XCTAssertEqual(WeekDay.friday.name, "Friday")
        XCTAssertEqual(WeekDay.friday.shortName, "Fri")
    }
    
    func testWeekDay_Sorting() {
        let unsortedDays: [WeekDay] = [.friday, .monday, .sunday, .wednesday]
        let sortedDays = unsortedDays.sorted()
        
        XCTAssertEqual(sortedDays, [.sunday, .monday, .wednesday, .friday])
    }
    
    // MARK: - AlarmTone Tests
    func testAlarmTone_Properties() {
        // Test all tones have required properties
        for tone in AlarmTone.allCases {
            XCTAssertFalse(tone.displayName.isEmpty)
            XCTAssertFalse(tone.description.isEmpty)
            XCTAssertFalse(tone.voiceId.isEmpty)
            XCTAssertEqual(tone.voiceId, tone.rawValue)
        }
    }
    
    // MARK: - UI Component Integration Tests
    func testAlarmViewModel_Integration() async {
        // Given
        let viewModel = AlarmViewModel(alarmRepository: mockAlarmRepository)
        let testAlarm = createTestAlarm()
        
        // When
        viewModel.addAlarm(testAlarm)
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(mockAlarmRepository.alarmsValue.count, 1)
        XCTAssertEqual(mockAlarmRepository.alarmsValue.first?.id, testAlarm.id)
    }
    
    func testAlarmViewModel_ErrorHandling() async {
        // Given
        let viewModel = AlarmViewModel(alarmRepository: mockAlarmRepository)
        mockAlarmRepository.shouldThrowError = true
        mockAlarmRepository.errorToThrow = .storageError("Test error")
        
        let testAlarm = createTestAlarm()
        
        // When
        viewModel.addAlarm(testAlarm)
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Test error"))
    }
    
    // MARK: - Performance Tests
    func testAlarmFormViewModel_PerformanceWithManyRepeatDays() {
        let viewModel = AlarmFormViewModel()
        
        measure {
            for _ in 0..<1000 {
                for day in WeekDay.allCases {
                    viewModel.toggleRepeatDay(day)
                    viewModel.toggleRepeatDay(day) // Toggle back
                }
            }
        }
    }
    
    func testAlarmModel_NextTriggerDatePerformance() {
        let alarms = (0..<100).map { index in
            var alarm = Alarm(time: Calendar.current.date(byAdding: .minute, value: index, to: Date())!)
            alarm.repeatDays = [.monday, .wednesday, .friday]
            return alarm
        }
        
        measure {
            for alarm in alarms {
                _ = alarm.nextTriggerDate
            }
        }
    }
    
    // MARK: - Edge Cases
    func testAlarmFormViewModel_ExtremeValues() {
        let viewModel = AlarmFormViewModel()
        
        // Test extreme snooze duration
        viewModel.snoozeDuration = 0.5 // 0.5 seconds
        XCTAssertFalse(viewModel.validate())
        
        viewModel.snoozeDuration = 3600 // 1 hour
        XCTAssertFalse(viewModel.validate())
        
        // Test extreme max snooze count
        viewModel.snoozeDuration = 300 // Reset to valid
        viewModel.maxSnoozeCount = 0
        XCTAssertFalse(viewModel.validate())
        
        viewModel.maxSnoozeCount = 100
        XCTAssertFalse(viewModel.validate())
    }
    
    func testAlarmModel_TimezoneHandling() {
        // Given
        let calendar = Calendar.current
        let components = DateComponents(
            timeZone: TimeZone(identifier: "America/New_York"),
            year: 2024,
            month: 1,
            day: 1,
            hour: 9,
            minute: 0
        )
        
        guard let time = calendar.date(from: components) else {
            XCTFail("Could not create date")
            return
        }
        
        let alarm = Alarm(time: time)
        
        // When
        let displayString = alarm.timeDisplayString
        
        // Then
        XCTAssertFalse(displayString.isEmpty)
        // The display string should work regardless of timezone
    }
    
    // MARK: - Helper Methods
    private func createTestAlarm() -> Alarm {
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        return Alarm(
            time: futureTime,
            label: "Test Alarm",
            tone: .energetic,
            snoozeEnabled: true,
            maxSnoozeCount: 3
        )
    }
}
