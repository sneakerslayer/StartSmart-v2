import SwiftUI
import Combine

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
    
    // Subscription state observation
    @State private var subscriptionService: SubscriptionService?
    @State private var subscriptionStateManager: SubscriptionStateManager?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isRestoringPurchases = false
    
    var body: some View {
        NavigationView {
            List {
                // Subscription Section - Dynamic based on isPremium
                Section {
                    Button(action: {
                        showPaywall = true
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: isPremium ? [.green, .blue] : [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: isPremium ? "star.fill" : "crown.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isPremium ? "Change Subscription" : "Upgrade to Premium")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                if isPremium {
                                    Text("Switch between weekly, monthly, or yearly plans")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                } else {
                                    let remaining = usageService.getRemainingAlarmCredits(isPremium: isPremium) ?? 0
                                    Text("\(remaining) of 15 free alarms remaining")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Restore Purchases Section
                Section("Subscription") {
                    Button(action: {
                        restorePurchases()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Restore Purchases")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Sync your subscription status")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isRestoringPurchases {
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
                    .disabled(isRestoringPurchases)
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
        // Check if user is premium from RevenueCat
        guard subscriptionService == nil else { return }
        
        Task {
            do {
                // ⚠️ IMPORTANT: Resolve as SubscriptionServiceProtocol (how it's registered in DependencyContainer)
                // NOT as concrete SubscriptionService class (which would not be found)
                guard let serviceProtocol: SubscriptionServiceProtocol = await DependencyContainer.shared.resolveSafe() else {
                    print("⚠️ SubscriptionService not available in SettingsView (DependencyContainer may still be initializing)")
                    self.isPremium = false
                    return
                }
                
                // Cast to concrete class for storing in @State
                guard let service = serviceProtocol as? SubscriptionService else {
                    print("⚠️ SubscriptionServiceProtocol is not a SubscriptionService instance")
                    self.isPremium = false
                    return
                }
                
                // Try to get SubscriptionStateManager
                guard let manager: SubscriptionStateManager = await DependencyContainer.shared.resolveSafe() else {
                    print("⚠️ SubscriptionStateManager not available in SettingsView (DependencyContainer may still be initializing)")
                    self.isPremium = false
                    return
                }
                
                DispatchQueue.main.async {
                    self.subscriptionService = service
                    self.subscriptionStateManager = manager
                    
                    // Set initial state
                    self.isPremium = service.currentSubscriptionStatus.isPremium
                    
                    // Observe subscription status changes
                    service.subscriptionStatusPublisher
                        .receive(on: DispatchQueue.main)
                        .sink { status in
                            self.isPremium = status.isPremium
                        }
                        .store(in: &self.cancellables)
                }
            }
        }
    }
    
    private func restorePurchases() {
        guard let manager = subscriptionStateManager else {
            checkPremiumStatus()
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.restorePurchases()
            }
            return
        }
        
        isRestoringPurchases = true
        
        Task {
            let success = await manager.restorePurchases()
            
            await MainActor.run {
                isRestoringPurchases = false
                
                if success {
                    restoreMessage = "✅ Purchases restored successfully! Your subscription has been synced."
                } else {
                    restoreMessage = "No previous purchases found to restore."
                }
                
                showRestoreAlert = true
            }
        }
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