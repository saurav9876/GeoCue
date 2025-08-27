import Foundation
import CoreLocation
import SwiftUI
import os.log

@available(iOS 17.0, *)
@MainActor
class ModernLocationManager: NSObject, ObservableObject {
    private var locationManager = CLLocationManager()
    private var monitor: CLMonitor?
    private let monitorName = "GeoCueMonitor"
    private let notificationManager = NotificationManager()
    private let notificationController = GeofenceNotificationController()
    private let logger = Logger.shared
    
    // Thread-safe queue for geofence operations
    private let geofenceQueue = DispatchQueue(label: "com.geocue.geofence", qos: .userInitiated)
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var geofenceLocations: [GeofenceLocation] = []
    @Published var showingLocationPermissionAlert = false
    @Published var isRequestingPermission = false
    @Published var locationServicesEnabled: Bool = false
    @Published var monitoringStatus: String = "Not Initialized"
    @Published var activeMonitoringCount: Int = 0
    
    override init() {
        super.init()
        setupLocationManager()
        setupNotificationManager()
        Task {
            await initializeMonitoring()
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        logger.info("Modern LocationManager initialized", category: .location)
        
        loadGeofenceLocations()
        updateLocationServicesStatus()
    }
    
    private func setupNotificationManager() {
        let ringtoneService = ServiceLocator.ringtoneService
        notificationManager.setRingtoneService(ringtoneService)
        logger.info("NotificationManager configured", category: .location)
    }
    
    private func initializeMonitoring() async {
        do {
            monitor = await CLMonitor(monitorName)
            await updateMonitoringStatus()
            await startMonitoringEvents()
            logger.info("CLMonitor initialized successfully", category: .location)
        } catch {
            logger.error("Failed to initialize CLMonitor: \(error.localizedDescription)", category: .location)
            monitoringStatus = "Failed to initialize: \(error.localizedDescription)"
        }
    }
    
    private func startMonitoringEvents() async {
        guard let monitor = monitor else { return }
        
        Task {
            do {
                for try await event in await monitor.events {
                    Task { @MainActor in
                        await self.handleMonitorEvent(event)
                    }
                }
            } catch {
                logger.error("Error monitoring events: \(error.localizedDescription)", category: .location)
            }
        }
    }
    
    // MARK: - Event Handling
    
    private func handleMonitorEvent(_ event: CLMonitor.Event) async {
        logger.info("Monitor event: \(event.identifier) - \(event.state.rawValue)", category: .location)
        
        guard let location = findGeofenceLocation(by: event.identifier) else {
            logger.warning("No geofence location found for identifier: \(event.identifier)", category: .location)
            return
        }
        
        switch event.state {
        case .satisfied:
            await handleGeofenceEntry(location: location)
        case .unsatisfied:
            await handleGeofenceExit(location: location)
        case .unmonitored:
            logger.warning("Geofence became unmonitored: \(event.identifier)", category: .location)
            await handleUnmonitored(location: location)
        case .unknown:
            logger.warning("Unknown monitor event state: \(event.state.rawValue)", category: .location)
        @unknown default:
            logger.warning("Unknown monitor event state: \(event.state.rawValue)", category: .location)
        }
    }
    
    private func handleGeofenceEntry(location: GeofenceLocation) async {
        logger.info("User entered region: \(location.name)", category: .location)
        
        guard location.isEnabled, location.notifyOnEntry else { return }
        
        if notificationController.shouldNotify(for: location, event: .entry) {
            if DoNotDisturbManager.shared.shouldSuppressNotification() {
                logger.info("Suppressing entry notification due to Do Not Disturb: \(location.name)", category: .location)
                return
            }
            
            let message = location.entryMessage.isEmpty ? 
                "You've arrived at \(location.name)" : location.entryMessage
            
            let priority = NotificationEscalator.shared.preferences.defaultStyle
            
            NotificationEscalator.shared.sendNotification(
                title: "GeoCue Reminder",
                body: message,
                identifier: "entry-\(location.id.uuidString)",
                priority: priority
            )
            
            notificationController.recordNotificationSent(for: location.id)
        }
    }
    
    private func handleGeofenceExit(location: GeofenceLocation) async {
        logger.info("User exited region: \(location.name)", category: .location)
        
        guard location.isEnabled, location.notifyOnExit else { return }
        
        if notificationController.shouldNotify(for: location, event: .exit) {
            if DoNotDisturbManager.shared.shouldSuppressNotification() {
                logger.info("Suppressing exit notification due to Do Not Disturb: \(location.name)", category: .location)
                return
            }
            
            let message = location.exitMessage.isEmpty ? 
                "You've left \(location.name)" : location.exitMessage
            
            let priority = NotificationEscalator.shared.preferences.defaultStyle
            
            NotificationEscalator.shared.sendNotification(
                title: "GeoCue Reminder",
                body: message,
                identifier: "exit-\(location.id.uuidString)",
                priority: priority
            )
            
            notificationController.recordNotificationSent(for: location.id)
        }
    }
    
    private func handleUnmonitored(location: GeofenceLocation) async {
        logger.warning("Geofence became unmonitored, attempting to restart: \(location.name)", category: .location)
        
        // Attempt to restart monitoring
        if activeMonitoringCount < 20 {
            await addGeofenceToMonitor(location)
        } else {
            logger.error("Cannot restart monitoring: 20 geofence limit reached", category: .location)
        }
    }
    
    // MARK: - Geofence Management with Limits
    
    func addGeofence(_ location: GeofenceLocation) async {
        // Thread-safe addition
        await MainActor.run {
            geofenceLocations.append(location)
        }
        
        saveGeofenceLocations()
        await addGeofenceToMonitor(location)
    }
    
    private func addGeofenceToMonitor(_ location: GeofenceLocation) async {
        guard let monitor = monitor else {
            logger.error("Monitor not initialized", category: .location)
            return
        }
        
        // Check iOS 20 geofence limit
        guard activeMonitoringCount < 20 else {
            logger.error("Cannot add geofence: 20 region limit reached", category: .location)
            await handleGeofenceLimitExceeded(location)
            return
        }
        
        guard authorizationStatus == .authorizedAlways else {
            logger.warning("Cannot add geofence without Always authorization", category: .location)
            return
        }
        
        do {
            let condition = CLMonitor.CircularGeographicCondition(
                center: CLLocationCoordinate2D(
                    latitude: location.latitude, 
                    longitude: location.longitude
                ),
                radius: location.radius
            )
            
            await monitor.add(condition, identifier: location.id.uuidString)
            await updateMonitoringStatus()
            logger.info("Added geofence: \(location.name)", category: .location)
            
        } catch {
            logger.error("Failed to add geofence \(location.name): \(error.localizedDescription)", category: .location)
        }
    }
    
    private func handleGeofenceLimitExceeded(_ newLocation: GeofenceLocation) async {
        logger.warning("Geofence limit exceeded, managing priorities", category: .location)
        
        // Find least important geofence to remove (disabled ones first, then oldest)
        let locations = geofenceLocations
        
        if let disabledLocation = locations.first(where: { !$0.isEnabled }) {
            await removeGeofence(disabledLocation)
            await addGeofenceToMonitor(newLocation)
            logger.info("Replaced disabled geofence \(disabledLocation.name) with \(newLocation.name)", category: .location)
        } else {
            // Could implement priority system here - for now, just log the issue
            logger.error("All 20 geofences are active - consider implementing priority system", category: .location)
            
            // Show user-facing error
            await MainActor.run {
                showingLocationPermissionAlert = true
            }
        }
    }
    
    func removeGeofence(_ location: GeofenceLocation) async {
        // Thread-safe removal
        await MainActor.run {
            geofenceLocations.removeAll { $0.id == location.id }
        }
        
        saveGeofenceLocations()
        
        guard let monitor = monitor else { return }
        
        do {
            await monitor.remove(location.id.uuidString)
            await updateMonitoringStatus()
            logger.info("Removed geofence: \(location.name)", category: .location)
        } catch {
            logger.error("Failed to remove geofence \(location.name): \(error.localizedDescription)", category: .location)
        }
    }
    
    func updateGeofence(_ location: GeofenceLocation) async {
        // Thread-safe update
        await MainActor.run {
            if let index = geofenceLocations.firstIndex(where: { $0.id == location.id }) {
                geofenceLocations[index] = location
            }
        }
        
        saveGeofenceLocations()
        
        // Remove and re-add to update the condition
        guard let monitor = monitor else { return }
        
        do {
            await monitor.remove(location.id.uuidString)
            
            if location.isEnabled {
                await addGeofenceToMonitor(location)
            }
        } catch {
            logger.error("Failed to update geofence \(location.name): \(error.localizedDescription)", category: .location)
        }
    }
    
    // MARK: - Monitoring Status and Validation
    
    private func updateMonitoringStatus() async {
        guard let monitor = monitor else {
            await MainActor.run {
                monitoringStatus = "Monitor not initialized"
                activeMonitoringCount = 0
            }
            return
        }
        
        let identifiers = await monitor.identifiers
        let count = identifiers.count
        
        await MainActor.run {
            activeMonitoringCount = count
            monitoringStatus = "Monitoring \(count)/20 geofences"
        }
        
        // Validate that all expected geofences are being monitored
        await validateMonitoring(activeIdentifiers: Set(identifiers))
    }
    
    private func validateMonitoring(activeIdentifiers: Set<String>) async {
        let expectedIdentifiers = Set(geofenceLocations.filter { $0.isEnabled }.map { $0.id.uuidString })
        let missingIdentifiers = expectedIdentifiers.subtracting(activeIdentifiers)
        
        if !missingIdentifiers.isEmpty {
            logger.warning("Missing \(missingIdentifiers.count) geofences from monitoring", category: .location)
            
            // Attempt to restore missing geofences
            for identifier in missingIdentifiers {
                if let location = findGeofenceLocation(by: identifier) {
                    await addGeofenceToMonitor(location)
                }
            }
        }
    }
    
    func performHealthCheck() async -> [String] {
        var issues: [String] = []
        
        // Check authorization
        if authorizationStatus != .authorizedAlways {
            issues.append("Location permission not set to 'Always'")
        }
        
        // Check location services
        if !locationServicesEnabled {
            issues.append("Location services disabled")
        }
        
        // Check monitor status
        if monitor == nil {
            issues.append("CLMonitor not initialized")
        }
        
        // Check geofence count vs monitoring count
        let enabledGeofences = geofenceLocations.filter { $0.isEnabled }.count
        if enabledGeofences != activeMonitoringCount {
            issues.append("Geofence count mismatch: \(enabledGeofences) expected, \(activeMonitoringCount) monitoring")
        }
        
        return issues
    }
    
    // MARK: - Permission Management
    
    func requestLocationPermission() {
        guard !isRequestingPermission else { return }
        
        isRequestingPermission = true
        
        // Timeout protection
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            if self?.isRequestingPermission == true {
                self?.logger.warning("Permission request timeout", category: .location)
                self?.isRequestingPermission = false
                self?.showingLocationPermissionAlert = true
            }
        }
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            isRequestingPermission = false
            showingLocationPermissionAlert = true
        case .authorizedAlways:
            isRequestingPermission = false
        @unknown default:
            isRequestingPermission = false
        }
    }
    
    // MARK: - Utility Methods
    
    private func findGeofenceLocation(by identifier: String) -> GeofenceLocation? {
        return geofenceLocations.first { $0.id.uuidString == identifier }
    }
    
    func canStartLocationUpdates() -> Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    func canAddGeofences() -> Bool {
        return authorizationStatus == .authorizedAlways
    }
    
    func getLocationServicesStatus() -> String {
        if !locationServicesEnabled {
            return "Location Services Disabled"
        }
        
        switch authorizationStatus {
        case .notDetermined: return "Permission Not Determined"
        case .denied: return "Permission Denied"
        case .restricted: return "Permission Restricted"
        case .authorizedWhenInUse: return "When In Use Only"
        case .authorizedAlways: return "Always Allowed"
        @unknown default: return "Unknown Status"
        }
    }
    
    // MARK: - Persistence
    
    private func saveGeofenceLocations() {
        Task { @MainActor in
            if let encoded = try? JSONEncoder().encode(geofenceLocations) {
                UserDefaults.standard.set(encoded, forKey: "geofenceLocations")
            }
        }
    }
    
    private func loadGeofenceLocations() {
        if let data = UserDefaults.standard.data(forKey: "geofenceLocations"),
           let decoded = try? JSONDecoder().decode([GeofenceLocation].self, from: data) {
            geofenceLocations = decoded
        }
    }
    
    private func updateLocationServicesStatus() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let isEnabled = CLLocationManager.locationServicesEnabled()
            DispatchQueue.main.async {
                self?.locationServicesEnabled = isEnabled
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

// MARK: - CLLocationManagerDelegate

@available(iOS 17.0, *)
extension ModernLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let oldStatus = authorizationStatus
            authorizationStatus = manager.authorizationStatus
            isRequestingPermission = false
            
            logger.info("Authorization changed from \(oldStatus.rawValue) to \(authorizationStatus.rawValue)", category: .location)
            
            updateLocationServicesStatus()
            
            switch authorizationStatus {
            case .authorizedAlways:
                logger.info("Got Always authorization - setting up geofences", category: .location)
                await setupExistingGeofences()
            case .denied, .restricted:
                logger.warning("Authorization denied/restricted - stopping monitoring", category: .location)
                await stopAllMonitoring()
            case .authorizedWhenInUse:
                logger.warning("Got When In Use authorization - need Always for geofencing", category: .location)
            case .notDetermined:
                logger.debug("Authorization not determined", category: .location)
            @unknown default:
                logger.warning("Unknown authorization status", category: .location)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              location.horizontalAccuracy < 100 else { return }
        
        Task { @MainActor in
            currentLocation = location
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.logger.error("Location manager failed: \(error.localizedDescription)", category: .location)
        }
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                ErrorHandler.shared.handle(.locationPermissionDenied, context: "Modern Location Manager")
            case .locationUnknown:
                ErrorHandler.shared.handle(.invalidLocation, context: "Modern Location Manager")
            case .network:
                ErrorHandler.shared.handle(.networkError(clError.localizedDescription), context: "Modern Location Manager")
            default:
                ErrorHandler.shared.handle(clError, context: "Modern Location Manager")
            }
        }
    }
    
    private func setupExistingGeofences() async {
        for location in geofenceLocations.filter({ $0.isEnabled }) {
            await addGeofenceToMonitor(location)
        }
    }
    
    private func stopAllMonitoring() async {
        guard let monitor = monitor else { return }
        
        let identifiers = await monitor.identifiers
        for identifier in identifiers {
            do {
                await monitor.remove(identifier)
            } catch {
                logger.error("Failed to remove monitoring for \(identifier): \(error.localizedDescription)", category: .location)
            }
        }
        
        await updateMonitoringStatus()
    }
}

