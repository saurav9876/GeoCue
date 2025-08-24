import Foundation
import SwiftUI

// MARK: - Notification Priority Levels
enum NotificationPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Standard notification without sound or vibration"
        case .medium:
            return "Notification with sound but no vibration"
        case .high:
            return "Notification with sound and haptic feedback"
        case .critical:
            return "All channels: sound, haptic, and visual emphasis"
        }
    }
    
    var icon: String {
        switch self {
        case .low:
            return "bell"
        case .medium:
            return "bell.fill"
        case .high:
            return "bell.badge"
        case .critical:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return .secondary
        case .medium:
            return .blue
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Notification Style Preferences
struct NotificationStylePreferences: Codable {
    var defaultStyle: NotificationPriority = .low
    var customStyles: [NotificationPriority: NotificationPriority] = [:]
    var soundEnabled: Bool = true
    var hapticEnabled: Bool = true
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    
    // Get the effective style for a given priority
    func effectiveStyle(for priority: NotificationPriority) -> NotificationPriority {
        return customStyles[priority] ?? defaultStyle
    }
    
    // Check if we should respect quiet hours
    func shouldRespectQuietHours(for priority: NotificationPriority) -> Bool {
        guard quietHoursEnabled else { return false }
        
        // Critical notifications always override quiet hours
        if priority == .critical { return false }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Check if current time is within quiet hours
        let startTime = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endTime = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        let currentTime = calendar.dateComponents([.hour, .minute], from: now)
        
        if startTime.hour! > endTime.hour! {
            // Quiet hours span midnight
            return (currentTime.hour! >= startTime.hour! || currentTime.hour! < endTime.hour!)
        } else {
            // Quiet hours within same day
            return (currentTime.hour! >= startTime.hour! && currentTime.hour! < endTime.hour!)
        }
    }
}

// MARK: - Notification Delivery Options
struct NotificationDeliveryOptions {
    let priority: NotificationPriority
    let sound: Bool
    let haptic: Bool
    let visual: Bool
    let repeatUntilAcknowledged: Bool
    let escalationDelay: TimeInterval?
    
    init(priority: NotificationPriority, preferences: NotificationStylePreferences) {
        self.priority = priority
        let effectiveStyle = preferences.effectiveStyle(for: priority)
        
        switch effectiveStyle {
        case .low:
            self.sound = false
            self.haptic = false
            self.visual = true
            self.repeatUntilAcknowledged = false
            self.escalationDelay = nil
            
        case .medium:
            self.sound = preferences.soundEnabled
            self.haptic = false
            self.visual = true
            self.repeatUntilAcknowledged = false
            self.escalationDelay = nil
            
        case .high:
            self.sound = preferences.soundEnabled
            self.haptic = preferences.hapticEnabled
            self.visual = true
            self.repeatUntilAcknowledged = false
            self.escalationDelay = 60 // Escalate after 1 minute if not acknowledged
            
        case .critical:
            self.sound = preferences.soundEnabled
            self.haptic = preferences.hapticEnabled
            self.visual = true
            self.repeatUntilAcknowledged = true
            self.escalationDelay = 30 // Escalate after 30 seconds if not acknowledged
        }
    }
}
