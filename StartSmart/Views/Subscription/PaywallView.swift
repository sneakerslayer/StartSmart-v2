import SwiftUI
import RevenueCat
import Combine

struct PaywallView: View {
    @StateObject private var subscriptionStateManager: SubscriptionStateManager
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @Environment(\.dismiss) private var dismiss
    
    let configuration: PaywallConfiguration
    let source: String // Track where the paywall was presented from
    
    init(configuration: PaywallConfiguration = .default, source: String = "unknown") {
        self.configuration = configuration
        self.source = source
        
        // TEMPORARY: Create a mock subscription service for testing
        let mockSubscriptionService = MockSubscriptionService()
        self._subscriptionStateManager = StateObject(wrappedValue: SubscriptionStateManager(
            subscriptionService: mockSubscriptionService
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // StartSmart Branded Background
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Header Section
                        headerSection
                        
                        // Benefits Section
                        benefitsSection
                        
                        // Subscription Plans
                        subscriptionPlansSection
                        
                        // Purchase Button
                        purchaseButtonSection
                        
                        // Restore Purchases
                        restorePurchasesSection
                        
                        // Continue with Free Option
                        continueWithFreeSection
                        
                        // Legal Text
                        legalSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $subscriptionStateManager.showErrorMessage) {
            Button("OK") { }
        } message: {
            Text(subscriptionStateManager.errorMessage)
        }
        .alert("Success!", isPresented: $subscriptionStateManager.showSuccessMessage) {
            Button("Continue") {
                // Mark paywall as seen
                UserDefaults.standard.set(true, forKey: "has_seen_paywall")
                dismiss()
            }
        } message: {
            Text(subscriptionStateManager.successMessage)
        }
        .task {
            await subscriptionStateManager.configure()
        }
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Animated Icon
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: UUID())
                }
                Spacer()
            }
            .padding(.top, 20)
            
            // Main Header with Animation
            Text(configuration.headerText)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: UUID())
            
            // Subheader with Gradient
            Text(configuration.subheaderText)
                .font(.headline)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Interactive Feature Highlights
            HStack(spacing: 20) {
                FeatureHighlight(icon: "brain.head.profile", text: "AI-Powered")
                FeatureHighlight(icon: "waveform", text: "Personalized")
                FeatureHighlight(icon: "chart.line.uptrend.xyaxis", text: "Analytics")
            }
            .padding(.top, 8)
        }
        .padding(.top, 0)
    }
    
    // MARK: - Feature Highlight Component
    private func FeatureHighlight(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(spacing: 10) {
            ForEach(configuration.benefitsText, id: \.self) { benefit in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                        .background(
                            Circle()
                                .fill(Color.green)
                                .frame(width: 20, height: 20)
                        )
                    
                    Text(benefit)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Subscription Plans Section
    private var subscriptionPlansSection: some View {
        VStack(spacing: 8) {
            Text("Choose Your Plan")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            VStack(spacing: 6) {
                ForEach(SubscriptionPlan.allPlans) { plan in
                    subscriptionPlanRow(plan)
                }
            }
        }
    }
    
    private func subscriptionPlanRow(_ plan: SubscriptionPlan) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(plan.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        if plan.isPopular && configuration.highlightPopular {
                            Text("POPULAR")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                        
                        if let discount = plan.discountPercentage,
                           configuration.showDiscountBadge {
                            Text("\(discount)% OFF")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(6)
                        }
                        
                        Spacer()
                    }
                    
                    Text(plan.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if let trialDays = plan.trialDays, configuration.showTrial {
                        HStack(spacing: 4) {
                            Image(systemName: "gift.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text("\(trialDays)-day FREE trial")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                                )
                        )
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(plan.price)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(plan.period.abbreviation)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedPlan.id == plan.id ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                selectedPlan.id == plan.id ? Color.white : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Purchase Button Section
    private var purchaseButtonSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await purchaseSelectedPlan()
                }
            } label: {
                HStack {
                    if subscriptionStateManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    }
                    
                    HStack(spacing: 6) {
                        if !subscriptionStateManager.isLoading {
                            Image(systemName: "gift.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        Text(subscriptionStateManager.isLoading ? "Processing..." : "Start Your \(selectedPlan.trialDays ?? 0)-Day FREE Trial")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .disabled(subscriptionStateManager.isLoading || subscriptionStateManager.isPremium)
            
            if subscriptionStateManager.isPremium {
                Text("You already have an active subscription")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    // MARK: - Restore Purchases Section
    private var restorePurchasesSection: some View {
        Button {
            Task {
                await restorePurchases()
            }
        } label: {
            Text("Restore Purchases")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
        }
        .disabled(subscriptionStateManager.isLoading)
    }
    
    // MARK: - Continue with Free Section
    private var continueWithFreeSection: some View {
        Button {
            // Mark paywall as seen and continue with free version
            UserDefaults.standard.set(true, forKey: "has_seen_paywall")
            dismiss()
        } label: {
            Text("Continue with Free Version")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .underline()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(spacing: 6) {
            Text(configuration.legalText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("Privacy Policy") {
                    // Open privacy policy
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                
                Button("Terms of Service") {
                    // Open terms of service
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    private func loadOfferings() async {
        await subscriptionStateManager.refreshSubscriptionData()
    }
    
    private func updatePlanPricesFromOfferings(_ offerings: Offerings) {
        guard let currentOffering = offerings.current else { return }
        
        // Update plan prices with actual values from RevenueCat
        for package in currentOffering.availablePackages {
            let _ = package.storeProduct.localizedPriceString
            
            switch package.storeProduct.productIdentifier {
            case SubscriptionPlan.weeklyProductId:
                if SubscriptionPlan.allPlans.firstIndex(where: { $0.id == SubscriptionPlan.weeklyProductId }) != nil {
                    // Note: In a real implementation, you'd want to update the plan or create a mutable version
                }
            case SubscriptionPlan.monthlyProductId:
                if SubscriptionPlan.allPlans.firstIndex(where: { $0.id == SubscriptionPlan.monthlyProductId }) != nil {
                    // Update monthly plan price
                }
            case SubscriptionPlan.annualProductId:
                if SubscriptionPlan.allPlans.firstIndex(where: { $0.id == SubscriptionPlan.annualProductId }) != nil {
                    // Update annual plan price
                }
            default:
                break
            }
        }
    }
    
    private func purchaseSelectedPlan() async {
        guard let package = subscriptionStateManager.getPackageForPlan(selectedPlan) else {
            subscriptionStateManager.showError("Selected plan is not available")
            return
        }
        
        let success = await subscriptionStateManager.purchasePackage(package)
        if success {
            // Track analytics
            trackPurchaseEvent(plan: selectedPlan, source: source)
        }
    }
    
    private func restorePurchases() async {
        _ = await subscriptionStateManager.restorePurchases()
    }
    
    
    private func trackPurchaseEvent(plan: SubscriptionPlan, source: String) {
        // Track purchase for analytics
        // This could integrate with Firebase Analytics, Mixpanel, etc.
        print("Purchase completed: \(plan.name) from \(source)")
    }
}

// MARK: - Preview
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView(source: "preview")
    }
}

// MARK: - Mock Subscription Service for Testing
class MockSubscriptionService: SubscriptionServiceProtocol {
    var currentSubscriptionStatus: StartSmartSubscriptionStatus = .free
    var customerInfo: CustomerInfo? = nil
    var availableOfferings: Offerings? = nil
    
    var subscriptionStatusPublisher: AnyPublisher<StartSmartSubscriptionStatus, Never> {
        Just(.free).eraseToAnyPublisher()
    }
    
    func configureRevenueCat() async {
        print("Mock: RevenueCat configured")
    }
    
    func getCustomerInfo() async throws -> CustomerInfo {
        print("Mock: Getting customer info")
        throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock service - no real customer info"])
    }
    
    func getOfferings() async throws -> Offerings {
        print("Mock: Getting offerings")
        throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock service - no real offerings"])
    }
    
    func purchasePackage(_ package: Package) async throws -> CustomerInfo {
        print("Mock: Purchasing package")
        throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock service - no real purchase"])
    }
    
    func restorePurchases() async throws -> CustomerInfo {
        print("Mock: Restoring purchases")
        throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock service - no real restore"])
    }
    
    func checkSubscriptionStatus() async throws -> StartSmartSubscriptionStatus {
        print("Mock: Checking subscription status")
        return .free
    }
    
    func presentCodeRedemptionSheet() {
        print("Mock: Presenting code redemption sheet")
    }
    
    func canMakePayments() -> Bool {
        print("Mock: Can make payments")
        return true
    }
}

// MARK: - Paywall Presentation Helper
extension View {
    func presentPaywall(
        isPresented: Binding<Bool>,
        configuration: PaywallConfiguration = .default,
        source: String = "unknown"
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            PaywallView(configuration: configuration, source: source)
        }
    }
}
