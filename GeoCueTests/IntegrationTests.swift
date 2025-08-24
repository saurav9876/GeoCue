import XCTest
import CoreLocation
import UserNotifications
@testable import GeoCue

final class IntegrationTests: XCTestCase {
    
    var locationManager: LocationManager!
    var notificationManager: NotificationManager!
    
    override func setUpWithError() throws {
        locationManager = LocationManager()
        notificationManager = NotificationManager()
        
        // Wait for managers to initialize
        let expectation = XCTestExpectation(description: "Managers initialization")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    override func tearDownWithError() throws {
        locationManager = nil
        notificationManager = nil
    }
    
    // MARK: - Location and Notification Integration
    
    func testGeofenceCreationAndNotificationScheduling() throws {
        let expectation = XCTestExpectation(description: "Geofence and notification integration")
        
        let location = GeofenceLocation(
            id: UUID(),
            name: "Integration Test Location",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            notifyOnEntry: true,
            notifyOnExit: false,
            isEnabled: true,
            entryMessage: "Integration test message",
            exitMessage: ""
        )
        
        // Add geofence
        locationManager.addGeofence(location)
        
        // Verify geofence was added
        XCTAssertEqual(locationManager.geofenceLocations.count, 1)
        XCTAssertEqual(locationManager.geofenceLocations.first?.name, "Integration Test Location")
        
        // Simulate geofence entry (this would normally come from Core Location)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // In a real scenario, this would be triggered by Core Location delegate
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testLocationPermissionFlow() throws {
        // Test the complete permission request flow
        let initialStatus = locationManager.authorizationStatus
        XCTAssertNotNil(initialStatus)
        
        // Test status checking methods
        let canStartUpdates = locationManager.canStartLocationUpdates()
        let canAddGeofences = locationManager.canAddGeofences()
        
        // These should be consistent
        if locationManager.authorizationStatus == .authorizedAlways {
            XCTAssertTrue(canStartUpdates)
            XCTAssertTrue(canAddGeofences)
        } else if locationManager.authorizationStatus == .authorizedWhenInUse {
            XCTAssertTrue(canStartUpdates)
            XCTAssertFalse(canAddGeofences)
        } else {
            XCTAssertFalse(canStartUpdates)
            XCTAssertFalse(canAddGeofences)
        }
    }
    
    func testNotificationPermissionFlow() throws {
        let expectation = XCTestExpectation(description: "Notification permission flow")
        
        // Check initial authorization status
        let initialStatus = notificationManager.authorizationStatus
        XCTAssertNotNil(initialStatus)
        
        // Test notification settings check
        notificationManager.checkNotificationSettings()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Data Flow Integration
    
    func testGeofenceDataPersistenceFlow() throws {
        let location1 = GeofenceLocation(
            id: UUID(),
            name: "Persistent Location 1",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            notifyOnEntry: true,
            notifyOnExit: false,
            isEnabled: true,
            entryMessage: "Message 1",
            exitMessage: ""
        )
        
        let location2 = GeofenceLocation(
            id: UUID(),
            name: "Persistent Location 2",
            latitude: 37.7849,
            longitude: -122.4094,
            radius: 150,
            notifyOnEntry: false,
            notifyOnExit: true,
            isEnabled: false,
            entryMessage: "",
            exitMessage: "Message 2"
        )
        
        // Add locations
        locationManager.addGeofence(location1)
        locationManager.addGeofence(location2)
        
        XCTAssertEqual(locationManager.geofenceLocations.count, 2)
        
        // Test update
        var updatedLocation1 = location1
        updatedLocation1.name = "Updated Location 1"
        updatedLocation1.isEnabled = false
        
        locationManager.updateGeofence(updatedLocation1)
        
        let foundLocation = locationManager.geofenceLocations.first { $0.id == location1.id }
        XCTAssertNotNil(foundLocation)
        XCTAssertEqual(foundLocation?.name, "Updated Location 1")
        XCTAssertFalse(foundLocation?.isEnabled ?? true)
        
        // Test removal
        locationManager.removeGeofence(location2)
        XCTAssertEqual(locationManager.geofenceLocations.count, 1)
    }
    
    // MARK: - Error Handling Integration
    
    func testErrorHandlingIntegration() throws {
        let expectation = XCTestExpectation(description: "Error handling integration")
        
        let errorHandler = ErrorHandler.shared
        errorHandler.clearError()
        
        // Test error handling through location manager
        let clError = CLError(.denied)
        
        // This should trigger error handling
        locationManager.locationManager(locationManager.locationManager, didFailWithError: clError)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(errorHandler.isShowingError)
            XCTAssertEqual(errorHandler.currentError, .locationPermissionDenied)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        errorHandler.clearError()
    }
}

// MARK: - Performance Tests

final class PerformanceTests: XCTestCase {
    
    var locationManager: LocationManager!
    
    override func setUpWithError() throws {
        locationManager = LocationManager()
    }
    
    override func tearDownWithError() throws {
        locationManager = nil
    }
    
    func testGeofenceAdditionPerformance() throws {
        measure {
            for i in 0..<20 {
                let location = GeofenceLocation(
                    id: UUID(),
                    name: "Performance Location \(i)",
                    latitude: 37.7749 + Double(i) * 0.001,
                    longitude: -122.4194 + Double(i) * 0.001,
                    radius: 100,
                    notifyOnEntry: true,
                    notifyOnExit: false,
                    isEnabled: true,
                    entryMessage: "Performance test",
                    exitMessage: ""
                )
                
                locationManager.addGeofence(location)
            }
            
            // Clear for next iteration
            while !locationManager.geofenceLocations.isEmpty {
                locationManager.removeGeofence(locationManager.geofenceLocations.first!)
            }
        }
    }
    
    func testGeofenceUpdatePerformance() throws {
        // Add test locations first
        var testLocations: [GeofenceLocation] = []
        for i in 0..<10 {
            let location = GeofenceLocation(
                id: UUID(),
                name: "Update Test Location \(i)",
                latitude: 37.7749 + Double(i) * 0.001,
                longitude: -122.4194 + Double(i) * 0.001,
                radius: 100,
                notifyOnEntry: true,
                notifyOnExit: false,
                isEnabled: true,
                entryMessage: "Original message \(i)",
                exitMessage: ""
            )
            testLocations.append(location)
            locationManager.addGeofence(location)
        }
        
        measure {
            for (index, var location) in testLocations.enumerated() {
                location.name = "Updated Location \(index)"
                location.entryMessage = "Updated message \(index)"
                location.isEnabled = index % 2 == 0
                
                locationManager.updateGeofence(location)
            }
        }
    }
    
    func testLargeDatasetHandling() throws {
        // Test with maximum number of geofences
        let maxGeofences = 20
        
        measure {
            // Add maximum geofences
            for i in 0..<maxGeofences {
                let location = GeofenceLocation(
                    id: UUID(),
                    name: "Large Dataset Location \(i)",
                    latitude: 37.0 + Double(i) * 0.01,
                    longitude: -122.0 + Double(i) * 0.01,
                    radius: 100 + i * 10,
                    notifyOnEntry: i % 2 == 0,
                    notifyOnExit: i % 2 == 1,
                    isEnabled: i % 3 == 0,
                    entryMessage: "Entry message for location \(i)",
                    exitMessage: "Exit message for location \(i)"
                )
                
                locationManager.addGeofence(location)
            }
            
            // Perform operations on all geofences
            for (index, var location) in locationManager.geofenceLocations.enumerated() {
                location.isEnabled = !location.isEnabled
                locationManager.updateGeofence(location)
                
                if index % 5 == 0 {
                    locationManager.removeGeofence(location)
                }
            }
        }
    }
    
    func testLocationPermissionCheckPerformance() throws {
        measure {
            for _ in 0..<1000 {
                _ = locationManager.canStartLocationUpdates()
                _ = locationManager.canAddGeofences()
                _ = locationManager.getLocationServicesStatus()
                _ = locationManager.isLocationServicesEnabled()
            }
        }
    }
    
    func testErrorHandlingPerformance() throws {
        let errorHandler = ErrorHandler.shared
        
        measure {
            for i in 0..<100 {
                let error = AppError.validationError("Performance test error \(i)")
                errorHandler.handle(error, context: "Performance Test")
                errorHandler.clearError()
            }
        }
    }
}