import Foundation
import Combine
import RevenueCat

// MARK: - Subscription Manager Protocol
protocol SubscriptionManagerProtocol {
    var currentSubscriptionStatus: SubscriptionStatus { get }
    var subscriptionStatusPublisher: AnyPublisher<SubscriptionStatus, Never> { get }
    var analytics: SubscriptionAnalytics { get }
    
    func canCreateAlarm() -> Bool
    func getRemainingAlarms() -> Int?
    func canAccessFeature(_ feature: SubscriptionFeature) -> Bool
    func getUpgradeMessage(for feature: SubscriptionFeature) -> String
    func trackFeatureUsage(_ feature: SubscriptionFeature, context: String?)
    func shouldShowPaywall(for feature: SubscriptionFeature) -> Bool
    func presentPaywallIfNeeded(for feature: SubscriptionFeature, source: String) -> Bool
}

// MARK: - Subscription Manager Implementation
class SubscriptionManager: SubscriptionManagerProtocol, ObservableObject {
    @Published private(set) var currentSubscriptionStatus: SubscriptionStatus = .free
    @Published private(set) var analytics: SubscriptionAnalytics = SubscriptionAnalytics()
    @Published private(set) var currentAlarmCount: Int = 0
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let localStorage: LocalStorageProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    var subscriptionStatusPublisher: AnyPublisher<SubscriptionStatus, Never> {
        $currentSubscriptionStatus.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(
        subscriptionService: SubscriptionServiceProtocol,
        localStorage: LocalStorageProtocol
    ) {
        self.subscriptionService = subscriptionService
        self.localStorage = localStorage
        
        setupSubscriptions()
        loadAnalytics()
        loadCurrentAlarmCount()
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        // Subscribe to subscription status changes
        subscriptionService.subscriptionStatusPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentSubscriptionStatus, on: self)
            .store(in: &cancellables)
        
        // Update analytics when subscription changes
        subscriptionService.subscriptionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAnalyticsFromRevenueCat()
            }
            .store(in: &cancellables)
    }
    
    private func loadAnalytics() {
        analytics = localStorage.load(SubscriptionAnalytics.self, key: "subscription_analytics") ?? SubscriptionAnalytics()
    }
    
    private func loadCurrentAlarmCount() {
        currentAlarmCount = localStorage.load(Int.self, key: "current_month_alarm_count") ?? 0
    }
    
    private func saveAnalytics() {
        localStorage.save(analytics, key: "subscription_analytics")
    }
    
    private func saveCurrentAlarmCount() {
        localStorage.save(currentAlarmCount, key: "current_month_alarm_count")
    }
    
    // MARK: - Feature Access Management
    func canCreateAlarm() -> Bool {
        // Premium users have unlimited alarms
        if currentSubscriptionStatus.isPremium {
            return true
        }
        
        // Free users have monthly limits
        guard let limit = currentSubscriptionStatus.monthlyAlarmLimit else {
            return true // No limit set
        }
        
        return currentAlarmCount < limit
    }
    
    func getRemainingAlarms() -> Int? {
        guard !currentSubscriptionStatus.isPremium,
              let limit = currentSubscriptionStatus.monthlyAlarmLimit else {
            return nil // Unlimited
        }
        
        return max(0, limit - currentAlarmCount)
    }
    
    func canAccessFeature(_ feature: SubscriptionFeature) -> Bool {
        let featureGate = FeatureGate(subscriptionStatus: currentSubscriptionStatus)
        return featureGate.canAccess(feature)
    }
    
    func getUpgradeMessage(for feature: SubscriptionFeature) -> String {
        let featureGate = FeatureGate(subscriptionStatus: currentSubscriptionStatus)
        return featureGate.getUpgradeMessage(for: feature)
    }
    
    func shouldShowPaywall(for feature: SubscriptionFeature) -> Bool {
        return !canAccessFeature(feature)
    }
    
    func presentPaywallIfNeeded(for feature: SubscriptionFeature, source: String) -> Bool {
        if shouldShowPaywall(for: feature) {
            // Track that paywall was triggered
            trackFeatureUsage(feature, context: "paywall_triggered_\(source)")
            return true
        }
        return false
    }
    
    // MARK: - Alarm Count Management
    func incrementAlarmCount() {
        currentAlarmCount += 1
        saveCurrentAlarmCount()
        
        // Track usage for analytics
        trackFeatureUsage(.unlimitedAlarms, context: "alarm_created")
        
        // Reset count at the beginning of each month
        checkAndResetMonthlyCount()
    }
    
    private func checkAndResetMonthlyCount() {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the last reset date (or use subscription start date)
        let lastResetKey = "last_alarm_count_reset"
        let lastReset = localStorage.load(Date.self, key: lastResetKey) ?? analytics.subscriptionStartDate ?? now
        
        // Check if we've crossed into a new month
        if !calendar.isDate(lastReset, equalTo: now, toGranularity: .month) {
            currentAlarmCount = 0
            saveCurrentAlarmCount()
            localStorage.save(now, key: lastResetKey)
        }
    }
    
    // MARK: - Analytics and Tracking
    func trackFeatureUsage(_ feature: SubscriptionFeature, context: String?) {
        // This could integrate with analytics services like Firebase, Mixpanel, etc.
        let eventData: [String: Any] = [
            "feature_id": feature.id,
            "feature_name": feature.name,
            "subscription_status": currentSubscriptionStatus.rawValue,
            "context": context ?? "unknown",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        print("Feature usage tracked: \(eventData)")
        
        // Store for local analytics if needed
        saveFeatureUsageLocally(feature: feature, context: context)
    }
    
    private func saveFeatureUsageLocally(feature: SubscriptionFeature, context: String?) {
        // Save to local storage for offline analytics
        var usageHistory = localStorage.load([String: Any].self, key: "feature_usage_history") ?? [:]
        
        let usageKey = "\(feature.id)_\(Date().timeIntervalSince1970)"
        usageHistory[usageKey] = [
            "feature_id": feature.id,
            "context": context ?? "unknown",
            "subscription_status": currentSubscriptionStatus.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        localStorage.save(usageHistory, key: "feature_usage_history")
    }
    
    private func updateAnalyticsFromRevenueCat() {
        guard let customerInfo = subscriptionService.customerInfo else { return }
        
        analytics.updateFromCustomerInfo(customerInfo)
        saveAnalytics()
    }
    
    // MARK: - Subscription Lifecycle
    func handleSubscriptionPurchase(source: String) {
        analytics.subscriptionSource = source
        analytics.subscriptionStartDate = Date()
        saveAnalytics()
        
        // Track purchase event
        trackPurchaseEvent(source: source)
    }
    
    func handleSubscriptionCancellation() {
        analytics.cancellationDate = Date()
        saveAnalytics()
        
        // Track cancellation event
        trackCancellationEvent()
    }
    
    private func trackPurchaseEvent(source: String) {
        let eventData: [String: Any] = [
            "event": "subscription_purchased",
            "subscription_status": currentSubscriptionStatus.rawValue,
            "source": source,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        print("Subscription purchase tracked: \(eventData)")
    }
    
    private func trackCancellationEvent() {
        let eventData: [String: Any] = [
            "event": "subscription_cancelled",
            "subscription_status": currentSubscriptionStatus.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        print("Subscription cancellation tracked: \(eventData)")
    }
    
    // MARK: - Paywall Optimization
    func getOptimalPaywallConfiguration(for feature: SubscriptionFeature, source: String) -> PaywallConfiguration {
        var config = PaywallConfiguration.default
        
        // Customize based on feature and context
        switch feature.id {
        case "unlimited_alarms":
            config = PaywallConfiguration(
                showTrial: true,
                highlightPopular: true,
                showDiscountBadge: true,
                primaryColor: "#6366F1",
                buttonStyle: .gradient,
                headerText: "Never Miss Your Motivation",
                subheaderText: "Create unlimited AI-powered alarms to transform every morning",
                benefitsText: [
                    "Unlimited AI-generated alarm content",
                    "All voice personalities",
                    "Create alarms for any goal or intention",
                    "Advanced wake-up analytics"
                ],
                legalText: PaywallConfiguration.default.legalText
            )
            
        case "all_voices":
            config = PaywallConfiguration(
                showTrial: true,
                highlightPopular: true,
                showDiscountBadge: true,
                primaryColor: "#6366F1",
                buttonStyle: .gradient,
                headerText: "Find Your Perfect Voice",
                subheaderText: "Choose from 4 unique AI personalities to match your motivation style",
                benefitsText: [
                    "Gentle: Calm and encouraging wake-ups",
                    "Energetic: High-energy motivation",
                    "Tough Love: Direct and challenging",
                    "Storyteller: Inspiring narrative approach"
                ],
                legalText: PaywallConfiguration.default.legalText
            )
            
        default:
            // Use default configuration
            break
        }
        
        return config
    }
    
    // MARK: - User Segmentation
    func getUserSegment() -> String {
        let daysSinceInstall = analytics.subscriptionStartDate?.timeIntervalSinceNow ?? 0
        let alarmUsage = currentAlarmCount
        
        if currentSubscriptionStatus.isPremium {
            return "premium_user"
        } else if alarmUsage >= 10 {
            return "power_user"
        } else if daysSinceInstall > 7 * 24 * 60 * 60 { // 7 days
            return "returning_user"
        } else {
            return "new_user"
        }
    }
    
    // MARK: - A/B Testing Support
    func shouldShowFeature(_ featureFlag: String) -> Bool {
        // Simple feature flag system - could integrate with services like LaunchDarkly
        let flags = [
            "show_weekly_plan": true,
            "show_discount_badges": true,
            "enable_social_proof": true
        ]
        
        return flags[featureFlag] ?? false
    }
}

// MARK: - Convenience Extensions
extension SubscriptionManager {
    var isInFreeTrial: Bool {
        return analytics.isInTrial
    }
    
    var daysUntilExpiration: Int? {
        return analytics.daysUntilExpiration
    }
    
    var isExpiringSoon: Bool {
        return analytics.isExpiring
    }
}
