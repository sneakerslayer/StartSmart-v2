import Foundation
import Combine

// MARK: - User View Model
@MainActor
class UserViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var preferences: UserPreferences
    
    private let storageManager: StorageManager
    private var cancellables = Set<AnyCancellable>()
    
    init(storageManager: StorageManager = StorageManager()) {
        self.storageManager = storageManager
        self.preferences = UserPreferences()
        loadCurrentUser()
    }
    
    // MARK: - Authentication Methods
    func loadCurrentUser() {
        isLoading = true
        errorMessage = nil
        
        do {
            currentUser = try storageManager.loadCurrentUser()
            isAuthenticated = currentUser != nil
            
            if let user = currentUser {
                preferences = user.preferences
            } else {
                // Load preferences even if no user (for anonymous usage)
                preferences = (try? storageManager.loadUserPreferences()) ?? UserPreferences()
            }
        } catch {
            errorMessage = "Failed to load user: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createAnonymousUser() {
        let user = User(preferences: preferences)
        currentUser = user
        isAuthenticated = true
        saveCurrentUser()
    }
    
    func signIn(email: String, displayName: String?) {
        let user = User(
            email: email,
            displayName: displayName,
            preferences: preferences
        )
        
        currentUser = user
        isAuthenticated = true
        saveCurrentUser()
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        storageManager.deleteCurrentUser()
    }
    
    // MARK: - Profile Management
    func updateProfile(displayName: String?, profileImageURL: String?) {
        guard var user = currentUser else { return }
        
        user.updateProfile(displayName: displayName, profileImageURL: profileImageURL)
        currentUser = user
        saveCurrentUser()
    }
    
    func updatePreferences(_ newPreferences: UserPreferences) {
        preferences = newPreferences
        
        if var user = currentUser {
            user.updatePreferences(newPreferences)
            currentUser = user
            saveCurrentUser()
        } else {
            // Save preferences even without a user account
            savePreferences()
        }
    }
    
    func updateSubscription(_ subscription: SubscriptionStatus) {
        guard var user = currentUser else { return }
        
        // Convert SubscriptionStatus to StartSmartSubscriptionStatus
        let startSmartSubscription: StartSmartSubscriptionStatus
        switch subscription {
        case .free:
            startSmartSubscription = .free
        case .proWeekly:
            startSmartSubscription = .proWeekly
        case .proMonthly:
            startSmartSubscription = .proMonthly
        case .proAnnual:
            startSmartSubscription = .proAnnual
        }
        
        user.subscription = startSmartSubscription
        currentUser = user
        saveCurrentUser()
    }
    
    // MARK: - Statistics Methods
    func recordAlarmCreated() {
        guard var user = currentUser else { return }
        
        user.incrementAlarmCount()
        currentUser = user
        saveCurrentUser()
    }
    
    func recordSuccessfulWakeUp() {
        guard var user = currentUser else { return }
        
        user.recordSuccessfulWakeUp()
        currentUser = user
        saveCurrentUser()
    }
    
    func recordSnooze() {
        guard var user = currentUser else { return }
        
        user.recordSnooze()
        currentUser = user
        saveCurrentUser()
    }
    
    func recordLogin() {
        guard var user = currentUser else { return }
        
        user.recordLogin()
        currentUser = user
        saveCurrentUser()
    }
    
    // MARK: - Subscription & Feature Access
    var canCreateMoreAlarms: Bool {
        guard let user = currentUser else { return true }
        
        if let limit = user.subscription.monthlyAlarmLimit {
            return user.stats.totalAlarmsCreated < limit
        }
        return true // Unlimited for premium users
    }
    
    var remainingAlarms: Int? {
        guard let user = currentUser,
              let limit = user.subscription.monthlyAlarmLimit else {
            return nil // Unlimited
        }
        
        return max(0, limit - user.stats.totalAlarmsCreated)
    }
    
    var canAccessPremiumFeatures: Bool {
        currentUser?.canAccessPremiumFeatures ?? false
    }
    
    var canAccessAdvancedAnalytics: Bool {
        currentUser?.subscription.hasAdvancedAnalytics ?? false
    }
    
    var canAccessAllVoices: Bool {
        currentUser?.subscription.hasAllVoices ?? false
    }
    
    // MARK: - Computed Properties
    var displayName: String {
        currentUser?.displayNameOrEmail ?? "Anonymous User"
    }
    
    var userStats: UserStats {
        currentUser?.stats ?? UserStats()
    }
    
    var subscriptionStatus: SubscriptionStatus {
        guard let userSubscription = currentUser?.subscription else { return .free }
        
        // Convert StartSmartSubscriptionStatus to SubscriptionStatus
        switch userSubscription {
        case .free:
            return .free
        case .proWeekly:
            return .proWeekly
        case .proMonthly:
            return .proMonthly
        case .proAnnual:
            return .proAnnual
        }
    }
    
    var isAnonymous: Bool {
        currentUser?.isAnonymous ?? true
    }
    
    // MARK: - Data Export/Import
    func exportUserData() -> Data? {
        do {
            return try storageManager.exportUserData()
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
            return nil
        }
    }
    
    func importUserData(_ data: Data) {
        do {
            try storageManager.importUserData(from: data)
            loadCurrentUser()
        } catch {
            errorMessage = "Failed to import data: \(error.localizedDescription)"
        }
    }
    
    func deleteAllUserData() {
        storageManager.clearAllData()
        currentUser = nil
        isAuthenticated = false
        preferences = UserPreferences()
    }
    
    // MARK: - User Update Methods
    func updateUser(_ user: User) {
        currentUser = user
        preferences = user.preferences
        saveCurrentUser()
    }
    
    // MARK: - Private Methods
    private func saveCurrentUser() {
        guard let user = currentUser else { return }
        
        do {
            try storageManager.saveCurrentUser(user)
        } catch {
            errorMessage = "Failed to save user: \(error.localizedDescription)"
        }
    }
    
    private func savePreferences() {
        do {
            try storageManager.saveUserPreferences(preferences)
        } catch {
            errorMessage = "Failed to save preferences: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preferences View Model
@MainActor
class PreferencesViewModel: ObservableObject {
    @Published var preferences: UserPreferences
    @Published var hasChanges = false
    
    private let originalPreferences: UserPreferences
    private let userViewModel: UserViewModel
    
    init(userViewModel: UserViewModel) {
        self.userViewModel = userViewModel
        self.preferences = userViewModel.preferences
        self.originalPreferences = userViewModel.preferences
        
        // Watch for changes
        $preferences
            .dropFirst()
            .sink { [weak self] newPreferences in
                self?.hasChanges = newPreferences != self?.originalPreferences
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    func save() {
        userViewModel.updatePreferences(preferences)
        hasChanges = false
    }
    
    func reset() {
        preferences = originalPreferences
        hasChanges = false
    }
    
    func resetToDefaults() {
        preferences = UserPreferences()
        hasChanges = true
    }
    
    // MARK: - Tone Slider Helpers
    func updateToneFromSlider(_ value: Double) {
        preferences.toneSliderPosition = value
        preferences.defaultAlarmTone = preferences.computedTone
    }
    
    var toneDescription: String {
        preferences.computedTone.description
    }
    
    // MARK: - Convenience Methods
    func toggleNotifications() {
        preferences.notificationsEnabled.toggle()
    }
    
    func toggleSound() {
        preferences.soundEnabled.toggle()
    }
    
    func toggleVibration() {
        preferences.vibrationEnabled.toggle()
    }
    
    func toggleSnooze() {
        preferences.snoozeEnabled.toggle()
    }
    
    func toggleSocialSharing() {
        preferences.shareToSocialMediaEnabled.toggle()
    }
    
    func toggleAnalytics() {
        preferences.analyticsEnabled.toggle()
    }
    
    func updateSnoozeDuration(_ duration: TimeInterval) {
        preferences.defaultSnoozeDuration = duration
    }
    
    func updateMaxSnoozeCount(_ count: Int) {
        preferences.maxSnoozeCount = count
    }
}
