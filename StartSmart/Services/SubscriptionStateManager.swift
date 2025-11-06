import Foundation
import RevenueCat
import Combine
import SwiftUI

// MARK: - Subscription State Manager
@MainActor
class SubscriptionStateManager: ObservableObject {
    @Published var subscriptionStatus: StartSmartSubscriptionStatus = .free
    @Published var customerInfo: CustomerInfo?
    @Published var availableOfferings: Offerings?
    @Published var isLoading = false
    @Published var lastError: SubscriptionError?
    @Published var showSuccessMessage = false
    @Published var successMessage = ""
    @Published var showErrorMessage = false
    @Published var errorMessage = ""
    
    private let subscriptionService: SubscriptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(subscriptionService: SubscriptionServiceProtocol) {
        self.subscriptionService = subscriptionService
        setupSubscriptions()
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        // Subscribe to subscription status changes
        subscriptionService.subscriptionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.subscriptionStatus = status
                self?.handleSubscriptionStatusChange(status)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func configure() async {
        isLoading = true
        defer { isLoading = false }
        
        await subscriptionService.configureRevenueCat()
        await refreshSubscriptionData()
    }
    
    func refreshSubscriptionData() async {
        do {
            let customerInfo = try await subscriptionService.getCustomerInfo()
            let offerings = try await subscriptionService.getOfferings()
            
            self.customerInfo = customerInfo
            self.availableOfferings = offerings
            self.subscriptionStatus = mapToSubscriptionStatus(customerInfo)
            
        } catch {
            showError("Failed to refresh subscription data: \(error.localizedDescription)")
        }
    }
    
    func purchasePackage(_ package: Package) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo = try await subscriptionService.purchasePackage(package)
            self.customerInfo = customerInfo
            self.subscriptionStatus = mapToSubscriptionStatus(customerInfo)
            
            // Sync the new subscription status to Firebase
            await syncSubscriptionToFirebase(self.subscriptionStatus)
            
            showSuccess("Welcome to StartSmart Pro! You now have access to all premium features.")
            return true
            
        } catch SubscriptionError.userCancelled {
            // User cancelled, no error needed
            return false
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo = try await subscriptionService.restorePurchases()
            self.customerInfo = customerInfo
            self.subscriptionStatus = mapToSubscriptionStatus(customerInfo)
            
            // Sync the restored subscription status to Firebase
            await syncSubscriptionToFirebase(self.subscriptionStatus)
            
            if subscriptionStatus.isPremium {
                showSuccess("Purchases restored successfully! Welcome back to StartSmart Pro.")
                return true
            } else {
                showError("No previous purchases found to restore")
                return false
            }
            
        } catch {
            showError("Failed to restore purchases: \(error.localizedDescription)")
            return false
        }
    }
    
    func checkSubscriptionStatus() async {
        do {
            let status = try await subscriptionService.checkSubscriptionStatus()
            self.subscriptionStatus = status
        } catch {
            showError("Failed to check subscription status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
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
            case "startsmart_pro_monthly_":
                return .proMonthly
            case "startsmart_pro_yearly_":
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
    
    private func handleSubscriptionStatusChange(_ status: StartSmartSubscriptionStatus) {
        // Handle any side effects of subscription status changes
        switch status {
        case .free:
            // User downgraded or subscription expired
            break
        case .proWeekly, .proMonthly, .proAnnual:
            // User upgraded to premium
            break
        }
    }
    
    private func showSuccess(_ message: String) {
        successMessage = message
        showSuccessMessage = true
    }
    
    func showError(_ message: String) {
        errorMessage = message
        showErrorMessage = true
        lastError = SubscriptionError.networkError // Simplified for now
    }
    
    // MARK: - Computed Properties
    var isPremium: Bool {
        subscriptionStatus.isPremium
    }
    
    var canMakePayments: Bool {
        subscriptionService.canMakePayments()
    }
    
    var hasActiveSubscription: Bool {
        guard let customerInfo = customerInfo else { return false }
        return !customerInfo.entitlements.active.isEmpty
    }
    
    var subscriptionExpirationDate: Date? {
        guard let customerInfo = customerInfo else { return nil }
        
        // Find the latest expiration date among active entitlements
        var latestExpiration: Date?
        for (_, entitlement) in customerInfo.entitlements.active {
            if let expirationDate = entitlement.expirationDate {
                if latestExpiration == nil || expirationDate > latestExpiration! {
                    latestExpiration = expirationDate
                }
            }
        }
        
        return latestExpiration
    }
    
    var daysUntilExpiration: Int? {
        guard let expirationDate = subscriptionExpirationDate else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: expirationDate)
        return components.day
    }
    
    var isSubscriptionExpiringSoon: Bool {
        guard let daysUntilExpiration = daysUntilExpiration else { return false }
        return daysUntilExpiration <= 7 && daysUntilExpiration > 0
    }
    
    var isSubscriptionExpired: Bool {
        guard let daysUntilExpiration = daysUntilExpiration else { return false }
        return daysUntilExpiration <= 0
    }
}

// MARK: - Subscription State Manager Extensions
extension SubscriptionStateManager {
    func getPackageForPlan(_ plan: SubscriptionPlan) -> Package? {
        guard let offerings = availableOfferings,
              let currentOffering = offerings.current else { return nil }
        
        return currentOffering.availablePackages.first { package in
            package.storeProduct.productIdentifier == plan.id
        }
    }
    
    func getLocalizedPriceForPlan(_ plan: SubscriptionPlan) -> String? {
        guard let package = getPackageForPlan(plan) else { return nil }
        return package.storeProduct.localizedPriceString
    }
    
    func getTrialPeriodForPlan(_ plan: SubscriptionPlan) -> String? {
        guard let package = getPackageForPlan(plan) else { return nil }
        guard let discount = package.storeProduct.introductoryDiscount else { return nil }
        
        switch discount.subscriptionPeriod.unit {
        case .day:
            return "\(discount.subscriptionPeriod.value) day trial"
        case .week:
            return "\(discount.subscriptionPeriod.value) week trial"
        case .month:
            return "\(discount.subscriptionPeriod.value) month trial"
        case .year:
            return "\(discount.subscriptionPeriod.value) year trial"
        @unknown default:
            return "Trial available"
        }
    }
}

// MARK: - Firebase Sync
extension SubscriptionStateManager {
    private func syncSubscriptionToFirebase(_ status: StartSmartSubscriptionStatus) async {
        do {
            // Use resolveSafe() to handle cases where UserViewModel might not be available yet
            guard let userViewModel: UserViewModel = await DependencyContainer.shared.resolveSafe() else {
                print("⚠️ UserViewModel not available for Firebase sync (DependencyContainer may be initializing)")
                return
            }
            
            let syncSuccess = await userViewModel.syncSubscriptionWithRevenueCat(status)
            if !syncSuccess {
                print("⚠️ Warning: Failed to sync subscription to Firebase, but purchase was successful")
            }
        }
    }
}
