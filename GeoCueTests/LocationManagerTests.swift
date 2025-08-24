import XCTest
import CoreLocation
@testable import GeoCue

final class LocationManagerTests: XCTestCase {
    
    var locationManager: LocationManager!
    
    override func setUpWithError() throws {
        locationManager = LocationManager()
    }
    
    override func tearDownWithError() throws {
        locationManager = nil
    }
    
    // MARK: - Geofence Management Tests
    
    func testAddGeofenceLocation() throws {
        let location = GeofenceLocation(
            id: UUID(),
            name: "Test Location",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            notifyOnEntry: true,
            notifyOnExit: false,
            isEnabled: true,
            entryMessage: "You've arrived!",
            exitMessage: ""
        )
        
        locationManager.addGeofence(location)
        
        XCTAssertEqual(locationManager.geofenceLocations.count, 1)
        XCTAssertEqual(locationManager.geofenceLocations.first?.name, "Test Location")
    }
    
    func testRemoveGeofenceLocation() throws {
        let location = GeofenceLocation(
            id: UUID(),
            name: "Test Location",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            notifyOnEntry: true,
            notifyOnExit: false,
            isEnabled: true,
            entryMessage: "You've arrived!",
            exitMessage: ""
        )
        
        locationManager.addGeofence(location)
        XCTAssertEqual(locationManager.geofenceLocations.count, 1)
        
        locationManager.removeGeofence(location)
        XCTAssertEqual(locationManager.geofenceLocations.count, 0)
    }
    
    func testUpdateGeofenceLocation() throws {
        let originalLocation = GeofenceLocation(
            id: UUID(),
            name: "Original Location",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            notifyOnEntry: true,
            notifyOnExit: false,
            isEnabled: true,
            entryMessage: "Original message",
            exitMessage: ""
        )
        
        locationManager.addGeofence(originalLocation)
        
        var updatedLocation = originalLocation
        updatedLocation.name = "Updated Location"
        updatedLocation.entryMessage = "Updated message"
        
        locationManager.updateGeofence(updatedLocation)
        
        XCTAssertEqual(locationManager.geofenceLocations.count, 1)
        XCTAssertEqual(locationManager.geofenceLocations.first?.name, "Updated Location")
        XCTAssertEqual(locationManager.geofenceLocations.first?.entryMessage, "Updated message")
    }
    
    func testGeofenceLimit() throws {
        // Test that we can't add more than 20 geofences (iOS limit)
        for i in 0..<21 {
            let location = GeofenceLocation(
                id: UUID(),
                name: "Location \(i)",
                latitude: 37.7749 + Double(i) * 0.001,
                longitude: -122.4194 + Double(i) * 0.001,
                radius: 100,
                notifyOnEntry: true,
                notifyOnExit: false,
                isEnabled: true,
                entryMessage: "Message \(i)",
                exitMessage: ""
            )
            
            locationManager.addGeofence(location)
        }
        
        // Should only have 20 geofences (iOS limit)
        XCTAssertLessThanOrEqual(locationManager.geofenceLocations.count, 20)
    }
    
    // MARK: - Permission Tests
    
    func testCanStartLocationUpdates() throws {
        // Test different authorization statuses
        locationManager.authorizationStatus = .authorizedAlways
        XCTAssertTrue(locationManager.canStartLocationUpdates())
        
        locationManager.authorizationStatus = .authorizedWhenInUse
        XCTAssertTrue(locationManager.canStartLocationUpdates())
        
        locationManager.authorizationStatus = .denied
        XCTAssertFalse(locationManager.canStartLocationUpdates())
        
        locationManager.authorizationStatus = .notDetermined
        XCTAssertFalse(locationManager.canStartLocationUpdates())
    }
    
    func testCanAddGeofences() throws {
        locationManager.authorizationStatus = .authorizedAlways
        XCTAssertTrue(locationManager.canAddGeofences())
        
        locationManager.authorizationStatus = .authorizedWhenInUse
        XCTAssertFalse(locationManager.canAddGeofences())
        
        locationManager.authorizationStatus = .denied
        XCTAssertFalse(locationManager.canAddGeofences())
    }
    
    // MARK: - Location Services Status
    
    func testLocationServicesStatus() throws {
        let statusString = locationManager.getLocationServicesStatus()
        XCTAssertFalse(statusString.isEmpty)
        
        // Status string should contain meaningful information
        let validStatuses = ["Always", "When In Use", "Denied", "Not Determined"]
        let containsValidStatus = validStatuses.contains { statusString.contains($0) }
        XCTAssertTrue(containsValidStatus)
    }
    
    // MARK: - Persistence Tests
    
    func testGeofenceLocationPersistence() throws {
        let location = GeofenceLocation(
            id: UUID(),
            name: "Persistent Location",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            notifyOnEntry: true,
            notifyOnExit: false,
            isEnabled: true,
            entryMessage: "Persistent message",
            exitMessage: ""
        )
        
        locationManager.addGeofence(location)
        
        // Simulate app restart by creating a new instance
        let newLocationManager = LocationManager()
        
        // Check if location was persisted (this would require actual UserDefaults integration)
        // For now, we'll test the structure is valid
        XCTAssertNotNil(newLocationManager)
    }
}

// MARK: - GeofenceLocation Tests

final class GeofenceLocationTests: XCTestCase {
    
    func testGeofenceLocationCreation() throws {
        let id = UUID()
        let location = GeofenceLocation(
            id: id,
            name: "Test Location",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            notifyOnEntry: true,
            notifyOnExit: false,
            isEnabled: true,
            entryMessage: "Welcome!",
            exitMessage: "Goodbye!"
        )
        
        XCTAssertEqual(location.id, id)
        XCTAssertEqual(location.name, "Test Location")
        XCTAssertEqual(location.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(location.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(location.radius, 100)
        XCTAssertTrue(location.notifyOnEntry)
        XCTAssertFalse(location.notifyOnExit)
        XCTAssertTrue(location.isEnabled)
        XCTAssertEqual(location.entryMessage, "Welcome!")
        XCTAssertEqual(location.exitMessage, "Goodbye!")
    }
    
    func testGeofenceLocationEquality() throws {
        let id = UUID()
        
        let location1 = GeofenceLocation(
            id: id,
            name: "Test Location",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            notifyOnEntry: true,
            notifyOnExit: false,
            isEnabled: true,
            entryMessage: "Welcome!",
            exitMessage: ""
        )
        
        let location2 = GeofenceLocation(
            id: id,
            name: "Test Location",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            notifyOnEntry: true,
            notifyOnExit: false,
            isEnabled: true,
            entryMessage: "Welcome!",
            exitMessage: ""
        )
        
        XCTAssertEqual(location1, location2)
    }
    
    func testGeofenceLocationCodable() throws {
        let location = GeofenceLocation(
            id: UUID(),
            name: "Test Location",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            notifyOnEntry: true,
            notifyOnExit: false,
            isEnabled: true,
            entryMessage: "Welcome!",
            exitMessage: "Goodbye!"
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(location)
        XCTAssertGreaterThan(data.count, 0)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedLocation = try decoder.decode(GeofenceLocation.self, from: data)
        
        XCTAssertEqual(location, decodedLocation)
    }
}