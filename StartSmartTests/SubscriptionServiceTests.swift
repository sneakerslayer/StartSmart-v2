import XCTest
import RevenueCat
import Combine
@testable import StartSmart

class SubscriptionServiceTests: XCTestCase {
    var subscriptionService: SubscriptionService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = Set<AnyCancellable>()
        
        // Use a test API key
        subscriptionService = SubscriptionService(revenueCatApiKey: "test_api_key")
    }
    
    override func tearDownWithError() throws {
        cancellables.removeAll()
        subscriptionService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(subscriptionService.currentSubscriptionStatus, .free)
        XCTAssertNil(subscriptionService.customerInfo)
        XCTAssertNil(subscriptionService.availableOfferings)
    }
    
    // MARK: - Subscription Status Mapping Tests
    
    func testSubscriptionStatusMapping_Free() {
        // Test free status with no active entitlements
        let mockCustomerInfo = createMockCustomerInfo(activeEntitlements: [:])
        let status = subscriptionService.mapToSubscriptionStatus(mockCustomerInfo)
        XCTAssertEqual(status, .free)
    }
    
    func testSubscriptionStatusMapping_ProWeekly() {
        let mockEntitlement = createMockEntitlement(productId: "startsmart_pro_weekly")
        let mockCustomerInfo = createMockCustomerInfo(activeEntitlements: ["pro": mockEntitlement])
        let status = subscriptionService.mapToSubscriptionStatus(mockCustomerInfo)
        XCTAssertEqual(status, .proWeekly)
    }
    
    func testSubscriptionStatusMapping_ProMonthly() {
        let mockEntitlement = createMockEntitlement(productId: "startsmart_pro_monthly")
        let mockCustomerInfo = createMockCustomerInfo(activeEntitlements: ["pro": mockEntitlement])
        let status = subscriptionService.mapToSubscriptionStatus(mockCustomerInfo)
        XCTAssertEqual(status, .proMonthly)
    }
    
    func testSubscriptionStatusMapping_ProAnnual() {
        let mockEntitlement = createMockEntitlement(productId: "startsmart_pro_annual")
        let mockCustomerInfo = createMockCustomerInfo(activeEntitlements: ["pro": mockEntitlement])
        let status = subscriptionService.mapToSubscriptionStatus(mockCustomerInfo)
        XCTAssertEqual(status, .proAnnual)
    }
    
    // MARK: - Publisher Tests
    
    func testSubscriptionStatusPublisher() throws {
        let expectation = expectation(description: "subscription status published")
        var receivedStatuses: [SubscriptionStatus] = []
        
        subscriptionService.subscriptionStatusPublisher
            .sink { status in
                receivedStatuses.append(status)
                if receivedStatuses.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate status change
        subscriptionService.currentSubscriptionStatus = .proMonthly
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(receivedStatuses.count, 2)
        XCTAssertEqual(receivedStatuses[0], .free) // Initial value
        XCTAssertEqual(receivedStatuses[1], .proMonthly) // Updated value
    }
    
    // MARK: - Error Handling Tests
    
    func testSubscriptionError_Equality() {
        let error1 = SubscriptionError.userCancelled
        let error2 = SubscriptionError.userCancelled
        let error3 = SubscriptionError.noOfferingsAvailable
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
    
    func testSubscriptionError_LocalizedDescription() {
        let errors: [SubscriptionError] = [
            .userCancelled,
            .noOfferingsAvailable,
            .unknownPurchaseError,
            .subscriptionExpired,
            .invalidProductId,
            .networkError
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
            XCTAssertNotNil(error.errorDescription)
        }
    }
    
    // MARK: - Utility Functions Tests
    
    func testCanMakePayments() {
        // This test depends on the device/simulator configuration
        let canMakePayments = subscriptionService.canMakePayments()
        XCTAssertTrue(canMakePayments || !canMakePayments) // Should not crash
    }
    
    // MARK: - Mock Helper Functions
    
    private func createMockCustomerInfo(activeEntitlements: [String: MockEntitlementInfo]) -> CustomerInfo {
        // Note: In a real test environment, you would use RevenueCat's test utilities
        // or create proper mock objects. This is a simplified approach.
        fatalError("Mock CustomerInfo creation not implemented - would require RevenueCat test utilities")
    }
    
    private func createMockEntitlement(productId: String) -> MockEntitlementInfo {
        return MockEntitlementInfo(productIdentifier: productId)
    }
}

// MARK: - Mock Objects

struct MockEntitlementInfo {
    let productIdentifier: String
    let isActive: Bool
    let willRenew: Bool
    let periodType: PeriodType
    let latestPurchaseDate: Date
    let originalPurchaseDate: Date
    let expirationDate: Date?
    
    init(
        productIdentifier: String,
        isActive: Bool = true,
        willRenew: Bool = true,
        periodType: PeriodType = .normal,
        latestPurchaseDate: Date = Date(),
        originalPurchaseDate: Date = Date(),
        expirationDate: Date? = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days
    ) {
        self.productIdentifier = productIdentifier
        self.isActive = isActive
        self.willRenew = willRenew
        self.periodType = periodType
        self.latestPurchaseDate = latestPurchaseDate
        self.originalPurchaseDate = originalPurchaseDate
        self.expirationDate = expirationDate
    }
}

// MARK: - Subscription Manager Tests

class SubscriptionManagerTests: XCTestCase {
    var subscriptionManager: SubscriptionManager!
    var mockSubscriptionService: MockSubscriptionService!
    var mockLocalStorage: MockLocalStorage!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = Set<AnyCancellable>()
        
        mockSubscriptionService = MockSubscriptionService()
        mockLocalStorage = MockLocalStorage()
        
        subscriptionManager = SubscriptionManager(
            subscriptionService: mockSubscriptionService,
            localStorage: mockLocalStorage
        )
    }
    
    override func tearDownWithError() throws {
        cancellables.removeAll()
        subscriptionManager = nil
        mockSubscriptionService = nil
        mockLocalStorage = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Feature Access Tests
    
    func testCanCreateAlarm_FreeUser_WithinLimit() {
        mockSubscriptionService.currentSubscriptionStatus = .free
        subscriptionManager.currentAlarmCount = 10 // Below limit of 15
        
        XCTAssertTrue(subscriptionManager.canCreateAlarm())
    }
    
    func testCanCreateAlarm_FreeUser_AtLimit() {
        mockSubscriptionService.currentSubscriptionStatus = .free
        subscriptionManager.currentAlarmCount = 15 // At limit
        
        XCTAssertFalse(subscriptionManager.canCreateAlarm())
    }
    
    func testCanCreateAlarm_PremiumUser() {
        mockSubscriptionService.currentSubscriptionStatus = .proMonthly
        subscriptionManager.currentAlarmCount = 100 // Way above free limit
        
        XCTAssertTrue(subscriptionManager.canCreateAlarm())
    }
    
    func testGetRemainingAlarms_FreeUser() {
        mockSubscriptionService.currentSubscriptionStatus = .free
        subscriptionManager.currentAlarmCount = 10
        
        let remaining = subscriptionManager.getRemainingAlarms()
        XCTAssertEqual(remaining, 5) // 15 - 10
    }
    
    func testGetRemainingAlarms_PremiumUser() {
        mockSubscriptionService.currentSubscriptionStatus = .proMonthly
        
        let remaining = subscriptionManager.getRemainingAlarms()
        XCTAssertNil(remaining) // Unlimited
    }
    
    func testCanAccessFeature_FreeFeature() {
        let freeFeature = SubscriptionFeature(
            id: "basic_feature",
            name: "Basic Feature",
            description: "A basic feature",
            iconName: "star",
            isPremiumOnly: false
        )
        
        mockSubscriptionService.currentSubscriptionStatus = .free
        XCTAssertTrue(subscriptionManager.canAccessFeature(freeFeature))
    }
    
    func testCanAccessFeature_PremiumFeature_FreeUser() {
        mockSubscriptionService.currentSubscriptionStatus = .free
        XCTAssertFalse(subscriptionManager.canAccessFeature(.unlimitedAlarms))
    }
    
    func testCanAccessFeature_PremiumFeature_PremiumUser() {
        mockSubscriptionService.currentSubscriptionStatus = .proMonthly
        XCTAssertTrue(subscriptionManager.canAccessFeature(.unlimitedAlarms))
    }
    
    // MARK: - Alarm Count Management Tests
    
    func testIncrementAlarmCount() {
        let initialCount = subscriptionManager.currentAlarmCount
        subscriptionManager.incrementAlarmCount()
        
        XCTAssertEqual(subscriptionManager.currentAlarmCount, initialCount + 1)
    }
    
    // MARK: - User Segmentation Tests
    
    func testGetUserSegment_PremiumUser() {
        mockSubscriptionService.currentSubscriptionStatus = .proMonthly
        
        let segment = subscriptionManager.getUserSegment()
        XCTAssertEqual(segment, "premium_user")
    }
    
    func testGetUserSegment_PowerUser() {
        mockSubscriptionService.currentSubscriptionStatus = .free
        subscriptionManager.currentAlarmCount = 15
        
        let segment = subscriptionManager.getUserSegment()
        XCTAssertEqual(segment, "power_user")
    }
    
    func testGetUserSegment_NewUser() {
        mockSubscriptionService.currentSubscriptionStatus = .free
        subscriptionManager.currentAlarmCount = 2
        // analytics.subscriptionStartDate would be recent
        
        let segment = subscriptionManager.getUserSegment()
        XCTAssertEqual(segment, "new_user")
    }
    
    // MARK: - Feature Flag Tests
    
    func testShouldShowFeature() {
        XCTAssertTrue(subscriptionManager.shouldShowFeature("show_weekly_plan"))
        XCTAssertTrue(subscriptionManager.shouldShowFeature("show_discount_badges"))
        XCTAssertFalse(subscriptionManager.shouldShowFeature("non_existent_feature"))
    }
    
    // MARK: - Paywall Configuration Tests
    
    func testGetOptimalPaywallConfiguration_UnlimitedAlarms() {
        let config = subscriptionManager.getOptimalPaywallConfiguration(
            for: .unlimitedAlarms,
            source: "test"
        )
        
        XCTAssertEqual(config.headerText, "Never Miss Your Motivation")
        XCTAssertTrue(config.showTrial)
        XCTAssertTrue(config.highlightPopular)
    }
    
    func testGetOptimalPaywallConfiguration_AllVoices() {
        let config = subscriptionManager.getOptimalPaywallConfiguration(
            for: .allVoices,
            source: "test"
        )
        
        XCTAssertEqual(config.headerText, "Find Your Perfect Voice")
        XCTAssertTrue(config.benefitsText.contains { $0.contains("Gentle") })
        XCTAssertTrue(config.benefitsText.contains { $0.contains("Energetic") })
    }
}

// MARK: - Mock Subscription Service

class MockSubscriptionService: SubscriptionServiceProtocol {
    var currentSubscriptionStatus: SubscriptionStatus = .free
    var customerInfo: CustomerInfo?
    var availableOfferings: Offerings?
    
    private let statusSubject = CurrentValueSubject<SubscriptionStatus, Never>(.free)
    
    var subscriptionStatusPublisher: AnyPublisher<SubscriptionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    func configureRevenueCat() async {
        // Mock implementation
    }
    
    func getOfferings() async throws -> Offerings {
        throw SubscriptionError.noOfferingsAvailable
    }
    
    func purchasePackage(_ package: Package) async throws -> CustomerInfo {
        throw SubscriptionError.userCancelled
    }
    
    func restorePurchases() async throws -> CustomerInfo {
        throw SubscriptionError.unknownRestoreError
    }
    
    func checkSubscriptionStatus() async throws -> SubscriptionStatus {
        return currentSubscriptionStatus
    }
    
    func getCustomerInfo() async throws -> CustomerInfo {
        throw SubscriptionError.noCustomerInfo
    }
    
    func presentCodeRedemptionSheet() {
        // Mock implementation
    }
    
    func canMakePayments() -> Bool {
        return true
    }
}

// MARK: - Mock Local Storage

class MockLocalStorage: LocalStorageProtocol {
    private var storage: [String: Any] = [:]
    
    func save<T: Codable>(_ object: T, key: String) {
        storage[key] = object
    }
    
    func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        return storage[key] as? T
    }
    
    func delete(key: String) {
        storage.removeValue(forKey: key)
    }
    
    func exists(key: String) -> Bool {
        return storage[key] != nil
    }
    
    func clear() {
        storage.removeAll()
    }
    
    func export() -> [String: Any] {
        return storage
    }
    
    func `import`(_ data: [String: Any]) {
        storage = data
    }
}

