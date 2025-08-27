import Foundation
import UserNotifications
import AVFoundation
import AudioToolbox

// MARK: - Error Types

enum RingtoneError: LocalizedError, Equatable {
    case audioSessionUnavailable
    case soundPlaybackFailed(String)
    case persistenceError(String)
    case invalidConfiguration
    case systemSoundNotAvailable(SystemSoundID)
    
    var errorDescription: String? {
        switch self {
        case .audioSessionUnavailable:
            return "Audio session is not available"
        case .soundPlaybackFailed(let reason):
            return "Sound playback failed: \(reason)"
        case .persistenceError(let reason):
            return "Failed to save settings: \(reason)"
        case .invalidConfiguration:
            return "Invalid ringtone configuration"
        case .systemSoundNotAvailable(let soundID):
            return "System sound \(soundID) is not available"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .audioSessionUnavailable:
            return "Please check your device's audio settings and try again"
        case .soundPlaybackFailed:
            return "Try selecting a different ringtone"
        case .persistenceError:
            return "Your settings may not be saved. Please try again"
        case .invalidConfiguration:
            return "Please reset to default settings"
        case .systemSoundNotAvailable:
            return "This ringtone is not available on your device"
        }
    }
}

// MARK: - Result Types

typealias RingtoneResult<T> = Result<T, RingtoneError>
typealias RingtoneCompletion<T> = (RingtoneResult<T>) -> Void

// MARK: - Core Protocols

protocol RingtoneServiceProtocol: AnyObject {
    var selectedRingtone: RingtoneType { get }
    var isRingtoneEnabled: Bool { get }
    var ringtonesByCategory: [RingtoneCategory: [RingtoneType]] { get }
    
    func updateRingtone(_ ringtone: RingtoneType, completion: @escaping RingtoneCompletion<Void>)
    func toggleRingtoneEnabled(completion: @escaping RingtoneCompletion<Bool>)
    func previewRingtone(_ ringtone: RingtoneType, completion: @escaping RingtoneCompletion<Void>)
    func stopPreview()
    func getNotificationSound() -> UNNotificationSound?
    func validateConfiguration() -> RingtoneResult<Void>
    func addObserver(_ observer: RingtoneServiceObserver)
    func removeObserver(_ observer: RingtoneServiceObserver)
}

protocol RingtonePersistenceProtocol: AnyObject {
    func saveRingtoneSettings(_ settings: RingtoneSettings) throws
    func loadRingtoneSettings() throws -> RingtoneSettings
    func clearRingtoneSettings() throws
}

protocol RingtoneAudioProtocol: AnyObject {
    func playSystemSound(_ soundID: SystemSoundID, completion: @escaping RingtoneCompletion<Void>)
    func playCustomAudio(_ fileName: String, completion: @escaping RingtoneCompletion<Void>)
    func stopAudioPlayback()
    func configureAudioSession() throws
}

// MARK: - Data Models

struct RingtoneSettings: Codable, Equatable {
    let selectedRingtone: RingtoneType
    let isEnabled: Bool
    let lastModified: Date
    let version: String
    
    init(selectedRingtone: RingtoneType = .defaultSound, 
         isEnabled: Bool = true,
         version: String = "1.0") {
        self.selectedRingtone = selectedRingtone
        self.isEnabled = isEnabled
        self.lastModified = Date()
        self.version = version
    }
}

// MARK: - Ringtone Type Enhanced

enum RingtoneType: String, CaseIterable, Codable, Identifiable {
    case defaultSound = "default_sound"
    case classicBell = "classic_bell"
    case digitalBeep = "digital_beep"
    case gentleChime = "gentle_chime"
    case notificationTone = "notification_tone"
    case urgentAlert = "urgent_alert"
    case happyTune = "happy_tune"
    case softDing = "soft_ding"
    case brightPing = "bright_ping"
    case zenBell = "zen_bell"
    
    
    
    // Custom audio files (M4A format)
    case customChime = "custom_chime"
    case customAlert = "custom_alert"
    case customSuccess = "custom_success"
    case customError = "custom_error"
    case customAmbient = "custom_ambient"
    
    // BBC Audio Files
    case bbcChime = "bbc_chime"
    case bbcAlert = "bbc_alert"
    case bbcSuccess = "bbc_success"
    case bbcError = "bbc_error"
    case bbcAmbient = "bbc_ambient"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .defaultSound: return NSLocalizedString("Default Sound", comment: "Default ringtone")
        case .classicBell: return NSLocalizedString("Classic Bell", comment: "Classic bell ringtone")
        case .digitalBeep: return NSLocalizedString("Digital Beep", comment: "Digital beep ringtone")
        case .gentleChime: return NSLocalizedString("Gentle Chime", comment: "Gentle chime ringtone")
        case .notificationTone: return NSLocalizedString("Notification Tone", comment: "Notification tone ringtone")
        case .urgentAlert: return NSLocalizedString("Urgent Alert", comment: "Urgent alert ringtone")
        case .happyTune: return NSLocalizedString("Happy Tune", comment: "Happy tune ringtone")
        case .softDing: return NSLocalizedString("Soft Ding", comment: "Soft ding ringtone")
        case .brightPing: return NSLocalizedString("Bright Ping", comment: "Bright ping ringtone")
        case .zenBell: return NSLocalizedString("Zen Bell", comment: "Zen bell ringtone")
        
        
        
