import Foundation
import StoreKit

// MARK: - Subscription Plan Types
enum SubscriptionPlanType: String, CaseIterable, Codable {
    case monthly = "monthly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        }
    }
    
    var description: String {
        switch self {
        case .monthly:
            return "Billed monthly"
        case .yearly:
            return "Billed annually (Save 58%)"
        }
    }
    
    var icon: String {
        switch self {
        case .monthly:
            return "calendar"
        case .yearly:
            return "calendar.badge.plus"
        }
    }
    
    var color: String {
        switch self {
        case .monthly:
            return "blue"
        case .yearly:
            return "green"
        }
    }
    
    var savingsText: String? {
        switch self {
        case .monthly:
            return nil
        case .yearly:
            return "Save 58%"
        }
    }
}

// MARK: - Subscription Plan
struct SubscriptionPlan: Identifiable, Codable {
    let id: String
    let type: SubscriptionPlanType
    let productId: String
    let price: Decimal
    let currencyCode: String
    let localizedPrice: String
    let billingPeriod: String
    let features: [String]
    let isPopular: Bool
    
    init(type: SubscriptionPlanType, productId: String, price: Decimal, currencyCode: String, localizedPrice: String, features: [String], isPopular: Bool = false) {
        self.id = productId
        self.type = type
        self.productId = productId
        self.price = price
        self.currencyCode = currencyCode
        self.localizedPrice = localizedPrice
        self.billingPeriod = type == .monthly ? "month" : "year"
        self.features = features
        self.isPopular = isPopular
    }
    
    // Default plans for development/testing
    static var defaultPlans: [SubscriptionPlan] {
        [
            SubscriptionPlan(
                type: .monthly,
                productId: "com.pixelsbysaurav.GeoCue.monthly",
                price: 1.99,
                currencyCode: "USD",
                localizedPrice: "$1.99",
                features: [
                    "Unlimited geofence locations",
                    "Advanced notification styles",
                    "Priority support",
                    "Premium ringtones",
                    "Export & backup",
                    "No ads"
                ]
            ),
            SubscriptionPlan(
                type: .yearly,
                productId: "com.pixelsbysaurav.GeoCue.yearly",
                price: 9.99,
                currencyCode: "USD",
                localizedPrice: "$9.99",
                features: [
                    "Everything in Monthly",
                    "58% savings",
                    "Early access to new features",
                    "Exclusive themes",
                    "Advanced analytics",
                    "Family sharing (coming soon)"
                ],
                isPopular: true
            )
        ]
    }
}

// MARK: - Subscription Status
enum SubscriptionStatus: String, Codable {
    case none = "none"
    case active = "active"
    case expired = "expired"
    case gracePeriod = "grace_period"
    case pending = "pending"
    
    var displayName: String {
        switch self {
        case .none:
            return "No Active Subscription"
        case .active:
            return "Active Subscription"
        case .expired:
            return "Subscription Expired"
        case .gracePeriod:
            return "Grace Period"
        case .pending:
            return "Subscription Pending"
        }
    }
    
    var isSubscribed: Bool {
        switch self {
        case .active, .gracePeriod:
            return true
        default:
            return false
        }
    }
}

// MARK: - Subscription Details
struct SubscriptionDetails: Codable {
    let status: SubscriptionStatus
    let planType: SubscriptionPlanType?
    let expirationDate: Date?
    let autoRenewStatus: Bool
    let originalTransactionId: String?
    let latestTransactionId: String?
    
    var isActive: Bool {
        status.isSubscribed
    }
    
    var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: expirationDate)
        return components.day
    }
    
    var expirationText: String? {
        guard let days = daysUntilExpiration else { return nil }
        
        if days < 0 {
            return "Expired \(abs(days)) days ago"
        } else if days == 0 {
            return "Expires today"
        } else if days == 1 {
            return "Expires tomorrow"
        } else {
            return "Expires in \(days) days"
        }
    }
}

// MARK: - Subscription Benefits
struct SubscriptionBenefits {
    static let features = [
        "Unlimited geofence locations",
        "Advanced notification styles",
        "Priority customer support",
        "Premium ringtones & sounds",
        "Export & backup your data",
        "Ad-free experience",
        "Early access to new features",
        "Exclusive themes & customization"
    ]
    
    static let premiumFeatures = [
        "Smart location clustering",
        "Advanced analytics & insights",
        "Custom notification schedules",
        "Location sharing with family",
        "Offline map support",
        "Advanced privacy controls"
    ]
}

// MARK: - Localized Pricing Helper
struct PricingHelper {
    static func formatPrice(_ price: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "\(price)"
    }
    
    static func getLocalizedPrice(for plan: SubscriptionPlanType, in currencyCode: String) -> String {
        // This would typically come from StoreKit
        // For now, return default pricing
        switch plan {
        case .monthly:
            return "$1.99"
        case .yearly:
            return "$9.99"
        }
    }
}

