import SwiftUI
import Combine

// MARK: - Streak View
struct StreakView: View {
    @StateObject private var streakService = DependencyContainer.shared.streakTrackingService as! StreakTrackingService
    @State private var enhancedStats = EnhancedUserStats()
    @State private var newAchievements: [StreakAchievement] = []
    @State private var showingAchievementDetails = false
    @State private var selectedAchievement: StreakAchievement?
    @State private var showingAllAchievements = false
    
    private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Main Streak Display
                    StreakHeaderView(stats: enhancedStats)
                    
                    // Statistics Cards
                    StatisticsCardsView(stats: enhancedStats)
                    
                    // Recent Achievements
                    RecentAchievementsView(
                        achievements: Array(enhancedStats.unlockedAchievements.suffix(3)),
                        onAchievementTap: { achievement in
                            selectedAchievement = achievement
                            showingAchievementDetails = true
                        }
                    )
                    
                    // Progress Section
                    ProgressSectionView(
                        streakService: streakService,
                        stats: enhancedStats
                    )
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Achievements") {
                        showingAllAchievements = true
                    }
                    .foregroundColor(.primary)
                }
            }
            .onReceive(streakService.enhancedStats) { stats in
                enhancedStats = stats
            }
            .onReceive(streakService.newAchievements) { achievements in
                newAchievements = achievements
            }
            .sheet(isPresented: $showingAchievementDetails) {
                if let achievement = selectedAchievement {
                    AchievementDetailView(achievement: achievement)
                }
            }
            .sheet(isPresented: $showingAllAchievements) {
                AllAchievementsView(
                    unlockedAchievements: enhancedStats.unlockedAchievements,
                    progressData: streakService.getAchievementProgress()
                )
            }
            .overlay(
                // New Achievement Overlay
                NewAchievementOverlay(achievements: newAchievements)
                    .animation(.spring(), value: newAchievements.count)
            )
        }
    }
}

// MARK: - Streak Header View
struct StreakHeaderView: View {
    let stats: EnhancedUserStats
    
    var body: some View {
        VStack(spacing: 16) {
            // Flame icon with streak count
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.2), Color.red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("\(stats.currentStreak)")
                        .font(.title.bold())
                        .foregroundColor(.primary)
                    
                    Text("day\(stats.currentStreak == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                Text("Current Streak")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let startDate = stats.streakStartDate {
                    Text("Started \(startDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if stats.longestStreak > stats.currentStreak {
                    Text("Personal Best: \(stats.longestStreak) days")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
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

// MARK: - Statistics Cards View
struct StatisticsCardsView: View {
    let stats: EnhancedUserStats
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Success Rate",
                value: "\(Int(stats.successRate * 100))%",
                icon: "target",
                color: .green
            )
            
            StatCard(
                title: "This Week",
                value: "\(stats.thisWeekSuccesses)/7",
                icon: "calendar.day.timeline.left",
                color: .blue
            )
            
            StatCard(
                title: "Total Wake-ups",
                value: "\(stats.successfulWakeUps)",
                icon: "sun.max.fill",
                color: .orange
            )
            
            StatCard(
                title: "Avg Wake Time",
                value: stats.averageWakeUpTimeFormatted,
                icon: "clock.fill",
                color: .purple
            )
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Recent Achievements View
struct RecentAchievementsView: View {
    let achievements: [StreakAchievement]
    let onAchievementTap: (StreakAchievement) -> Void
    
    var body: some View {
        if !achievements.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Achievements")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(achievements, id: \.self) { achievement in
                            AchievementBadge(achievement: achievement)
                                .onTapGesture {
                                    onAchievementTap(achievement)
                                }
                        }
                    }
                    .padding(.horizontal, 4)
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
}

// MARK: - Achievement Badge
struct AchievementBadge: View {
    let achievement: StreakAchievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.iconName)
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            Text(achievement.title)
                .font(.caption.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
    }
}

// MARK: - Progress Section View
struct ProgressSectionView: View {
    let streakService: StreakTrackingService
    let stats: EnhancedUserStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievement Progress")
                .font(.headline)
                .foregroundColor(.primary)
            
            let progressData = streakService.getAchievementProgress()
            let nextAchievements = StreakAchievement.allCases.filter { !stats.unlockedAchievements.contains($0) }.prefix(3)
            
            ForEach(Array(nextAchievements), id: \.self) { achievement in
                ProgressRowView(
                    achievement: achievement,
                    progress: progressData[achievement] ?? 0.0
                )
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

// MARK: - Progress Row View
struct ProgressRowView: View {
    let achievement: StreakAchievement
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: achievement.iconName)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(achievement.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            Text(achievement.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - New Achievement Overlay
struct NewAchievementOverlay: View {
    let achievements: [StreakAchievement]
    
    var body: some View {
        if let achievement = achievements.first {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.yellow, Color.orange],
                                center: .center,
                                startRadius: 20,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: achievements.count)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Achievement Unlocked!")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text(achievement.title)
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text(achievement.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .opacity
            ))
        }
    }
}

// MARK: - Achievement Detail View
struct AchievementDetailView: View {
    let achievement: StreakAchievement
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Large achievement icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.1)],
                                center: .center,
                                startRadius: 50,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                }
                
                VStack(spacing: 16) {
                    Text(achievement.title)
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(achievement.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Achievement")
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

// MARK: - All Achievements View
struct AllAchievementsView: View {
    let unlockedAchievements: Set<StreakAchievement>
    let progressData: [StreakAchievement: Double]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(StreakAchievement.allCases, id: \.self) { achievement in
                        AllAchievementCard(
                            achievement: achievement,
                            isUnlocked: unlockedAchievements.contains(achievement),
                            progress: progressData[achievement] ?? 0.0
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("All Achievements")
            .navigationBarTitleDisplayMode(.large)
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

// MARK: - All Achievement Card
struct AllAchievementCard: View {
    let achievement: StreakAchievement
    let isUnlocked: Bool
    let progress: Double
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        isUnlocked ?
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: achievement.iconName)
                    .font(.title)
                    .foregroundColor(isUnlocked ? .orange : .gray)
            }
            
            Text(achievement.title)
                .font(.headline)
                .foregroundColor(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
            
            Text(achievement.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            if !isUnlocked {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding(.horizontal, 8)
                
                Text("\(Int(progress * 100))% complete")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .opacity(isUnlocked ? 1.0 : 0.7)
    }
}

// MARK: - Previews
#Preview {
    StreakView()
}

#Preview("Achievement Detail") {
    AchievementDetailView(achievement: .weekStreak)
}

#Preview("All Achievements") {
    AllAchievementsView(
        unlockedAchievements: [.firstWakeUp, .threeDayStreak],
        progressData: [.weekStreak: 0.6, .perfectWeek: 0.3]
    )
}
