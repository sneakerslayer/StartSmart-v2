import Foundation
import AlarmKit
import os.log

// MARK: - AlarmKit Validation Script

/// Validation script to test core AlarmKit functionality
/// This script can be run to validate the integration without UI
@available(iOS 26.0, *)
class AlarmKitValidationScript {
    
    private let logger = Logger(subsystem: "com.startsmart.app", category: "ValidationScript")
    private let alarmKitManager = AlarmKitManager.shared
    private let alarmRepository = AlarmRepository()
    
    // MARK: - Validation Results
    
    struct ValidationResult {
        let testName: String
        let passed: Bool
        let message: String
        let duration: TimeInterval
    }
    
    private var results: [ValidationResult] = []
    
    // MARK: - Main Validation Method
    
    func runAllValidations() async -> [ValidationResult] {
        logger.info("🔍 Starting AlarmKit validation script")
        results.removeAll()
        
        // Run all validation tests
        await validateAlarmKitAvailability()
        await validateAlarmCreation()
        await validateAlarmScheduling()
        await validateAlarmCancellation()
        await validateAppIntents()
        await validateErrorHandling()
        await validatePerformance()
        
        // Print summary
        printValidationSummary()
        
        return results
    }
    
    // MARK: - Individual Validation Tests
    
    private func validateAlarmKitAvailability() async {
        let startTime = Date()
        
        do {
            let status = try await alarmKitManager.requestAuthorization()
            let passed = status == .authorized
            
            let result = ValidationResult(
                testName: "AlarmKit Availability",
                passed: passed,
                message: "Authorization status: \(status)",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.info("✅ AlarmKit availability validation: \(passed ? "PASSED" : "FAILED")")
            
        } catch {
            let result = ValidationResult(
                testName: "AlarmKit Availability",
                passed: false,
                message: "Error: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.error("❌ AlarmKit availability validation failed: \(error.localizedDescription)")
        }
    }
    
    private func validateAlarmCreation() async {
        let startTime = Date()
        
        do {
            let testAlarm = createTestAlarm()
            try await alarmRepository.saveAlarm(testAlarm)
            
            let savedAlarms = await alarmRepository.getEnabledAlarms()
            let alarmExists = savedAlarms.contains { $0.id == testAlarm.id }
            
            let result = ValidationResult(
                testName: "Alarm Creation",
                passed: alarmExists,
                message: alarmExists ? "Alarm created successfully" : "Alarm not found after creation",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.info("✅ Alarm creation validation: \(alarmExists ? "PASSED" : "FAILED")")
            
        } catch {
            let result = ValidationResult(
                testName: "Alarm Creation",
                passed: false,
                message: "Error: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.error("❌ Alarm creation validation failed: \(error.localizedDescription)")
        }
    }
    
    private func validateAlarmScheduling() async {
        let startTime = Date()
        
        do {
            let testAlarm = createTestAlarm()
            try await alarmKitManager.scheduleAlarm(for: testAlarm)
            
            let alarmKitAlarms = alarmKitManager.alarms
            let alarmScheduled = alarmKitAlarms.contains { $0.id.uuidString == testAlarm.id.uuidString }
            
            let result = ValidationResult(
                testName: "Alarm Scheduling",
                passed: alarmScheduled,
                message: alarmScheduled ? "Alarm scheduled in AlarmKit" : "Alarm not found in AlarmKit",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.info("✅ Alarm scheduling validation: \(alarmScheduled ? "PASSED" : "FAILED")")
            
        } catch {
            let result = ValidationResult(
                testName: "Alarm Scheduling",
                passed: false,
                message: "Error: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.error("❌ Alarm scheduling validation failed: \(error.localizedDescription)")
        }
    }
    
    private func validateAlarmCancellation() async {
        let startTime = Date()
        
        do {
            let testAlarm = createTestAlarm()
            try await alarmKitManager.scheduleAlarm(for: testAlarm)
            
            // Cancel the alarm
            try await alarmKitManager.cancelAlarm(withId: testAlarm.id.uuidString)
            
            let alarmKitAlarms = alarmKitManager.alarms
            let alarmCancelled = !alarmKitAlarms.contains { $0.id.uuidString == testAlarm.id.uuidString }
            
            let result = ValidationResult(
                testName: "Alarm Cancellation",
                passed: alarmCancelled,
                message: alarmCancelled ? "Alarm cancelled successfully" : "Alarm still exists after cancellation",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.info("✅ Alarm cancellation validation: \(alarmCancelled ? "PASSED" : "FAILED")")
            
        } catch {
            let result = ValidationResult(
                testName: "Alarm Cancellation",
                passed: false,
                message: "Error: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.error("❌ Alarm cancellation validation failed: \(error.localizedDescription)")
        }
    }
    
    private func validateAppIntents() async {
        let startTime = Date()
        
        do {
            // Test DismissAlarmIntent
            let dismissIntent = DismissAlarmIntent(alarmId: UUID().uuidString)
            let dismissResult = try await dismissIntent.perform()
            
            // Test SnoozeAlarmIntent
            let snoozeIntent = SnoozeAlarmIntent(alarmId: UUID().uuidString, snoozeDuration: 300)
            let snoozeResult = try await snoozeIntent.perform()
            
            // Test CreateAlarmIntent
            let createIntent = CreateAlarmIntent(
                alarmLabel: "Test Intent Alarm",
                alarmTime: Date().addingTimeInterval(3600),
                isRepeating: false,
                snoozeDuration: 300
            )
            let createResult = try await createIntent.perform()
            
            // Test ListAlarmsIntent
            let listIntent = ListAlarmsIntent()
            let listResult = try await listIntent.perform()
            
            let allIntentsWork = dismissResult != nil && snoozeResult != nil && createResult != nil && listResult != nil
            
            let result = ValidationResult(
                testName: "App Intents",
                passed: allIntentsWork,
                message: allIntentsWork ? "All App Intents work correctly" : "Some App Intents failed",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.info("✅ App Intents validation: \(allIntentsWork ? "PASSED" : "FAILED")")
            
        } catch {
            let result = ValidationResult(
                testName: "App Intents",
                passed: false,
                message: "Error: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.error("❌ App Intents validation failed: \(error.localizedDescription)")
        }
    }
    
    private func validateErrorHandling() async {
        let startTime = Date()
        
        do {
            // Test with invalid alarm ID
            try await alarmKitManager.cancelAlarm(withId: "invalid-id")
            
            // Test with non-existent alarm
            try await alarmKitManager.snoozeAlarm(withId: UUID().uuidString, duration: 300)
            
            // These should not throw errors, but handle them gracefully
            let result = ValidationResult(
                testName: "Error Handling",
                passed: true,
                message: "Error handling works correctly",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.info("✅ Error handling validation: PASSED")
            
        } catch {
            let result = ValidationResult(
                testName: "Error Handling",
                passed: false,
                message: "Error: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.error("❌ Error handling validation failed: \(error.localizedDescription)")
        }
    }
    
    private func validatePerformance() async {
        let startTime = Date()
        
        do {
            // Test bulk alarm creation
            let alarms = (0..<5).map { _ in createTestAlarm() }
            
            for alarm in alarms {
                try await alarmRepository.saveAlarm(alarm)
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let averageTime = duration / Double(alarms.count)
            let performanceGood = averageTime < 1.0 // Should be less than 1 second per alarm
            
            let result = ValidationResult(
                testName: "Performance",
                passed: performanceGood,
                message: "Average creation time: \(String(format: "%.2f", averageTime))s per alarm",
                duration: duration
            )
            results.append(result)
            
            logger.info("✅ Performance validation: \(performanceGood ? "PASSED" : "FAILED")")
            
            // Clean up test alarms
            for alarm in alarms {
                try await alarmRepository.deleteAlarm(alarm)
            }
            
        } catch {
            let result = ValidationResult(
                testName: "Performance",
                passed: false,
                message: "Error: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startTime)
            )
            results.append(result)
            
            logger.error("❌ Performance validation failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestAlarm() -> Alarm {
        return Alarm(
            label: "Validation Test Alarm \(UUID().uuidString.prefix(8))",
            time: Date().addingTimeInterval(3600), // 1 hour from now
            isRepeating: false,
            snoozeEnabled: true,
            snoozeDuration: 300
        )
    }
    
    private func printValidationSummary() {
        let passedCount = results.filter { $0.passed }.count
        let totalCount = results.count
        let passRate = Double(passedCount) / Double(totalCount) * 100
        
        logger.info("📊 Validation Summary:")
        logger.info("   Total Tests: \(totalCount)")
        logger.info("   Passed: \(passedCount)")
        logger.info("   Failed: \(totalCount - passedCount)")
        logger.info("   Pass Rate: \(String(format: "%.1f", passRate))%")
        
        print("\n🔍 AlarmKit Validation Results:")
        print("=" * 50)
        
        for result in results {
            let status = result.passed ? "✅ PASS" : "❌ FAIL"
            print("\(status) \(result.testName)")
            print("   Message: \(result.message)")
            print("   Duration: \(String(format: "%.3f", result.duration))s")
            print()
        }
        
        print("=" * 50)
        print("📊 Summary: \(passedCount)/\(totalCount) tests passed (\(String(format: "%.1f", passRate))%)")
        
        if passRate >= 90.0 {
            print("🎉 Validation PASSED - Ready for release!")
        } else if passRate >= 70.0 {
            print("⚠️  Validation PARTIAL - Some issues need attention")
        } else {
            print("❌ Validation FAILED - Major issues need fixing")
        }
    }
}

// MARK: - Validation Runner

/// Convenience function to run validation
@available(iOS 26.0, *)
func runAlarmKitValidation() async {
    let validator = AlarmKitValidationScript()
    let results = await validator.runAllValidations()
    
    // Return results for further processing if needed
    _ = results
}

// MARK: - String Extension for Repeat Operator

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
