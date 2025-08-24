import XCTest
import CoreLocation
import Combine
@testable import GeoCue

final class ErrorHandlerTests: XCTestCase {
    
    var errorHandler: ErrorHandler!
    
    override func setUpWithError() throws {
        errorHandler = ErrorHandler.shared
        errorHandler.clearError() // Clear any existing errors
    }
    
    override func tearDownWithError() throws {
        errorHandler.clearError()
        errorHandler = nil
    }
    
    // MARK: - App Error Tests
    
    func testAppErrorDescriptions() throws {
        let locationPermissionError = AppError.locationPermissionDenied
        XCTAssertNotNil(locationPermissionError.errorDescription)
        XCTAssertTrue(locationPermissionError.errorDescription!.contains("Location permission"))
        
        let notificationError = AppError.notificationPermissionDenied
        XCTAssertNotNil(notificationError.errorDescription)
        XCTAssertTrue(notificationError.errorDescription!.contains("Notification permission"))
        
        let geofenceError = AppError.geofenceLimit
        XCTAssertNotNil(geofenceError.errorDescription)
        XCTAssertTrue(geofenceError.errorDescription!.contains("maximum number"))
        
        let networkError = AppError.networkError("Connection failed")
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertTrue(networkError.errorDescription!.contains("Connection failed"))
    }
    
    func testAppErrorRecoverySuggestions() throws {
        let locationError = AppError.locationPermissionDenied
        XCTAssertNotNil(locationError.recoverySuggestion)
        XCTAssertTrue(locationError.recoverySuggestion!.contains("Settings"))
        
        let notificationError = AppError.notificationPermissionDenied
        XCTAssertNotNil(notificationError.recoverySuggestion)
        XCTAssertTrue(notificationError.recoverySuggestion!.contains("Settings"))
        
        let geofenceError = AppError.geofenceLimit
        XCTAssertNotNil(geofenceError.recoverySuggestion)
        XCTAssertTrue(geofenceError.recoverySuggestion!.contains("Delete"))
    }
    
    func testAppErrorEquality() throws {
        let error1 = AppError.locationPermissionDenied
        let error2 = AppError.locationPermissionDenied
        let error3 = AppError.notificationPermissionDenied
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        
        let networkError1 = AppError.networkError("Same message")
        let networkError2 = AppError.networkError("Same message")
        let networkError3 = AppError.networkError("Different message")
        
        XCTAssertEqual(networkError1, networkError2)
        XCTAssertNotEqual(networkError1, networkError3)
    }
    
    // MARK: - Error Handler Tests
    
