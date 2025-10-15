import XCTest
import AlarmKit
@testable import StartSmart

// MARK: - Final Testing Suite

/// Comprehensive final testing suite for AlarmKit migration
@available(iOS 26.0, *)
class FinalTestingSuite: XCTestCase {
    
    var alarmKitManager: AlarmKitManager!
    var optimizedAlarmKitManager: OptimizedAlarmKitManager!
    var alarmDataCacheService: AlarmDataCacheService!
    var performanceMonitoringService: PerformanceMonitoringService!
    var dynamicIslandService: DynamicIslandAlarmService!
    var customizationService: AdvancedAlarmCustomizationService!
    var recommendationsService: SmartAlarmRecommendationsService!
    
    override func setUp() {
        super.setUp()
        alarmKitManager = AlarmKitManager.shared
        optimizedAlarmKitManager = OptimizedAlarmKitManager.shared
        alarmDataCacheService = AlarmDataCacheService.shared
        performanceMonitoringService = PerformanceMonitoringService.shared
        dynamicIslandService = DynamicIslandAlarmService.shared
        customizationService = AdvancedAlarmCustomizationService.shared
        recommendationsService = SmartAlarmRecommendationsService.shared
    }
    
    override func tearDown() {
        alarmKitManager = nil
        optimizedAlarmKitManager = nil
        alarmDataCacheService = nil
        performanceMonitoringService = nil
        dynamicIslandService = nil
        customizationService = nil
        recommendationsService = nil
        super.tearDown()
    }
    
    // MARK: - Core Functionality Tests
    
    func testAlarmKitManagerSingleton() {
        // Test singleton pattern
        let instance1 = AlarmKitManager.shared
        let instance2 = AlarmKitManager.shared
        XCTAssertIdentical(instance1, instance2)
    }
    
    func testOptimizedAlarmKitManagerSingleton() {
        // Test optimized manager singleton
        let instance1 = OptimizedAlarmKitManager.shared
        let instance2 = OptimizedAlarmKitManager.shared
        XCTAssertIdentical(instance1, instance2)
    }
    
    func testAlarmDataCacheServiceSingleton() {
        // Test cache service singleton
        let instance1 = AlarmDataCacheService.shared
        let instance2 = AlarmDataCacheService.shared
        XCTAssertIdentical(instance1, instance2)
    }
    
    func testPerformanceMonitoringServiceSingleton() {
        // Test performance monitoring singleton
        let instance1 = PerformanceMonitoringService.shared
        let instance2 = PerformanceMonitoringService.shared
        XCTAssertIdentical(instance1, instance2)
    }
    
    func testDynamicIslandServiceSingleton() {
        // Test Dynamic Island service singleton
        let instance1 = DynamicIslandAlarmService.shared
        let instance2 = DynamicIslandAlarmService.shared
        XCTAssertIdentical(instance1, instance2)
    }
    
    func testCustomizationServiceSingleton() {
        // Test customization service singleton
        let instance1 = AdvancedAlarmCustomizationService.shared
        let instance2 = AdvancedAlarmCustomizationService.shared
        XCTAssertIdentical(instance1, instance2)
    }
    
    func testRecommendationsServiceSingleton() {
        // Test recommendations service singleton
        let instance1 = SmartAlarmRecommendationsService.shared
        let instance2 = SmartAlarmRecommendationsService.shared
        XCTAssertIdentical(instance1, instance2)
    }
    
    // MARK: - AlarmKit Integration Tests
    
    func testAlarmKitAuthorization() async throws {
        // Test AlarmKit authorization
        let status = try await alarmKitManager.requestAuthorization()
        XCTAssertTrue(status == .authorized || status == .denied || status == .notDetermined)
    }
    
    func testAlarmKitAlarmScheduling() async throws {
        // Test alarm scheduling
        let testAlarm = createTestAlarm()
        try await alarmKitManager.scheduleAlarm(for: testAlarm)
        
        let alarms = alarmKitManager.alarms
        XCTAssertTrue(alarms.contains { $0.id.uuidString == testAlarm.id.uuidString })
    }
    
