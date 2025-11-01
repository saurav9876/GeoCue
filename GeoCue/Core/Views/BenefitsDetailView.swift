import SwiftUI

struct BenefitsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Current Features
                    currentFeaturesSection
                    
                    // Coming Soon Features
                    comingSoonSection
                    
                    // Comparison Table
                    comparisonSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Premium Benefits")
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
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            VStack(spacing: 8) {
                Text("Unlock Premium Features")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Get access to advanced features that make GeoCue even more powerful and personalized.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Current Features Section
    private var currentFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                Text("Available Now")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 12) {
                ForEach(SubscriptionBenefits.features, id: \.self) { feature in
                    FeatureRow(
                        feature: feature,
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
            }
        }
    }
    
    // MARK: - Coming Soon Section
    private var comingSoonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
                
                Text("Coming Soon")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 12) {
                ForEach(SubscriptionBenefits.premiumFeatures, id: \.self) { feature in
                    FeatureRow(
                        feature: feature,
                        icon: "sparkles",
                        color: .purple
                    )
                }
            }
        }
    }
    
    // MARK: - Comparison Section
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Free vs Premium")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Feature")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Free")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 60)
                    
                    Text("Premium")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 60)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Features
                VStack(spacing: 0) {
                    ComparisonRow(
                        feature: "Geofence Locations",
                        freeValue: "3",
                        premiumValue: "Unlimited"
                    )
                    
                    ComparisonRow(
                        feature: "Notification Styles",
                        freeValue: "Basic",
                        premiumValue: "Advanced"
                    )
                    
                    ComparisonRow(
                        feature: "Custom Ringtones",
                        freeValue: "No",
                        premiumValue: "Yes"
                    )
                    
                    ComparisonRow(
                        feature: "Export & Backup",
                        freeValue: "No",
                        premiumValue: "Yes"
                    )
                    
                    ComparisonRow(
                        feature: "Customer Support",
                        freeValue: "Email",
                        premiumValue: "Priority"
                    )
                    
                    ComparisonRow(
                        feature: "Ads",
                        freeValue: "Yes",
                        premiumValue: "No"
                    )
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let feature: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(feature)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Comparison Row
struct ComparisonRow: View {
    let feature: String
    let freeValue: String
    let premiumValue: String
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(freeValue)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 60)
            
            Text(premiumValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        
        Divider()
            .padding(.horizontal, 16)
    }
}

#Preview {
    BenefitsDetailView()
}






