import SwiftUI
import RevenueCat

struct PaywallView: View {
    @StateObject private var subscriptionService = DependencyContainer.shared.resolve() as SubscriptionService
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessMessage = false
    @Environment(\.dismiss) private var dismiss
    
    let configuration: PaywallConfiguration
    let source: String // Track where the paywall was presented from
    
    init(configuration: PaywallConfiguration = .default, source: String = "unknown") {
        self.configuration = configuration
        self.source = source
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
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
                    
                    // Legal Text
                    legalSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("StartSmart Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success!", isPresented: $showSuccessMessage) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("Welcome to StartSmart Pro! You now have access to all premium features.")
        }
        .task {
            await loadOfferings()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Pro Badge
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                Text("PRO")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            
            // Main Header
            Text(configuration.headerText)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Subheader
            Text(configuration.subheaderText)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            ForEach(configuration.benefitsText, id: \.self) { benefit in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    Text(benefit)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Subscription Plans Section
    private var subscriptionPlansSection: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
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
                        .foregroundColor(.secondary)
                    
                    if let trialDays = plan.trialDays, configuration.showTrial {
                        Text("\(trialDays)-day free trial")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(plan.price)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(plan.period.abbreviation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedPlan.id == plan.id ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedPlan.id == plan.id ? Color.blue : Color.clear,
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
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isLoading ? "Processing..." : "Start Your \(selectedPlan.trialDays ?? 0)-Day Free Trial")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Group {
                        switch configuration.buttonStyle {
                        case .gradient:
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        case .solid:
                            Color.blue
                        case .outline:
                            Color.clear
                        }
                    }
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            configuration.buttonStyle == .outline ? Color.blue : Color.clear,
                            lineWidth: 2
                        )
                )
            }
            .disabled(isLoading || subscriptionService.currentSubscriptionStatus.isPremium)
            
            if subscriptionService.currentSubscriptionStatus.isPremium {
                Text("You already have an active subscription")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                .foregroundColor(.blue)
        }
        .disabled(isLoading)
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(spacing: 8) {
            Text(configuration.legalText)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("Privacy Policy") {
                    // Open privacy policy
                }
                .font(.caption)
                
                Button("Terms of Service") {
                    // Open terms of service
                }
                .font(.caption)
            }
            .foregroundColor(.blue)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    private func loadOfferings() async {
        do {
            let offerings = try await subscriptionService.getOfferings()
            // Update plan prices from RevenueCat if available
            updatePlanPricesFromOfferings(offerings)
        } catch {
            showErrorMessage("Failed to load subscription options: \(error.localizedDescription)")
        }
    }
    
    private func updatePlanPricesFromOfferings(_ offerings: Offerings) {
        guard let currentOffering = offerings.current else { return }
        
        // Update plan prices with actual values from RevenueCat
        for package in currentOffering.availablePackages {
            let priceString = package.storeProduct.localizedPriceString
            
            switch package.storeProduct.productIdentifier {
            case SubscriptionPlan.weeklyProductId:
                if let index = SubscriptionPlan.allPlans.firstIndex(where: { $0.id == SubscriptionPlan.weeklyProductId }) {
                    // Note: In a real implementation, you'd want to update the plan or create a mutable version
                }
            case SubscriptionPlan.monthlyProductId:
                if let index = SubscriptionPlan.allPlans.firstIndex(where: { $0.id == SubscriptionPlan.monthlyProductId }) {
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
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            // Get current offerings
            let offerings = try await subscriptionService.getOfferings()
            guard let currentOffering = offerings.current else {
                throw SubscriptionError.noOfferingsAvailable
            }
            
            // Find the package for selected plan
            guard let package = currentOffering.availablePackages.first(where: {
                $0.storeProduct.productIdentifier == selectedPlan.id
            }) else {
                throw SubscriptionError.invalidProductId
            }
            
            // Make the purchase
            let _ = try await subscriptionService.purchasePackage(package)
            
            // Success
            showSuccessMessage = true
            
            // Track analytics
            trackPurchaseEvent(plan: selectedPlan, source: source)
            
        } catch SubscriptionError.userCancelled {
            // User cancelled, no error needed
            return
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    private func restorePurchases() async {
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            let customerInfo = try await subscriptionService.restorePurchases()
            
            if subscriptionService.currentSubscriptionStatus.isPremium {
                showSuccessMessage = true
            } else {
                showErrorMessage("No previous purchases found to restore")
            }
            
        } catch {
            showErrorMessage("Failed to restore purchases: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
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
