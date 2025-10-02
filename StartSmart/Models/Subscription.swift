import Foundation
import RevenueCat

// MARK: - Enhanced Subscription Models

// MARK: - Subscription Feature
enum StartSmartFeature: String, CaseIterable, Codable {
    case unlimitedAlarms = "unlimited_alarms"
    case allVoices = "all_voices"
    case advancedAnalytics = "advanced_analytics"
    case earlyAccess = "early_access"
    case prioritySupport = "priority_support"
    case customTones = "custom_tones"
    case socialSharing = "social_sharing"
    
    var displayName: String {
        switch self {
        case .unlimitedAlarms: return "Unlimited Alarms"
        case .allVoices: return "All AI Voices"
        case .advancedAnalytics: return "Advanced Analytics"
        case .earlyAccess: return "Early Access"
        case .prioritySupport: return "Priority Support"
        case .customTones: return "Custom Tones"
        case .socialSharing: return "Social Sharing"
        }
    }
    
    static let freeFeatures: [StartSmartFeature] = [.socialSharing]
    static let proFeatures: [StartSmartFeature] = [.unlimitedAlarms, .allVoices, .advancedAnalytics, .customTones, .socialSharing]
    
    var isPremiumOnly: Bool {
        switch self {
        case .socialSharing: return false
        default: return true
        }
    }
}

// MARK: - Subscription Status
enum StartSmartSubscriptionStatus: String, CaseIterable, Codable {
    case free = "free"
    case proWeekly = "pro_weekly"
    case proMonthly = "pro_monthly"
    case proAnnual = "pro_annual"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .proWeekly: return "Pro Weekly"
        case .proMonthly: return "Pro Monthly"
        case .proAnnual: return "Pro Annual"
        }
    }
    
    var isPremium: Bool {
        self != .free
    }
    
    var weeklyAlarmLimit: Int? {
        switch self {
        case .free: return 3
        case .proWeekly, .proMonthly, .proAnnual: return nil // Unlimited
        }
    }
    
    // Legacy support - keeping monthlyAlarmLimit for compatibility
    var monthlyAlarmLimit: Int? {
        switch self {
        case .free: return 12 // 3 alarms/week * 4 weeks
        case .proWeekly, .proMonthly, .proAnnual: return nil // Unlimited
        }
    }
    
    var hasAdvancedAnalytics: Bool {
        isPremium
    }
    
    var hasAllVoices: Bool {
        isPremium
    }
    
    var hasEarlyAccess: Bool {
        self == .proAnnual
    }
}

// MARK: - Subscription Plan
struct SubscriptionPlan: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let price: String
    let period: SubscriptionPeriod
    let features: [StartSmartFeature]
    let isPopular: Bool
    let trialDays: Int?
    let discountPercentage: Int?
    
    // MARK: - Product IDs (these should match your RevenueCat/App Store Connect configuration)
    static let weeklyProductId = "startsmart_pro_weekly"
    static let monthlyProductId = "startsmart_pro_monthly_"
    static let annualProductId = "startsmart_pro_yearly_"
    
    // MARK: - Predefined Plans
    static let weekly = SubscriptionPlan(
        id: weeklyProductId,
        name: "Pro Weekly",
        description: "Perfect for trying out premium features",
        price: "$3.99",
        period: .weekly,
        features: StartSmartFeature.proFeatures,
        isPopular: false,
        trialDays: 3,
        discountPercentage: nil
    )
    
    static let monthly = SubscriptionPlan(
        id: monthlyProductId,
        name: "Pro Monthly",
        description: "Great for regular users",
        price: "$6.99",
        period: .monthly,
        features: StartSmartFeature.proFeatures,
        isPopular: true,
        trialDays: 7,
        discountPercentage: nil
    )
    
    static let annual = SubscriptionPlan(
        id: annualProductId,
        name: "Pro Annual",
        description: "Best value with exclusive perks",
        price: "$39.99",
        period: .annual,
        features: StartSmartFeature.proFeatures + [.earlyAccess, .prioritySupport],
        isPopular: false,
        trialDays: 7,
        discountPercentage: 33
    )
    
    static let allPlans = [weekly, monthly, annual]
}

