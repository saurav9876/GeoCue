import Foundation

final class RingtonePersistenceService: RingtonePersistenceProtocol {
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let logger: LoggerProtocol
    
    private enum Keys {
        static let ringtoneSettings = "com.pixelsbysaurav.geocue.ringtone_settings"
        static let migrationVersion = "com.pixelsbysaurav.geocue.ringtone_migration_version"
    }
    
    private let currentMigrationVersion = 1
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard, logger: LoggerProtocol = Logger.shared) {
        self.userDefaults = userDefaults
        self.logger = logger
        performMigrationIfNeeded()
    }
    
    // MARK: - Public Methods
    
    func saveRingtoneSettings(_ settings: RingtoneSettings) throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(settings)
            
            userDefaults.set(data, forKey: Keys.ringtoneSettings)
            userDefaults.synchronize()
            
            logger.info("Successfully saved ringtone settings", category: .persistence)
            
        } catch {
            logger.error("Failed to save ringtone settings: \(error.localizedDescription)", category: .persistence)
            throw RingtoneError.persistenceError("Failed to encode settings: \(error.localizedDescription)")
        }
    }
    
    func loadRingtoneSettings() throws -> RingtoneSettings {
        guard let data = userDefaults.data(forKey: Keys.ringtoneSettings) else {
            logger.info("No existing ringtone settings found, returning defaults", category: .persistence)
            return RingtoneSettings() // Return default settings
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let settings = try decoder.decode(RingtoneSettings.self, from: data)
            
            logger.info("Successfully loaded ringtone settings", category: .persistence)
            return settings
            
        } catch {
            logger.error("Failed to load ringtone settings: \(error.localizedDescription)", category: .persistence)
            
            // Try to recover by returning default settings
            logger.info("Attempting to recover with default settings", category: .persistence)
            let defaultSettings = RingtoneSettings()
            try saveRingtoneSettings(defaultSettings)
            
            return defaultSettings
        }
    }
    
    func clearRingtoneSettings() throws {
        userDefaults.removeObject(forKey: Keys.ringtoneSettings)
        userDefaults.synchronize()
        
        logger.info("Successfully cleared ringtone settings", category: .persistence)
    }
    
    // MARK: - Private Methods
    
    private func performMigrationIfNeeded() {
        let currentVersion = userDefaults.integer(forKey: Keys.migrationVersion)
        
        if currentVersion < currentMigrationVersion {
            logger.info("Performing ringtone settings migration from version \(currentVersion) to \(currentMigrationVersion)", category: .persistence)
            
            switch currentVersion {
            case 0:
                migrateLegacySettings()
            default:
                break
            }
            
            userDefaults.set(currentMigrationVersion, forKey: Keys.migrationVersion)
            userDefaults.synchronize()
            
            logger.info("Migration completed successfully", category: .persistence)
        }
    }
    
    private func migrateLegacySettings() {
        // Legacy keys from the original implementation
        let legacyRingtoneKey = "selectedRingtone"
        let legacyEnabledKey = "isRingtoneEnabled"
        
        var selectedRingtone = RingtoneType.defaultSound
        var isEnabled = true
        
        // Migrate legacy ringtone selection
        if let legacyRingtoneString = userDefaults.string(forKey: legacyRingtoneKey),
           let legacyRingtone = RingtoneType(rawValue: legacyRingtoneString) {
            selectedRingtone = legacyRingtone
            userDefaults.removeObject(forKey: legacyRingtoneKey)
        }
        
        // Migrate legacy enabled state
        if userDefaults.object(forKey: legacyEnabledKey) != nil {
            isEnabled = userDefaults.bool(forKey: legacyEnabledKey)
            userDefaults.removeObject(forKey: legacyEnabledKey)
        }
        
        // Create new settings structure
        let migratedSettings = RingtoneSettings(
            selectedRingtone: selectedRingtone,
            isEnabled: isEnabled
        )
        
        do {
            try saveRingtoneSettings(migratedSettings)
            logger.info("Successfully migrated legacy ringtone settings", category: .persistence)
        } catch {
            logger.error("Failed to save migrated settings: \(error.localizedDescription)", category: .persistence)
        }
        
        userDefaults.synchronize()
    }
}

// MARK: - Logger Protocol

protocol LoggerProtocol {
    func info(_ message: String, category: LogCategory)
    func warning(_ message: String, category: LogCategory)
    func error(_ message: String, category: LogCategory)
    func debug(_ message: String, category: LogCategory)
}

enum LogCategory: String {
    case persistence = "Persistence"
    case audio = "Audio"
    case ui = "UI"
    case notification = "Notification"
    case service = "Service"
    case general = "General"
    case location = "Location"
    case privacy = "Privacy"
    case analytics = "Analytics"
    case security = "Security"
}

// MARK: - Logger Implementation

final class Logger: LoggerProtocol {
    static let shared = Logger()
    
    private init() {}
    
    func info(_ message: String, category: LogCategory) {
        log(level: "INFO", message: message, category: category)
    }
    
    func warning(_ message: String, category: LogCategory) {
        log(level: "WARNING", message: message, category: category)
    }
    
    func error(_ message: String, category: LogCategory) {
        log(level: "ERROR", message: message, category: category)
    }
    
    func debug(_ message: String, category: LogCategory) {
        #if DEBUG
        log(level: "DEBUG", message: message, category: category)
        #endif
    }
    
    private func log(level: String, message: String, category: LogCategory) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level)] [\(category.rawValue)] \(message)"
        
        print(logMessage)
        
        // In production, you might want to send this to a logging service
        // like Firebase Crashlytics, Sentry, or your own logging backend
    }
}

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}