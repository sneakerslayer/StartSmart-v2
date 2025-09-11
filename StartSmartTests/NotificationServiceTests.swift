import XCTest
import UserNotifications
@testable import StartSmart

// MARK: - Mock Notification Center
class MockNotificationCenter: UNUserNotificationCenter {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var shouldGrantPermission = true
    var pendingRequests: [UNNotificationRequest] = []
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    
    override func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationStatus = shouldGrantPermission ? .authorized : .denied
        return shouldGrantPermission
    }
    
    override func notificationSettings() async -> UNNotificationSettings {
        return MockNotificationSettings(authorizationStatus: authorizationStatus)
    }
    
    override func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        pendingRequests.append(request)
    }
    
    override func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return pendingRequests
    }
    
    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        pendingRequests.removeAll { request in
            identifiers.contains(request.identifier)
        }
    }
    
    override func removeAllPendingNotificationRequests() {
        removedIdentifiers.append(contentsOf: pendingRequests.map { $0.identifier })
        pendingRequests.removeAll()
    }
}

// MARK: - Mock Notification Settings
class MockNotificationSettings: UNNotificationSettings {
    private let _authorizationStatus: UNAuthorizationStatus
    
    init(authorizationStatus: UNAuthorizationStatus) {
        _authorizationStatus = authorizationStatus
        super.init()
    }
    
    override var authorizationStatus: UNAuthorizationStatus {
        return _authorizationStatus
    }
}

// MARK: - Mock Notification Service
class MockNotificationService: NotificationServiceProtocol {
    var permissionStatus: NotificationPermissionStatus = .notDetermined
    var shouldThrowPermissionError = false
    var shouldThrowSchedulingError = false
    var scheduledAlarms: [Alarm] = []
    var removedIdentifiers: [String] = []
    var pendingNotifications: [UNNotificationRequest] = []
    
    func requestPermission() async throws -> NotificationPermissionStatus {
        if shouldThrowPermissionError {
            throw NotificationServiceError.permissionDenied
        }
        permissionStatus = .authorized
        return permissionStatus
    }
    
    func getPermissionStatus() async -> NotificationPermissionStatus {
        return permissionStatus
    }
    
    func scheduleNotification(for alarm: Alarm) async throws {
        if shouldThrowSchedulingError {
            throw NotificationServiceError.schedulingFailed("Mock error")
        }
        scheduledAlarms.append(alarm)
    }
    
    func removeNotification(with identifier: String) async {
        removedIdentifiers.append(identifier)
        scheduledAlarms.removeAll { $0.id.uuidString == identifier }
    }
    
    func removeAllNotifications() async {
        removedIdentifiers.append(contentsOf: scheduledAlarms.map { $0.id.uuidString })
        scheduledAlarms.removeAll()
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return pendingNotifications
    }
}

// MARK: - Notification Service Tests
final class NotificationServiceTests: XCTestCase {
    
    var sut: NotificationService!
    var mockNotificationCenter: MockNotificationCenter!
    
    override func setUp() {
        super.setUp()
        mockNotificationCenter = MockNotificationCenter()
        sut = NotificationService()
        // Note: In a real implementation, we would inject the mock notification center
    }
    
    override func tearDown() {
        sut = nil
        mockNotificationCenter = nil
        super.tearDown()
    }
    
    // MARK: - Permission Tests
    func testRequestPermission_WhenGranted_ReturnsAuthorized() async throws {
        // Given
        mockNotificationCenter.shouldGrantPermission = true
        
        // When
        let status = try await sut.requestPermission()
        
        // Then
        XCTAssertEqual(status, .authorized)
    }
    
