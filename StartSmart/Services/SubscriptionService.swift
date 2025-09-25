import Foundation
import RevenueCat
import Combine

// MARK: - Subscription Service Protocol
protocol SubscriptionServiceProtocol {
    var currentSubscriptionStatus: StartSmartSubscriptionStatus { get }
    var subscriptionStatusPublisher: AnyPublisher<StartSmartSubscriptionStatus, Never> { get }
    var customerInfo: CustomerInfo? { get }
    var availableOfferings: Offerings? { get }
    
    func configureRevenueCat() async
    func getOfferings() async throws -> Offerings
    func purchasePackage(_ package: Package) async throws -> CustomerInfo
    func restorePurchases() async throws -> CustomerInfo
    func checkSubscriptionStatus() async throws -> StartSmartSubscriptionStatus
    func getCustomerInfo() async throws -> CustomerInfo
    func presentCodeRedemptionSheet()
    func canMakePayments() -> Bool
}

// MARK: - Subscription Service Implementation
class SubscriptionService: NSObject, SubscriptionServiceProtocol, ObservableObject {
    @Published private(set) var currentSubscriptionStatus: StartSmartSubscriptionStatus = .free
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var availableOfferings: Offerings?
    @Published private(set) var isConfigured = false
    
    private let revenueCatApiKey: String
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    var subscriptionStatusPublisher: AnyPublisher<StartSmartSubscriptionStatus, Never> {
        $currentSubscriptionStatus.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(revenueCatApiKey: String = ServiceConfiguration.APIKeys.revenueCat) {
        self.revenueCatApiKey = revenueCatApiKey
        super.init()
        setupRevenueCat()
    }
    
    // MARK: - RevenueCat Configuration
    @MainActor
    func configureRevenueCat() async {
        guard !isConfigured else { return }
        
        // Configure RevenueCat
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: revenueCatApiKey)
        
        // Set up delegate to receive updates
        Purchases.shared.delegate = self
        
        isConfigured = true
        
        // Initial load of customer info and offerings
        await loadInitialData()
    }
    
    private func setupRevenueCat() {
        Task {
            await configureRevenueCat()
        }
    }
    
    @MainActor
    private func loadInitialData() async {
        do {
            // Load customer info
            let customerInfo = try await getCustomerInfo()
            self.customerInfo = customerInfo
            
            // Load offerings
            let offerings = try await getOfferings()
            self.availableOfferings = offerings
            
            // Update subscription status
            self.currentSubscriptionStatus = mapToSubscriptionStatus(customerInfo)
            
        } catch {
            print("Failed to load initial RevenueCat data: \(error)")
        }
    }
    
    // MARK: - Offerings Management
    func getOfferings() async throws -> Offerings {
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getOfferings { offerings, error in
                if let error = error {
                    continuation.resume(throwing: SubscriptionError.offeringsLoadFailed(error))
                } else if let offerings = offerings {
                    continuation.resume(returning: offerings)
                } else {
                    continuation.resume(throwing: SubscriptionError.noOfferingsAvailable)
                }
            }
        }
    }
    
    // MARK: - Purchase Management
    func purchasePackage(_ package: Package) async throws -> CustomerInfo {
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
                if let error = error {
                    if userCancelled {
                        continuation.resume(throwing: SubscriptionError.userCancelled)
                    } else {
                        continuation.resume(throwing: SubscriptionError.purchaseFailed(error))
                    }
                } else if let customerInfo = customerInfo {
                    continuation.resume(returning: customerInfo)
                } else {
                    continuation.resume(throwing: SubscriptionError.unknownPurchaseError)
                }
            }
        }
    }
    
    func restorePurchases() async throws -> CustomerInfo {
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.restorePurchases { customerInfo, error in
                if let error = error {
                    continuation.resume(throwing: SubscriptionError.restoreFailed(error))
                } else if let customerInfo = customerInfo {
                    continuation.resume(returning: customerInfo)
                } else {
                    continuation.resume(throwing: SubscriptionError.unknownRestoreError)
                }
            }
        }
    }
    
    // MARK: - Customer Info Management
    func getCustomerInfo() async throws -> CustomerInfo {
        return try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getCustomerInfo { customerInfo, error in
                if let error = error {
                    continuation.resume(throwing: SubscriptionError.customerInfoFailed(error))
                } else if let customerInfo = customerInfo {
                    continuation.resume(returning: customerInfo)
                } else {
                    continuation.resume(throwing: SubscriptionError.noCustomerInfo)
                }
            }
        }
    }
    
    func checkSubscriptionStatus() async throws -> StartSmartSubscriptionStatus {
        let customerInfo = try await getCustomerInfo()
        return mapToSubscriptionStatus(customerInfo)
    }
    
    // MARK: - Utility Methods
    func presentCodeRedemptionSheet() {
        if #available(iOS 14.0, *) {
            Purchases.shared.presentCodeRedemptionSheet()
        }
    }
    
    func canMakePayments() -> Bool {
        return Purchases.canMakePayments()
    }
    
    // MARK: - Subscription Status Mapping
    private func mapToSubscriptionStatus(_ customerInfo: CustomerInfo) -> StartSmartSubscriptionStatus {
        // Check for active entitlements
        if customerInfo.entitlements.active.isEmpty {
            return .free
        }
        
        // Check for specific product identifiers
        for (_, entitlement) in customerInfo.entitlements.active {
            switch entitlement.productIdentifier {
            case "startsmart_pro_weekly":
                return .proWeekly
            case "startsmart_pro_monthly":
                return .proMonthly
            case "startsmart_pro_annual":
                return .proAnnual
            default:
                continue
            }
        }
        
        // Fallback to checking any premium entitlement
        if customerInfo.entitlements.active["pro"] != nil {
            return .proMonthly // Default to monthly if we can't determine specific tier
        }
        
        return .free
    }
}

