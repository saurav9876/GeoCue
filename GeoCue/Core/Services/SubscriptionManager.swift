import Foundation
import StoreKit
import Combine

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var availablePlans: [SubscriptionPlan] = []
    @Published var currentSubscription: SubscriptionDetails?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var products: [Product] = []
    private var updateListenerTask: Task<Void, Error>?
    private let userDefaults = UserDefaults.standard
    private let subscriptionKey = "current_subscription"
    
    private override init() {
        super.init()
        loadSubscriptionFromUserDefaults()
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Interface
    
    /// Load available subscription plans
    func loadSubscriptionPlans() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch products from App Store
            let productIds = Set(SubscriptionPlanType.allCases.map { planType in
                switch planType {
                case .monthly:
                    return "com.pixelsbysaurav.GeoCue.monthly"
                case .yearly:
                    return "com.pixelsbysaurav.GeoCue.yearly"
                }
            })
            
            let products = try await Product.products(for: productIds)
            self.products = products
            
            // Create subscription plans from products
            availablePlans = products.compactMap { product in
                guard let planType = getPlanType(from: product.id) else { return nil }
                
                return SubscriptionPlan(
                    type: planType,
                    productId: product.id,
                    price: product.price,
                    currencyCode: product.priceFormatStyle.currencyCode,
                    localizedPrice: product.displayPrice,
                    features: getFeatures(for: planType),
                    isPopular: planType == .yearly
                )
            }
            
            // If no products loaded, use default plans
            if availablePlans.isEmpty {
                availablePlans = SubscriptionPlan.defaultPlans
            }
            
        } catch {
            errorMessage = "Failed to load subscription plans: \(error.localizedDescription)"
            // Fallback to default plans
            availablePlans = SubscriptionPlan.defaultPlans
        }
        
        isLoading = false
    }
    
    /// Purchase a subscription
    func purchase(_ plan: SubscriptionPlan) async -> Bool {
        guard let product = products.first(where: { $0.id == plan.productId }) else {
            errorMessage = "Product not available"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Handle successful purchase
                await handleSuccessfulPurchase(verification, for: plan)
                return true
                
            case .userCancelled:
                errorMessage = "Purchase cancelled"
                return false
                
            case .pending:
                errorMessage = "Purchase pending approval"
                return false
                
            @unknown default:
                errorMessage = "Unknown purchase result"
                return false
            }
            
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    /// Restore purchases
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            return true
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    /// Check subscription status
    func checkSubscriptionStatus() async {
        await updateSubscriptionStatus()
    }
    
    /// Get subscription benefits text
    func getSubscriptionBenefitsText() -> String {
        let features = SubscriptionBenefits.features
        let premiumFeatures = SubscriptionBenefits.premiumFeatures
        
        var text = "🌟 **Premium Features Include:**\n\n"
        
        for feature in features {
            text += "✅ \(feature)\n"
        }
        
        text += "\n🚀 **Coming Soon:**\n\n"
        
        for feature in premiumFeatures {
            text += "🔮 \(feature)\n"
        }
        
        return text
    }
    
    /// Get pricing comparison text
    func getPricingComparisonText() -> String {
        let monthlyPrice = availablePlans.first { $0.type == .monthly }?.localizedPrice ?? "$1.99"
        let yearlyPrice = availablePlans.first { $0.type == .yearly }?.localizedPrice ?? "$9.99"
        
        return """
        💰 **Pricing Options:**
        
        📅 **Monthly Plan**: \(monthlyPrice)/month
        📅 **Yearly Plan**: \(yearlyPrice)/year
        
        💡 **Save 58%** with the yearly plan!
        That's just **$0.83/month** instead of \(monthlyPrice)/month.
        
        🔄 **Cancel anytime** - no commitment required.
        """
    }
    
    // MARK: - Private Methods
    
    private func getPlanType(from productId: String) -> SubscriptionPlanType? {
        if productId.contains("monthly") {
            return .monthly
        } else if productId.contains("yearly") {
            return .yearly
        }
        return nil
    }
    
    private func getFeatures(for planType: SubscriptionPlanType) -> [String] {
        switch planType {
        case .monthly:
            return [
                "Unlimited geofence locations",
                "Advanced notification styles",
                "Priority support",
                "Premium ringtones",
                "Export & backup",
                "No ads"
            ]
        case .yearly:
            return [
                "Everything in Monthly",
                "58% savings",
                "Early access to new features",
                "Exclusive themes",
                "Advanced analytics",
                "Family sharing (coming soon)"
            ]
        }
    }
    
    private func handleSuccessfulPurchase(_ verification: VerificationResult<Transaction>, for plan: SubscriptionPlan) async {
        guard case .verified(let transaction) = verification else {
            errorMessage = "Transaction verification failed"
            return
        }
        
        // Update subscription status
        let subscription = SubscriptionDetails(
            status: .active,
            planType: plan.type,
            expirationDate: transaction.expirationDate,
            autoRenewStatus: transaction.isUpgraded,
            originalTransactionId: String(transaction.originalID),
            latestTransactionId: String(transaction.id)
        )
        
        currentSubscription = subscription
        saveSubscriptionToUserDefaults(subscription)
        
        // Finish the transaction
        await transaction.finish()
        
        Logger.shared.info("Subscription purchased successfully: \(plan.type.displayName)", category: .general)
    }
    
    private func updateSubscriptionStatus() async {
        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            // Check if subscription is still active
            if let expirationDate = transaction.expirationDate, expirationDate > Date() {
                let planType = getPlanType(from: transaction.productID) ?? .monthly
                
                let subscription = SubscriptionDetails(
                    status: .active,
                    planType: planType,
                    expirationDate: expirationDate,
                    autoRenewStatus: !transaction.isUpgraded,
                    originalTransactionId: String(transaction.originalID),
                    latestTransactionId: String(transaction.id)
                )
                
                currentSubscription = subscription
                saveSubscriptionToUserDefaults(subscription)
                return
            }
        }
        
        // No active subscription found
        currentSubscription = SubscriptionDetails(
            status: .none,
            planType: nil,
            expirationDate: nil,
            autoRenewStatus: false,
            originalTransactionId: nil,
            latestTransactionId: nil
        )
        saveSubscriptionToUserDefaults(currentSubscription)
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                await self.handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            return
        }
        
        // Handle transaction updates (renewals, cancellations, etc.)
        await updateSubscriptionStatus()
        
        // Finish the transaction
        await transaction.finish()
    }
    
    // MARK: - UserDefaults Persistence
    
    private func saveSubscriptionToUserDefaults(_ subscription: SubscriptionDetails?) {
        if let data = try? JSONEncoder().encode(subscription) {
            userDefaults.set(data, forKey: subscriptionKey)
        }
    }
    
    private func loadSubscriptionFromUserDefaults() {
        if let data = userDefaults.data(forKey: subscriptionKey),
           let subscription = try? JSONDecoder().decode(SubscriptionDetails.self, from: data) {
            currentSubscription = subscription
        }
    }
}

// MARK: - Subscription Manager Extensions

extension SubscriptionManager {
    /// Check if user has active subscription
    var isSubscribed: Bool {
        currentSubscription?.isActive ?? false
    }
    
    /// Get current plan type
    var currentPlanType: SubscriptionPlanType? {
        currentSubscription?.planType
    }
    
    /// Check if feature is available
    func isFeatureAvailable(_ feature: String) -> Bool {
        // For now, all features require subscription
        // You can implement more granular feature checking here
        return isSubscribed
    }
    
    /// Get subscription expiration info
    var subscriptionExpirationInfo: String? {
        currentSubscription?.expirationText
    }
}
