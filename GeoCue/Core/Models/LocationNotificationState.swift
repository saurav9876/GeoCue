import Foundation

// MARK: - Location Notification State

struct LocationNotificationState: Codable, Equatable {
    var lastNotificationTime: Date?
    var lastEntryTime: Date?
    var lastExitTime: Date?
    var notificationCount: Int
    var dailyNotificationCount: Int
    var lastResetDate: Date
    
    init() {
        self.lastNotificationTime = nil
        self.lastEntryTime = nil
        self.lastExitTime = nil
        self.notificationCount = 0
        self.dailyNotificationCount = 0
        self.lastResetDate = Date()
    }
    
    // Reset daily counters if it's a new day
    mutating func resetDailyCountersIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
            dailyNotificationCount = 0
            lastResetDate = Date()
        }
    }
    
    // Check if we should reset counters based on time passed
    mutating func updateCounters() {
        resetDailyCountersIfNeeded()
        
        // Reset notification count if it's been more than 24 hours since last notification
        if let lastNotification = lastNotificationTime,
           Date().timeIntervalSince(lastNotification) > 24 * 60 * 60 {
            notificationCount = 0
        }
    }
    
    // Record a new notification
    mutating func recordNotification() {
        updateCounters()
        lastNotificationTime = Date()
        notificationCount += 1
        dailyNotificationCount += 1
    }
    
    // Record entry/exit events
    mutating func recordEntry() {
        lastEntryTime = Date()
    }
    
    mutating func recordExit() {
        lastExitTime = Date()
    }
}

// MARK: - Geofence Event Types

enum GeofenceEvent {
    case entry
    case exit
    
    var displayName: String {
        switch self {
        case .entry: return "Entry"
        case .exit: return "Exit"
        }
    }
}

// MARK: - Notification Mode Settings

enum NotificationMode: String, CaseIterable, Codable {
    case normal = "normal"
    
    var displayName: String {
        return "Normal"
    }
    
    var cooldownPeriod: TimeInterval {
        return 30 * 60 // 30 minutes
    }
}