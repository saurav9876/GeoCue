import Foundation
import SwiftUI

// MARK: - Do Not Disturb Duration

enum DoNotDisturbDuration: String, CaseIterable, Codable {
    case off = "off"
    case oneHour = "1hour"
    case twoHours = "2hours"
    case oneDay = "1day"
    case permanent = "permanent"
    case until = "until"
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .oneHour: return "1 Hour"
        case .twoHours: return "2 Hours"
        case .oneDay: return "1 Day"
        case .permanent: return "Permanent"
        case .until: return "Until..."
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .off: return nil
        case .oneHour: return 1 * 60 * 60 // 1 hour
        case .twoHours: return 2 * 60 * 60 // 2 hours
        case .oneDay: return 24 * 60 * 60 // 1 day
        case .permanent: return nil
        case .until: return nil
        }
    }
    
    var icon: String {
        switch self {
        case .off: return "bell"
        case .oneHour: return "clock"
        case .twoHours: return "clock"
        case .oneDay: return "moon"
        case .permanent: return "moon.zzz"
        case .until: return "calendar.circle"
        }
    }
}

// MARK: - Do Not Disturb Manager

final class DoNotDisturbManager: ObservableObject {
    static let shared = DoNotDisturbManager()
    
    @Published var isEnabled: Bool = false
    @Published var duration: DoNotDisturbDuration = .off
    @Published var customEndDate: Date?
    
    private let userDefaults = UserDefaults.standard
    private let logger = Logger.shared
    
    private enum Keys {
        static let isEnabled = "dnd_is_enabled"
        static let duration = "dnd_duration"
        static let endDate = "dnd_end_date"
        static let customEndDate = "dnd_custom_end_date"
    }
    
    private init() {
        loadSettings()
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    var isCurrentlyActive: Bool {
        guard isEnabled else { return false }
        
        switch duration {
        case .off:
            return false
        case .permanent:
            return true
        case .until:
            guard let endDate = customEndDate else { return false }
            return Date() < endDate
        default:
            guard let savedEndDate = userDefaults.object(forKey: Keys.endDate) as? Date else { return false }
            return Date() < savedEndDate
        }
    }
    
    var statusDescription: String {
        guard isCurrentlyActive else { return "Notifications are active" }
        
        switch duration {
        case .off:
            return "Notifications are active"
        case .permanent:
            return "Notifications silenced permanently"
        case .until:
            guard let endDate = customEndDate else { return "Notifications silenced" }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Notifications silenced until \(formatter.string(from: endDate))"
        default:
            guard let endDate = userDefaults.object(forKey: Keys.endDate) as? Date else {
                return "Notifications silenced"
            }
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Notifications silenced until \(formatter.string(from: endDate))"
        }
    }
    
    func setDoNotDisturb(_ duration: DoNotDisturbDuration, customEndDate: Date? = nil) {
        self.duration = duration
        self.customEndDate = customEndDate
        
        switch duration {
        case .off:
            self.isEnabled = false
        case .permanent:
            self.isEnabled = true
        case .until:
            self.isEnabled = customEndDate != nil && customEndDate! > Date()
        default:
            self.isEnabled = true
            if let timeInterval = duration.timeInterval {
                let endDate = Date().addingTimeInterval(timeInterval)
                userDefaults.set(endDate, forKey: Keys.endDate)
            }
        }
        
        saveSettings()
        logger.info("Do Not Disturb updated: \(duration.displayName)", category: .general)
    }
    
    func shouldSuppressNotification() -> Bool {
        return isCurrentlyActive
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        isEnabled = userDefaults.bool(forKey: Keys.isEnabled)
        
        if let durationString = userDefaults.string(forKey: Keys.duration),
           let savedDuration = DoNotDisturbDuration(rawValue: durationString) {
            duration = savedDuration
        }
        
        customEndDate = userDefaults.object(forKey: Keys.customEndDate) as? Date
        
        // Check if timed do not disturb has expired
        checkIfExpired()
    }
    
    private func saveSettings() {
        userDefaults.set(isEnabled, forKey: Keys.isEnabled)
        userDefaults.set(duration.rawValue, forKey: Keys.duration)
        
        if let customEndDate = customEndDate {
            userDefaults.set(customEndDate, forKey: Keys.customEndDate)
        } else {
            userDefaults.removeObject(forKey: Keys.customEndDate)
        }
        
        userDefaults.synchronize()
    }
    
    private func startMonitoring() {
        // Check every minute if timed do not disturb has expired
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.checkIfExpired()
        }
    }
    
    private func checkIfExpired() {
        guard isEnabled else { return }
        
        let hasExpired: Bool
        
        switch duration {
        case .off, .permanent:
            hasExpired = false
        case .until:
            hasExpired = customEndDate == nil || Date() >= customEndDate!
        default:
            guard let endDate = userDefaults.object(forKey: Keys.endDate) as? Date else {
                hasExpired = true
                return
            }
            hasExpired = Date() >= endDate
        }
        
        if hasExpired {
            DispatchQueue.main.async {
                self.setDoNotDisturb(.off)
                self.logger.info("Do Not Disturb expired automatically", category: .general)
            }
        }
    }
}