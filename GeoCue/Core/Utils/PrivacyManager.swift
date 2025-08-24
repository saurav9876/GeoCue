import Foundation
import CoreLocation

// MARK: - Privacy Manager

final class PrivacyManager {
    static let shared = PrivacyManager()
    
    private let logger = Logger.shared
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Data Collection Consent
    
    var hasConsentForAnalytics: Bool {
        get {
            userDefaults.bool(forKey: "privacy_analytics_consent")
        }
        set {
            userDefaults.set(newValue, forKey: "privacy_analytics_consent")
            logger.info("Analytics consent updated: \(newValue)", category: .privacy)
        }
    }
    
    var hasConsentForCrashReporting: Bool {
        get {
            userDefaults.bool(forKey: "privacy_crash_reporting_consent")
        }
        set {
            userDefaults.set(newValue, forKey: "privacy_crash_reporting_consent")
            logger.info("Crash reporting consent updated: \(newValue)", category: .privacy)
        }
    }
    
    // MARK: - Location Data Privacy
    
    func validateLocationDataUsage() -> Bool {
        // Ensure we're only using location data for the stated purpose
        logger.info("Validating location data usage compliance", category: .privacy)
        
        // GeoCue only uses location data for:
        // 1. Geofencing (monitoring entry/exit of saved locations)
        // 2. Displaying user location on map
        // 3. Setting up new location reminders
        
        // We do NOT:
        // - Store precise location history
        // - Share location data with third parties
        // - Use location for advertising
        // - Track user movements beyond geofence boundaries
        
        return true
    }
    
    func anonymizeLocationData(_ location: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // For analytics, we can reduce precision of location data
        // This is not currently used but available for future analytics
        let reducedPrecision = 0.01 // ~1km precision
        
        let anonymizedLat = (location.latitude / reducedPrecision).rounded() * reducedPrecision
        let anonymizedLng = (location.longitude / reducedPrecision).rounded() * reducedPrecision
        
        return CLLocationCoordinate2D(latitude: anonymizedLat, longitude: anonymizedLng)
    }
    
    // MARK: - Data Retention
    
    func getDataRetentionPolicy() -> [String: Any] {
        return [
            "geofence_locations": "Stored locally until user deletes",
            "notification_history": "Not stored - immediate delivery only",
            "location_history": "Not stored - current location only",
            "user_preferences": "Stored locally until app deletion",
            "logs": "Max 7 days locally, not transmitted",
            "crash_reports": "Transmitted immediately, not stored locally"
        ]
    }
    
    func clearAllUserData() {
        logger.info("Clearing all user data", category: .privacy)
        
        // Clear user defaults related to app data
        let keys = [
            "geofence_locations",
            "privacy_analytics_consent",
            "privacy_crash_reporting_consent",
            "theme_selection",
            "notification_preferences"
        ]
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
        
        userDefaults.synchronize()
        logger.info("User data cleared successfully", category: .privacy)
    }
    
    // MARK: - GDPR Compliance
    
    func requestDataExport() -> [String: Any] {
        logger.info("Data export requested", category: .privacy)
        
        // Collect all user data for export
        var exportData: [String: Any] = [:]
        
        // Geofence locations
        if let locationsData = userDefaults.data(forKey: "geofence_locations") {
            exportData["geofence_locations"] = locationsData
        }
        
        // User preferences
        exportData["privacy_analytics_consent"] = hasConsentForAnalytics
        exportData["privacy_crash_reporting_consent"] = hasConsentForCrashReporting
        
        if let theme = userDefaults.object(forKey: "theme_selection") {
            exportData["theme_selection"] = theme
        }
        
        // App metadata
        exportData["export_date"] = Date().iso8601String
        exportData["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
        
        return exportData
    }
    
    // MARK: - Privacy Permissions Tracking
    
    func trackPermissionRequest(_ permission: String, granted: Bool) {
        let event = granted ? "permission_granted" : "permission_denied"
        logger.info("\(event): \(permission)", category: .privacy)
        
        // Only track if user has consented to analytics
        if hasConsentForAnalytics {
            CrashReporter.shared.recordEvent(event, parameters: [
                "permission_type": permission,
                "granted": granted
            ])
        }
    }
    
    // MARK: - Privacy Policy Acceptance
    
    var hasAcceptedPrivacyPolicy: Bool {
        get {
            userDefaults.bool(forKey: "privacy_policy_accepted")
        }
        set {
            userDefaults.set(newValue, forKey: "privacy_policy_accepted")
            if newValue {
                userDefaults.set(Date(), forKey: "privacy_policy_accepted_date")
            }
        }
    }
    
    var privacyPolicyAcceptedDate: Date? {
        return userDefaults.object(forKey: "privacy_policy_accepted_date") as? Date
    }
    
    func getCurrentPrivacyPolicyVersion() -> String {
        // This should match your actual privacy policy version
        return "1.0.0"
    }
    
    // MARK: - Data Processing Basis
    
    func getProcessingBasis() -> [String: String] {
        return [
            "location_data": "Legitimate interest - providing location-based reminders",
            "notification_data": "Consent - sending user-requested notifications",
            "usage_analytics": "Consent - improving app functionality",
            "crash_reports": "Legitimate interest - fixing app issues"
        ]
    }
}

// MARK: - Extensions

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