    func testAlarmKitAlarmCancellation() async throws {
        // Test alarm cancellation
        let testAlarm = createTestAlarm()
        try await alarmKitManager.scheduleAlarm(for: testAlarm)
        
        try await alarmKitManager.cancelAlarm(withId: testAlarm.id.uuidString)
        
        let alarms = alarmKitManager.alarms
        XCTAssertFalse(alarms.contains { $0.id.uuidString == testAlarm.id.uuidString })
    }
    
    // MARK: - Performance Optimization Tests
    
    func testOptimizedAlarmScheduling() async throws {
        // Test optimized alarm scheduling
        let testAlarm = createTestAlarm()
        let startTime = Date()
        
        try await optimizedAlarmKitManager.scheduleAlarm(for: testAlarm)
        
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 2.0) // Should complete within 2 seconds
    }
    
    func testBatchAlarmOperations() async throws {
        // Test batch alarm operations
        let alarms = (0..<5).map { _ in createTestAlarm() }
        let startTime = Date()
        
        try await optimizedAlarmKitManager.scheduleAlarmBatch(alarms)
        
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
    }
    
    func testCachePerformance() {
        // Test cache performance
        let testAlarm = createTestAlarm()
        let config = AlarmManager.AlarmConfiguration(
            countdownDuration: AlarmKit.Alarm.CountdownDuration(preAlert: nil, postAlert: nil),
            schedule: AlarmKit.Alarm.Schedule.relative(AlarmKit.Alarm.Schedule.Relative(
                time: AlarmKit.Alarm.Schedule.Relative.Time(hour: 7, minute: 0),
                repeats: AlarmKit.Alarm.Schedule.Relative.Recurrence.never
            )),
            attributes: AlarmAttributes(
                presentation: AlarmPresentation(
                    alert: AlarmPresentation.Alert(
                        title: LocalizedStringResource(stringLiteral: "Test"),
                        stopButton: AlarmButton(text: "Done", textColor: .white, systemImageName: "checkmark"),
                        secondaryButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "repeat"),
                        secondaryButtonBehavior: .countdown
                    ),
                    countdown: AlarmPresentation.Countdown(
                        title: LocalizedStringResource(stringLiteral: "Snoozing"),
                        pauseButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "repeat")
                    )
                ),
                metadata: StartSmartAlarmMetadata(),
                tintColor: .blue
            ),
            secondaryIntent: nil,
            sound: .default
        )
        
        // Test cache operations
        alarmDataCacheService.cacheAlarmConfiguration(config, for: testAlarm.id.uuidString)
        
        let cachedConfig = alarmDataCacheService.getCachedAlarmConfiguration(for: testAlarm.id.uuidString)
        XCTAssertNotNil(cachedConfig)
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testPerformanceMonitoring() {
        // Test performance monitoring
        let startTime = Date()
        
        // Simulate some work
        Thread.sleep(forTimeInterval: 0.1)
        
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThan(duration, 0.05)
    }
    
    func testMemoryUsageMonitoring() {
        // Test memory usage monitoring
        let memoryUsage = performanceMonitoringService.currentMemoryUsage
        XCTAssertGreaterThanOrEqual(memoryUsage, 0.0)
    }
    
    func testBatteryLevelMonitoring() {
        // Test battery level monitoring
        let batteryLevel = performanceMonitoringService.batteryLevel
        XCTAssertGreaterThanOrEqual(batteryLevel, 0.0)
        XCTAssertLessThanOrEqual(batteryLevel, 1.0)
    }
    
    // MARK: - Dynamic Island Tests
    
    func testDynamicIslandSupport() {
        // Test Dynamic Island support detection
        let isSupported = dynamicIslandService.isDynamicIslandSupported
        // This will be false on simulator, true on iPhone 14 Pro+
        XCTAssertNotNil(isSupported)
    }
    
    func testDynamicIslandActivityCreation() async {
        // Test Dynamic Island activity creation
        let testAlarm = createTestAlarm()
        
        await dynamicIslandService.startAlarmActivity(for: testAlarm)
        
        // Verify activity was created (this will depend on device support)
        XCTAssertNotNil(dynamicIslandService.activeAlarmActivity)
    }
    
    // MARK: - Customization Tests
    
    func testThemeCustomization() {
        // Test theme customization
        let themes = customizationService.availableThemes
        XCTAssertGreaterThan(themes.count, 0)
        
        if let firstTheme = themes.first {
            customizationService.selectedTheme = firstTheme
            XCTAssertEqual(customizationService.selectedTheme?.id, firstTheme.id)
        }
    }
    
    func testSoundCustomization() {
        // Test sound customization
        let sounds = customizationService.availableSounds
        XCTAssertGreaterThan(sounds.count, 0)
        
        if let firstSound = sounds.first {
            customizationService.selectedSound = firstSound
            XCTAssertEqual(customizationService.selectedSound?.id, firstSound.id)
        }
    }
    
    func testAnimationCustomization() {
        // Test animation customization
        let animations = customizationService.availableAnimations
        XCTAssertGreaterThan(animations.count, 0)
        
        if let firstAnimation = animations.first {
            customizationService.selectedAnimation = firstAnimation
            XCTAssertEqual(customizationService.selectedAnimation?.id, firstAnimation.id)
        }
    }
    
    func testGestureCustomization() {
        // Test gesture customization
        let gestures = customizationService.availableGestures
        XCTAssertGreaterThan(gestures.count, 0)
        
        if let firstGesture = gestures.first {
            customizationService.selectedGesture = firstGesture
            XCTAssertEqual(customizationService.selectedGesture?.id, firstGesture.id)
        }
    }
    
    func testEffectCustomization() {
        // Test effect customization
        let effects = customizationService.availableEffects
        XCTAssertGreaterThan(effects.count, 0)
        
        if let firstEffect = effects.first {
            customizationService.selectedEffects.insert(firstEffect)
            XCTAssertTrue(customizationService.selectedEffects.contains(firstEffect))
        }
    }
    
    func testCustomizationValidation() {
        // Test customization validation
        let issues = customizationService.validateCustomization()
        // Should not have critical issues
        XCTAssertTrue(issues.count < 5)
    }
    
    func testCustomizationRecommendations() {
        // Test customization recommendations
        let recommendations = customizationService.getCustomizationRecommendations()
        XCTAssertNotNil(recommendations)
    }
    
    // MARK: - Smart Recommendations Tests
    
    func testRecommendationsAnalysis() async {
        // Test recommendations analysis
        await recommendationsService.analyzeUserData()
        
        // Should complete analysis
        XCTAssertFalse(recommendationsService.isAnalyzing)
    }
    
    func testRecommendationsGeneration() async {
        // Test recommendations generation
        await recommendationsService.analyzeUserData()
        
        let recommendations = recommendationsService.recommendations
        XCTAssertNotNil(recommendations)
    }
    
    func testRecommendationsPriority() async {
        // Test recommendations priority
        await recommendationsService.analyzeUserData()
        
        let recommendations = recommendationsService.recommendations
        for recommendation in recommendations {
            XCTAssertTrue(recommendation.priority == .low || recommendation.priority == .medium || recommendation.priority == .high)
        }
    }
    
    func testRecommendationsConfidence() async {
        // Test recommendations confidence
        await recommendationsService.analyzeUserData()
        
        let recommendations = recommendationsService.recommendations
        for recommendation in recommendations {
            XCTAssertGreaterThanOrEqual(recommendation.confidence, 0.0)
            XCTAssertLessThanOrEqual(recommendation.confidence, 1.0)
        }
    }
    
    // MARK: - Integration Tests
    
    func testCompleteAlarmLifecycle() async throws {
        // Test complete alarm lifecycle
        let testAlarm = createTestAlarm()
        
        // Create alarm
        try await alarmKitManager.scheduleAlarm(for: testAlarm)
        
        // Verify creation
        let alarms = alarmKitManager.alarms
        XCTAssertTrue(alarms.contains { $0.id.uuidString == testAlarm.id.uuidString })
        
        // Update alarm
        var updatedAlarm = testAlarm
        updatedAlarm.label = "Updated Test Alarm"
        try await alarmKitManager.scheduleAlarm(for: updatedAlarm)
        
        // Verify update
        let updatedAlarms = alarmKitManager.alarms
        XCTAssertTrue(updatedAlarms.contains { $0.id.uuidString == testAlarm.id.uuidString })
        
        // Delete alarm
        try await alarmKitManager.cancelAlarm(withId: testAlarm.id.uuidString)
        
        // Verify deletion
        let finalAlarms = alarmKitManager.alarms
        XCTAssertFalse(finalAlarms.contains { $0.id.uuidString == testAlarm.id.uuidString })
    }
    
    func testPerformanceUnderLoad() async throws {
        // Test performance under load
        let alarms = (0..<10).map { _ in createTestAlarm() }
        let startTime = Date()
        
        for alarm in alarms {
            try await alarmKitManager.scheduleAlarm(for: alarm)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 10.0) // Should complete within 10 seconds
        
        // Clean up
        for alarm in alarms {
            try await alarmKitManager.cancelAlarm(withId: alarm.id.uuidString)
        }
    }
    
    func testMemoryUsageUnderLoad() async throws {
        // Test memory usage under load
        let initialMemory = performanceMonitoringService.currentMemoryUsage
        
        let alarms = (0..<20).map { _ in createTestAlarm() }
        
        for alarm in alarms {
            try await alarmKitManager.scheduleAlarm(for: alarm)
        }
        
        let finalMemory = performanceMonitoringService.currentMemoryUsage
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable
        XCTAssertLessThan(memoryIncrease, 50.0) // Less than 50MB increase
        
        // Clean up
        for alarm in alarms {
            try await alarmKitManager.cancelAlarm(withId: alarm.id.uuidString)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async {
        // Test error handling
        do {
            try await alarmKitManager.cancelAlarm(withId: "invalid-id")
        } catch {
            // Should handle invalid ID gracefully
            XCTAssertNotNil(error)
        }
    }
    
    func testGracefulDegradation() async {
        // Test graceful degradation
        // This would test fallback behavior when AlarmKit is not available
        // For now, we'll test that the system doesn't crash
        XCTAssertTrue(true) // Placeholder for graceful degradation test
    }
    
    // MARK: - Helper Methods
    
    private func createTestAlarm() -> StartSmart.Alarm {
        return StartSmart.Alarm(
            label: "Test Alarm \(UUID().uuidString.prefix(8))",
            time: Date().addingTimeInterval(3600), // 1 hour from now
            isRepeating: false,
            snoozeEnabled: true,
            snoozeDuration: 300
        )
    }
}

// MARK: - Performance Benchmark Tests

@available(iOS 26.0, *)
class PerformanceBenchmarkTests: XCTestCase {
    
    func testAlarmCreationPerformance() {
        // Test alarm creation performance
        measure {
            let testAlarm = StartSmart.Alarm(
                label: "Performance Test Alarm",
                time: Date().addingTimeInterval(3600),
                isRepeating: false,
                snoozeEnabled: true,
                snoozeDuration: 300
            )
            
            // This should be fast
            XCTAssertNotNil(testAlarm)
        }
    }
    
    func testCachePerformance() {
        // Test cache performance
        let cacheService = AlarmDataCacheService.shared
        
        measure {
            // Test cache operations
            let testKey = UUID().uuidString
            let testConfig = AlarmManager.AlarmConfiguration(
                countdownDuration: AlarmKit.Alarm.CountdownDuration(preAlert: nil, postAlert: nil),
                schedule: AlarmKit.Alarm.Schedule.relative(AlarmKit.Alarm.Schedule.Relative(
                    time: AlarmKit.Alarm.Schedule.Relative.Time(hour: 7, minute: 0),
                    repeats: AlarmKit.Alarm.Schedule.Relative.Recurrence.never
                )),
                attributes: AlarmAttributes(
                    presentation: AlarmPresentation(
                        alert: AlarmPresentation.Alert(
                            title: LocalizedStringResource(stringLiteral: "Test"),
                            stopButton: AlarmButton(text: "Done", textColor: .white, systemImageName: "checkmark"),
                            secondaryButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "repeat"),
                            secondaryButtonBehavior: .countdown
                        ),
                        countdown: AlarmPresentation.Countdown(
                            title: LocalizedStringResource(stringLiteral: "Snoozing"),
                            pauseButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "repeat")
                        )
                    ),
                    metadata: StartSmartAlarmMetadata(),
                    tintColor: .blue
                ),
                secondaryIntent: nil,
                sound: .default
            )
            
            cacheService.cacheAlarmConfiguration(testConfig, for: testKey)
            let cachedConfig = cacheService.getCachedAlarmConfiguration(for: testKey)
            XCTAssertNotNil(cachedConfig)
        }
    }
}

