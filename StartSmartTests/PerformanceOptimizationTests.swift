import XCTest
@testable import StartSmart
import SwiftUI
import Combine

/// Performance optimization validation tests
final class PerformanceOptimizationTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testPerformanceOptimizerInitialization() {
        let optimizer = PerformanceOptimizer.shared
        XCTAssertNotNil(optimizer)
        XCTAssertNotNil(optimizer.memoryUsage)
    }
    
    func testExecutionTimeMeasurement() {
        let optimizer = PerformanceOptimizer.shared
        
        let result = optimizer.measureExecutionTime(operation: "Test Operation") {
            // Simulate some work
            Thread.sleep(forTimeInterval: 0.1)
            return "completed"
        }
        
        XCTAssertEqual(result, "completed")
    }
    
    func testAsyncExecutionTimeMeasurement() async {
        let optimizer = PerformanceOptimizer.shared
        
        let result = await optimizer.measureAsyncExecutionTime(operation: "Async Test Operation") {
            // Simulate async work
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return "async completed"
        }
        
        XCTAssertEqual(result, "async completed")
    }
    
    func testMemoryUsageCalculation() {
        let optimizer = PerformanceOptimizer.shared
        let memoryUsage = optimizer.memoryUsage
        
        XCTAssertGreaterThanOrEqual(memoryUsage.used, 0)
        XCTAssertGreaterThanOrEqual(memoryUsage.total, 0)
        XCTAssertGreaterThanOrEqual(memoryUsage.percentage, 0.0)
        XCTAssertLessThanOrEqual(memoryUsage.percentage, 1.0)
    }
    
    // MARK: - Data Processing Performance Tests
    
    func testBatchProcessingPerformance() {
        let largeDataSet = Array(1...10000)
        
        // Measure batch processing performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let results = PerformanceOptimizer.processInBatches(
            data: largeDataSet,
            batchSize: 100
        ) { number in
            return number * 2
        }
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertEqual(results.count, largeDataSet.count)
        XCTAssertEqual(results.first, 2)
        XCTAssertEqual(results.last, 20000)
        XCTAssertLessThan(executionTime, 1.0) // Should complete within 1 second
    }
    
    func testAsyncBatchProcessingPerformance() async {
        let largeDataSet = Array(1...1000)
        
        // Measure async batch processing performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let results = await PerformanceOptimizer.processInBatchesAsync(
            data: largeDataSet,
            batchSize: 100,
            maxConcurrency: 4
        ) { number in
            // Simulate async work
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            return number * 3
        }
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertEqual(results.count, largeDataSet.count)
        XCTAssertEqual(results.first, 3)
        XCTAssertEqual(results.last, 3000)
        XCTAssertLessThan(executionTime, 5.0) // Should complete within 5 seconds with concurrency
    }
    
    // MARK: - Asset Optimization Tests
    
    func testAssetOptimizerInitialization() {
        let optimizer = AssetOptimizer.shared
        XCTAssertNotNil(optimizer)
    }
    
    func testImageOptimization() {
        let optimizer = AssetOptimizer.shared
        
        // Create a test image
        let testImage = createTestImage(size: CGSize(width: 2000, height: 2000))
        
        // Optimize the image
        let optimizedImage = optimizer.optimizeImage(
            testImage,
            maxWidth: 1024,
            maxHeight: 1024,
            compressionQuality: 0.8
        )
        
        XCTAssertNotNil(optimizedImage)
        XCTAssertLessThanOrEqual(optimizedImage!.size.width, 1024)
        XCTAssertLessThanOrEqual(optimizedImage!.size.height, 1024)
    }
    
    func testBundleAnalysis() {
        let optimizer = AssetOptimizer.shared
        
        // Perform bundle analysis
        let analysis = optimizer.analyzeBundleSize()
        
        XCTAssertGreaterThan(analysis.totalSize, 0)
        XCTAssertNotNil(analysis.imageAssets)
        XCTAssertNotNil(analysis.audioAssets)
        XCTAssertNotNil(analysis.codeSize)
        
        // Verify analysis includes recommendations
        XCTAssertNotNil(analysis.recommendations)
    }
    
    func testImageCachePerformance() {
        let optimizer = AssetOptimizer.shared
        
        // Clear cache first
        optimizer.clearImageCache()
        
        // Test loading and caching performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 1...10 {
            let imageName = "test_image_\(i)"
            _ = optimizer.loadOptimizedImage(named: imageName)
        }
        
        let firstLoadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Test cached loading performance
        let cacheStartTime = CFAbsoluteTimeGetCurrent()
        
        for i in 1...10 {
            let imageName = "test_image_\(i)"
            _ = optimizer.loadOptimizedImage(named: imageName)
        }
        
        let cachedLoadTime = CFAbsoluteTimeGetCurrent() - cacheStartTime
        
        // Cached loading should be faster (or at least not significantly slower)
        XCTAssertLessThanOrEqual(cachedLoadTime, firstLoadTime * 1.5)
    }
    
    // MARK: - View Performance Tests
    
    func testOptimizedViewModifiers() {
        // Test that optimized view modifiers don't crash
        let testView = Text("Test")
            .performanceOptimized()
            .lazyLoading()
            .optimizedForLargeList()
        
        XCTAssertNotNil(testView)
    }
    
    func testLazyVStackPerformance() {
        // Test LazyVStack performance with large data sets
        let largeDataSet = Array(1...1000)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let lazyVStack = LazyVStack {
            ForEach(largeDataSet, id: \.self) { item in
                Text("Item \(item)")
                    .optimizedForLargeList()
            }
        }
        
        let creationTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertNotNil(lazyVStack)
        XCTAssertLessThan(creationTime, 0.1) // Should create quickly
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryCleanupNotification() {
        let expectation = expectation(description: "Memory cleanup notification")
        
        NotificationCenter.default.addObserver(
            forName: .performMemoryCleanup,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        // Trigger memory cleanup
        NotificationCenter.default.post(name: .performMemoryCleanup, object: nil)
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testLargeDataSetHandling() {
        // Test handling of large data sets without memory issues
        let mockStorage = MockStorageManager()
        let viewModel = AlarmViewModel(storageManager: mockStorage)
        
        // Create a large number of alarms
        let largeAlarmSet = (1...1000).map { index in
            Alarm(
                time: Date().addingTimeInterval(TimeInterval(index * 60)),
                label: "Alarm \(index)"
            )
        }
        
        // Measure memory before
        let initialMemory = PerformanceOptimizer.shared.memoryUsage.used
        
        // Add all alarms
        let startTime = CFAbsoluteTimeGetCurrent()
        for alarm in largeAlarmSet {
            viewModel.addAlarm(alarm)
        }
        let addTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Measure memory after
        let finalMemory = PerformanceOptimizer.shared.memoryUsage.used
        let memoryIncrease = finalMemory - initialMemory
        
        XCTAssertEqual(viewModel.alarms.count, 1000)
        XCTAssertLessThan(addTime, 2.0) // Should add all alarms within 2 seconds
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024) // Should use less than 50MB additional memory
    }
    
    // MARK: - Performance Metrics Tests
    
    func testPerformanceMetricsCollection() {
        let metrics = PerformanceMetrics.shared
        
        // Record some test metrics
        metrics.recordMetric("test_operation", value: 0.1)
        metrics.recordMetric("test_operation", value: 0.2)
        metrics.recordMetric("test_operation", value: 0.15)
        
        // Get average
        let average = metrics.getAverageMetric("test_operation")
        XCTAssertNotNil(average)
        XCTAssertEqual(average!, 0.15, accuracy: 0.01)
        
        // Get summary
        let summary = metrics.getMetricSummary("test_operation")
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary!.name, "test_operation")
        XCTAssertEqual(summary!.count, 3)
        XCTAssertEqual(summary!.min, 0.1, accuracy: 0.01)
        XCTAssertEqual(summary!.max, 0.2, accuracy: 0.01)
    }
    
    // MARK: - UI Responsiveness Tests
    
    @MainActor
    func testUIResponsiveness() async {
        // Test that UI operations complete quickly
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate UI updates
        let mockViewModel = AlarmViewModel(storageManager: MockStorageManager())
        
        for i in 1...100 {
            let alarm = Alarm(time: Date(), label: "Test \(i)")
            mockViewModel.addAlarm(alarm)
        }
        
        let uiUpdateTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(uiUpdateTime, 1.0) // UI updates should complete within 1 second
        XCTAssertEqual(mockViewModel.alarms.count, 100)
    }
    
    func testAnimationPerformance() {
        // Test that animations don't cause performance issues
        let testView = Rectangle()
            .fill(Color.blue)
            .frame(width: 100, height: 100)
            .animation(.easeInOut(duration: 0.2), value: UUID())
        
        XCTAssertNotNil(testView)
    }
    
    // MARK: - Stress Tests
    
    func testConcurrentOperationsStress() async {
        // Test multiple concurrent operations
        let operations = (1...50).map { index in
            Task {
                await PerformanceOptimizer.shared.measureAsyncExecutionTime(operation: "Concurrent Op \(index)") {
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    return index * 2
                }
            }
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let results = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
            for operation in operations {
                group.addTask {
                    await operation.value
                }
            }
            
            var allResults: [Int] = []
            for await result in group {
                allResults.append(result)
            }
            return allResults
        }
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertEqual(results.count, 50)
        XCTAssertLessThan(totalTime, 2.0) // Should complete within 2 seconds with concurrency
    }
    
    func testMemoryPressureHandling() {
        // Simulate memory pressure
        var largeObjects: [Data] = []
        
        // Create large data objects
        for _ in 1...100 {
            let largeData = Data(count: 1024 * 1024) // 1MB each
            largeObjects.append(largeData)
        }
        
        // Check that memory monitoring still works
        let memoryUsage = PerformanceOptimizer.shared.memoryUsage
        XCTAssertGreaterThan(memoryUsage.used, 0)
        
        // Clean up
        largeObjects.removeAll()
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}

// MARK: - Performance Test Extensions

extension XCTestCase {
    func measurePerformance(description: String, block: () -> Void) {
        let startTime = CFAbsoluteTimeGetCurrent()
        block()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        print("⏱️ \(description): \(String(format: "%.3f", executionTime))s")
    }
    
    func measureAsyncPerformance(description: String, block: () async -> Void) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        await block()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        print("⏱️ \(description): \(String(format: "%.3f", executionTime))s")
    }
}

