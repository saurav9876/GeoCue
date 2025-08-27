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