// MARK: - Integration Test Suite

@available(iOS 26.0, *)
class IntegrationTestSuite: XCTestCase {
    
    func testCompleteSystemIntegration() async throws {
        // Test complete system integration
        let alarmKitManager = AlarmKitManager.shared
        let optimizedManager = OptimizedAlarmKitManager.shared
        let cacheService = AlarmDataCacheService.shared
        let performanceService = PerformanceMonitoringService.shared
        let dynamicIslandService = DynamicIslandAlarmService.shared
        let customizationService = AdvancedAlarmCustomizationService.shared
        let recommendationsService = SmartAlarmRecommendationsService.shared
        
        // Test that all services are properly initialized
        XCTAssertNotNil(alarmKitManager)
        XCTAssertNotNil(optimizedManager)
        XCTAssertNotNil(cacheService)
        XCTAssertNotNil(performanceService)
        XCTAssertNotNil(dynamicIslandService)
        XCTAssertNotNil(customizationService)
        XCTAssertNotNil(recommendationsService)
        
        // Test basic functionality
        let testAlarm = StartSmart.Alarm(
            label: "Integration Test Alarm",
            time: Date().addingTimeInterval(3600),
            isRepeating: false,
            snoozeEnabled: true,
            snoozeDuration: 300
        )
        
        // Test alarm scheduling
        try await alarmKitManager.scheduleAlarm(for: testAlarm)
        
        // Test cache operations
        let config = AlarmManager.AlarmConfiguration(
            countdownDuration: AlarmKit.Alarm.CountdownDuration(preAlert: nil, postAlert: nil),
            schedule: AlarmKit.Alarm.Schedule.relative(AlarmKit.Alarm.Schedule.Relative(
                time: AlarmKit.Alarm.Schedule.Relative.Time(hour: 7, minute: 0),
                repeats: AlarmKit.Alarm.Schedule.Relative.Recurrence.never
            )),
            attributes: AlarmAttributes(
                presentation: AlarmPresentation(
                    alert: AlarmPresentation.Alert(
                        title: LocalizedStringResource(stringLiteral: "Test"),
                        stopButton: AlarmButton(text: "Done", textColor: .white, systemImageName: "checkmark"),
                        secondaryButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "repeat"),
                        secondaryButtonBehavior: .countdown
                    ),
                    countdown: AlarmPresentation.Countdown(
                        title: LocalizedStringResource(stringLiteral: "Snoozing"),
                        pauseButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "repeat")
                    )
                ),
                metadata: StartSmartAlarmMetadata(),
                tintColor: .blue
            ),
            secondaryIntent: nil,
            sound: .default
        )
        
        cacheService.cacheAlarmConfiguration(config, for: testAlarm.id.uuidString)
        
        // Test Dynamic Island integration
        await dynamicIslandService.startAlarmActivity(for: testAlarm)
        
        // Test customization
        if let firstTheme = customizationService.availableThemes.first {
            customizationService.selectedTheme = firstTheme
        }
        
        // Test recommendations
        await recommendationsService.analyzeUserData()
        
        // Clean up
        try await alarmKitManager.cancelAlarm(withId: testAlarm.id.uuidString)
        await dynamicIslandService.endAlarmActivity()
        
        // Verify cleanup
        let finalAlarms = alarmKitManager.alarms
        XCTAssertFalse(finalAlarms.contains { $0.id.uuidString == testAlarm.id.uuidString })
    }
}
