import SwiftUI

struct NotificationDebugView: View {
    @EnvironmentObject private var locationManager: AnyLocationManager
    @State private var showingDebugInfo = false
    @State private var selectedLocation: GeofenceLocation?
    @State private var debugInfo = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("Notification Debug")
                    .font(.largeTitle.bold())
                    .padding(.top)
                
                // Location Selection
                if !locationManager.geofenceLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Location to Test:")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(locationManager.geofenceLocations) { location in
                                    locationCard(for: location)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                } else {
                    Text("No geofence locations found.\nCreate some locations first!")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Show Debug Info") {
                        showingDebugInfo.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if let selectedLocation = selectedLocation {
                        Button("Reset Notification State") {
                            locationManager.resetNotificationState(for: selectedLocation)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDebugInfo) {
                debugInfoView
            }
        }
    }
    
    private func locationCard(for location: GeofenceLocation) -> some View {
        let isSelected = selectedLocation?.id == location.id
        let stats = locationManager.getNotificationStats(for: location)
        
        return Button(action: {
            selectedLocation = location
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(location.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mode: \(location.notificationMode.displayName.components(separatedBy: " (").first ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Daily notifications: \(stats.dailyCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let lastNotification = stats.lastNotification {
                            let timeAgo = Date().timeIntervalSince(lastNotification)
                            Text("Last: \(Int(timeAgo/60))m ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Last: Never")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var debugInfoView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notification System Debug Info")
                        .font(.title2.bold())
                    
                    Text(locationManager.getNotificationDebugInfo())
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    if let selectedLocation = selectedLocation {
                        Divider()
                        
                        Text("Selected Location: \(selectedLocation.name)")
                            .font(.headline)
                        
                        let stats = locationManager.getNotificationStats(for: selectedLocation)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("📊 Statistics:")
                                .font(.subheadline.bold())
                            
                            Text("• Daily notifications: \(stats.dailyCount)")
                            Text("• Total notifications: \(stats.totalCount)")
                            
                            if let lastNotification = stats.lastNotification {
                                Text("• Last notification: \(lastNotification.formatted())")
                            } else {
                                Text("• Last notification: Never")
                            }
                            
                            Text("• Notification mode: \(selectedLocation.notificationMode.displayName)")
                            Text("• Cooldown period: \(Int(selectedLocation.notificationMode.cooldownPeriod/60)) minutes")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Debug Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingDebugInfo = false
                    }
                }
            }
        }
        .onAppear {
            debugInfo = locationManager.getNotificationDebugInfo()
        }
    }
}

#if DEBUG
struct NotificationDebugView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationDebugView()
            .environmentObject(ServiceLocator.locationManager)
    }
}
#endif
