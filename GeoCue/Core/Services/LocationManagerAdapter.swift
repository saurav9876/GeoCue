import Foundation
import CoreLocation
import SwiftUI
import Combine

// Protocol to abstract location management functionality
@MainActor
protocol LocationManagerProtocol: ObservableObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var currentLocation: CLLocation? { get }
    var geofenceLocations: [GeofenceLocation] { get }
    var showingLocationPermissionAlert: Bool { get }
    var isRequestingPermission: Bool { get }
    var locationServicesEnabled: Bool { get }
    
    func requestLocationPermission()
    func canStartLocationUpdates() -> Bool
    func canAddGeofences() -> Bool
    func getLocationServicesStatus() -> String
    func getNotificationStats(for location: GeofenceLocation) -> (dailyCount: Int, totalCount: Int, lastNotification: Date?)
    func resetNotificationState(for location: GeofenceLocation)
    func getNotificationDebugInfo() -> String
}

// Extend both location managers to conform to the protocol
extension LocationManager: LocationManagerProtocol {}

@available(iOS 17.0, *)
extension ModernLocationManager: LocationManagerProtocol {}

// Factory class to create appropriate location manager based on iOS version
@MainActor
class LocationManagerFactory {
    static func createLocationManager() -> any LocationManagerProtocol {
        if #available(iOS 17.0, *) {
            Logger.shared.info("Creating ModernLocationManager for iOS 17+", category: .location)
            return ModernLocationManager()
        } else {
            Logger.shared.info("Creating legacy LocationManager for iOS < 17", category: .location)
            return LocationManager()
        }
    }
}

// Adapter to provide async methods for legacy LocationManager
extension LocationManager {
    func addGeofence(_ location: GeofenceLocation) async {
        // Legacy implementation - run on main thread
        await MainActor.run {
            self.addGeofence(location)
        }
    }
    
    func removeGeofence(_ location: GeofenceLocation) async {
        await MainActor.run {
            self.removeGeofence(location)
        }
    }
    
    func updateGeofence(_ location: GeofenceLocation) async {
        await MainActor.run {
            self.updateGeofence(location)
        }
    }
    
    func performHealthCheck() async -> [String] {
        var issues: [String] = []
        
        if authorizationStatus != .authorizedAlways {
            issues.append("Location permission not set to 'Always' (Legacy)")
        }
        
        if !locationServicesEnabled {
            issues.append("Location services disabled (Legacy)")
        }
        
        // Legacy doesn't have monitoring count validation
        issues.append("Using legacy geofencing API - consider upgrading to iOS 17+")
        
        return issues
    }
}

// Type-erased wrapper for the location manager
@MainActor
class AnyLocationManager: ObservableObject {
    private var legacyManager: LocationManager?
    private var modernManager: ModernLocationManager?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var geofenceLocations: [GeofenceLocation] = []
    @Published var showingLocationPermissionAlert = false
    @Published var isRequestingPermission = false
    @Published var locationServicesEnabled: Bool = false
    
    init() {
        setupLocationManager()
        bindToManager()
    }
    
