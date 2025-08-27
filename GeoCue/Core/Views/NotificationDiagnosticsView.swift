import SwiftUI
import UserNotifications
import CoreLocation

struct NotificationDiagnosticsView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var notificationEscalator: NotificationEscalator
    @Environment(\.dismiss) private var dismiss
    
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var showingTestNotification = false
    @State private var diagnosticResults: [String] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("Notification Diagnostics")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Check notification and location permissions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Permission Status
                    permissionStatusSection
                    
                    // Test Notifications
                    testNotificationSection
                    
                    // Diagnostic Results
                    if !diagnosticResults.isEmpty {
                        diagnosticResultsSection
                    }
                    
                    // Troubleshooting Tips
                    troubleshootingSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            checkPermissions()
            runDiagnostics()
        }
    }
    
    // MARK: - Permission Status Section
    private var permissionStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Permission Status")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                // Notification Permission
                HStack {
                    Image(systemName: notificationStatus == .authorized ? "bell.fill" : "bell.slash")
                        .foregroundColor(notificationStatus == .authorized ? .green : .red)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.system(size: 15, weight: .medium))
                        
                        Text(getNotificationStatusText())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if notificationStatus != .authorized {
                        Button("Request") {
                            requestNotificationPermission()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                    }
                }
                
                // Location Permission
                HStack {
                    Image(systemName: locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse ? "location.fill" : "location.slash")
                        .foregroundColor(locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse ? .green : .red)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location")
                            .font(.system(size: 15, weight: .medium))
                        
                        Text(getLocationStatusText())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if locationStatus != .authorizedAlways && locationStatus != .authorizedWhenInUse {
                        Button("Request") {
                            locationManager.requestLocationPermission()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Test Notification Section
    private var testNotificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Test Notifications")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                Button(action: sendTestNotification) {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.white)
                        Text("Send Test Notification")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if showingTestNotification {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Test notification sent!")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Diagnostic Results Section
    private var diagnosticResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Diagnostic Results")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(diagnosticResults, id: \.self) { result in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        
                        Text(result)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Troubleshooting Section
    private var troubleshootingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Troubleshooting Tips")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                troubleshootingTip(
                    icon: "bell.slash",
                    title: "No Notifications",
                    description: "Check if Do Not Disturb is enabled in iOS Settings or in the app"
                )
                
                troubleshootingTip(
                    icon: "location.slash",
                    title: "Location Not Working",
                    description: "Ensure location permissions are granted and location services are enabled"
                )
                
                troubleshootingTip(
                    icon: "gearshape",
                    title: "App Settings",
                    description: "Check notification styles and quiet hours settings in the app"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func troubleshootingTip(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Methods
    private func checkPermissions() {
        // Check notification permission asynchronously
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
            }
        }
        
        // Check location permission - access on main thread but defer UI updates if needed
        Task { @MainActor in
            let authStatus = locationManager.authorizationStatus
            locationStatus = authStatus
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.notificationStatus = .authorized
                }
                if let error = error {
                    self.diagnosticResults.append("Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func sendTestNotification() {
        notificationEscalator.sendNotification(
            title: "Test Notification",
            body: "This is a test notification to verify the system is working",
            identifier: "test-notification",
            priority: .medium
        )
        
        showingTestNotification = true
        
        // Hide the success message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showingTestNotification = false
        }
    }
    
    private func runDiagnostics() {
        diagnosticResults.removeAll()
        
        // Check geofences first (can access on main thread since we're already here)
        let geofenceCount = locationManager.geofenceLocations.count
        if geofenceCount == 0 {
            diagnosticResults.append("No geofence locations configured")
        } else {
            diagnosticResults.append("\(geofenceCount) geofence locations configured")
        }
        
        // Check location services asynchronously to avoid blocking
        Task.detached {
            let locationServicesEnabled = CLLocationManager.locationServicesEnabled()
            
            await MainActor.run {
                if !locationServicesEnabled {
                    self.diagnosticResults.append("Location services are disabled in iOS Settings")
                }
                
                let appState = UIApplication.shared.applicationState
                if appState != .active {
                    self.diagnosticResults.append("App is running in background - notifications should work")
                }
            }
        }
        
        // Check notification center settings asynchronously
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied {
                    self.diagnosticResults.append("Notifications are denied in iOS Settings")
                }
                
                if settings.alertSetting == .disabled {
                    self.diagnosticResults.append("Alert notifications are disabled")
                }
                
                if settings.soundSetting == .disabled {
                    self.diagnosticResults.append("Sound notifications are disabled")
                }
                
                if settings.badgeSetting == .disabled {
                    self.diagnosticResults.append("Badge notifications are disabled")
                }
            }
        }
    }
    
    private func getNotificationStatusText() -> String {
        switch notificationStatus {
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not determined"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func getLocationStatusText() -> String {
        switch locationStatus {
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When in use"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not determined"
        @unknown default:
            return "Unknown"
        }
    }
}
