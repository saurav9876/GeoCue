import SwiftUI

struct PricingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Pricing Breakdown
                    pricingBreakdownSection
                    
                    // Savings Calculator
                    savingsCalculatorSection
                    
                    // Payment Information
                    paymentInfoSection
                    
                    // FAQ
                    faqSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Pricing Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("Transparent Pricing")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("No hidden fees, no surprises. Choose the plan that works best for you.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Pricing Breakdown Section
    private var pricingBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plan Breakdown")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                let monthlyPlan = subscriptionManager.availablePlans.first { $0.type == .monthly }
                let yearlyPlan = subscriptionManager.availablePlans.first { $0.type == .yearly }
                
                if let monthly = monthlyPlan {
                    PricingBreakdownCard(
                        title: "Monthly Plan",
                        price: monthly.localizedPrice,
                        period: "per month",
                        description: "Perfect for trying out premium features",
                        features: [
                            "Billed monthly",
                            "Cancel anytime",
                            "Full premium access",
                            "No commitment"
                        ],
                        color: .blue
                    )
                }
                
                if let yearly = yearlyPlan {
                    PricingBreakdownCard(
                        title: "Yearly Plan",
                        price: yearly.localizedPrice,
                        period: "per year",
                        description: "Best value for long-term users",
                        features: [
                            "Billed annually",
                            "58% savings",
                            "Full premium access",
                            "Early feature access"
                        ],
                        color: .green,
                        isPopular: true
                    )
                }
            }
        }
    }
    
    // MARK: - Savings Calculator Section
    private var savingsCalculatorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Savings Calculator")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Monthly cost comparison
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Plan")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        Text("$1.99 × 12 months")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("$23.88")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                // Yearly cost
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Yearly Plan")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        Text("$9.99 total")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("$9.99")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                Divider()
                
                // Total savings
                HStack {
                    Text("Total Savings")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("$13.89")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }
                
                // Monthly equivalent
                HStack {
                    Text("Monthly Equivalent")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("$0.83/month")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Payment Information Section
    private var paymentInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Information")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "creditcard.fill",
                    title: "Secure Payment",
                    description: "All payments are processed securely through Apple's App Store"
                )
                
                InfoRow(
                    icon: "arrow.clockwise",
                    title: "Auto-Renewal",
                    description: "Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period"
                )
                
                InfoRow(
                    icon: "xmark.circle",
                    title: "Easy Cancellation",
                    description: "Cancel anytime in your device's Settings > Subscriptions"
                )
                
                InfoRow(
                    icon: "globe",
                    title: "Local Pricing",
                    description: "Prices are displayed in your local currency and may vary by region"
                )
            }
        }
    }
    
    // MARK: - FAQ Section
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Frequently Asked Questions")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                FAQRow(
                    question: "Can I cancel my subscription?",
                    answer: "Yes, you can cancel anytime in your device's Settings > Subscriptions. Your premium features will remain active until the end of your current billing period."
                )
                
                FAQRow(
                    question: "What happens when my subscription expires?",
                    answer: "You'll lose access to premium features, but your data and locations will be preserved. You can resubscribe anytime to regain access."
                )
                
                FAQRow(
                    question: "Do you offer refunds?",
                    answer: "Refunds are handled by Apple according to their App Store policies. Contact Apple Support for refund requests."
                )
                
                FAQRow(
                    question: "Can I switch between plans?",
                    answer: "Yes, you can upgrade or downgrade your plan at any time. Changes will take effect at your next billing cycle."
                )
            }
        }
    }
}

// MARK: - Pricing Breakdown Card
struct PricingBreakdownCard: View {
    let title: String
    let price: String
    let period: String
    let description: String
    let features: [String]
    let color: Color
    let isPopular: Bool
    
    init(title: String, price: String, period: String, description: String, features: [String], color: Color, isPopular: Bool = false) {
        self.title = title
        self.price = price
        self.period = period
        self.description = description
        self.features = features
        self.color = color
        self.isPopular = isPopular
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if isPopular {
                            Text("BEST VALUE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(color)
                    
                    Text(period)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(color)
                        
                        Text(feature)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPopular ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - FAQ Row
struct FAQRow: View {
    let question: String
    let answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(answer)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    PricingDetailView()
        .environmentObject(SubscriptionManager.shared)
}






