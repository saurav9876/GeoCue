import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: SubscriptionPlan?
    @State private var showingBenefits = false
    @State private var showingPricing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Subscription Plans
                    plansSection
                    
                    // Benefits Preview
                    benefitsPreviewSection
                    
                    // Pricing Comparison
                    pricingComparisonSection
                    
                    // Footer
                    footerSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Premium Features")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await subscriptionManager.loadSubscriptionPlans()
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Title
            VStack(spacing: 8) {
                Text("Unlock Premium Features")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Get the most out of GeoCue with unlimited locations, advanced notifications, and premium features.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Plans Section
    private var plansSection: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(subscriptionManager.availablePlans) { plan in
                    SubscriptionPlanCard(
                        plan: plan,
                        isSelected: selectedPlan?.id == plan.id,
                        onSelect: {
                            selectedPlan = plan
                        }
                    )
                }
            }
            
            // Purchase Button
            if let selectedPlan = selectedPlan {
                Button(action: {
                    Task {
                        let success = await subscriptionManager.purchase(selectedPlan)
                        if success {
                            dismiss()
                        }
                    }
                }) {
                    HStack {
                        if subscriptionManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Subscribe to \(selectedPlan.type.displayName)")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(subscriptionManager.isLoading)
                .padding(.top, 8)
            }
            
            // Error Message
            if let errorMessage = subscriptionManager.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Benefits Preview Section
    private var benefitsPreviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("What You'll Get")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    showingBenefits = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Array(SubscriptionBenefits.features.prefix(6)), id: \.self) { feature in
                    BenefitCard(feature: feature)
                }
            }
        }
        .sheet(isPresented: $showingBenefits) {
            BenefitsDetailView()
        }
    }
    
    // MARK: - Pricing Comparison Section
    private var pricingComparisonSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Pricing Comparison")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View Details") {
                    showingPricing = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                let monthlyPlan = subscriptionManager.availablePlans.first { $0.type == .monthly }
                let yearlyPlan = subscriptionManager.availablePlans.first { $0.type == .yearly }
                
                if let monthly = monthlyPlan, let yearly = yearlyPlan {
                    PricingComparisonCard(
                        monthlyPlan: monthly,
                        yearlyPlan: yearly
                    )
                }
            }
        }
        .sheet(isPresented: $showingPricing) {
            PricingDetailView()
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Restore Purchases
            Button("Restore Purchases") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.blue)
            
            // Terms and Privacy
            VStack(spacing: 8) {
                Text("By subscribing, you agree to our Terms of Service and Privacy Policy.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    Button("Terms of Service") {
                        // Open terms
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    
                    Button("Privacy Policy") {
                        // Open privacy policy
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                }
            }
            
            // Subscription Info
            VStack(spacing: 4) {
                Text("• Subscriptions automatically renew unless cancelled")
                Text("• Cancel anytime in Settings > Subscriptions")
                Text("• Prices may vary by location")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
}

// MARK: - Subscription Plan Card
struct SubscriptionPlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.type.displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if plan.isPopular {
                                Text("BEST VALUE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        
                        Text(plan.type.description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(plan.localizedPrice)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("per \(plan.billingPeriod)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Features
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.features.prefix(3), id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            
                            Text(feature)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Benefit Card
struct BenefitCard: View {
    let feature: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow)
            
            Text(feature)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Pricing Comparison Card
struct PricingComparisonCard: View {
    let monthlyPlan: SubscriptionPlan
    let yearlyPlan: SubscriptionPlan
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text(monthlyPlan.localizedPrice)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Yearly")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text(yearlyPlan.localizedPrice)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            
            HStack {
                Spacer()
                
                Text("Save 58% with yearly plan!")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(SubscriptionManager.shared)
}

