import SwiftUI
import Charts
import Combine

/// Performance-optimized version of the Analytics Dashboard
struct OptimizedAnalyticsDashboardView: View {
    @StateObject private var streakService = DependencyContainer.shared.resolve(StreakTrackingServiceProtocol.self) as! StreakTrackingService
    @State private var stats = EnhancedUserStats()
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingDetailView = false
    @State private var selectedInsight: AnalyticsInsight?
    
    // Performance optimization: Lazy loading states
    @State private var hasLoadedCharts = false
    @State private var hasLoadedInsights = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Time range selector - Always visible
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                        .performanceOptimized()
                    
                    // Key metrics overview - Always visible
                    KeyMetricsSection(stats: stats, timeRange: selectedTimeRange)
                        .performanceOptimized()
                    
                    // Charts section - Lazy loaded
                    if hasLoadedCharts {
                        ChartsSection(stats: stats, timeRange: selectedTimeRange)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .performanceOptimized()
                    } else {
                        ChartLoadingPlaceholder()
                            .onAppear {
                                withAnimation(.easeIn(duration: 0.3)) {
                                    hasLoadedCharts = true
                                }
                            }
                    }
                    
                    // Insights section - Lazy loaded
                    if hasLoadedInsights {
                        InsightsSection(
                            stats: stats,
                            onInsightTap: { insight in
                                selectedInsight = insight
                                showingDetailView = true
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .performanceOptimized()
                    } else if hasLoadedCharts {
                        InsightsLoadingPlaceholder()
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation(.easeIn(duration: 0.3)) {
                                        hasLoadedInsights = true
                                    }
                                }
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshData()
            }
            .onAppear {
                loadInitialData()
            }
            .onChange(of: selectedTimeRange) { _ in
                updateDataForTimeRange()
            }
            .sheet(isPresented: $showingDetailView) {
                if let insight = selectedInsight {
                    InsightDetailView(insight: insight)
                }
            }
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            PerformanceDebugView()
                .padding()
        }
        #endif
    }
    
    // MARK: - Data Loading Methods
    
    private func loadInitialData() {
        Task {
            await PerformanceOptimizer.shared.measureAsyncExecutionTime(operation: "Load Initial Analytics Data") {
                stats = await streakService.getEnhancedStats(for: selectedTimeRange)
            }
        }
    }
    
    @MainActor
    private func refreshData() async {
        await PerformanceOptimizer.shared.measureAsyncExecutionTime(operation: "Refresh Analytics Data") {
            stats = await streakService.getEnhancedStats(for: selectedTimeRange)
        }
    }
    
    private func updateDataForTimeRange() {
        Task {
            await PerformanceOptimizer.shared.measureAsyncExecutionTime(operation: "Update Data for Time Range") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    stats = await streakService.getEnhancedStats(for: selectedTimeRange)
                }
            }
        }
    }
}

// MARK: - Optimized Chart Section

struct ChartsSection: View {
    let stats: EnhancedUserStats
    let timeRange: TimeRange
    
    var body: some View {
        VStack(spacing: 16) {
            // Streak progress chart
            OptimizedStreakProgressChart(
                stats: stats,
                timeRange: timeRange
            )
            
            // Wake-up patterns
            OptimizedWakeUpPatternsChart(
                stats: stats,
                timeRange: timeRange
            )
        }
    }
}

// MARK: - Optimized Insights Section

struct InsightsSection: View {
    let stats: EnhancedUserStats
    let onInsightTap: (AnalyticsInsight) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Performance insights
            OptimizedPerformanceInsightsSection(
                stats: stats,
                onInsightTap: onInsightTap
            )
            
            // Goal recommendations
            OptimizedGoalRecommendationsSection(stats: stats)
        }
    }
}

// MARK: - Optimized Chart Components

struct OptimizedStreakProgressChart: View {
    let stats: EnhancedUserStats
    let timeRange: TimeRange
    
    // Memoized chart data
    private var chartData: [StreakDataPoint] {
        PerformanceOptimizer.processInBatches(
            data: stats.streakHistory,
            batchSize: 50
        ) { dataPoint in
            StreakDataPoint(
                date: dataPoint.date,
                streak: dataPoint.streak,
                isSuccess: dataPoint.isSuccess
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak Progress")
                .font(.headline)
                .foregroundColor(.primary)
            
            Chart(chartData, id: \.date) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Streak", dataPoint.streak)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                if dataPoint.isSuccess {
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Streak", dataPoint.streak)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(30)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

struct OptimizedWakeUpPatternsChart: View {
    let stats: EnhancedUserStats
    let timeRange: TimeRange
    
    // Memoized chart data
    private var chartData: [WakeUpPattern] {
        stats.wakeUpPatterns.prefix(20).map { $0 } // Limit to 20 data points for performance
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wake-up Patterns")
                .font(.headline)
                .foregroundColor(.primary)
            
            Chart(chartData, id: \.day) { pattern in
                BarMark(
                    x: .value("Day", pattern.day),
                    y: .value("Average Time", pattern.averageWakeTime)
                )
                .foregroundStyle(
                    pattern.isOnTime ? .green : .orange
                )
                .cornerRadius(4)
            }
            .frame(height: 150)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Optimized Insights Components

struct OptimizedPerformanceInsightsSection: View {
    let stats: EnhancedUserStats
    let onInsightTap: (AnalyticsInsight) -> Void
    
    // Memoized insights
    private var insights: [AnalyticsInsight] {
        stats.insights.prefix(5).map { $0 } // Limit to 5 insights for performance
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Insights")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 8) {
                ForEach(insights, id: \.id) { insight in
                    OptimizedInsightRow(insight: insight) {
                        onInsightTap(insight)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

struct OptimizedInsightRow: View {
    let insight: AnalyticsInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: insight.icon)
                    .foregroundColor(insight.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    Text(insight.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .optimizedForLargeList()
    }
}

struct OptimizedGoalRecommendationsSection: View {
    let stats: EnhancedUserStats
    
    // Memoized recommendations
    private var recommendations: [GoalRecommendation] {
        stats.recommendations.prefix(3).map { $0 } // Limit to 3 recommendations
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goal Recommendations")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 8) {
                ForEach(recommendations, id: \.id) { recommendation in
                    OptimizedRecommendationRow(recommendation: recommendation)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

struct OptimizedRecommendationRow: View {
    let recommendation: GoalRecommendation
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recommendation.icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.05))
        )
    }
}

// MARK: - Loading Placeholders

struct ChartLoadingPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            // Chart placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 200)
                .overlay {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading charts...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            
            // Wake-up patterns placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 150)
        }
        .lazyLoading()
    }
}

struct InsightsLoadingPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            // Insights placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 120)
                .overlay {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading insights...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            
            // Recommendations placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 100)
        }
        .lazyLoading()
    }
}

// MARK: - Data Models for Charts

struct StreakDataPoint {
    let date: Date
    let streak: Int
    let isSuccess: Bool
}

struct WakeUpPattern {
    let day: String
    let averageWakeTime: Date
    let isOnTime: Bool
}

// MARK: - Preview

#if DEBUG
struct OptimizedAnalyticsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        OptimizedAnalyticsDashboardView()
    }
}
#endif