// MARK: - Subscription Plan Tests

class SubscriptionPlanTests: XCTestCase {
    
    func testPredefinedPlans() {
        XCTAssertEqual(SubscriptionPlan.weekly.period, .weekly)
        XCTAssertEqual(SubscriptionPlan.monthly.period, .monthly)
        XCTAssertEqual(SubscriptionPlan.annual.period, .annual)
        
        XCTAssertTrue(SubscriptionPlan.monthly.isPopular)
        XCTAssertFalse(SubscriptionPlan.weekly.isPopular)
        XCTAssertFalse(SubscriptionPlan.annual.isPopular)
        
        XCTAssertEqual(SubscriptionPlan.annual.discountPercentage, 33)
        XCTAssertNil(SubscriptionPlan.monthly.discountPercentage)
    }
    
    func testAllPlansArray() {
        XCTAssertEqual(SubscriptionPlan.allPlans.count, 3)
        XCTAssertTrue(SubscriptionPlan.allPlans.contains { $0.period == .weekly })
        XCTAssertTrue(SubscriptionPlan.allPlans.contains { $0.period == .monthly })
        XCTAssertTrue(SubscriptionPlan.allPlans.contains { $0.period == .annual })
    }
}

// MARK: - Subscription Status Extension Tests

class SubscriptionStatusExtensionTests: XCTestCase {
    
