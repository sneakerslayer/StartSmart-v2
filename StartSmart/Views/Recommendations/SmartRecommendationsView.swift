import SwiftUI

// MARK: - Smart Recommendations View

struct SmartRecommendationsView: View {
    @StateObject private var recommendationsService = SmartAlarmRecommendationsService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Analysis Status
                    analysisStatusSection
                    
                    // Recommendations
                    recommendationsSection
                    
                    // Apply Recommendations
                    applyButton
                }
                .padding()
            }
            .navigationTitle("Smart Recommendations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await recommendationsService.analyzeUserData()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("AI-Powered Recommendations")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Get personalized suggestions to improve your alarm experience")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Analysis Status Section
    
    private var analysisStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("Analysis Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if recommendationsService.isAnalyzing {
                VStack(spacing: 8) {
                    ProgressView(value: recommendationsService.analysisProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("Analyzing your sleep patterns and alarm usage...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Analysis Complete")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Recommendations Section
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if recommendationsService.recommendations.isEmpty {
                emptyRecommendationsView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(recommendationsService.recommendations) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Recommendations View
    
    private var emptyRecommendationsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("No Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Your alarm settings are already optimized! Keep up the great work.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    // MARK: - Apply Button
    
    private var applyButton: some View {
        Button(action: {
            // Apply selected recommendations
            dismiss()
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Apply Recommendations")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
        .disabled(recommendationsService.recommendations.isEmpty)
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: AlarmRecommendation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                priorityIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(recommendation.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            // Description
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Confidence
                    HStack {
                        Text("Confidence:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("\(Int(recommendation.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    
                    // Action Button
                    Button(action: {
                        // Apply recommendation
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Apply This Recommendation")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(priorityColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(priorityColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var priorityIcon: some View {
        Image(systemName: priorityIconName)
            .foregroundColor(priorityColor)
            .font(.title3)
    }
    
    private var priorityIconName: String {
        switch recommendation.priority {
        case .high:
            return "exclamationmark.triangle.fill"
        case .medium:
            return "info.circle.fill"
        case .low:
            return "lightbulb.fill"
        }
    }
    
    private var priorityColor: Color {
        switch recommendation.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        }
    }
}

// MARK: - Recommendation Type Extensions

extension AlarmRecommendation.RecommendationType {
    var icon: String {
        switch self {
        case .sleepPattern:
            return "moon.fill"
        case .alarmEffectiveness:
            return "bell.fill"
        case .userPreference:
            return "heart.fill"
        case .smartWakeUp:
            return "sun.max.fill"
        case .customization:
            return "paintbrush.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .sleepPattern:
            return .purple
        case .alarmEffectiveness:
            return .blue
        case .userPreference:
            return .pink
        case .smartWakeUp:
            return .orange
        case .customization:
            return .green
        }
    }
}

// MARK: - Preview

#Preview {
    SmartRecommendationsView()
}
