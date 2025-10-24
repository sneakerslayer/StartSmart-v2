import SwiftUI

struct SettingsView: View {
    @State private var showPaywall = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var usageService = UsageTrackingService.shared
    @State private var isPremium = false
    
    var body: some View {
        NavigationView {
            List {
                // Subscription Section
                if !isPremium {
                    Section {
                        Button(action: {
                            showPaywall = true
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Upgrade to Premium")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    let remaining = usageService.getRemainingAlarmCredits(isPremium: isPremium) ?? 0
                                    Text("\(remaining) of 15 free alarms remaining")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Legal Section
                Section("Legal") {
                    Link("Privacy Policy", destination: URL(string: "https://www.startsmartmobile.com/support")!)
                    Link("Terms of Service", destination: URL(string: "https://www.startsmartmobile.com/support")!)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                checkPremiumStatus()
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(restoreMessage)
        }
    }
    
    private func checkPremiumStatus() {
        // Check if user is premium
        isPremium = false // Will be updated when subscription service is integrated
    }
}

#Preview {
    SettingsView()
}