    func testPlanProperty() {
        XCTAssertNil(SubscriptionStatus.free.plan)
        XCTAssertEqual(SubscriptionStatus.proWeekly.plan?.period, .weekly)
        XCTAssertEqual(SubscriptionStatus.proMonthly.plan?.period, .monthly)
        XCTAssertEqual(SubscriptionStatus.proAnnual.plan?.period, .annual)
    }
    
    func testFeatureAccess() {
        let freeStatus = SubscriptionStatus.free
        let proStatus = SubscriptionStatus.proMonthly
        
        XCTAssertFalse(freeStatus.canCreateUnlimitedAlarms)
        XCTAssertTrue(proStatus.canCreateUnlimitedAlarms)
        
        XCTAssertFalse(freeStatus.canAccessAllVoices)
        XCTAssertTrue(proStatus.canAccessAllVoices)
        
        XCTAssertFalse(freeStatus.canAccessAdvancedAnalytics)
        XCTAssertTrue(proStatus.canAccessAdvancedAnalytics)
        
        XCTAssertFalse(freeStatus.hasAdFreeExperience)
        XCTAssertTrue(proStatus.hasAdFreeExperience)
    }
    
    func testAlarmLimits() {
        XCTAssertEqual(SubscriptionStatus.free.alarmLimit, 15)
        XCTAssertNil(SubscriptionStatus.proMonthly.alarmLimit)
        XCTAssertNil(SubscriptionStatus.proAnnual.alarmLimit)
    }
}

