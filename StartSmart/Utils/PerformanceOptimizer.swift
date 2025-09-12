import Foundation
import SwiftUI
import Combine
import os.log

/// Performance optimization utilities and monitoring
final class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    private let logger = Logger(subsystem: "com.startsmart.performance", category: "optimization")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Memory Management
    
    /// Monitor memory usage and trigger cleanup when needed
    @Published var memoryUsage: MemoryUsage = MemoryUsage()
    
    private init() {
        startMemoryMonitoring()
    }
    
    private func startMemoryMonitoring() {
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMemoryUsage()
            }
            .store(in: &cancellables)
    }
    
    private func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        DispatchQueue.main.async {
            self.memoryUsage = usage
            
            // Trigger cleanup if memory usage is high
            if usage.percentage > 0.8 {
                self.performMemoryCleanup()
            }
        }
    }
    
    private func getCurrentMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = info.resident_size
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            
            return MemoryUsage(
                used: usedMemory,
                total: totalMemory,
                percentage: Double(usedMemory) / Double(totalMemory)
            )
        }
        
        return MemoryUsage()
    }
    
    private func performMemoryCleanup() {
        logger.info("Performing memory cleanup due to high usage")
        
        // Clear caches
        NotificationCenter.default.post(name: .performMemoryCleanup, object: nil)
        
        // Force garbage collection
        autoreleasepool {
            // Empty pool to release temporary objects
        }
    }
    
    // MARK: - Performance Monitoring
    
    func measureExecutionTime<T>(
        operation: String,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.info("⏱️ \(operation) took \(String(format: "%.3f", executionTime))s")
        
        if executionTime > 1.0 {
            logger.warning("⚠️ Slow operation detected: \(operation) took \(String(format: "%.3f", executionTime))s")
        }
        
        return result
    }
    
    func measureAsyncExecutionTime<T>(
        operation: String,
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.info("⏱️ \(operation) took \(String(format: "%.3f", executionTime))s")
        
        if executionTime > 2.0 {
            logger.warning("⚠️ Slow async operation detected: \(operation) took \(String(format: "%.3f", executionTime))s")
        }
        
        return result
    }
    
    // MARK: - View Performance Optimization
    
    /// Optimize SwiftUI view updates
    static func optimizeViewUpdates<T: View>(_ view: T) -> some View {
        view
            .drawingGroup(opaque: false, colorMode: .nonLinear) // Flatten view hierarchy for complex views
            .animation(.easeInOut(duration: 0.2), value: UUID()) // Optimize animations
    }
    
    /// Create optimized list row
    static func optimizedListRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .buttonStyle(PlainButtonStyle()) // Prevent unnecessary button animations
    }
    
    // MARK: - Image Optimization
    
    /// Optimize image loading and caching
    static func optimizedAsyncImage(url: URL?, placeholder: Image = Image(systemName: "photo")) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                placeholder
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            case .failure(_):
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red.opacity(0.6))
            @unknown default:
                placeholder
            }
        }
        .animation(.easeInOut(duration: 0.3), value: url)
    }
    
    // MARK: - Data Processing Optimization
    
    /// Optimize large data processing with batching
    static func processInBatches<T, U>(
        data: [T],
        batchSize: Int = 100,
        transform: (T) -> U
    ) -> [U] {
        var results: [U] = []
        results.reserveCapacity(data.count)
        
        for batch in data.chunked(into: batchSize) {
            autoreleasepool {
                let batchResults = batch.map(transform)
                results.append(contentsOf: batchResults)
            }
        }
        
        return results
    }
    
    /// Optimize async data processing with concurrency
    static func processInBatchesAsync<T, U>(
        data: [T],
        batchSize: Int = 100,
        maxConcurrency: Int = 4,
        transform: @escaping (T) async -> U
    ) async -> [U] {
        let batches = data.chunked(into: batchSize)
        var results: [U] = []
        results.reserveCapacity(data.count)
        
        for batch in batches.chunked(into: maxConcurrency) {
            let batchResults = await withTaskGroup(of: [U].self) { group in
                for subBatch in batch {
                    group.addTask {
                        var subResults: [U] = []
                        for item in subBatch {
                            let result = await transform(item)
                            subResults.append(result)
                        }
                        return subResults
                    }
                }
                
                var allResults: [U] = []
                for await batchResult in group {
                    allResults.append(contentsOf: batchResult)
                }
                return allResults
            }
            
            results.append(contentsOf: batchResults)
        }
        
        return results
    }
}

// MARK: - Memory Usage Model

struct MemoryUsage {
    let used: UInt64
    let total: UInt64
    let percentage: Double
    
    init() {
        self.used = 0
        self.total = 0
        self.percentage = 0.0
    }
    
    init(used: UInt64, total: UInt64, percentage: Double) {
        self.used = used
        self.total = total
        self.percentage = percentage
    }
    
