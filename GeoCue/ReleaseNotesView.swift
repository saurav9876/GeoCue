import SwiftUI

struct ReleaseNotesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Version 1.0.0")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("January 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎉 Initial Release")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            bulletPoint("Location-based reminders with geofencing")
                            bulletPoint("Custom notification messages for entry and exit")
                            bulletPoint("Smart notification frequency control")
                            bulletPoint("Do Not Disturb functionality")
                            bulletPoint("Multiple theme options")
                            bulletPoint("Privacy-focused data handling")
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Coming Soon")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        bulletPoint("Widget support")
                        bulletPoint("Apple Watch integration")
                        bulletPoint("Location sharing")
                        bulletPoint("Advanced scheduling options")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            .padding(20)
        }
        .navigationTitle("Release Notes")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationView {
        ReleaseNotesView()
    }
}