// MARK: - Subscription Period
enum SubscriptionPeriod: String, Codable, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case annual = "annual"
    
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        }
    }
    
    var abbreviation: String {
        switch self {
        case .weekly: return "/week"
        case .monthly: return "/month"
        case .annual: return "/year"
        }
    }
}

// MARK: - Subscription Features
struct SubscriptionFeature: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let isPremiumOnly: Bool
    
    // MARK: - Conversion Methods
    var startSmartFeature: StartSmartFeature? {
        return StartSmartFeature(rawValue: id)
    }
    
    // MARK: - Feature Definitions
    static let unlimitedAlarms = SubscriptionFeature(
        id: "unlimited_alarms",
        name: "Unlimited Alarms",
        description: "Create as many AI-powered alarms as you want",
        iconName: "alarm.waves.left.and.right",
        isPremiumOnly: true
    )
    
    static let allVoices = SubscriptionFeature(
        id: "all_voices",
        name: "All Voice Personalities",
        description: "Access to gentle, energetic, tough love, and storyteller voices",
        iconName: "person.3.sequence",
        isPremiumOnly: true
    )
    
    static let advancedAnalytics = SubscriptionFeature(
        id: "advanced_analytics",
        name: "Advanced Analytics",
        description: "Detailed insights into your wake-up patterns and streaks",
        iconName: "chart.bar.xaxis",
        isPremiumOnly: true
    )
    
    static let customContent = SubscriptionFeature(
        id: "custom_content",
        name: "Custom AI Content",
        description: "Personalized motivational speeches based on your goals",
        iconName: "brain.head.profile",
        isPremiumOnly: true
    )
    
    static let socialSharing = SubscriptionFeature(
        id: "social_sharing",
        name: "Social Sharing",
        description: "Share your achievements with beautiful auto-generated cards",
        iconName: "square.and.arrow.up",
        isPremiumOnly: true
    )
    
    static let prioritySupport = SubscriptionFeature(
        id: "priority_support",
        name: "Priority Support",
        description: "Get help faster with priority customer support",
        iconName: "headphones",
        isPremiumOnly: true
    )
    
    static let earlyAccess = SubscriptionFeature(
        id: "early_access",
        name: "Early Access",
        description: "Be the first to try new features and voice personalities",
        iconName: "star.circle",
        isPremiumOnly: true
    )
    
    static let adFree = SubscriptionFeature(
        id: "ad_free",
        name: "Ad-Free Experience",
        description: "Enjoy StartSmart without any advertisements",
        iconName: "eye.slash",
        isPremiumOnly: true
    )
    
    // MARK: - Feature Collections
    static let freeFeatures: [SubscriptionFeature] = [
        SubscriptionFeature(
            id: "basic_alarms",
            name: "Basic Alarms",
            description: "Up to 3 alarms per week",
            iconName: "alarm",
            isPremiumOnly: false
        ),
        SubscriptionFeature(
            id: "one_voice",
            name: "One Voice Personality",
            description: "Access to energetic voice personality",
            iconName: "person.wave.2",
            isPremiumOnly: false
        ),
        SubscriptionFeature(
            id: "basic_streaks",
            name: "Basic Streaks",
            description: "Track your wake-up streaks",
            iconName: "flame",
            isPremiumOnly: false
        )
    ]
    
    static let proFeatures: [SubscriptionFeature] = [
        unlimitedAlarms,
        allVoices,
        advancedAnalytics,
        customContent,
        socialSharing,
        adFree
    ]
}

// MARK: - Enhanced Subscription Status
extension StartSmartSubscriptionStatus {
    var plan: SubscriptionPlan? {
        switch self {
        case .free:
            return nil
        case .proWeekly:
            return .weekly
        case .proMonthly:
            return .monthly
        case .proAnnual:
            return .annual
        }
    }
    
    var features: [StartSmartFeature] {
        switch self {
        case .free:
            return StartSmartFeature.freeFeatures
        case .proWeekly, .proMonthly:
            return StartSmartFeature.proFeatures
        case .proAnnual:
            return StartSmartFeature.proFeatures + [.earlyAccess, .prioritySupport]
        }
    }
    
    func hasFeature(_ feature: StartSmartFeature) -> Bool {
        return features.contains(feature)
    }
    
    var alarmLimit: Int? {
        return monthlyAlarmLimit
    }
    
    // MARK: - Feature Checks
    var canCreateUnlimitedAlarms: Bool {
        return isPremium
    }
    
