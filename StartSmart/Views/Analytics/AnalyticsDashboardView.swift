import SwiftUI
import Charts
import Combine

// MARK: - Analytics Dashboard View
struct AnalyticsDashboardView: View {
    @StateObject private var streakService = DependencyContainer.shared.resolve(StreakTrackingServiceProtocol.self) as! StreakTrackingService
    @State private var stats = EnhancedUserStats()
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingDetailView = false
    @State private var selectedInsight: AnalyticsInsight?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Time range selector
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                    
                    // Key metrics overview
                    KeyMetricsSection(stats: stats, timeRange: selectedTimeRange)
                    
                    // Streak progress chart
                    StreakProgressChart(
                        stats: stats,
                        timeRange: selectedTimeRange
                    )
                    
                    // Wake-up patterns
                    WakeUpPatternsSection(
                        stats: stats,
                        timeRange: selectedTimeRange
                    )
                    
                    // Performance insights
                    PerformanceInsightsSection(
                        stats: stats,
                        onInsightTap: { insight in
                            selectedInsight = insight
                            showingDetailView = true
                        }
                    )
                    
                    // Goal recommendations
                    GoalRecommendationsSection(stats: stats)
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDetailView) {
                if let insight = selectedInsight {
                    InsightDetailView(insight: insight)
                }
            }
            .onReceive(streakService.enhancedStats) { newStats in
                stats = newStats
            }
        }
    }
}

// MARK: - Time Range Enum
enum TimeRange: String, CaseIterable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case year = "1Y"
    
    var displayName: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .quarter: return "Last 3 Months"
        case .year: return "This Year"
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

// MARK: - Time Range Selector
struct TimeRangeSelector: View {
    @Binding var selectedRange: TimeRange
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedRange = range
                }) {
                    Text(range.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(selectedRange == range ? .white : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedRange == range ? Color.blue : Color.blue.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Key Metrics Section
struct KeyMetricsSection: View {
    let stats: EnhancedUserStats
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Metrics")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "Success Rate",
                    value: "\(Int(stats.successRate * 100))%",
                    subtitle: "Overall performance",
                    icon: "target",
                    color: .green,
                    trend: .stable
                )
                
                MetricCard(
                    title: "Current Streak",
                    value: "\(stats.currentStreak)",
                    subtitle: "days in a row",
                    icon: "flame.fill",
                    color: .orange,
                    trend: stats.currentStreak > 0 ? .up : .down
                )
                
                MetricCard(
                    title: "This Week",
                    value: "\(stats.thisWeekSuccesses)/7",
                    subtitle: "\(Int(stats.weeklySuccessRate * 100))% success",
                    icon: "calendar.day.timeline.left",
                    color: .blue,
                    trend: stats.weeklySuccessRate >= 0.8 ? .up : stats.weeklySuccessRate >= 0.5 ? .stable : .down
                )
                
                MetricCard(
                    title: "Avg Wake Time",
                    value: stats.averageWakeUpTimeFormatted,
                    subtitle: "daily average",
                    icon: "clock.fill",
                    color: .purple,
                    trend: .stable
                )
            }
        }
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    
    enum TrendDirection {
        case up, down, stable
        
        var iconName: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: trend.iconName)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Streak Progress Chart
struct StreakProgressChart: View {
    let stats: EnhancedUserStats
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Streak Progress")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            if #available(iOS 16.0, *) {
                Chart(generateChartData()) { dataPoint in
                    LineMark(
                        x: .value("Day", dataPoint.date),
                        y: .value("Streak", dataPoint.streakLength)
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.stepStart)
                    
                    AreaMark(
                        x: .value("Day", dataPoint.date),
                        y: .value("Streak", dataPoint.streakLength)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .orange.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.stepStart)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: timeRange == .week ? 1 : 7)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            } else {
                // Fallback for iOS < 16
                StreakProgressFallbackView(stats: stats, timeRange: timeRange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func generateChartData() -> [StreakDataPoint] {
        var dataPoints: [StreakDataPoint] = []
        let calendar = Calendar.current
        let endDate = Date()
        
        for i in 0..<timeRange.days {
            let date = calendar.date(byAdding: .day, value: -i, to: endDate) ?? endDate
            
            // Simulate streak data based on current stats
            // In a real implementation, this would come from stored historical data
            let streakLength = max(0, stats.currentStreak - i)
            
            dataPoints.append(StreakDataPoint(date: date, streakLength: streakLength))
        }
        
        return dataPoints.reversed()
    }
}

// MARK: - Streak Data Point
struct StreakDataPoint {
    let date: Date
    let streakLength: Int
}

// MARK: - Streak Progress Fallback View (iOS < 16)
struct StreakProgressFallbackView: View {
    let stats: EnhancedUserStats
    let timeRange: TimeRange
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(stats.currentStreak) days")
                        .font(.title2.bold())
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Best Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(stats.longestStreak) days")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(
                            width: geometry.size.width * progressPercentage,
                            height: 8
                        )
                }
            }
            .frame(height: 8)
        }
    }
    
    private var progressPercentage: Double {
        guard stats.longestStreak > 0 else { return 0.0 }
        return min(1.0, Double(stats.currentStreak) / Double(stats.longestStreak))
    }
}