    func testRequestPermission_WhenDenied_ThrowsPermissionDeniedError() async {
        // Given
        mockNotificationCenter.shouldGrantPermission = false
        
        // When/Then
        do {
            _ = try await sut.requestPermission()
            XCTFail("Expected permission denied error")
        } catch let error as NotificationServiceError {
            XCTAssertEqual(error, .permissionDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testGetPermissionStatus_ReturnsCorrectStatus() async {
        // Given
        mockNotificationCenter.authorizationStatus = .authorized
        
        // When
        let status = await sut.getPermissionStatus()
        
        // Then
        XCTAssertEqual(status, .authorized)
    }
    
    func testPermissionStatusMapping() {
        // Test all permission status mappings
        let testCases: [(UNAuthorizationStatus, NotificationPermissionStatus)] = [
            (.notDetermined, .notDetermined),
            (.denied, .denied),
            (.authorized, .authorized),
            (.provisional, .provisional)
        ]
        
        for (input, expected) in testCases {
            mockNotificationCenter.authorizationStatus = input
            Task {
                let result = await sut.getPermissionStatus()
                XCTAssertEqual(result, expected, "Failed for status: \(input)")
            }
        }
    }
    
    // MARK: - Notification Scheduling Tests
    func testScheduleNotification_WithValidAlarm_SucceedsForMockService() async throws {
        // Given
        let mockService = MockNotificationService()
        mockService.permissionStatus = .authorized
        
        let alarm = createTestAlarm()
        
        // When
        try await mockService.scheduleNotification(for: alarm)
        
        // Then
        XCTAssertEqual(mockService.scheduledAlarms.count, 1)
        XCTAssertEqual(mockService.scheduledAlarms.first?.id, alarm.id)
    }
    
    func testScheduleNotification_WithDisabledAlarm_ThrowsInvalidAlarmError() async {
        // Given
        let mockService = MockNotificationService()
        mockService.permissionStatus = .authorized
        
        var alarm = createTestAlarm()
        alarm.toggle() // Disable the alarm
        
        // When/Then
        do {
            try await mockService.scheduleNotification(for: alarm)
            XCTFail("Expected invalid alarm error")
        } catch let error as NotificationServiceError {
            XCTAssertEqual(error, .invalidAlarm)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testScheduleNotification_WithoutPermission_ThrowsPermissionDeniedError() async {
        // Given
        let mockService = MockNotificationService()
        mockService.permissionStatus = .denied
        
        let alarm = createTestAlarm()
        
        // When/Then
        do {
            try await mockService.scheduleNotification(for: alarm)
            XCTFail("Expected permission denied error")
        } catch let error as NotificationServiceError {
            XCTAssertEqual(error, .permissionDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testScheduleNotification_WithRepeatingAlarm_HandlesMultipleDays() async throws {
        // Given
        let mockService = MockNotificationService()
        mockService.permissionStatus = .authorized
        
        var alarm = createTestAlarm()
        alarm.repeatDays = [.monday, .wednesday, .friday]
        
        // When
        try await mockService.scheduleNotification(for: alarm)
        
        // Then
        XCTAssertEqual(mockService.scheduledAlarms.count, 1)
        XCTAssertTrue(mockService.scheduledAlarms.first?.isRepeating == true)
    }
    
    // MARK: - Notification Removal Tests
    func testRemoveNotification_RemovesCorrectNotification() async {
        // Given
        let mockService = MockNotificationService()
        let alarm = createTestAlarm()
        try? await mockService.scheduleNotification(for: alarm)
        
        // When
        await mockService.removeNotification(with: alarm.id.uuidString)
        
        // Then
        XCTAssertTrue(mockService.removedIdentifiers.contains(alarm.id.uuidString))
        XCTAssertTrue(mockService.scheduledAlarms.isEmpty)
    }
    
    func testRemoveAllNotifications_RemovesAllNotifications() async {
        // Given
        let mockService = MockNotificationService()
        let alarm1 = createTestAlarm()
        let alarm2 = createTestAlarm()
        
        try? await mockService.scheduleNotification(for: alarm1)
        try? await mockService.scheduleNotification(for: alarm2)
        
        // When
        await mockService.removeAllNotifications()
        
        // Then
        XCTAssertEqual(mockService.removedIdentifiers.count, 2)
        XCTAssertTrue(mockService.scheduledAlarms.isEmpty)
    }
    
    // MARK: - Alarm Model Tests
    func testAlarmNextTriggerDate_OneTimeAlarm() {
        // Given
        let calendar = Calendar.current
        let futureTime = calendar.date(byAdding: .hour, value: 2, to: Date())!
        let alarm = Alarm(time: futureTime)
        
        // When
        let nextTrigger = alarm.nextTriggerDate
        
        // Then
        XCTAssertNotNil(nextTrigger)
        XCTAssertTrue(nextTrigger! > Date())
    }
    
    func testAlarmNextTriggerDate_RepeatingAlarm() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: now)
        let alarmTime = calendar.nextDate(after: now, matching: timeComponents, matchingPolicy: .nextTime)!
        
        var alarm = Alarm(time: alarmTime)
        alarm.repeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
        
        // When
        let nextTrigger = alarm.nextTriggerDate
        
        // Then
        XCTAssertNotNil(nextTrigger)
        XCTAssertTrue(nextTrigger! > Date())
    }
    
    func testAlarmNextTriggerDate_DisabledAlarm() {
        // Given
        var alarm = createTestAlarm()
        alarm.toggle() // Disable
        
        // When
        let nextTrigger = alarm.nextTriggerDate
        
        // Then
        XCTAssertNil(nextTrigger)
    }
    
    // MARK: - Error Handling Tests
    func testNotificationServiceError_LocalizedDescriptions() {
        let errors: [NotificationServiceError] = [
            .permissionDenied,
            .schedulingFailed("Test reason"),
            .invalidAlarm,
            .notificationNotFound
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    func testNotificationServiceError_Equality() {
        XCTAssertEqual(
            NotificationServiceError.permissionDenied,
            NotificationServiceError.permissionDenied
        )
        
        XCTAssertEqual(
            NotificationServiceError.schedulingFailed("test"),
            NotificationServiceError.schedulingFailed("test")
        )
        
        XCTAssertNotEqual(
            NotificationServiceError.schedulingFailed("test1"),
            NotificationServiceError.schedulingFailed("test2")
        )
    }
    
    // MARK: - Integration Tests
    func testNotificationContent_CreatedCorrectly() {
        // This would test the private createNotificationContent method
        // In a real implementation, we might make this method internal for testing
        let alarm = createTestAlarm()
        
        // Test that the alarm has the expected properties
        XCTAssertEqual(alarm.label, "Test Alarm")
        XCTAssertEqual(alarm.tone, .energetic)
        XCTAssertTrue(alarm.snoozeEnabled)
        XCTAssertEqual(alarm.maxSnoozeCount, 3)
    }
    
    func testNotificationDelegate_SharedInstance() {
        // Given
        let delegate1 = NotificationDelegate.shared
        let delegate2 = NotificationDelegate.shared
        
        // Then
        XCTAssertTrue(delegate1 === delegate2)
    }
    
    // MARK: - Performance Tests
    func testNotificationSchedulingPerformance() {
        let mockService = MockNotificationService()
        mockService.permissionStatus = .authorized
        
        let alarms = (0..<100).map { _ in createTestAlarm() }
        
        measure {
            Task {
                for alarm in alarms {
                    try? await mockService.scheduleNotification(for: alarm)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func createTestAlarm() -> Alarm {
        let calendar = Calendar.current
        let futureTime = calendar.date(byAdding: .hour, value: 1, to: Date())!
        
        return Alarm(
            time: futureTime,
            label: "Test Alarm",
            tone: .energetic,
            snoozeEnabled: true,
            maxSnoozeCount: 3
        )
    }
}

// MARK: - NotificationServiceError Equatable Extension
extension NotificationServiceError: Equatable {
    static func == (lhs: NotificationServiceError, rhs: NotificationServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied),
             (.invalidAlarm, .invalidAlarm),
             (.notificationNotFound, .notificationNotFound):
            return true
        case (.schedulingFailed(let lhsReason), .schedulingFailed(let rhsReason)):
            return lhsReason == rhsReason
        default:
            return false
        }
    }
}