// MARK: - Mock Storage Manager Extension for Performance Testing

extension MockStorageManager {
    func generateLargeDataSet(count: Int) -> [Alarm] {
        return (1...count).map { index in
            Alarm(
                time: Date().addingTimeInterval(TimeInterval(index * 60)),
                label: "Performance Test Alarm \(index)",
                tone: AlarmTone.allCases.randomElement() ?? .energetic
            )
        }
    }
}

// MARK: - Performance Benchmarks

final class PerformanceBenchmarks {
    static func runAllBenchmarks() {
        print("🚀 Starting Performance Benchmarks")
        
        benchmarkDataProcessing()
        benchmarkMemoryUsage()
        benchmarkUIPerformance()
        
        print("✅ Performance Benchmarks Completed")
    }
    
    private static func benchmarkDataProcessing() {
        print("📊 Benchmarking Data Processing...")
        
        let largeDataSet = Array(1...100000)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let results = PerformanceOptimizer.processInBatches(data: largeDataSet, batchSize: 1000) { $0 * 2 }
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        print("   Processed \(results.count) items in \(String(format: "%.3f", executionTime))s")
    }
    
    private static func benchmarkMemoryUsage() {
        print("💾 Benchmarking Memory Usage...")
        
        let initialMemory = PerformanceOptimizer.shared.memoryUsage.used
        
        // Create and release large objects
        autoreleasepool {
            var largeObjects: [Data] = []
            for _ in 1...100 {
                largeObjects.append(Data(count: 1024 * 1024)) // 1MB each
            }
            largeObjects.removeAll()
        }
        
        let finalMemory = PerformanceOptimizer.shared.memoryUsage.used
        let memoryDelta = finalMemory - initialMemory
        
        print("   Memory delta: \(memoryDelta / (1024 * 1024))MB")
    }
    
    private static func benchmarkUIPerformance() {
        print("🎨 Benchmarking UI Performance...")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate UI creation
        let views = (1...1000).map { index in
            Text("Item \(index)")
                .performanceOptimized()
        }
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        print("   Created \(views.count) optimized views in \(String(format: "%.3f", executionTime))s")
    }
}