    private func setupLocationManager() {
        if #available(iOS 17.0, *) {
            modernManager = ModernLocationManager()
            Logger.shared.info("Using ModernLocationManager for iOS 17+", category: .location)
        } else {
            legacyManager = LocationManager()
            Logger.shared.info("Using legacy LocationManager for iOS < 17", category: .location)
        }
    }
    
    private func bindToManager() {
        if #available(iOS 17.0, *), let modern = modernManager {
            // Bind to modern manager
            modern.$authorizationStatus
                .assign(to: &$authorizationStatus)
            modern.$currentLocation
                .assign(to: &$currentLocation)
            modern.$geofenceLocations
                .assign(to: &$geofenceLocations)
            modern.$showingLocationPermissionAlert
                .assign(to: &$showingLocationPermissionAlert)
            modern.$isRequestingPermission
                .assign(to: &$isRequestingPermission)
            modern.$locationServicesEnabled
                .assign(to: &$locationServicesEnabled)
        } else if let legacy = legacyManager {
            // Bind to legacy manager
            legacy.$authorizationStatus
                .assign(to: &$authorizationStatus)
            legacy.$currentLocation
                .assign(to: &$currentLocation)
            legacy.$geofenceLocations
                .assign(to: &$geofenceLocations)
            legacy.$showingLocationPermissionAlert
                .assign(to: &$showingLocationPermissionAlert)
            legacy.$isRequestingPermission
                .assign(to: &$isRequestingPermission)
            legacy.$locationServicesEnabled
                .assign(to: &$locationServicesEnabled)
        }
    }
    
    // Forward all calls to the underlying manager
    func requestLocationPermission() {
        if #available(iOS 17.0, *), let modern = modernManager {
            modern.requestLocationPermission()
        } else if let legacy = legacyManager {
            legacy.requestLocationPermission()
        }
    }
    
    func canStartLocationUpdates() -> Bool {
        if #available(iOS 17.0, *), let modern = modernManager {
            return modern.canStartLocationUpdates()
        } else if let legacy = legacyManager {
            return legacy.canStartLocationUpdates()
        }
        return false
    }
    
    func canAddGeofences() -> Bool {
        if #available(iOS 17.0, *), let modern = modernManager {
            return modern.canAddGeofences()
        } else if let legacy = legacyManager {
            return legacy.canAddGeofences()
        }
        return false
    }
    
    func getLocationServicesStatus() -> String {
        if #available(iOS 17.0, *), let modern = modernManager {
            return modern.getLocationServicesStatus()
        } else if let legacy = legacyManager {
            return legacy.getLocationServicesStatus()
        }
        return "Unknown"
    }
    
    func addGeofence(_ location: GeofenceLocation) async {
        if #available(iOS 17.0, *), let modern = modernManager {
            await modern.addGeofence(location)
        } else if let legacy = legacyManager {
            await legacy.addGeofence(location)
        }
    }
    
    func removeGeofence(_ location: GeofenceLocation) async {
        if #available(iOS 17.0, *), let modern = modernManager {
            await modern.removeGeofence(location)
        } else if let legacy = legacyManager {
            await legacy.removeGeofence(location)
        }
    }
    
    func updateGeofence(_ location: GeofenceLocation) async {
        if #available(iOS 17.0, *), let modern = modernManager {
            await modern.updateGeofence(location)
        } else if let legacy = legacyManager {
            await legacy.updateGeofence(location)
        }
    }
    
    func performHealthCheck() async -> [String] {
        if #available(iOS 17.0, *), let modern = modernManager {
            return await modern.performHealthCheck()
        } else if let legacy = legacyManager {
            return await legacy.performHealthCheck()
        }
        return ["Unknown location manager type"]
    }
    
    func getNotificationStats(for location: GeofenceLocation) -> (dailyCount: Int, totalCount: Int, lastNotification: Date?) {
        if #available(iOS 17.0, *), let modern = modernManager {
            return modern.getNotificationStats(for: location)
        } else if let legacy = legacyManager {
            return legacy.getNotificationStats(for: location)
        }
        return (0, 0, nil)
    }
    
    func resetNotificationState(for location: GeofenceLocation) {
        if #available(iOS 17.0, *), let modern = modernManager {
            modern.resetNotificationState(for: location)
        } else if let legacy = legacyManager {
            legacy.resetNotificationState(for: location)
        }
    }
    
    func getNotificationDebugInfo() -> String {
        if #available(iOS 17.0, *), let modern = modernManager {
            return modern.getNotificationDebugInfo()
        } else if let legacy = legacyManager {
            return legacy.getNotificationDebugInfo()
        }
        return "No location manager available"
    }
    
    // Expose additional properties for ModernLocationManager if available
    var monitoringStatus: String {
        if #available(iOS 17.0, *), let modern = modernManager {
            return modern.monitoringStatus
        }
        return "Legacy Manager"
    }
    
    var activeMonitoringCount: Int {
        if #available(iOS 17.0, *), let modern = modernManager {
            return modern.activeMonitoringCount
        }
        return geofenceLocations.filter { $0.isEnabled }.count
    }
}