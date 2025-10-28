import SwiftUI

struct SettingsView: View {
    @State private var showPaywall = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccountWarning = false
    @State private var isDeleting = false
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
                
                // Account Section
                Section("Account") {
                    Button(action: {
                        showDeleteAccountWarning = true
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Delete Account")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.red)
                                
                                Text("Permanently delete your account and data")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isDeleting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
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
        .alert("Delete Account?", isPresented: $showDeleteAccountWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                showDeleteAccountConfirmation = true
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .alert("Confirm Deletion", isPresented: $showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you absolutely sure? Your account and all alarms will be permanently deleted.")
        }
    }
    
    private func checkPremiumStatus() {
        // Check if user is premium
        isPremium = false // Will be updated when subscription service is integrated
    }
    
    private func deleteAccount() {
        isDeleting = true
        
        Task {
            do {
                // Delete from Firebase
                try await deleteUserFromFirebase()
                
                // Sign out using DependencyContainer
                let authService = DependencyContainer.shared.authenticationService
                do {
                    try await authService.signOut()
                } catch {
                    print("⚠️ Sign out failed during account deletion: \(error)")
                    // Continue with cleanup even if sign out fails
                }
                
                // Clear local data
                UserDefaults.standard.removeObject(forKey: "onboarding_completion_data")
                UserDefaults.standard.removeObject(forKey: "is_guest_user")
                
                await MainActor.run {
                    isDeleting = false
                    // Navigate back to login/onboarding
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    print("❌ Failed to delete account: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteUserFromFirebase() async throws {
        // Delete user from Firebase Authentication and Firestore
        let firebaseService = FirebaseService()
        try await firebaseService.deleteUser()
        print("✅ Account deleted successfully")
    }
}

#Preview {
    SettingsView()
}