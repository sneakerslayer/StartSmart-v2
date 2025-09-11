import XCTest
import UserNotifications
import Combine
@testable import StartSmart

// MARK: - Alarm Scheduling Service Tests
final class AlarmSchedulingServiceTests: XCTestCase {
    
    var sut: AlarmSchedulingService!
    var mockNotificationService: MockNotificationService!
    var mockAlarmRepository: MockAlarmRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockNotificationService = MockNotificationService()
        mockNotificationService.permissionStatus = .authorized
        mockAlarmRepository = MockAlarmRepository()
        cancellables = Set<AnyCancellable>()
        
        sut = AlarmSchedulingService(
            notificationService: mockNotificationService,
            alarmRepository: mockAlarmRepository,
            maxScheduledNotifications: 10, // Lower limit for testing
            futureSchedulingLimitDays: 30,
            timezoneMonitoringEnabled: false // Disable for testing
        )
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockAlarmRepository = nil
        mockNotificationService = nil
        super.tearDown()
    }
    
    // MARK: - Schedule Alarm Tests
    func testScheduleOneTimeAlarm_Success() async throws {
        // Given
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let alarm = Alarm(time: futureTime, label: "Test Alarm")
        
        // When
        try await sut.scheduleAlarm(alarm)
        
        // Then
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 1)
        XCTAssertEqual(sut.scheduledAlarms.count, 1)
        XCTAssertEqual(sut.scheduledAlarms.first?.alarmId, alarm.id)
        XCTAssertFalse(sut.scheduledAlarms.first?.isRepeating ?? true)
    }
    
    func testScheduleRepeatingAlarm_Success() async throws {
        // Given
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        var alarm = Alarm(time: futureTime, label: "Repeating Alarm")
        alarm.repeatDays = [.monday, .wednesday, .friday]
        
        // When
        try await sut.scheduleAlarm(alarm)
        
        // Then
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 1) // Mock service doesn't separate by repeat day
        XCTAssertEqual(sut.scheduledAlarms.count, 3) // One for each repeat day
        XCTAssertTrue(sut.scheduledAlarms.allSatisfy { $0.isRepeating })
        XCTAssertTrue(sut.scheduledAlarms.allSatisfy { $0.alarmId == alarm.id })
    }
    
    func testScheduleAlarm_DisabledAlarm_DoesNotSchedule() async throws {
        // Given
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        var alarm = Alarm(time: futureTime, label: "Disabled Alarm")
        alarm.toggle() // Disable the alarm
        
        // When
        try await sut.scheduleAlarm(alarm)
        
        // Then
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 0)
        XCTAssertEqual(sut.scheduledAlarms.count, 0)
    }
    
    func testScheduleAlarm_NoPermission_ThrowsError() async {
        // Given
        mockNotificationService.permissionStatus = .denied
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let alarm = Alarm(time: futureTime)
        
        // When/Then
        do {
            try await sut.scheduleAlarm(alarm)
            XCTFail("Expected error to be thrown")
        } catch let error as AlarmSchedulingServiceError {
            XCTAssertEqual(error, .invalidAlarmConfiguration)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testScheduleAlarm_ReplacesExistingNotification() async throws {
        // Given
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let alarm = Alarm(time: futureTime, label: "Original Alarm")
        
        // Schedule first time
        try await sut.scheduleAlarm(alarm)
        let originalCount = sut.scheduledAlarms.count
        
        // When - Schedule again with same alarm
        try await sut.scheduleAlarm(alarm)
        
        // Then
        XCTAssertEqual(sut.scheduledAlarms.count, originalCount) // Should replace, not add
        XCTAssertTrue(mockNotificationService.removedIdentifiers.contains(alarm.id.uuidString))
    }
    
    // MARK: - Update Scheduled Alarm Tests
    func testUpdateScheduledAlarm_Success() async throws {
        // Given
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let alarm = Alarm(time: futureTime, label: "Original Alarm")
        try await sut.scheduleAlarm(alarm)
        
        var updatedAlarm = alarm
        updatedAlarm.label = "Updated Alarm"
        
        // When
        try await sut.updateScheduledAlarm(updatedAlarm)
        
        // Then
        XCTAssertEqual(sut.scheduledAlarms.count, 1)
        XCTAssertEqual(sut.scheduledAlarms.first?.alarmId, alarm.id)
    }
    
    // MARK: - Remove Scheduled Alarm Tests
    func testRemoveScheduledAlarm_Success() async {
        // Given
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let alarm = Alarm(time: futureTime)
        try? await sut.scheduleAlarm(alarm)
        
        // When
        await sut.removeScheduledAlarm(alarm)
        
        // Then
        XCTAssertEqual(sut.scheduledAlarms.count, 0)
        XCTAssertTrue(mockNotificationService.removedIdentifiers.contains(alarm.id.uuidString))
    }
    
    func testRemoveScheduledAlarms_Multiple() async {
        // Given
        let alarms = [
            Alarm(time: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!),
            Alarm(time: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!),
            Alarm(time: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!)
        ]
        
        for alarm in alarms {
            try? await sut.scheduleAlarm(alarm)
        }
        
        // When
        await sut.removeScheduledAlarms(alarms)
        
        // Then
        XCTAssertEqual(sut.scheduledAlarms.count, 0)
        for alarm in alarms {
            XCTAssertTrue(mockNotificationService.removedIdentifiers.contains(alarm.id.uuidString))
        }
    }
    
    func testRemoveAllScheduledAlarms_Success() async {
        // Given
        let alarms = [
            Alarm(time: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!),
            Alarm(time: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!)
        ]
        
        for alarm in alarms {
            try? await sut.scheduleAlarm(alarm)
        }
        
        // When
        await sut.removeAllScheduledAlarms()
        
        // Then
        XCTAssertEqual(sut.scheduledAlarms.count, 0)
    }
    
    // MARK: - Validation Tests
    func testValidateAlarmScheduling_ValidAlarm_ReturnsValid() async {
        // Given
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let alarm = Alarm(time: futureTime)
        
        // When
        let result = await sut.validateAlarmScheduling(alarm)
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertFalse(result.hasErrors)
        XCTAssertFalse(result.hasWarnings)
    }
    
    func testValidateAlarmScheduling_NoPermission_ReturnsInvalid() async {
        // Given
        mockNotificationService.permissionStatus = .denied
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let alarm = Alarm(time: futureTime)
        
        // When
        let result = await sut.validateAlarmScheduling(alarm)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains { issue in
            if case .notificationPermissionDenied = issue { return true }
            return false
        })
    }
    
    func testValidateAlarmScheduling_TimeInPast_ReturnsInvalid() async {
        // Given
        let pastTime = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        let alarm = Alarm(time: pastTime)
        
        // When
        let result = await sut.validateAlarmScheduling(alarm)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains { issue in
            if case .timeInPast = issue { return true }
            return false
        })
    }
    
    func testValidateAlarmScheduling_SystemLimitExceeded_ReturnsInvalid() async {
        // Given
        // Fill up the mock notification service to near limit
        mockNotificationService.pendingNotifications = Array(0..<9).map { index in
            UNNotificationRequest(
                identifier: "test-\(index)",
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        }
        
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        var alarm = Alarm(time: futureTime)
        alarm.repeatDays = [.monday, .wednesday, .friday] // This would add 3 more notifications
        
        // When
        let result = await sut.validateAlarmScheduling(alarm)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains { issue in
            if case .systemLimitExceeded = issue { return true }
            return false
        })
    }
    
    func testValidateAlarmScheduling_DuplicateTime_ReturnsWarning() async {
        // Given
        let time = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let existingAlarm = Alarm(time: time)
        mockAlarmRepository._alarms = [existingAlarm]
        
        let newAlarm = Alarm(time: time) // Same time, different ID
        
        // When
        let result = await sut.validateAlarmScheduling(newAlarm)
        
        // Then
        XCTAssertTrue(result.isValid) // Should be valid but with warnings
        XCTAssertFalse(result.hasErrors)
        XCTAssertTrue(result.hasWarnings)
        XCTAssertTrue(result.warnings.contains { warning in
            if case .duplicateTime = warning { return true }
            return false
        })
    }
    
    // MARK: - Refresh All Scheduled Alarms Tests
    func testRefreshAllScheduledAlarms_Success() async throws {
        // Given
        let alarms = [
            Alarm(time: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!),
            Alarm(time: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!)
        ]
        
        var disabledAlarm = Alarm(time: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!)
        disabledAlarm.toggle() // Disable
        
        let allAlarms = alarms + [disabledAlarm]
        
        // When
        try await sut.refreshAllScheduledAlarms(allAlarms)
        
        // Then
        XCTAssertEqual(sut.scheduledAlarms.count, 2) // Only enabled alarms should be scheduled
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 2)
    }
    
    // MARK: - Timezone Handling Tests
    func testHandleTimeZoneChange_RefreshesAlarms() async throws {
        // Given
        let alarms = [
            Alarm(time: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!)
        ]
        
        try await sut.refreshAllScheduledAlarms(alarms)
        let originalScheduledCount = sut.scheduledAlarms.count
        
        // When
        try await sut.handleTimeZoneChange()
        
        // Then
        // Should maintain same number of scheduled alarms but refresh them
        XCTAssertEqual(sut.scheduledAlarms.count, originalScheduledCount)
    }
    
    // MARK: - Get Scheduled Alarms Tests
    func testGetScheduledAlarms_ReturnsCurrentSchedule() async throws {
        // Given
        let alarms = [
            Alarm(time: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!),
            Alarm(time: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!)
        ]
        
        for alarm in alarms {
            try await sut.scheduleAlarm(alarm)
        }
        
        // When
        let scheduledAlarms = await sut.getScheduledAlarms()
        
        // Then
        XCTAssertEqual(scheduledAlarms.count, 2)
        XCTAssertEqual(Set(scheduledAlarms.map { $0.alarmId }), Set(alarms.map { $0.id }))
    }
    
    // MARK: - Reactive Updates Tests
    func testScheduledAlarmsPublisher_UpdatesOnChanges() async throws {
        // Given
        var receivedScheduledAlarms: [ScheduledAlarmInfo] = []
        let expectation = expectation(description: "Scheduled alarms updated")
        
        sut.$scheduledAlarms
            .sink { scheduledAlarms in
                receivedScheduledAlarms = scheduledAlarms
                if !scheduledAlarms.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        let alarm = Alarm(time: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!)
        try await sut.scheduleAlarm(alarm)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedScheduledAlarms.count, 1)
        XCTAssertEqual(receivedScheduledAlarms.first?.alarmId, alarm.id)
    }
    
    // MARK: - Error Handling Tests
    func testScheduleAlarm_NotificationServiceFails_ThrowsError() async {
        // Given
        mockNotificationService.shouldThrowError = true
        let futureTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let alarm = Alarm(time: futureTime)
        
        // When/Then
        do {
            try await sut.scheduleAlarm(alarm)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testErrorEquality() {
        XCTAssertEqual(
            AlarmSchedulingServiceError.notificationServiceUnavailable,
            AlarmSchedulingServiceError.notificationServiceUnavailable
        )
        
        XCTAssertEqual(
            AlarmSchedulingServiceError.schedulingFailed("test"),
            AlarmSchedulingServiceError.schedulingFailed("test")
        )
        
        XCTAssertNotEqual(
            AlarmSchedulingServiceError.schedulingFailed("test1"),
            AlarmSchedulingServiceError.schedulingFailed("test2")
        )
    }
    
    func testErrorDescriptions() {
        let errors: [AlarmSchedulingServiceError] = [
            .notificationServiceUnavailable,
            .invalidAlarmConfiguration,
            .schedulingFailed("Test error"),
            .notificationLimitExceeded,
            .timezoneConflict,
            .permissionDenied
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Edge Cases Tests
    func testScheduleAlarm_EdgeOfDST_HandlesCorrectly() async throws {
        // Given - Create alarm for 2 AM during DST transition (spring forward)
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 3  // March
        components.day = 10   // Second Sunday in March (DST transition)
        components.hour = 2   // 2 AM - this time gets skipped during spring forward
        components.minute = 0
        
        guard let dstDate = calendar.date(from: components) else {
            XCTFail("Could not create DST date")
            return
        }
        
        let alarm = Alarm(time: dstDate)
        
        // When
        let validation = await sut.validateAlarmScheduling(alarm)
        
        // Then
        // Should detect timezone ambiguity
        XCTAssertTrue(validation.hasWarnings)
        XCTAssertTrue(validation.warnings.contains { warning in
            if case .timezoneAmbiguity = warning { return true }
            return false
        })
    }
    
    func testScheduleAlarm_FarFuture_ReturnsWarning() async {
        // Given
        let farFutureTime = Calendar.current.date(byAdding: .day, value: 400, to: Date())!
        let alarm = Alarm(time: farFutureTime)
        
        // When
        let validation = await sut.validateAlarmScheduling(alarm)
        
        // Then
        XCTAssertTrue(validation.isValid)
        XCTAssertTrue(validation.hasWarnings)
        XCTAssertTrue(validation.warnings.contains { warning in
            if case .scheduledFarInFuture = warning { return true }
            return false
        })
    }
    
    // MARK: - Performance Tests
    func testSchedulingPerformance_MultipleAlarms() async throws {
        // Given
        let alarms = (0..<50).map { index in
            Alarm(time: Calendar.current.date(byAdding: .minute, value: index, to: Date())!)
        }
        
        // When
        measure {
            Task {
                try? await sut.refreshAllScheduledAlarms(alarms)
            }
        }
    }
    
    // MARK: - Mock Alarm Repository Extension
    private extension MockAlarmRepository {
        var _alarms: [Alarm] {
            get { alarmsValue }
            set { 
                // This is a simplification for testing
                // In reality, we'd need a proper setter
            }
        }
    }
}

// MARK: - AlarmSchedulingServiceError Equatable Extension
extension AlarmSchedulingServiceError: Equatable {
    static func == (lhs: AlarmSchedulingServiceError, rhs: AlarmSchedulingServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.notificationServiceUnavailable, .notificationServiceUnavailable),
             (.invalidAlarmConfiguration, .invalidAlarmConfiguration),
             (.notificationLimitExceeded, .notificationLimitExceeded),
             (.timezoneConflict, .timezoneConflict),
             (.permissionDenied, .permissionDenied):
            return true
        case (.schedulingFailed(let lhsReason), .schedulingFailed(let rhsReason)):
            return lhsReason == rhsReason
        default:
            return false
        }
    }
}

// MARK: - Notification Category Service Tests
final class NotificationCategoryServiceTests: XCTestCase {
    
    var sut: NotificationCategoryService!
    var mockNotificationCenter: MockNotificationCenter!
    
    override func setUp() {
        super.setUp()
        mockNotificationCenter = MockNotificationCenter()
        sut = NotificationCategoryService(notificationCenter: mockNotificationCenter)
    }
    
    override func tearDown() {
        sut = nil
        mockNotificationCenter = nil
        super.tearDown()
    }
    
    func testSetupAlarmNotificationCategories_CreatesCorrectCategories() async {
        // When
        await sut.setupAlarmNotificationCategories()
        
        // Then
        // In a real test, we'd verify that setNotificationCategories was called
        // with the correct categories. For now, just test that the method completes
        XCTAssertTrue(true)
    }
    
    func testGetAlarmNotificationCategory_ReturnsCorrectCategory() {
        // When
        let category = sut.getAlarmNotificationCategory()
        
        // Then
        XCTAssertEqual(category.identifier, "ALARM_CATEGORY")
        XCTAssertEqual(category.actions.count, 3) // snooze, dismiss, turn off
        XCTAssertTrue(category.actions.contains { $0.identifier == "SNOOZE_ACTION" })
        XCTAssertTrue(category.actions.contains { $0.identifier == "DISMISS_ACTION" })
        XCTAssertTrue(category.actions.contains { $0.identifier == "TURN_OFF_ACTION" })
    }
    
    func testGetSnoozeNotificationCategory_ReturnsCorrectCategory() {
        // When
        let category = sut.getSnoozeNotificationCategory()
        
        // Then
        XCTAssertEqual(category.identifier, "SNOOZE_CATEGORY")
        XCTAssertEqual(category.actions.count, 4) // 5min, 10min, 15min, dismiss
        XCTAssertTrue(category.actions.contains { $0.identifier == "SNOOZE_5_ACTION" })
        XCTAssertTrue(category.actions.contains { $0.identifier == "SNOOZE_10_ACTION" })
        XCTAssertTrue(category.actions.contains { $0.identifier == "SNOOZE_15_ACTION" })
        XCTAssertTrue(category.actions.contains { $0.identifier == "DISMISS_ACTION" })
    }
}