// MARK: - Wake-up Patterns Section
struct WakeUpPatternsSection: View {
    let stats: EnhancedUserStats
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wake-up Patterns")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Weekly breakdown
                WeeklyBreakdownView(stats: stats)
                
                // Time analysis
                TimeAnalysisView(stats: stats)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Weekly Breakdown View
struct WeeklyBreakdownView: View {
    let stats: EnhancedUserStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week's Performance")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                ForEach(Array(generateWeekData().enumerated()), id: \.offset) { index, success in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(success ? .green : .gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: success ? "checkmark" : "xmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            )
                        
                        Text(dayNames[index])
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var dayNames: [String] {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }
    
    private func generateWeekData() -> [Bool] {
        // Simulate weekly data based on current stats
        // In a real implementation, this would come from stored daily data
        let successRate = stats.weeklySuccessRate
        return (0..<7).map { _ in Double.random(in: 0...1) < successRate }
    }
}

// MARK: - Time Analysis View
struct TimeAnalysisView: View {
    let stats: EnhancedUserStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wake-up Time Analysis")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                TimeStatItem(
                    title: "Average",
                    time: stats.averageWakeUpTimeFormatted,
                    icon: "clock",
                    color: .blue
                )
                
                TimeStatItem(
                    title: "Earliest",
                    time: "6:15 AM", // Would be calculated from historical data
                    icon: "sunrise",
                    color: .orange
                )
                
                TimeStatItem(
                    title: "Latest",
                    time: "8:45 AM", // Would be calculated from historical data
                    icon: "sunset",
                    color: .purple
                )
            }
        }
    }
}

// MARK: - Time Stat Item
struct TimeStatItem: View {
    let title: String
    let time: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(time)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Performance Insights Section
struct PerformanceInsightsSection: View {
    let stats: EnhancedUserStats
    let onInsightTap: (AnalyticsInsight) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Insights")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(generateInsights(), id: \.id) { insight in
                    InsightCard(insight: insight) {
                        onInsightTap(insight)
                    }
                }
            }
        }
    }
    
    private func generateInsights() -> [AnalyticsInsight] {
        var insights: [AnalyticsInsight] = []
        
        // Success rate insights
        if stats.successRate >= 0.9 {
            insights.append(AnalyticsInsight(
                id: "high_success",
                title: "Excellent Performance! 🎉",
                description: "You're maintaining a \(Int(stats.successRate * 100))% success rate. Keep up the great work!",
                type: .positive,
                actionTitle: "Share Achievement"
            ))
        } else if stats.successRate < 0.5 {
            insights.append(AnalyticsInsight(
                id: "low_success",
                title: "Room for Improvement",
                description: "Your current success rate is \(Int(stats.successRate * 100))%. Try setting earlier bedtimes or adjusting your alarm tone.",
                type: .improvement,
                actionTitle: "Get Tips"
            ))
        }
        
        // Streak insights
        if stats.currentStreak >= 7 {
            insights.append(AnalyticsInsight(
                id: "week_streak",
                title: "Week Streak Achievement! 🔥",
                description: "You've maintained a \(stats.currentStreak)-day streak. You're building a strong habit!",
                type: .positive,
                actionTitle: "Share Streak"
            ))
        }
        
        // Early bird insights
        if stats.earlyBirdDays >= 3 {
            insights.append(AnalyticsInsight(
                id: "early_bird",
                title: "Early Bird Pattern Detected 🌅",
                description: "You've been waking up early \(stats.earlyBirdDays) times recently. This can improve your productivity!",
                type: .positive,
                actionTitle: "Learn More"
            ))
        }
        
        // Snooze insights
        if stats.snoozeRate > 0.5 {
            insights.append(AnalyticsInsight(
                id: "snooze_habit",
                title: "Frequent Snoozing Detected",
                description: "You're snoozing \(Int(stats.snoozeRate * 100))% of the time. Try going to bed 30 minutes earlier.",
                type: .improvement,
                actionTitle: "Sleep Tips"
            ))
        }
        
        return insights
    }
}

