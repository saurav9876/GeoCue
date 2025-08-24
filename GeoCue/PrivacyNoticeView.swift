import SwiftUI

struct PrivacyNoticeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                privacySection(
                    title: "📍 Location Data",
                    items: [
                        "Your location data is stored locally on your device only",
                        "We never share your location with third parties",
                        "Location data is used only for geofence notifications",
                        "You can delete all location data anytime from the app"
                    ]
                )
                
                privacySection(
                    title: "🔔 Notifications",
                    items: [
                        "Notifications are generated locally on your device",
                        "No notification data is sent to external servers",
                        "You have full control over notification frequency",
                        "Do Not Disturb settings are respected"
                    ]
                )
                
                privacySection(
                    title: "💾 Data Storage",
                    items: [
                        "All app data is stored locally using iOS secure storage",
                        "No cloud storage or external databases are used",
                        "App settings and preferences remain on your device",
                        "Uninstalling the app removes all stored data"
                    ]
                )
                
                privacySection(
                    title: "🔒 Security",
                    items: [
                        "Sensitive data is encrypted using iOS Keychain",
                        "App follows iOS security best practices",
                        "No personal data is transmitted over the internet",
                        "Regular security updates are provided"
                    ]
                )
                
                privacySection(
                    title: "📊 Analytics",
                    items: [
                        "No analytics or tracking services are integrated",
                        "No usage statistics are collected",
                        "No crash reports contain personal information",
                        "Your privacy is our top priority"
                    ]
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Contact Us")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("If you have any questions about this privacy notice or how your data is handled, please contact us through the App Store.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                Text("Last updated: January 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
            .padding(20)
        }
        .navigationTitle("Privacy Notice")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func privacySection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                        
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    NavigationView {
        PrivacyNoticeView()
    }
}