        // Custom audio files
        case .customChime: return NSLocalizedString("Custom Chime", comment: "Custom notification chime")
        case .customAlert: return NSLocalizedString("Custom Alert", comment: "Custom alert sound")
        case .customSuccess: return NSLocalizedString("Custom Success", comment: "Custom success sound")
        case .customError: return NSLocalizedString("Custom Error", comment: "Custom error sound")
        case .customAmbient: return NSLocalizedString("Custom Ambient", comment: "Custom ambient sound")
        
        // BBC Audio Files
        case .bbcChime: return NSLocalizedString("BBC Chime", comment: "BBC notification chime")
        case .bbcAlert: return NSLocalizedString("BBC Alert", comment: "BBC alert sound")
        case .bbcSuccess: return NSLocalizedString("BBC Success", comment: "BBC success sound")
        case .bbcError: return NSLocalizedString("BBC Error", comment: "BBC error sound")
        case .bbcAmbient: return NSLocalizedString("BBC Ambient", comment: "BBC ambient sound")
        }
    }
    
    var systemSoundID: SystemSoundID? {
        switch self {
        case .defaultSound: return 1000
        case .classicBell: return 1005
        case .digitalBeep: return 1003
        case .gentleChime: return 1020
        case .notificationTone: return 1016
        case .urgentAlert: return 1005
        case .happyTune: return 1021
        case .softDing: return 1027
        case .brightPing: return 1033
        case .zenBell: return 1030
        
        
        
        // Custom audio files (no system sound ID, will use custom files)
        case .customChime, .customAlert, .customSuccess, .customError, .customAmbient:
            return nil
        
        // BBC audio files (no system sound ID, will use custom files)
        case .bbcChime, .bbcAlert, .bbcSuccess, .bbcError, .bbcAmbient:
            return nil
        }
    }
    
    /// Audio file name for notifications (supports CAF, M4A, and MP3 formats)
    var audioFileName: String {
        switch self {
        case .customChime, .customAlert, .customSuccess, .customError, .customAmbient:
            return "\(rawValue).m4a"  // Custom audio files use M4A format
        case .bbcChime, .bbcAlert, .bbcSuccess, .bbcError, .bbcAmbient:
            return "\(rawValue).mp3"  // BBC audio files use MP3 format
        default:
            return "\(rawValue).caf"  // System sounds use CAF format
        }
    }
    
    var notificationSound: UNNotificationSound {
        if self == .defaultSound {
            return UNNotificationSound.default
        } else if systemSoundID != nil {
            // For system sounds, use the system sound ID
            return UNNotificationSound.default
        } else {
            // For custom audio files (BBC and custom sounds), we need to handle this differently
            // iOS doesn't support custom audio files directly in UNNotificationSound
            // We'll use the default sound for now and handle custom audio in the notification content
            print("ℹ️ Custom audio file '\(audioFileName)' detected, using default sound for notification")
            return UNNotificationSound.default
        }
    }
    
    /// Check if this ringtone type has a custom audio file
    var hasCustomAudioFile: Bool {
        return systemSoundID == nil && self != .defaultSound
    }
    
    /// Get the custom audio file path if available
    var customAudioFilePath: String? {
        guard hasCustomAudioFile else { return nil }
        
        let fileName = audioFileName
        if let path = Bundle.main.path(forResource: String(fileName.dropLast(4)), ofType: String(fileName.dropFirst(fileName.count - 3))) {
            return path
        }
        return nil
    }
    
    var category: RingtoneCategory {
        switch self {
        case .defaultSound:
            return .system
        case .classicBell, .digitalBeep:
            return .traditional
        case .happyTune:
            return .musical
        case .gentleChime, .softDing, .zenBell:
            return .ambient
        case .urgentAlert:
            return .dramatic
        case .notificationTone, .brightPing:
            return .modern
        
        case .customChime, .customSuccess, .customAmbient:
            return .ambient
        case .customAlert:
            return .dramatic
        case .customError:
            return .modern
        case .bbcChime, .bbcSuccess, .bbcAmbient:
            return .ambient
        case .bbcAlert:
            return .dramatic
        case .bbcError:
            return .modern
        }
    }
}

enum RingtoneCategory: String, CaseIterable {
    case system = "System"
    case traditional = "Traditional"
    case musical = "Musical"
    case ambient = "Ambient"
    case dramatic = "Dramatic"
    case modern = "Modern"
    case classical = "Classical"
    
    var displayName: String {
        switch self {
        case .system: return NSLocalizedString("System", comment: "System ringtone category")
        case .traditional: return NSLocalizedString("Traditional", comment: "Traditional ringtone category")
        case .musical: return NSLocalizedString("Musical", comment: "Musical ringtone category")
        case .ambient: return NSLocalizedString("Ambient", comment: "Ambient ringtone category")
        case .dramatic: return NSLocalizedString("Dramatic", comment: "Dramatic ringtone category")
        case .modern: return NSLocalizedString("Modern", comment: "Modern ringtone category")
        case .classical: return NSLocalizedString("Classical", comment: "Classical ringtone category")
        }
    }
}

// MARK: - Observer Protocol

protocol RingtoneServiceObserver: AnyObject {
    func ringtoneService(_ service: RingtoneServiceProtocol, didUpdateRingtone ringtone: RingtoneType)
    func ringtoneService(_ service: RingtoneServiceProtocol, didToggleEnabled isEnabled: Bool)
    func ringtoneService(_ service: RingtoneServiceProtocol, didEncounterError error: RingtoneError)
}