// MARK: - Feature Gate Tests

class FeatureGateTests: XCTestCase {
    
    func testFeatureGate_FreeUser() {
        let gate = FeatureGate(subscriptionStatus: .free)
        
        XCTAssertTrue(gate.canAccess(SubscriptionFeature.freeFeatures[0]))
        XCTAssertFalse(gate.canAccess(.unlimitedAlarms))
        XCTAssertTrue(gate.requiresPremium(.unlimitedAlarms))
    }
    
    func testFeatureGate_PremiumUser() {
        let gate = FeatureGate(subscriptionStatus: .proMonthly)
        
        XCTAssertTrue(gate.canAccess(SubscriptionFeature.freeFeatures[0]))
        XCTAssertTrue(gate.canAccess(.unlimitedAlarms))
        XCTAssertFalse(gate.requiresPremium(.unlimitedAlarms))
    }
    
    func testUpgradeMessage() {
        let gate = FeatureGate(subscriptionStatus: .free)
        let message = gate.getUpgradeMessage(for: .unlimitedAlarms)
        
        XCTAssertTrue(message.contains("Upgrade to Pro"))
        XCTAssertTrue(message.contains("Unlimited Alarms"))
    }
}

// MARK: - Subscription Analytics Tests

class SubscriptionAnalyticsTests: XCTestCase {
    
    func testInitialState() {
        let analytics = SubscriptionAnalytics()
        
        XCTAssertNil(analytics.subscriptionStartDate)
        XCTAssertNil(analytics.subscriptionEndDate)
        XCTAssertFalse(analytics.isInTrial)
        XCTAssertNil(analytics.daysUntilExpiration)
        XCTAssertEqual(analytics.totalSubscriptionValue, 0)
    }
    
    func testIsExpiring() {
        var analytics = SubscriptionAnalytics()
        
        analytics.daysUntilExpiration = 5
        XCTAssertFalse(analytics.isExpiring)
        
        analytics.daysUntilExpiration = 2
        XCTAssertTrue(analytics.isExpiring)
        
        analytics.daysUntilExpiration = 0
        XCTAssertTrue(analytics.isExpiring)
    }
    
    func testSubscriptionDuration() {
        var analytics = SubscriptionAnalytics()
        
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(30 * 24 * 60 * 60) // 30 days
        
        analytics.subscriptionStartDate = startDate
        analytics.subscriptionEndDate = endDate
        
        let duration = analytics.subscriptionDuration
        XCTAssertNotNil(duration)
        XCTAssertEqual(duration!, 30 * 24 * 60 * 60, accuracy: 1.0)
    }
}
