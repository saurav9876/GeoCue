import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Escalator Service
class NotificationEscalator: ObservableObject {
    static let shared = NotificationEscalator()
    
    private let notificationManager = NotificationManager()
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "notification_style_preferences"
    
    @Published var preferences: NotificationStylePreferences {
        didSet {
            savePreferences()
        }
    }
    
    private init() {
        // Load saved preferences or use defaults
        if let data = userDefaults.data(forKey: preferencesKey),
           let savedPreferences = try? JSONDecoder().decode(NotificationStylePreferences.self, from: data) {
            self.preferences = savedPreferences
        } else {
            self.preferences = NotificationStylePreferences()
        }
    }
    
    // MARK: - Public Interface
    
    /// Send a notification with smart escalation based on priority
    func sendNotification(
        title: String,
        body: String,
        identifier: String,
        priority: NotificationPriority,
        badge: NSNumber? = 1
    ) {
        // Check if we should respect quiet hours
        if preferences.shouldRespectQuietHours(for: priority) {
            // Schedule for later or send silently
            scheduleForQuietHoursEnd(title: title, body: body, identifier: identifier, priority: priority, badge: badge)
            return
        }
        
        // Get delivery options based on priority and preferences
        let deliveryOptions = NotificationDeliveryOptions(priority: priority, preferences: preferences)
        
        // Send the notification with appropriate settings
        sendNotificationWithOptions(
            title: title,
            body: body,
            identifier: identifier,
            options: deliveryOptions,
            badge: badge
        )
        
        // Schedule escalation if needed
        if let escalationDelay = deliveryOptions.escalationDelay {
            scheduleEscalation(
                for: identifier,
                title: title,
                body: body,
                priority: priority,
                delay: escalationDelay
            )
        }
    }
    
    /// Send a notification with specific delivery options
    private func sendNotificationWithOptions(
        title: String,
        body: String,
        identifier: String,
        options: NotificationDeliveryOptions,
        badge: NSNumber?
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.badge = badge
        content.categoryIdentifier = "GEOFENCE_REMINDER"
        
        // Configure sound
        if options.sound {
            content.sound = UNNotificationSound.default
        }
        
        // Configure custom data for escalation
        content.userInfo = [
            "priority": options.priority.rawValue,
            "escalationEnabled": options.escalationDelay != nil,
            "repeatUntilAcknowledged": options.repeatUntilAcknowledged
        ]
        
        // Create notification request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.shared.error("Error scheduling notification: \(error.localizedDescription)", category: .notification)
            } else {
                Logger.shared.info("Notification scheduled successfully: \(identifier)", category: .notification)
                
                // Trigger haptic feedback if enabled
                if options.haptic {
                    DispatchQueue.main.async {
                        self.triggerHapticFeedback(for: options.priority)
                    }
                }
            }
        }
    }
    
    /// Schedule escalation for high-priority notifications
    private func scheduleEscalation(
        for identifier: String,
        title: String,
        body: String,
        priority: NotificationPriority,
        delay: TimeInterval
    ) {
        let escalationIdentifier = "\(identifier)_escalation"
        
        let content = UNMutableNotificationContent()
        content.title = "🔔 \(title)" // Add bell emoji for escalation
        content.body = "\(body) - Reminder"
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.categoryIdentifier = "GEOFENCE_REMINDER"
        content.userInfo = [
            "priority": priority.rawValue,
            "isEscalation": true,
            "originalIdentifier": identifier
        ]
        
        // Create time-based trigger for escalation
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: escalationIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.shared.error("Error scheduling escalation: \(error.localizedDescription)", category: .notification)
            } else {
                Logger.shared.info("Escalation scheduled for: \(identifier) in \(delay) seconds", category: .notification)
            }
        }
    }
    
    /// Schedule notification for when quiet hours end
    private func scheduleForQuietHoursEnd(
        title: String,
        body: String,
        identifier: String,
        priority: NotificationPriority,
        badge: NSNumber?
    ) {
        let quietHoursIdentifier = "\(identifier)_quiet_hours"
        
        let content = UNMutableNotificationContent()
        content.title = "📱 \(title)" // Add phone emoji for delayed notification
        content.body = "\(body) - Delivered after quiet hours"
        content.sound = UNNotificationSound.default
        content.badge = badge
        content.categoryIdentifier = "GEOFENCE_REMINDER"
        content.userInfo = [
            "priority": priority.rawValue,
            "wasDelayedByQuietHours": true,
            "originalIdentifier": identifier
        ]
        
        // Calculate when quiet hours end
        let calendar = Calendar.current
        let now = Date()
        let quietHoursEnd = preferences.quietHoursEnd
        
        var targetDate = calendar.date(bySetting: .hour, value: calendar.component(.hour, from: quietHoursEnd), of: now) ?? now
        targetDate = calendar.date(bySetting: .minute, value: calendar.component(.minute, from: quietHoursEnd), of: targetDate) ?? targetDate
        
        // If quiet hours end time has passed today, schedule for tomorrow
        if targetDate <= now {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        }
        
        let timeInterval = targetDate.timeIntervalSince(now)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: quietHoursIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.shared.error("Error scheduling quiet hours notification: \(error.localizedDescription)", category: .notification)
            } else {
                Logger.shared.info("Quiet hours notification scheduled for: \(identifier) at \(targetDate)", category: .notification)
            }
        }
    }
    
    /// Trigger haptic feedback based on priority
    private func triggerHapticFeedback(for priority: NotificationPriority) {
        let impactFeedbackGenerator: UIImpactFeedbackGenerator
        
        switch priority {
        case .low:
            return // No haptic for low priority
            
        case .medium:
            impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
            
        case .high:
            impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            
        case .critical:
            impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        }
        
        impactFeedbackGenerator.impactOccurred()
    }
    
    /// Update user preferences
    func updatePreferences(_ newPreferences: NotificationStylePreferences) {
        preferences = newPreferences
    }
    
    /// Reset preferences to defaults
    func resetToDefaults() {
        preferences = NotificationStylePreferences()
    }
    
    // MARK: - Private Methods
    
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            userDefaults.set(data, forKey: preferencesKey)
            userDefaults.synchronize()
        }
    }
}

// MARK: - Notification Escalation Manager
class NotificationEscalationManager {
    static let shared = NotificationEscalationManager()
    
    private var escalationTimers: [String: Timer] = [:]
    
    /// Start escalation timer for a notification
    func startEscalation(for identifier: String, delay: TimeInterval, action: @escaping () -> Void) {
        // Cancel existing timer if any
        escalationTimers[identifier]?.invalidate()
        
        // Create new timer
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            action()
            self.escalationTimers.removeValue(forKey: identifier)
        }
        
        escalationTimers[identifier] = timer
    }
    
    /// Cancel escalation for a notification
    func cancelEscalation(for identifier: String) {
        escalationTimers[identifier]?.invalidate()
        escalationTimers.removeValue(forKey: identifier)
    }
    
    /// Cancel all escalations
    func cancelAllEscalations() {
        escalationTimers.values.forEach { $0.invalidate() }
        escalationTimers.removeAll()
    }
}