    func testHandleAppError() throws {
        let expectation = XCTestExpectation(description: "Error handling")
        
        // Set up observation
        errorHandler.$isShowingError
            .sink { isShowing in
                if isShowing {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        errorHandler.handle(.locationPermissionDenied, context: "Test")
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(errorHandler.isShowingError)
        XCTAssertEqual(errorHandler.currentError, .locationPermissionDenied)
    }
    
    func testClearError() throws {
        errorHandler.handle(.locationPermissionDenied, context: "Test")
        
        XCTAssertTrue(errorHandler.isShowingError)
        XCTAssertNotNil(errorHandler.currentError)
        
        errorHandler.clearError()
        
        XCTAssertFalse(errorHandler.isShowingError)
        XCTAssertNil(errorHandler.currentError)
    }
    
    func testMapCLErrorToAppError() throws {
        let clDeniedError = CLError(.denied)
        errorHandler.handle(clDeniedError, context: "Test")
        
        XCTAssertEqual(errorHandler.currentError, .locationPermissionDenied)
        
        errorHandler.clearError()
        
        let clLocationUnknownError = CLError(.locationUnknown)
        errorHandler.handle(clLocationUnknownError, context: "Test")
        
        XCTAssertEqual(errorHandler.currentError, .invalidLocation)
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Privacy Manager Tests

final class PrivacyManagerTests: XCTestCase {
    
    var privacyManager: PrivacyManager!
    
    override func setUpWithError() throws {
        privacyManager = PrivacyManager.shared
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        UserDefaults.standard.removeObject(forKey: "privacy_analytics_consent")
        UserDefaults.standard.removeObject(forKey: "privacy_crash_reporting_consent")
        UserDefaults.standard.removeObject(forKey: "privacy_policy_accepted")
        privacyManager = nil
    }
    
    func testAnalyticsConsent() throws {
        XCTAssertFalse(privacyManager.hasConsentForAnalytics) // Default should be false
        
        privacyManager.hasConsentForAnalytics = true
        XCTAssertTrue(privacyManager.hasConsentForAnalytics)
        
        privacyManager.hasConsentForAnalytics = false
        XCTAssertFalse(privacyManager.hasConsentForAnalytics)
    }
    
    func testCrashReportingConsent() throws {
        XCTAssertFalse(privacyManager.hasConsentForCrashReporting) // Default should be false
        
        privacyManager.hasConsentForCrashReporting = true
        XCTAssertTrue(privacyManager.hasConsentForCrashReporting)
        
        privacyManager.hasConsentForCrashReporting = false
        XCTAssertFalse(privacyManager.hasConsentForCrashReporting)
    }
    
    func testLocationDataValidation() throws {
        let isValid = privacyManager.validateLocationDataUsage()
        XCTAssertTrue(isValid)
    }
    
    func testLocationDataAnonymization() throws {
        let originalLocation = CLLocationCoordinate2D(latitude: 37.7749295, longitude: -122.4194155)
        let anonymizedLocation = privacyManager.anonymizeLocationData(originalLocation)
        
        // Should be less precise than original
        XCTAssertNotEqual(originalLocation.latitude, anonymizedLocation.latitude)
        XCTAssertNotEqual(originalLocation.longitude, anonymizedLocation.longitude)
        
        // Should be rounded to ~1km precision
        let expectedLat = (originalLocation.latitude / 0.01).rounded() * 0.01
        let expectedLng = (originalLocation.longitude / 0.01).rounded() * 0.01
        
        XCTAssertEqual(anonymizedLocation.latitude, expectedLat, accuracy: 0.0001)
        XCTAssertEqual(anonymizedLocation.longitude, expectedLng, accuracy: 0.0001)
    }
    
    func testDataRetentionPolicy() throws {
        let policy = privacyManager.getDataRetentionPolicy()
        
        XCTAssertNotNil(policy["geofence_locations"])
        XCTAssertNotNil(policy["notification_history"])
        XCTAssertNotNil(policy["location_history"])
        XCTAssertNotNil(policy["logs"])
        
        // Check that we're not storing location history
        XCTAssertTrue(policy["location_history"] as? String == "Not stored - current location only")
    }
    
    func testDataExport() throws {
        privacyManager.hasConsentForAnalytics = true
        privacyManager.hasConsentForCrashReporting = false
        
        let exportData = privacyManager.requestDataExport()
        
        XCTAssertNotNil(exportData["export_date"])
        XCTAssertNotNil(exportData["app_version"])
        XCTAssertEqual(exportData["privacy_analytics_consent"] as? Bool, true)
        XCTAssertEqual(exportData["privacy_crash_reporting_consent"] as? Bool, false)
    }
    
    func testPrivacyPolicyAcceptance() throws {
        XCTAssertFalse(privacyManager.hasAcceptedPrivacyPolicy)
        XCTAssertNil(privacyManager.privacyPolicyAcceptedDate)
        
        privacyManager.hasAcceptedPrivacyPolicy = true
        
        XCTAssertTrue(privacyManager.hasAcceptedPrivacyPolicy)
        XCTAssertNotNil(privacyManager.privacyPolicyAcceptedDate)
    }
    
    func testProcessingBasis() throws {
        let basis = privacyManager.getProcessingBasis()
        
        XCTAssertNotNil(basis["location_data"])
        XCTAssertNotNil(basis["notification_data"])
        XCTAssertNotNil(basis["usage_analytics"])
        XCTAssertNotNil(basis["crash_reports"])
        
        // Check that location data is based on legitimate interest
        XCTAssertTrue(basis["location_data"]!.contains("Legitimate interest"))
        // Check that notifications are based on consent
        XCTAssertTrue(basis["notification_data"]!.contains("Consent"))
    }
}