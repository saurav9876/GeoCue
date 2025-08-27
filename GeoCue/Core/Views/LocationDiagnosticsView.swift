import SwiftUI
import CoreLocation

struct LocationDiagnosticsView: View {
    @StateObject private var locationManager = ServiceLocator.locationManager
    @State private var healthCheckResults: [String] = []
    @State private var isPerformingHealthCheck = false
    
    var body: some View {
        NavigationView {
            List {
                statusSection
                permissionsSection
                geofenceSection
                healthCheckSection
                actionSection
            }
            .navigationTitle("Location Diagnostics")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task {
                await performHealthCheck()
            }
        }
    }
    
    private var statusSection: some View {
        Section("System Status") {
            StatusRow(
                title: "Location Services",
                value: locationManager.locationServicesEnabled ? "Enabled" : "Disabled",
                isHealthy: locationManager.locationServicesEnabled
            )
            
            StatusRow(
                title: "Authorization",
                value: locationManager.getLocationServicesStatus(),
                isHealthy: locationManager.authorizationStatus == .authorizedAlways
            )
            
            StatusRow(
                title: "iOS Version",
                value: UIDevice.current.systemVersion,
                isHealthy: true
            )
            
            if #available(iOS 17.0, *) {
                StatusRow(
                    title: "Location Manager Type",
                    value: "Modern (CLMonitor)",
                    isHealthy: true
                )
                
                StatusRow(
                    title: "Monitoring Status",
                    value: locationManager.monitoringStatus,
                    isHealthy: locationManager.activeMonitoringCount > 0
                )
            } else {
                StatusRow(
                    title: "Location Manager Type",
                    value: "Legacy (CLLocationManager)",
                    isHealthy: false
                )
            }
        }
    }
    
    private var permissionsSection: some View {
        Section("Permissions") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: locationManager.canStartLocationUpdates() ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(locationManager.canStartLocationUpdates() ? .green : .red)
                    Text("Can track location")
                }
                
                HStack {
                    Image(systemName: locationManager.canAddGeofences() ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(locationManager.canAddGeofences() ? .green : .red)
                    Text("Can monitor geofences")
                }
                
                if locationManager.authorizationStatus != .authorizedAlways {
                    Button("Request Always Permission") {
                        locationManager.requestLocationPermission()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private var geofenceSection: some View {
        Section("Geofences") {
            HStack {
                Text("Total Geofences")
                Spacer()
                Text("\(locationManager.geofenceLocations.count)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Enabled Geofences")
                Spacer()
                Text("\(locationManager.geofenceLocations.filter { $0.isEnabled }.count)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Active Monitoring")
                Spacer()
                Text("\(locationManager.activeMonitoringCount)/20")
                    .foregroundColor(locationManager.activeMonitoringCount > 18 ? .red : .secondary)
            }
            
            if locationManager.activeMonitoringCount > 18 {
                Text("⚠️ Approaching iOS 20 geofence limit")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var healthCheckSection: some View {
        Section("Health Check") {
            if isPerformingHealthCheck {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking system health...")
                        .foregroundColor(.secondary)
                }
            } else if healthCheckResults.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All systems healthy")
                }
            } else {
                ForEach(healthCheckResults, id: \.self) { issue in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(issue)
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    private var actionSection: some View {
        Section("Actions") {
            Button("Refresh Health Check") {
                Task {
                    await performHealthCheck()
                }
            }
            
            Button("View Debug Info") {
                let debugInfo = locationManager.getNotificationDebugInfo()
                UIPasteboard.general.string = debugInfo
                
                let alert = UIAlertController(
                    title: "Debug Info",
                    message: "Debug information copied to clipboard",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(alert, animated: true)
                }
            }
            
            if locationManager.geofenceLocations.count > 18 {
                Button("Optimize Geofences") {
                    // Future: Implement geofence optimization logic
                }
                .foregroundColor(.orange)
            }
        }
    }
    
    private func performHealthCheck() async {
        isPerformingHealthCheck = true
        
        // Small delay for UX
        try? await Task.sleep(for: .seconds(1))
        
        let issues = await locationManager.performHealthCheck()
        
        await MainActor.run {
            healthCheckResults = issues
            isPerformingHealthCheck = false
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    let isHealthy: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isHealthy ? .green : .orange)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

#Preview {
    LocationDiagnosticsView()
}