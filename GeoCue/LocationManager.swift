import Foundation
import CoreLocation
import SwiftUI

@MainActor
class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let notificationController = GeofenceNotificationController()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var geofenceLocations: [GeofenceLocation] = []
    @Published var showingLocationPermissionAlert = false
    @Published var isRequestingPermission = false
    @Published var locationServicesEnabled: Bool = false
    
    override init() {
        super.init()
        setupLocationManager()
        // NotificationService is now self-contained and doesn't require configuration
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        Logger.shared.info("LocationManager initialized", category: .location)
        
        loadGeofenceLocations()
        
        // Don't access authorizationStatus immediately to avoid UI warnings
        // The delegate method will be called automatically and set the status
        Logger.shared.debug("Waiting for authorization status from delegate", category: .location)
        
        // Update location services status in background to avoid UI blocking
        updateLocationServicesStatus()

        // If the app already has Always authorization at startup, ensure any
        // previously saved geofences are registered so background events fire.
        // This covers the case where authorization did not "change" this launch.
        if locationManager.authorizationStatus == .authorizedAlways {
            setupExistingGeofences()
        }
    }
    
    private func setupNotificationManager() { }
    
    // Public method to refresh location services status
    func refreshLocationServicesStatus() {
        updateLocationServicesStatus()
    }
    
    func requestLocationPermission() {
        Logger.shared.debug("Current authorization status: \(authorizationStatus)", category: .location)
        
        // Prevent multiple simultaneous requests
        if isRequestingPermission {
            Logger.shared.warning("Already requesting permission, skipping", category: .location)
            return
        }
        
        isRequestingPermission = true
        
        // Add a timeout to prevent getting stuck
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            if self?.isRequestingPermission == true {
                Logger.shared.warning("Permission request timeout, resetting state", category: .location)
                self?.isRequestingPermission = false
                // Show alert to user about the timeout
                DispatchQueue.main.async {
                    self?.showingLocationPermissionAlert = true
                }
            }
        }
        
        switch authorizationStatus {
        case .notDetermined:
            Logger.shared.info("Requesting When In Use authorization", category: .location)
            // Check if we can actually request permission
            if locationServicesEnabled {
                locationManager.requestWhenInUseAuthorization()
            } else {
                print("❌ Location services are disabled")
                isRequestingPermission = false
                showingLocationPermissionAlert = true
            }
        case .authorizedWhenInUse:
            Logger.shared.info("Requesting Always authorization", category: .location)
            if locationServicesEnabled {
                locationManager.requestAlwaysAuthorization()
            } else {
                print("❌ Location services are disabled")
                isRequestingPermission = false
                showingLocationPermissionAlert = true
            }
        case .denied, .restricted:
            Logger.shared.warning("Authorization denied/restricted", category: .location)
            isRequestingPermission = false
            showingLocationPermissionAlert = true
        case .authorizedAlways:
            Logger.shared.debug("Already have Always authorization", category: .location)
            isRequestingPermission = false
            break
        @unknown default:
            Logger.shared.warning("Unknown authorization status", category: .location)
            isRequestingPermission = false
            break
        }
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            Logger.shared.warning("Cannot start location updates without authorization", category: .location)
            return
        }
        
        Logger.shared.info("Starting location updates", category: .location)
        locationManager.startUpdatingLocation()
    }
    
    func requestLocationUpdate() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            Logger.shared.warning("Cannot request location update without authorization", category: .location)
            return
        }
        
        Logger.shared.info("Requesting one-time location update", category: .location)
        locationManager.requestLocation()
    }
    
    func canStartLocationUpdates() -> Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    func canAddGeofences() -> Bool {
        return authorizationStatus == .authorizedAlways
    }
    
    func isLocationServicesEnabled() -> Bool {
        return locationServicesEnabled
    }
    
    func getLocationServicesStatus() -> String {
        if !locationServicesEnabled {
            return "Location Services Disabled"
        }
        
        switch authorizationStatus {
        case .notDetermined:
            return "Permission Not Determined"
        case .denied:
            return "Permission Denied"
        case .restricted:
            return "Permission Restricted"
        case .authorizedWhenInUse:
            return "When In Use Only"
        case .authorizedAlways:
            return "Always Allowed"
        @unknown default:
            return "Unknown Status"
        }
    }
    
    func resetPermissionState() {
        isRequestingPermission = false
        showingLocationPermissionAlert = false
        Logger.shared.info("Permission state reset", category: .location)
    }
    
    func retryPermissionRequest() {
        Logger.shared.info("Retrying permission request", category: .location)
        resetPermissionState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.requestLocationPermission()
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    func addGeofence(_ location: GeofenceLocation) {
        guard authorizationStatus == .authorizedAlways else {
            Logger.shared.warning("Cannot add geofence without Always authorization", category: .location)
            return
        }

        geofenceLocations.append(location)
        saveGeofenceLocations()

        // Respect enabled state and iOS 20-region limit
        guard location.isEnabled else {
            Logger.shared.info("Geofence saved but not monitored (disabled): \(location.name)", category: .location)
            return
        }

        if locationManager.monitoredRegions.count >= 20 {
            Logger.shared.error("Cannot start monitoring more than 20 regions", category: .location)
            return
        }

        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            radius: location.radius,
            identifier: location.id.uuidString
        )
        region.notifyOnEntry = location.notifyOnEntry
        region.notifyOnExit = location.notifyOnExit

        locationManager.startMonitoring(for: region)
    }
    
    func removeGeofence(_ location: GeofenceLocation) {
        geofenceLocations.removeAll { $0.id == location.id }
        saveGeofenceLocations()
        
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            radius: location.radius,
            identifier: location.id.uuidString
        )
        
        locationManager.stopMonitoring(for: region)
    }
    
    func updateGeofence(_ location: GeofenceLocation) {
        guard authorizationStatus == .authorizedAlways else {
            Logger.shared.warning("Cannot update geofence without Always authorization", category: .location)
            return
        }
        
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.geofenceLocations.firstIndex(where: { $0.id == location.id }) {
                // Validate index is still valid
                guard index < self.geofenceLocations.count else {
                    Logger.shared.error("Index out of range when updating geofence", category: .location)
                    return
                }
                
                let oldLocation = self.geofenceLocations[index]
                
                // Update the location in the array first
                self.geofenceLocations[index] = location
                self.saveGeofenceLocations()
                
                // Remove old geofence monitoring
                let oldRegion = CLCircularRegion(
                    center: CLLocationCoordinate2D(latitude: oldLocation.latitude, longitude: oldLocation.longitude),
                    radius: oldLocation.radius,
                    identifier: oldLocation.id.uuidString
                )
                self.locationManager.stopMonitoring(for: oldRegion)
                
                // Add new geofence monitoring if enabled
                if location.isEnabled {
                    let newRegion = CLCircularRegion(
                        center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                        radius: location.radius,
                        identifier: location.id.uuidString
                    )
                    newRegion.notifyOnEntry = location.notifyOnEntry
                    newRegion.notifyOnExit = location.notifyOnExit
                    
                    self.locationManager.startMonitoring(for: newRegion)
                }
                
                Logger.shared.info("Updated geofence: \(location.name) - Enabled: \(location.isEnabled)", category: .location)
            } else {
                Logger.shared.warning("Could not find geofence to update with ID: \(location.id)", category: .location)
            }
        }
    }
    
    private func setupExistingGeofences() {
        for location in geofenceLocations where location.isEnabled {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                radius: location.radius,
                identifier: location.id.uuidString
            )
            region.notifyOnEntry = location.notifyOnEntry
            region.notifyOnExit = location.notifyOnExit
            
            locationManager.startMonitoring(for: region)
        }
    }
    
    private func saveGeofenceLocations() {
        if let encoded = try? JSONEncoder().encode(geofenceLocations) {
            UserDefaults.standard.set(encoded, forKey: "geofenceLocations")
        }
    }
    
    private func loadGeofenceLocations() {
        if let data = UserDefaults.standard.data(forKey: "geofenceLocations"),
           let decoded = try? JSONDecoder().decode([GeofenceLocation].self, from: data) {
            geofenceLocations = decoded
        }
    }
    
    private func updateLocationServicesStatus() {
        // This method should be called from a background queue to avoid UI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let isEnabled = CLLocationManager.locationServicesEnabled()
            DispatchQueue.main.async {
                self?.locationServicesEnabled = isEnabled
                Logger.shared.info("Location services status updated: \(isEnabled)", category: .location)
            }
        }
    }
    
    // MARK: - Notification Statistics
    
    func getNotificationStats(for location: GeofenceLocation) -> (dailyCount: Int, totalCount: Int, lastNotification: Date?) {
        return notificationController.getNotificationStats(for: location.id)
    }
    
    func resetNotificationState(for location: GeofenceLocation) {
        notificationController.resetNotificationState(for: location.id)
    }
    
    func getNotificationDebugInfo() -> String {
        return notificationController.getDebugSummary()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let oldStatus = authorizationStatus
            
            authorizationStatus = manager.authorizationStatus
            isRequestingPermission = false
            
            Logger.shared.info("Authorization changed from \(oldStatus) to \(authorizationStatus)", category: .location)
            
            // Update location services status in background to avoid UI blocking
            updateLocationServicesStatus()
            
            switch authorizationStatus {
            case .authorizedAlways:
                Logger.shared.info("Got Always authorization - setting up geofences", category: .location)
                setupExistingGeofences()
            case .denied, .restricted:
                Logger.shared.warning("Authorization denied/restricted - stopping monitoring", category: .location)
                for monitoredRegion in locationManager.monitoredRegions {
                    locationManager.stopMonitoring(for: monitoredRegion)
                }
            case .authorizedWhenInUse:
                Logger.shared.warning("Got When In Use authorization - need Always for geofencing", category: .location)
            case .notDetermined:
                Logger.shared.debug("Authorization not determined", category: .location)
            @unknown default:
                Logger.shared.warning("Unknown authorization status in delegate", category: .location)
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = locations.last
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            print("🚪 LocationManager: didEnterRegion called for \(region.identifier)")
            
            guard let geofenceLocation = geofenceLocations.first(where: { $0.id.uuidString == region.identifier }) else { 
                Logger.shared.warning("No geofence location found for region: \(region.identifier)", category: .location)
                print("❌ LocationManager: No matching geofence found for region \(region.identifier)")
                return 
            }
            
            Logger.shared.info("User entered region: \(geofenceLocation.name)", category: .location)
            print("📍 LocationManager: User entered \(geofenceLocation.name) (enabled: \(geofenceLocation.isEnabled), notifyOnEntry: \(geofenceLocation.notifyOnEntry))")
            
            // Check if we should send a notification using the smart controller
            if notificationController.shouldNotify(for: geofenceLocation, event: .entry) {
                Logger.shared.info("Attempting to send entry notification for: \(geofenceLocation.name)", category: .location)
                if NotificationService.shared.postGeofenceNotification(event: .entry, location: geofenceLocation) {
                    // Record that notification was actually enqueued
                    notificationController.recordNotificationSent(for: geofenceLocation.id)
                } else {
                    Logger.shared.info("Notification service throttled entry notification for: \(geofenceLocation.name)", category: .location)
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            print("🚪 LocationManager: didExitRegion called for \(region.identifier)")
            
            guard let geofenceLocation = geofenceLocations.first(where: { $0.id.uuidString == region.identifier }) else { 
                Logger.shared.warning("No geofence location found for region: \(region.identifier)", category: .location)
                print("❌ LocationManager: No matching geofence found for region \(region.identifier)")
                return 
            }
            
            Logger.shared.info("User exited region: \(geofenceLocation.name)", category: .location)
            print("📍 LocationManager: User exited \(geofenceLocation.name) (enabled: \(geofenceLocation.isEnabled), notifyOnExit: \(geofenceLocation.notifyOnExit))")
            
            // Check if we should send a notification using the smart controller
            if notificationController.shouldNotify(for: geofenceLocation, event: .exit) {
                Logger.shared.info("Attempting to send exit notification for: \(geofenceLocation.name)", category: .location)
                if NotificationService.shared.postGeofenceNotification(event: .exit, location: geofenceLocation) {
                    // Record that notification was actually enqueued
                    notificationController.recordNotificationSent(for: geofenceLocation.id)
                } else {
                    Logger.shared.info("Notification service throttled exit notification for: \(geofenceLocation.name)", category: .location)
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.shared.error("Location manager failed with error: \(error.localizedDescription)", category: .location)
        
        // Handle specific location errors
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                ErrorHandler.shared.handle(.locationPermissionDenied, context: "Location Manager")
                DispatchQueue.main.async { [weak self] in
                    self?.updateLocationServicesStatus()
                }
            case .locationUnknown:
                ErrorHandler.shared.handle(.invalidLocation, context: "Location Manager")
            case .network:
                ErrorHandler.shared.handle(.networkError(clError.localizedDescription), context: "Location Manager")
            default:
                ErrorHandler.shared.handle(clError, context: "Location Manager")
            }
        } else {
            ErrorHandler.shared.handle(error, context: "Location Manager")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Logger.shared.error("Monitoring failed for region: \(region?.identifier ?? "Unknown") with error: \(error.localizedDescription)", category: .location)
        
        // Handle geofence monitoring errors
        if let clError = error as? CLError {
            switch clError.code {
            case .regionMonitoringDenied:
                ErrorHandler.shared.handle(.locationPermissionDenied, context: "Geofence Monitoring")
            case .regionMonitoringFailure:
                ErrorHandler.shared.handle(.unknown("Failed to monitor location: \(clError.localizedDescription)"), context: "Geofence Monitoring")
            default:
                ErrorHandler.shared.handle(clError, context: "Geofence Monitoring")
            }
        } else {
            ErrorHandler.shared.handle(error, context: "Geofence Monitoring")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Determine notification priority based on location and event
}