// MARK: - Analytics Insight Model
struct AnalyticsInsight {
    let id: String
    let title: String
    let description: String
    let type: InsightType
    let actionTitle: String
    
    enum InsightType {
        case positive, improvement, warning
        
        var color: Color {
            switch self {
            case .positive: return .green
            case .improvement: return .blue
            case .warning: return .orange
            }
        }
        
        var iconName: String {
            switch self {
            case .positive: return "checkmark.circle.fill"
            case .improvement: return "lightbulb.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let insight: AnalyticsInsight
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: insight.type.iconName)
                .font(.title2)
                .foregroundColor(insight.type.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(insight.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button(insight.actionTitle) {
                action()
            }
            .font(.caption.bold())
            .foregroundColor(insight.type.color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(insight.type.color.opacity(0.1))
        )
    }
}

// MARK: - Goal Recommendations Section
struct GoalRecommendationsSection: View {
    let stats: EnhancedUserStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended Goals")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(generateRecommendations(), id: \.title) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                }
            }
        }
    }
    
    private func generateRecommendations() -> [GoalRecommendation] {
        var recommendations: [GoalRecommendation] = []
        
        // Based on current performance, suggest appropriate goals
        if stats.currentStreak < 7 {
            recommendations.append(GoalRecommendation(
                title: "Build a Week Streak",
                description: "Aim for 7 consecutive successful wake-ups",
                progress: Double(stats.currentStreak) / 7.0,
                daysLeft: 7 - stats.currentStreak
            ))
        } else if stats.currentStreak < 30 {
            recommendations.append(GoalRecommendation(
                title: "Reach 30-Day Milestone",
                description: "Build a month-long habit",
                progress: Double(stats.currentStreak) / 30.0,
                daysLeft: 30 - stats.currentStreak
            ))
        }
        
        if stats.weeklySuccessRate < 1.0 {
            recommendations.append(GoalRecommendation(
                title: "Perfect Week Challenge",
                description: "Wake up successfully every day this week",
                progress: stats.weeklySuccessRate,
                daysLeft: 7 - stats.thisWeekSuccesses
            ))
        }
        
        if stats.earlyBirdDays < 5 {
            recommendations.append(GoalRecommendation(
                title: "Early Bird Achievement",
                description: "Wake up before 7 AM for 5 consecutive days",
                progress: Double(stats.earlyBirdDays) / 5.0,
                daysLeft: 5 - stats.earlyBirdDays
            ))
        }
        
        return recommendations
    }
}

// MARK: - Goal Recommendation Model
struct GoalRecommendation {
    let title: String
    let description: String
    let progress: Double
    let daysLeft: Int
}

// MARK: - Recommendation Card
struct RecommendationCard: View {
    let recommendation: GoalRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(recommendation.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(recommendation.progress * 100))%")
                        .font(.headline.bold())
                        .foregroundColor(.blue)
                    
                    Text("\(recommendation.daysLeft) days left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: recommendation.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

// MARK: - Insight Detail View
struct InsightDetailView: View {
    let insight: AnalyticsInsight
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Large icon
                    Image(systemName: insight.type.iconName)
                        .font(.system(size: 60))
                        .foregroundColor(insight.type.color)
                    
                    VStack(spacing: 16) {
                        Text(insight.title)
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text(insight.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Action recommendations based on insight type
                    if insight.type == .improvement {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Improvement Tips")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ImprovementTipsList()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.systemGray6))
                        )
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Insight Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Improvement Tips List
struct ImprovementTipsList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TipItem(
                icon: "bed.double.fill",
                title: "Earlier Bedtime",
                description: "Try going to bed 30 minutes earlier for better morning energy"
            )
            
            TipItem(
                icon: "speaker.wave.2.fill",
                title: "Adjust Alarm Tone",
                description: "Experiment with different motivation styles to find what works best"
            )
            
            TipItem(
                icon: "moon.fill",
                title: "Better Sleep Environment",
                description: "Keep your bedroom cool, dark, and quiet for quality sleep"
            )
            
            TipItem(
                icon: "figure.walk",
                title: "Morning Routine",
                description: "Create a consistent routine to make waking up more automatic"
            )
        }
    }
}

// MARK: - Tip Item
struct TipItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Previews
#Preview {
    AnalyticsDashboardView()
}

#Preview("Insight Detail") {
    InsightDetailView(insight: AnalyticsInsight(
        id: "test",
        title: "Great Performance!",
        description: "You're doing amazing with your wake-up routine.",
        type: .positive,
        actionTitle: "Share"
    ))
}