    var usedMB: Double {
        Double(used) / (1024 * 1024)
    }
    
    var totalMB: Double {
        Double(total) / (1024 * 1024)
    }
    
    var isHighUsage: Bool {
        percentage > 0.8
    }
    
    var status: MemoryStatus {
        switch percentage {
        case 0..<0.5:
            return .good
        case 0.5..<0.8:
            return .warning
        default:
            return .critical
        }
    }
}

enum MemoryStatus {
    case good
    case warning
    case critical
    
    var color: Color {
        switch self {
        case .good:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
    
    var description: String {
        switch self {
        case .good:
            return "Good"
        case .warning:
            return "High"
        case .critical:
            return "Critical"
        }
    }
}

// MARK: - Performance Notifications

extension Notification.Name {
    static let performMemoryCleanup = Notification.Name("performMemoryCleanup")
    static let performanceWarning = Notification.Name("performanceWarning")
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Performance-Optimized View Modifiers

struct PerformanceOptimized: ViewModifier {
    func body(content: Content) -> some View {
        content
            .drawingGroup(opaque: false, colorMode: .nonLinear)
            .animation(.easeInOut(duration: 0.2), value: UUID())
    }
}

struct LazyLoadingModifier: ViewModifier {
    let threshold: CGFloat = 100
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) {
                    isVisible = true
                }
            }
            .onDisappear {
                isVisible = false
            }
    }
}

extension View {
    func performanceOptimized() -> some View {
        modifier(PerformanceOptimized())
    }
    
    func lazyLoading() -> some View {
        modifier(LazyLoadingModifier())
    }
    
    /// Optimize for large lists
    func optimizedForLargeList() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Performance Metrics Collection

final class PerformanceMetrics {
    static let shared = PerformanceMetrics()
    
    private var metrics: [String: [Double]] = [:]
    private let queue = DispatchQueue(label: "performance.metrics", qos: .utility)
    
    private init() {}
    
    func recordMetric(_ name: String, value: Double) {
        queue.async {
            if self.metrics[name] == nil {
                self.metrics[name] = []
            }
            self.metrics[name]?.append(value)
            
            // Keep only last 100 measurements
            if let count = self.metrics[name]?.count, count > 100 {
                self.metrics[name]?.removeFirst()
            }
        }
    }
    
    func getAverageMetric(_ name: String) -> Double? {
        return queue.sync {
            guard let values = metrics[name], !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }
    }
    
    func getMetricSummary(_ name: String) -> MetricSummary? {
        return queue.sync {
            guard let values = metrics[name], !values.isEmpty else { return nil }
            
            let sorted = values.sorted()
            let count = values.count
            let sum = values.reduce(0, +)
            
            return MetricSummary(
                name: name,
                count: count,
                average: sum / Double(count),
                min: sorted.first!,
                max: sorted.last!,
                median: count % 2 == 0 
                    ? (sorted[count/2 - 1] + sorted[count/2]) / 2
                    : sorted[count/2]
            )
        }
    }
    
    func getAllMetrics() -> [MetricSummary] {
        return queue.sync {
            return metrics.keys.compactMap { getMetricSummary($0) }
        }
    }
}

struct MetricSummary {
    let name: String
    let count: Int
    let average: Double
    let min: Double
    let max: Double
    let median: Double
}

// MARK: - Performance Debug View

#if DEBUG
struct PerformanceDebugView: View {
    @StateObject private var optimizer = PerformanceOptimizer.shared
    @State private var showingMetrics = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance Monitor")
                    .font(.headline)
                Spacer()
                Button("Metrics") {
                    showingMetrics = true
                }
                .buttonStyle(.bordered)
            }
            
            HStack {
                Circle()
                    .fill(optimizer.memoryUsage.status.color)
                    .frame(width: 12, height: 12)
                
                Text("Memory: \(String(format: "%.1f", optimizer.memoryUsage.usedMB))MB")
                    .font(.caption)
                
                Text("(\(String(format: "%.1f", optimizer.memoryUsage.percentage * 100))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(optimizer.memoryUsage.status.description)
                    .font(.caption)
                    .foregroundColor(optimizer.memoryUsage.status.color)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showingMetrics) {
            PerformanceMetricsView()
        }
    }
}

struct PerformanceMetricsView: View {
    @State private var metrics: [MetricSummary] = []
    
    var body: some View {
        NavigationView {
            List(metrics, id: \.name) { metric in
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.name)
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Avg: \(String(format: "%.3f", metric.average))s")
                            Text("Count: \(metric.count)")
                        }
                        .font(.caption)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Min: \(String(format: "%.3f", metric.min))s")
                            Text("Max: \(String(format: "%.3f", metric.max))s")
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("Performance Metrics")
            .onAppear {
                metrics = PerformanceMetrics.shared.getAllMetrics()
            }
        }
    }
}
#endif