// MARK: - PurchasesDelegate
extension SubscriptionService: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        DispatchQueue.main.async { [weak self] in
            self?.customerInfo = customerInfo
            self?.currentSubscriptionStatus = self?.mapToSubscriptionStatus(customerInfo) ?? .free
        }
    }
    
    func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase startPurchase: @escaping StartPurchaseBlock) {
        // Handle promoted product purchases if needed
        startPurchase { transaction, customerInfo, error, cancelled in
            // Handle the result
        }
    }
}

// MARK: - Subscription Errors
enum SubscriptionError: LocalizedError, Equatable {
    case offeringsLoadFailed(Error)
    case noOfferingsAvailable
    case purchaseFailed(Error)
    case userCancelled
    case unknownPurchaseError
    case restoreFailed(Error)
    case unknownRestoreError
    case customerInfoFailed(Error)
    case noCustomerInfo
    case subscriptionExpired
    case invalidProductId
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .offeringsLoadFailed(let error):
            return "Failed to load subscription options: \(error.localizedDescription)"
        case .noOfferingsAvailable:
            return "No subscription options are currently available"
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .userCancelled:
            return "Purchase was cancelled"
        case .unknownPurchaseError:
            return "An unknown error occurred during purchase"
        case .restoreFailed(let error):
            return "Failed to restore purchases: \(error.localizedDescription)"
        case .unknownRestoreError:
            return "An unknown error occurred while restoring purchases"
        case .customerInfoFailed(let error):
            return "Failed to get customer information: \(error.localizedDescription)"
        case .noCustomerInfo:
            return "No customer information available"
        case .subscriptionExpired:
            return "Your subscription has expired"
        case .invalidProductId:
            return "Invalid product identifier"
        case .networkError:
            return "Network error. Please check your connection and try again"
        }
    }
    
    static func == (lhs: SubscriptionError, rhs: SubscriptionError) -> Bool {
        switch (lhs, rhs) {
        case (.noOfferingsAvailable, .noOfferingsAvailable),
             (.userCancelled, .userCancelled),
             (.unknownPurchaseError, .unknownPurchaseError),
             (.unknownRestoreError, .unknownRestoreError),
             (.noCustomerInfo, .noCustomerInfo),
             (.subscriptionExpired, .subscriptionExpired),
             (.invalidProductId, .invalidProductId),
             (.networkError, .networkError):
            return true
        case (.offeringsLoadFailed, .offeringsLoadFailed),
             (.purchaseFailed, .purchaseFailed),
             (.restoreFailed, .restoreFailed),
             (.customerInfoFailed, .customerInfoFailed):
            return true // Note: This is a simplified comparison
        default:
            return false
        }
    }
}

