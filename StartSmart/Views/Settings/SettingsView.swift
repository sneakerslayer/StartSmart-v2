import SwiftUI

struct SettingsView: View {
    @StateObject private var subscriptionManager = DependencyContainer.shared.resolve() as SubscriptionManager
    @StateObject private var userViewModel = DependencyContainer.shared.resolve() as UserViewModel
    @State private var showPaywall = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Subscription Section
                subscriptionSection
                
                // Account Section
                accountSection
                
                // Preferences Section
                preferencesSection
                
                // Privacy Section
                privacySection
                
                // Support Section
                supportSection
                
                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentPaywall(
            isPresented: $showPaywall,
            configuration: .default,
            source: "settings"
        )
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK") { }
        } message: {
            Text(restoreMessage)
        }
    }
    
    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        Section {
            if subscriptionManager.currentSubscriptionStatus.isPremium {
                // Current subscription info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("StartSmart Pro")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(subscriptionManager.currentSubscriptionStatus.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                    
                    if let daysUntil = subscriptionManager.daysUntilExpiration {
                        if subscriptionManager.isExpiringSoon {
                            Text("Expires in \(daysUntil) days")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("Active subscription")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if subscriptionManager.isInFreeTrial {
                        Text("Free trial active")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4)
                
                // Manage subscription
                Button {
                    openAppStoreSubscriptions()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Manage Subscription")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
                
            } else {
                // Upgrade to Pro
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Pro")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            Text("Unlock unlimited alarms, all voices, and more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
                
                // Current usage
                if let remaining = subscriptionManager.getRemainingAlarms() {
                    HStack {
                        Image(systemName: "alarm")
                            .foregroundColor(.blue)
                        Text("Alarms this month")
                        Spacer()
                        Text("\(15 - remaining)/15")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Restore purchases
            Button {
                Task {
                    await restorePurchases()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Restore Purchases")
                    Spacer()
                }
            }
            
        } header: {
            Text("Subscription")
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        Section {
            if let user = userViewModel.currentUser {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayNameOrEmail)
                            .font(.headline)
                        
                        if let email = user.email {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                
                Button {
                    Task {
                        await signOut()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.backward.square")
                        Text("Sign Out")
                        Spacer()
                    }
                }
                .foregroundColor(.red)
            } else {
                Button("Sign In") {
                    // Navigate to authentication
                }
            }
        } header: {
            Text("Account")
        }
    }
    
    // MARK: - Preferences Section
    private var preferencesSection: some View {
        Section {
            FeatureToggle(
                feature: SubscriptionFeature(
                    id: "notifications",
                    name: "Notifications",
                    description: "Enable push notifications for alarms",
                    iconName: "bell",
                    isPremiumOnly: false
                ),
                isEnabled: userViewModel.currentUser?.preferences.notificationsEnabled ?? true,
                source: "settings"
            ) { enabled in
                userViewModel.updateNotificationPreference(enabled)
            }
            
            FeatureToggle(
                feature: SubscriptionFeature(
                    id: "sound",
                    name: "Sound",
                    description: "Play sound for alarms",
                    iconName: "speaker.wave.2",
                    isPremiumOnly: false
                ),
                isEnabled: userViewModel.currentUser?.preferences.soundEnabled ?? true,
                source: "settings"
            ) { enabled in
                userViewModel.updateSoundPreference(enabled)
            }
            
            FeatureToggle(
                feature: SubscriptionFeature(
                    id: "vibration",
                    name: "Vibration",
                    description: "Vibrate device for alarms",
                    iconName: "iphone.radiowaves.left.and.right",
                    isPremiumOnly: false
                ),
                isEnabled: userViewModel.currentUser?.preferences.vibrationEnabled ?? true,
                source: "settings"
            ) { enabled in
                userViewModel.updateVibrationPreference(enabled)
            }
            
            FeatureToggle(
                feature: .socialSharing,
                isEnabled: userViewModel.currentUser?.preferences.shareToSocialMediaEnabled ?? false,
                source: "settings"
            ) { enabled in
                userViewModel.updateSocialSharingPreference(enabled)
            }
        } header: {
            Text("Preferences")
        }
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        Section {
            NavigationLink {
                SharingPrivacyView()
            } label: {
                HStack {
                    Image(systemName: "hand.raised")
                    Text("Privacy Settings")
                    Spacer()
                }
            }
            
            Button {
                openPrivacyPolicy()
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            Button {
                openTermsOfService()
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Terms of Service")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
        } header: {
            Text("Privacy")
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        Section {
            Button {
                sendFeedback()
            } label: {
                HStack {
                    Image(systemName: "envelope")
                    Text("Send Feedback")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            Button {
                openSupport()
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text("Help & Support")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            Button {
                rateApp()
            } label: {
                HStack {
                    Image(systemName: "star")
                    Text("Rate StartSmart")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
        } header: {
            Text("Support")
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("About")
        }
    }
    
    // MARK: - Actions
    private func restorePurchases() async {
        do {
            let subscriptionService = DependencyContainer.shared.subscriptionService
            _ = try await subscriptionService.restorePurchases()
            
            if subscriptionManager.currentSubscriptionStatus.isPremium {
                restoreMessage = "Your purchases have been restored successfully!"
            } else {
                restoreMessage = "No previous purchases found to restore."
            }
        } catch {
            restoreMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        showRestoreAlert = true
    }
    
    private func signOut() async {
        do {
            try await userViewModel.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
    }
    
    private func openAppStoreSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://startsmart.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfService() {
        if let url = URL(string: "https://startsmart.app/terms") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendFeedback() {
        if let url = URL(string: "mailto:support@startsmart.app?subject=StartSmart%20Feedback") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openSupport() {
        if let url = URL(string: "https://startsmart.app/support") {
            UIApplication.shared.open(url)
        }
    }
    
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/startsmart/id123456789?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - UserViewModel Extensions for Settings
extension UserViewModel {
    func updateNotificationPreference(_ enabled: Bool) {
        guard var user = currentUser else { return }
        user.preferences.notificationsEnabled = enabled
        updateUser(user)
    }
    
    func updateSoundPreference(_ enabled: Bool) {
        guard var user = currentUser else { return }
        user.preferences.soundEnabled = enabled
        updateUser(user)
    }
    
    func updateVibrationPreference(_ enabled: Bool) {
        guard var user = currentUser else { return }
        user.preferences.vibrationEnabled = enabled
        updateUser(user)
    }
    
    func updateSocialSharingPreference(_ enabled: Bool) {
        guard var user = currentUser else { return }
        user.preferences.shareToSocialMediaEnabled = enabled
        updateUser(user)
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