    var canAccessAllVoices: Bool {
        return isPremium
    }
    
    var canAccessAdvancedAnalytics: Bool {
        return isPremium
    }
    
    var canShareToSocial: Bool {
        return isPremium
    }
    
    var canAccessCustomContent: Bool {
        return isPremium
    }
    
    var hasAdFreeExperience: Bool {
        return isPremium
    }
}

// MARK: - Subscription Analytics
struct SubscriptionAnalytics: Codable, Equatable {
    var subscriptionStartDate: Date?
    var subscriptionEndDate: Date?
    var trialStartDate: Date?
    var trialEndDate: Date?
    var isInTrial: Bool
    var daysUntilExpiration: Int?
    var renewalDate: Date?
    var cancellationDate: Date?
    var totalSubscriptionValue: Decimal
    var subscriptionSource: String? // "paywall", "onboarding", "settings", etc.
    
    init() {
        self.subscriptionStartDate = nil
        self.subscriptionEndDate = nil
        self.trialStartDate = nil
        self.trialEndDate = nil
        self.isInTrial = false
        self.daysUntilExpiration = nil
        self.renewalDate = nil
        self.cancellationDate = nil
        self.totalSubscriptionValue = 0
        self.subscriptionSource = nil
    }
    
    mutating func updateFromCustomerInfo(_ customerInfo: CustomerInfo) {
        // Update trial information
        if let entitlement = customerInfo.entitlements.active.first?.value {
            self.isInTrial = entitlement.periodType == .trial
            
            // Set subscription dates
            if let purchaseDate = entitlement.originalPurchaseDate {
                self.subscriptionStartDate = purchaseDate
            }
            
            if let expirationDate = entitlement.expirationDate {
                self.subscriptionEndDate = expirationDate
                self.renewalDate = entitlement.willRenew ? expirationDate : nil
                
                // Calculate days until expiration
                let calendar = Calendar.current
                let days = calendar.dateComponents([.day], from: Date(), to: expirationDate).day
                self.daysUntilExpiration = max(0, days ?? 0)
            }
        }
    }
    
    var isExpiring: Bool {
        guard let daysUntil = daysUntilExpiration else { return false }
        return daysUntil <= 3 // Expiring within 3 days
    }
    
    var subscriptionDuration: TimeInterval? {
        guard let start = subscriptionStartDate,
              let end = subscriptionEndDate else { return nil }
        return end.timeIntervalSince(start)
    }
}

// MARK: - Paywall Configuration
struct PaywallConfiguration: Codable {
    let showTrial: Bool
    let highlightPopular: Bool
    let showDiscountBadge: Bool
    let primaryColor: String // Hex color
    let buttonStyle: PaywallButtonStyle
    let headerText: String
    let subheaderText: String
    let benefitsText: [String]
    let legalText: String
    
    static let `default` = PaywallConfiguration(
        showTrial: true,
        highlightPopular: true,
        showDiscountBadge: true,
        primaryColor: "#6366F1", // Indigo
        buttonStyle: .gradient,
        headerText: "Unlock Your Full Potential",
        subheaderText: "Transform every morning with AI-powered motivation",
        benefitsText: [
            "Unlimited AI-generated alarm content",
            "All voice personalities",
            "Advanced analytics & insights",
            "Social sharing with auto-generated cards",
            "Ad-free experience"
        ],
        legalText: "Cancel anytime. Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period."
    )
}

enum PaywallButtonStyle: String, Codable, CaseIterable {
    case gradient = "gradient"
    case solid = "solid"
    case outline = "outline"
}

// MARK: - Feature Gating Helper
struct FeatureGate {
    private let subscriptionStatus: SubscriptionStatus
    
    init(subscriptionStatus: SubscriptionStatus) {
        self.subscriptionStatus = subscriptionStatus
    }
    
    func canAccess(_ feature: SubscriptionFeature) -> Bool {
        if !feature.isPremiumOnly {
            return true
        }
        
        return subscriptionStatus.isPremium
    }
    
    func requiresPremium(_ feature: StartSmartFeature) -> Bool {
        return feature.isPremiumOnly && !subscriptionStatus.isPremium
    }
    
    func getUpgradeMessage(for feature: StartSmartFeature) -> String {
        return "Upgrade to Pro to access \(feature.displayName)"
    }
}
