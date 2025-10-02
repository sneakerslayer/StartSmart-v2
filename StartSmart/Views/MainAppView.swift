import SwiftUI

struct MainAppView: View {
    @StateObject private var subscriptionManager = DependencyContainer.shared.resolve() as SubscriptionManager
    @State private var showingAlarmListView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // App Icon
                Image(systemName: "alarm.waves.left.and.right")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 50)
                
                // Welcome Message
                Text("Welcome to StartSmart!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                Text("Your AI-powered morning motivation is ready")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Spacer()
                
                // Feature Cards
                VStack(spacing: 16) {
                    FeatureCard(
                        icon: "alarm",
                        title: "Smart Alarms",
                        description: "AI-generated motivational content"
                    )
                    
                    FeatureCard(
                        icon: "person.3.sequence",
                        title: "Voice Personalities",
                        description: "Choose from multiple AI voices"
                    )
                    
                    FeatureCard(
                        icon: "chart.bar.xaxis",
                        title: "Analytics",
                        description: "Track your wake-up patterns"
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    NavigationLink(destination: AlarmListView(), isActive: $showingAlarmListView) {
                        EmptyView()
                    }
                    
                    Button("View My Alarms") {
                        showingAlarmListView = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Manage Subscription") {
                        // TODO: Show subscription management
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("StartSmart")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}


#Preview {
    MainAppView()
}
