import XCTest
import Combine
@testable import StartSmart

// MARK: - Mock Storage Manager
class MockStorageManager: StorageManager {
    var shouldThrowError = false
    var savedAlarms: [Alarm] = []
    var loadedAlarms: [Alarm] = []
    
    override func saveAlarms(_ alarms: [Alarm]) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        savedAlarms = alarms
    }
    
    override func loadAlarms() throws -> [Alarm] {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock load error"])
        }
        return loadedAlarms
    }
}

// MARK: - Alarm Repository Tests
final class AlarmRepositoryTests: XCTestCase {
    
    var sut: AlarmRepository!
    var mockStorageManager: MockStorageManager!
    var mockNotificationService: MockNotificationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockStorageManager = MockStorageManager()
        mockNotificationService = MockNotificationService()
        mockNotificationService.permissionStatus = .authorized
        cancellables = Set<AnyCancellable>()
        
        sut = AlarmRepository(
            storageManager: mockStorageManager,
            notificationService: mockNotificationService,
            maxAlarms: 5,
            autoSyncEnabled: true
        )
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockNotificationService = nil
        mockStorageManager = nil
        super.tearDown()
    }
    
    // MARK: - Load Alarms Tests
    func testLoadAlarms_Success() async throws {
        // Given
        let expectedAlarms = [createTestAlarm(), createTestAlarm()]
        mockStorageManager.loadedAlarms = expectedAlarms
        
        // When
        try await sut.loadAlarms()
        
        // Then
        XCTAssertEqual(sut.alarmsValue.count, expectedAlarms.count)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.lastError)
    }
    
    func testLoadAlarms_Failure() async {
        // Given
        mockStorageManager.shouldThrowError = true
        
        // When/Then
        do {
            try await sut.loadAlarms()
            XCTFail("Expected error to be thrown")
        } catch let error as AlarmRepositoryError {
            XCTAssertEqual(error, .storageError("Mock load error"))
            XCTAssertNotNil(sut.lastError)
            XCTAssertFalse(sut.isLoading)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testLoadAlarms_SortsAlarmsByTime() async throws {
        // Given
        let calendar = Calendar.current
        let baseTime = Date()
        let alarm1 = Alarm(time: calendar.date(byAdding: .hour, value: 2, to: baseTime)!)
        let alarm2 = Alarm(time: calendar.date(byAdding: .hour, value: 1, to: baseTime)!)
        let alarm3 = Alarm(time: calendar.date(byAdding: .hour, value: 3, to: baseTime)!)
        
        mockStorageManager.loadedAlarms = [alarm1, alarm2, alarm3]
        
        // When
        try await sut.loadAlarms()
        
        // Then
        let alarms = sut.alarmsValue
        XCTAssertEqual(alarms.count, 3)
        XCTAssertTrue(alarms[0].time <= alarms[1].time)
        XCTAssertTrue(alarms[1].time <= alarms[2].time)
    }
    
    // MARK: - Save Alarm Tests
    func testSaveAlarm_Success() async throws {
        // Given
        let alarm = createTestAlarm()
        
        // When
        try await sut.saveAlarm(alarm)
        
        // Then
        XCTAssertEqual(sut.alarmsValue.count, 1)
        XCTAssertEqual(sut.alarmsValue.first?.id, alarm.id)
        XCTAssertEqual(mockStorageManager.savedAlarms.count, 1)
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 1)
    }
    
    func testSaveAlarm_MaxAlarmsReached() async {
        // Given
        let existingAlarms = (0..<5).map { _ in createTestAlarm() }
        mockStorageManager.loadedAlarms = existingAlarms
        try? await sut.loadAlarms()
        
        let newAlarm = createTestAlarm()
        
        // When/Then
        do {
            try await sut.saveAlarm(newAlarm)
            XCTFail("Expected maxAlarmsReached error")
        } catch let error as AlarmRepositoryError {
            XCTAssertEqual(error, .maxAlarmsReached(5))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSaveAlarm_DuplicateAlarm() async throws {
        // Given
        let time = Date()
        let repeatDays: Set<WeekDay> = [.monday, .wednesday]
        
        let alarm1 = Alarm(time: time, repeatDays: repeatDays)
        let alarm2 = Alarm(time: time, repeatDays: repeatDays) // Same time and repeat days
        
        try await sut.saveAlarm(alarm1)
        
        // When/Then
        do {
            try await sut.saveAlarm(alarm2)
            XCTFail("Expected duplicateAlarm error")
        } catch let error as AlarmRepositoryError {
            XCTAssertEqual(error, .duplicateAlarm)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSaveAlarm_DisabledAlarm_DoesNotScheduleNotification() async throws {
        // Given
        var alarm = createTestAlarm()
        alarm.toggle() // Disable the alarm
        
        // When
        try await sut.saveAlarm(alarm)
        
        // Then
        XCTAssertEqual(sut.alarmsValue.count, 1)
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 0)
    }
    
    // MARK: - Update Alarm Tests
    func testUpdateAlarm_Success() async throws {
        // Given
        let alarm = createTestAlarm()
        try await sut.saveAlarm(alarm)
        
        var updatedAlarm = alarm
        updatedAlarm.label = "Updated Label"
        
        // When
        try await sut.updateAlarm(updatedAlarm)
        
        // Then
        XCTAssertEqual(sut.alarmsValue.count, 1)
        XCTAssertEqual(sut.alarmsValue.first?.label, "Updated Label")
    }
    
    func testUpdateAlarm_NotFound() async {
        // Given
        let alarm = createTestAlarm()
        
        // When/Then
        do {
            try await sut.updateAlarm(alarm)
            XCTFail("Expected alarmNotFound error")
        } catch let error as AlarmRepositoryError {
            XCTAssertEqual(error, .alarmNotFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testUpdateAlarm_UpdatesNotification() async throws {
        // Given
        let alarm = createTestAlarm()
        try await sut.saveAlarm(alarm)
        
        var updatedAlarm = alarm
        updatedAlarm.toggle() // Disable
        
        // When
        try await sut.updateAlarm(updatedAlarm)
        
        // Then
        XCTAssertTrue(mockNotificationService.removedIdentifiers.contains(alarm.id.uuidString))
        XCTAssertEqual(mockNotificationService.scheduledAlarms.count, 0)
    }
    
    // MARK: - Delete Alarm Tests
    func testDeleteAlarm_Success() async throws {
        // Given
        let alarm = createTestAlarm()
        try await sut.saveAlarm(alarm)
        
        // When
        try await sut.deleteAlarm(alarm)
        
        // Then
        XCTAssertEqual(sut.alarmsValue.count, 0)
        XCTAssertTrue(mockNotificationService.removedIdentifiers.contains(alarm.id.uuidString))
    }
    
    func testDeleteAlarmById_Success() async throws {
        // Given
        let alarm = createTestAlarm()
        try await sut.saveAlarm(alarm)
        
        // When
        try await sut.deleteAlarm(withId: alarm.id)
        
        // Then
        XCTAssertEqual(sut.alarmsValue.count, 0)
    }
    
    func testDeleteAlarm_NotFound() async {
        // Given
        let alarm = createTestAlarm()
        
        // When/Then
        do {
            try await sut.deleteAlarm(alarm)
            XCTFail("Expected alarmNotFound error")
        } catch let error as AlarmRepositoryError {
            XCTAssertEqual(error, .alarmNotFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testDeleteAllAlarms_Success() async throws {
        // Given
        let alarms = [createTestAlarm(), createTestAlarm(), createTestAlarm()]
        for alarm in alarms {
            try await sut.saveAlarm(alarm)
        }
        
        // When
        try await sut.deleteAllAlarms()
        
        // Then
        XCTAssertEqual(sut.alarmsValue.count, 0)
        XCTAssertEqual(mockStorageManager.savedAlarms.count, 0)
    }
    
    // MARK: - Toggle Alarm Tests
    func testToggleAlarm_Success() async throws {
        // Given
        let alarm = createTestAlarm()
        try await sut.saveAlarm(alarm)
        let originalState = alarm.isEnabled
        
        // When
        try await sut.toggleAlarm(withId: alarm.id)
        
        // Then
        let updatedAlarm = sut.alarmsValue.first!
        XCTAssertEqual(updatedAlarm.isEnabled, !originalState)
    }
    
    func testToggleAlarm_NotFound() async {
        // Given
        let alarm = createTestAlarm()
        
        // When/Then
        do {
            try await sut.toggleAlarm(withId: alarm.id)
            XCTFail("Expected alarmNotFound error")
        } catch let error as AlarmRepositoryError {
            XCTAssertEqual(error, .alarmNotFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Snooze Alarm Tests
    func testSnoozeAlarm_Success() async throws {
        // Given
        let alarm = createTestAlarm()
        try await sut.saveAlarm(alarm)
        
        // When
        try await sut.snoozeAlarm(withId: alarm.id)
        
        // Then
        let updatedAlarm = sut.alarmsValue.first!
        XCTAssertEqual(updatedAlarm.currentSnoozeCount, 1)
    }
    
    func testSnoozeAlarm_CannotSnooze() async throws {
        // Given
        var alarm = createTestAlarm()
        alarm.currentSnoozeCount = alarm.maxSnoozeCount // Already at max
        try await sut.saveAlarm(alarm)
        
        // When/Then
        do {
            try await sut.snoozeAlarm(withId: alarm.id)
            XCTFail("Expected invalidAlarmData error")
        } catch let error as AlarmRepositoryError {
            XCTAssertEqual(error, .invalidAlarmData)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Mark Alarm as Triggered Tests
    func testMarkAlarmAsTriggered_OneTimeAlarm() async throws {
        // Given
        let alarm = createTestAlarm() // One-time alarm
        try await sut.saveAlarm(alarm)
        
        // When
        try await sut.markAlarmAsTriggered(withId: alarm.id)
        
        // Then
        let updatedAlarm = sut.alarmsValue.first!
        XCTAssertNotNil(updatedAlarm.lastTriggered)
        XCTAssertFalse(updatedAlarm.isEnabled) // Should be disabled after triggering
    }
    
    func testMarkAlarmAsTriggered_RepeatingAlarm() async throws {
        // Given
        var alarm = createTestAlarm()
        alarm.repeatDays = [.monday, .friday]
        try await sut.saveAlarm(alarm)
        
        // When
        try await sut.markAlarmAsTriggered(withId: alarm.id)
        
        // Then
        let updatedAlarm = sut.alarmsValue.first!
        XCTAssertNotNil(updatedAlarm.lastTriggered)
        XCTAssertTrue(updatedAlarm.isEnabled) // Should remain enabled for repeating alarms
    }
    
    // MARK: - Query Methods Tests
    func testGetAlarm_Success() async throws {
        // Given
        let alarm = createTestAlarm()
        try await sut.saveAlarm(alarm)
        
        // When
        let foundAlarm = await sut.getAlarm(withId: alarm.id)
        
        // Then
        XCTAssertNotNil(foundAlarm)
        XCTAssertEqual(foundAlarm?.id, alarm.id)
    }
    
    func testGetAlarm_NotFound() async throws {
        // Given
        let alarm = createTestAlarm()
        
        // When
        let foundAlarm = await sut.getAlarm(withId: alarm.id)
        
        // Then
        XCTAssertNil(foundAlarm)
    }
    
    func testGetEnabledAlarms() async throws {
        // Given
        var alarm1 = createTestAlarm()
        alarm1.label = "Enabled"
        var alarm2 = createTestAlarm()
        alarm2.label = "Disabled"
        alarm2.toggle() // Disable
        
        try await sut.saveAlarm(alarm1)
        try await sut.saveAlarm(alarm2)
        
        // When
        let enabledAlarms = await sut.getEnabledAlarms()
        
        // Then
        XCTAssertEqual(enabledAlarms.count, 1)
        XCTAssertEqual(enabledAlarms.first?.label, "Enabled")
    }
    
    func testGetNextAlarm() async throws {
        // Given
        let calendar = Calendar.current
        let now = Date()
        
        let alarm1 = Alarm(time: calendar.date(byAdding: .hour, value: 2, to: now)!)
        let alarm2 = Alarm(time: calendar.date(byAdding: .hour, value: 1, to: now)!)
        var alarm3 = Alarm(time: calendar.date(byAdding: .minute, value: 30, to: now)!)
        alarm3.toggle() // Disable this one
        
        try await sut.saveAlarm(alarm1)
        try await sut.saveAlarm(alarm2)
        try await sut.saveAlarm(alarm3)
        
        // When
        let nextAlarm = await sut.getNextAlarm()
        
        // Then
        XCTAssertNotNil(nextAlarm)
        XCTAssertEqual(nextAlarm?.id, alarm2.id) // Should be the soonest enabled alarm
    }
    
    // MARK: - Batch Operations Tests
    func testImportAlarms_Success() async throws {
        // Given
        let alarmsToImport = [createTestAlarm(), createTestAlarm()]
        
        // When
        try await sut.importAlarms(alarmsToImport)
        
        // Then
        XCTAssertEqual(sut.alarmsValue.count, 2)
    }
    
    func testImportAlarms_ExceedsMaxLimit() async {
        // Given
        let existingAlarms = [createTestAlarm(), createTestAlarm()]
        let alarmsToImport = [createTestAlarm(), createTestAlarm(), createTestAlarm(), createTestAlarm()]
        
        mockStorageManager.loadedAlarms = existingAlarms
        try? await sut.loadAlarms()
        
        // When/Then
        do {
            try await sut.importAlarms(alarmsToImport)
            XCTFail("Expected maxAlarmsReached error")
        } catch let error as AlarmRepositoryError {
            XCTAssertEqual(error, .maxAlarmsReached(5))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testExportAlarms() async throws {
        // Given
        let alarms = [createTestAlarm(), createTestAlarm()]
        for alarm in alarms {
            try await sut.saveAlarm(alarm)
        }
        
        // When
        let exportedAlarms = await sut.exportAlarms()
        
        // Then
        XCTAssertEqual(exportedAlarms.count, 2)
    }
    
    // MARK: - Statistics Tests
    func testGetAlarmStatistics() async throws {
        // Given
        var alarm1 = createTestAlarm()
        alarm1.tone = .energetic
        var alarm2 = createTestAlarm()
        alarm2.tone = .gentle
        alarm2.toggle() // Disable
        var alarm3 = createTestAlarm()
        alarm3.repeatDays = [.monday, .friday]
        alarm3.tone = .energetic
        
        try await sut.saveAlarm(alarm1)
        try await sut.saveAlarm(alarm2)
        try await sut.saveAlarm(alarm3)
        
        // When
        let stats = await sut.getAlarmStatistics()
        
        // Then
        XCTAssertEqual(stats.totalAlarms, 3)
        XCTAssertEqual(stats.enabledAlarms, 2)
        XCTAssertEqual(stats.disabledAlarms, 1)
        XCTAssertEqual(stats.repeatingAlarms, 1)
        XCTAssertEqual(stats.oneTimeAlarms, 2)
        XCTAssertEqual(stats.toneDistribution[.energetic], 2)
        XCTAssertEqual(stats.toneDistribution[.gentle], 1)
        XCTAssertEqual(stats.mostPopularTone, .energetic)
    }
    
    // MARK: - Reactive Updates Tests
    func testReactiveUpdates() async throws {
        // Given
        var receivedAlarms: [Alarm] = []
        let expectation = expectation(description: "Alarms updated")
        
        sut.alarms
            .sink { alarms in
                receivedAlarms = alarms
                if !alarms.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        let alarm = createTestAlarm()
        try await sut.saveAlarm(alarm)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedAlarms.count, 1)
        XCTAssertEqual(receivedAlarms.first?.id, alarm.id)
    }
    
    // MARK: - Error Handling Tests
    func testErrorEquality() {
        XCTAssertEqual(AlarmRepositoryError.alarmNotFound, AlarmRepositoryError.alarmNotFound)
        XCTAssertEqual(AlarmRepositoryError.duplicateAlarm, AlarmRepositoryError.duplicateAlarm)
        XCTAssertEqual(AlarmRepositoryError.invalidAlarmData, AlarmRepositoryError.invalidAlarmData)
        XCTAssertEqual(AlarmRepositoryError.maxAlarmsReached(5), AlarmRepositoryError.maxAlarmsReached(5))
        XCTAssertEqual(AlarmRepositoryError.storageError("test"), AlarmRepositoryError.storageError("test"))
        
        XCTAssertNotEqual(AlarmRepositoryError.maxAlarmsReached(5), AlarmRepositoryError.maxAlarmsReached(10))
        XCTAssertNotEqual(AlarmRepositoryError.storageError("test1"), AlarmRepositoryError.storageError("test2"))
    }
    
    func testErrorDescriptions() {
        let errors: [AlarmRepositoryError] = [
            .alarmNotFound,
            .invalidAlarmData,
            .storageError("Test error"),
            .duplicateAlarm,
            .maxAlarmsReached(10)
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Performance Tests
    func testPerformanceWithManyAlarms() async throws {
        // Given
        let alarms = (0..<100).map { _ in createTestAlarm() }
        
        // When
        measure {
            Task {
                for alarm in alarms.prefix(50) { // Only test first 50 due to max limit
                    try? await sut.saveAlarm(alarm)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func createTestAlarm() -> Alarm {
        let calendar = Calendar.current
        let futureTime = calendar.date(byAdding: .hour, value: Int.random(in: 1...12), to: Date())!
        
        return Alarm(
            time: futureTime,
            label: "Test Alarm \(UUID().uuidString.prefix(8))",
            tone: AlarmTone.allCases.randomElement()!,
            snoozeEnabled: Bool.random(),
            maxSnoozeCount: Int.random(in: 1...5)
        )
    }
}

// MARK: - AlarmRepositoryError Equatable Extension
extension AlarmRepositoryError: Equatable {
    static func == (lhs: AlarmRepositoryError, rhs: AlarmRepositoryError) -> Bool {
        switch (lhs, rhs) {
        case (.alarmNotFound, .alarmNotFound),
             (.invalidAlarmData, .invalidAlarmData),
             (.duplicateAlarm, .duplicateAlarm):
            return true
        case (.storageError(let lhsReason), .storageError(let rhsReason)):
            return lhsReason == rhsReason
        case (.maxAlarmsReached(let lhsLimit), .maxAlarmsReached(let rhsLimit)):
            return lhsLimit == rhsLimit
        default:
            return false
        }
    }
}
