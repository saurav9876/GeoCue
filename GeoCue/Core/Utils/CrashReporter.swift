import Foundation
import UIKit

// MARK: - Crash Reporter

final class CrashReporter {
    static let shared = CrashReporter()
    
    private let logger = Logger.shared
    private var crashData: [String: Any] = [:]
    
    private init() {
        setupCrashDetection()
    }
    
    // MARK: - Public Methods
    
    func recordEvent(_ event: String, parameters: [String: Any] = [:]) {
        let eventData: [String: Any] = [
            "event": event,
            "parameters": parameters,
            "timestamp": Date().timeIntervalSince1970,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "os_version": UIDevice.current.systemVersion,
            "device_model": UIDevice.current.model
        ]
        
        logger.info("Analytics event: \(event)", category: .analytics)
        
        #if DEBUG
        print("📊 Analytics: \(event) - \(parameters)")
        #else
        // In production, you would send this to your analytics service
        // Example: Firebase Analytics, Mixpanel, etc.
        #endif
    }
    
    func recordError(_ error: Error, context: String = "") {
        let errorData: [String: Any] = [
            "error_description": error.localizedDescription,
            "context": context,
            "timestamp": Date().timeIntervalSince1970,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "os_version": UIDevice.current.systemVersion,
            "device_model": UIDevice.current.model
        ]
        
        logger.error("Error recorded: \(error.localizedDescription) in \(context)", category: .general)
        
        #if DEBUG
        print("🚨 Error: \(error.localizedDescription) in \(context)")
        #else
        // In production, you would send this to your crash reporting service
        // Example: Firebase Crashlytics, Sentry, etc.
        #endif
    }
    
    func recordCrash(_ crashInfo: [String: Any]) {
        crashData = crashInfo
        logger.error("Crash recorded", category: .general)
        
        #if !DEBUG
        // In production, you would send this to your crash reporting service
        #endif
    }
    
    func setUserProperty(_ value: String, forName name: String) {
        logger.debug("User property set: \(name) = \(value)", category: .analytics)
        
        #if !DEBUG
        // In production, you would set this in your analytics service
        #endif
    }
    
    // MARK: - Private Methods
    
    private func setupCrashDetection() {
        // Set up crash detection using NSSetUncaughtExceptionHandler
        NSSetUncaughtExceptionHandler { exception in
            let crashInfo: [String: Any] = [
                "exception_name": exception.name.rawValue,
                "exception_reason": exception.reason ?? "Unknown",
                "call_stack": exception.callStackSymbols,
                "timestamp": Date().timeIntervalSince1970,
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            ]
            
            CrashReporter.shared.recordCrash(crashInfo)
        }
        
        // Set up signal handler for additional crash detection
        signal(SIGABRT, crashSignalHandler)
        signal(SIGILL, crashSignalHandler)
        signal(SIGSEGV, crashSignalHandler)
        signal(SIGFPE, crashSignalHandler)
        signal(SIGBUS, crashSignalHandler)
        signal(SIGPIPE, crashSignalHandler)
    }
}

// MARK: - Signal Handler

private func crashSignalHandler(signal: Int32) {
    let crashInfo: [String: Any] = [
        "signal": signal,
        "timestamp": Date().timeIntervalSince1970,
        "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    ]
    
    CrashReporter.shared.recordCrash(crashInfo)
    exit(signal)
}

// MARK: - Analytics Extension

extension CrashReporter {
    
    // Common events for GeoCue
    func recordGeofenceCreated(name: String, radius: Double) {
        recordEvent("geofence_created", parameters: [
            "name": name,
            "radius": radius
        ])
    }
    
    func recordGeofenceTriggered(name: String, type: String) {
        recordEvent("geofence_triggered", parameters: [
            "name": name,
            "type": type
        ])
    }
    
    func recordLocationPermissionGranted(type: String) {
        recordEvent("location_permission_granted", parameters: [
            "type": type
        ])
    }
    
    func recordNotificationPermissionGranted() {
        recordEvent("notification_permission_granted")
    }
    
    func recordAppLaunched() {
        recordEvent("app_launched")
    }
}