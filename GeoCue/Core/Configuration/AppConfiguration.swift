import Foundation
import UIKit

// MARK: - App Configuration

struct AppConfiguration {
    
    // MARK: - Environment
    
    enum Environment: String, CaseIterable {
        case development = "Development"
        case staging = "Staging"
        case production = "Production"
        
        static var current: Environment {
            #if DEBUG
            return .development
            #elseif STAGING
            return .staging
            #else
            return .production
            #endif
        }
        
        var isProduction: Bool {
            return self == .production
        }
        
        var isDevelopment: Bool {
            return self == .development
        }
    }
    
    // MARK: - Feature Flags
    
    struct FeatureFlags {
        static let ringtonePreviewEnabled = true
        static let analyticsEnabled = Environment.current.isProduction
        static let debugLoggingEnabled = Environment.current.isDevelopment
        static let crashReportingEnabled = Environment.current.isProduction
        static let performanceMonitoringEnabled = true
    }
    
    // MARK: - Audio Configuration
    
    struct Audio {
        static let defaultPreviewDuration: TimeInterval = 2.0
        static let maxConcurrentPreviews = 1
        static let audioSessionCategory = "AVAudioSessionCategoryAmbient"
        static let supportedSampleRates: [Double] = [44100.0, 48000.0]
    }
    
    // MARK: - Persistence Configuration
    
    struct Persistence {
        static let migrationVersion = 1
        static let settingsKey = "com.pixelsbysaurav.geocue.ringtone_settings"
        static let backupEnabled = true
        static let encryptionEnabled = false // Could be enabled for sensitive data
    }
    
    // MARK: - UI Configuration
    
    struct UI {
        static let animationDuration: TimeInterval = 0.2
        static let loadingTimeoutDuration: TimeInterval = 5.0
        static let errorDisplayDuration: TimeInterval = 3.0
        static let hapticFeedbackEnabled = true
        
        struct Accessibility {
            static let minimumTouchTarget: CGFloat = 44.0
            static let highContrastEnabled = false
            static let reduceMotionRespected = true
        }
    }
    
    // MARK: - Performance Configuration
    
    struct Performance {
        static let maxConcurrentOperations = 3
        static let cacheSize = 50
        static let backgroundQueueQoS = DispatchQoS.utility
        static let networkTimeoutInterval: TimeInterval = 10.0
    }
    
    // MARK: - Logging Configuration
    
    struct Logging {
        static let logLevel: LogLevel = Environment.current.isDevelopment ? .debug : .info
        static let maxLogFileSize = 10 * 1024 * 1024 // 10MB
        static let maxLogFiles = 5
        static let enableConsoleLogging = Environment.current.isDevelopment
        static let enableFileLogging = Environment.current.isProduction
        
        enum LogLevel: Int, CaseIterable {
            case debug = 0
            case info = 1
            case warning = 2
            case error = 3
            
            var description: String {
                switch self {
                case .debug: return "DEBUG"
                case .info: return "INFO"
                case .warning: return "WARNING"
                case .error: return "ERROR"
                }
            }
        }
    }
    
    // MARK: - Notification Configuration
    
    struct Notifications {
        static let soundEnabled = true
        static let badgeEnabled = true
        static let alertEnabled = true
        static let defaultRingtone = RingtoneType.defaultSound
        static let maxPendingNotifications = 64
    }
}

// MARK: - Configuration Manager

final class ConfigurationManager {
    
    static let shared = ConfigurationManager()
    
    private init() {}
    
    // MARK: - Runtime Configuration
    
    private var runtimeFlags: [String: Any] = [:]
    
    func setRuntimeFlag<T>(_ key: String, value: T) {
        runtimeFlags[key] = value
    }
    
    func getRuntimeFlag<T>(_ key: String, defaultValue: T) -> T {
        return runtimeFlags[key] as? T ?? defaultValue
    }
    
    // MARK: - Environment Detection
    
    var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var isRunningInPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    var isRunningTests: Bool {
        return NSClassFromString("XCTestCase") != nil
    }
    
    // MARK: - Device Information
    
    var deviceModel: String {
        return UIDevice.current.model
    }
    
    var systemVersion: String {
        return UIDevice.current.systemVersion
    }
    
    var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - Build Configuration

extension Bundle {
    
    var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    var bundleDisplayName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "GeoCue"
    }
    
    var bundleIdentifier: String {
        return object(forInfoDictionaryKey: "CFBundleIdentifier") as? String ?? "com.pixelsbysaurav.geocue"
    }
}

// MARK: - SwiftUI Preview Configuration

#if DEBUG
struct PreviewConfiguration {
    // For previews, we'll use the default service from the service locator
    static var sampleRingtoneService: RingtoneServiceProtocol {
        ServiceLocator.ringtoneService
    }
    
    static func createMockServiceContainer() -> ServiceContainer {
        let container = ServiceContainer.shared
        
        // For previews, we can use the shared container
        // In a real preview environment, you might want to register mock services
        return container
    }
}
#endif