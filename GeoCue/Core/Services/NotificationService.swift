import Foundation
import UserNotifications
import UIKit

// Simple, unified notification service for GeoCue
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    // No external dependencies in minimal mode

    // Request notification authorization
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    // Public API: post entry/exit notification. Returns true if the request
    // was enqueued with UNUserNotificationCenter.
    @discardableResult
    func postGeofenceNotification(event: GeofenceEvent, location: GeofenceLocation) -> Bool {
        print("🔔 NotificationService: Attempting to post \(event.displayName) notification for \(location.name)")
        
        // Simplified: ignore Do Not Disturb in minimal mode

        let title = "GeoCue Reminder"
        let body: String
        switch event {
        case .entry:
            body = location.entryMessage.isEmpty ? "You've arrived at \(location.name)" : location.entryMessage
        case .exit:
            body = location.exitMessage.isEmpty ? "You've left \(location.name)" : location.exitMessage
        }

        let content = buildContent(title: title, body: body, timeSensitive: true)
        // Use a unique identifier so multiple notifications are shown without throttling
        let uniqueId = "geo-\(event == .entry ? "entry" : "exit")-\(location.id.uuidString)-\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: uniqueId, content: content, trigger: nil)
        
        center.add(request) { error in
            if let error = error {
                print("❌ NotificationService: Failed to add notification: \(error.localizedDescription)")
            } else {
                print("✅ NotificationService: Successfully added notification for \(location.name)")
            }
        }
        return true
    }

    // Public API: comprehensive test of the notification system
    func testNotificationSystem(completion: @escaping (String) -> Void) {
        var results: [String] = []
        
        // Test 1: Check notification authorization
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    results.append("✅ Notification permission: Authorized")
                case .denied:
                    results.append("❌ Notification permission: Denied")
                    completion(results.joined(separator: "\n"))
                    return
                case .notDetermined:
                    results.append("⚠️ Notification permission: Not determined")
                    completion(results.joined(separator: "\n"))
                    return
                default:
                    results.append("⚠️ Notification permission: \(settings.authorizationStatus)")
                }
                
                // Test 2: Check individual settings
                results.append("Alert: \(settings.alertSetting == .enabled ? "✅" : "❌")")
                results.append("Sound: \(settings.soundSetting == .enabled ? "✅" : "❌")")
                results.append("Badge: \(settings.badgeSetting == .enabled ? "✅" : "❌")")
                
                // Test 3: Send actual test notification
                results.append("📤 Sending test notification...")
                self.sendTestNotification()
                results.append("✅ Test notification sent successfully")
                
                completion(results.joined(separator: "\n"))
            }
        }
    }
    
    // Public API: send a test that simulates a real geofence reminder
    func sendTestNotification(simulateEntry: Bool? = nil) {
        let event: GeofenceEvent = (simulateEntry ?? Bool.random()) ? .entry : .exit
        let name: String

        // Pick a real saved location name if available
        let saved = UserDefaults.standard.data(forKey: "geofenceLocations")
            .flatMap { try? JSONDecoder().decode([GeofenceLocation].self, from: $0) }
        if let loc = saved?.first {
            name = loc.name
        } else {
            name = event == .entry ? "Home" : "Work"
        }

        let title = "GeoCue Reminder"
        let body = event == .entry ? "You've arrived at \(name)" : "You've left \(name)"
        let content = buildContent(title: title, body: body, timeSensitive: true)
        let id = "test-\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request, withCompletionHandler: nil)

        // Minimal mode: rely on system notification sound only
    }

    // MARK: - Internals

    private func registerCategories() {
        let markDone = UNNotificationAction(identifier: "MARK_DONE", title: "Mark Done", options: [])
        let snooze10 = UNNotificationAction(identifier: "SNOOZE_10", title: "Snooze 10 min", options: [])
        let open = UNNotificationAction(identifier: "OPEN_APP", title: "Open", options: [.foreground])

        let geofenceCategory = UNNotificationCategory(
            identifier: "GEOFENCE_REMINDER",
            actions: [markDone, snooze10, open],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([geofenceCategory])
    }

    private func buildContent(title: String, body: String, timeSensitive: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.badge = 1
        content.categoryIdentifier = "GEOFENCE_REMINDER"

        // Minimal mode: always use system default sound
        content.sound = .default

        if #available(iOS 15.0, *) {
            content.interruptionLevel = timeSensitive ? .timeSensitive : .active
        }

        return content
    }

}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Minimal mode: show banner, badge, and play system sound in foreground
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        switch response.actionIdentifier {
        case UNNotificationDismissActionIdentifier:
            // No-op; could clear related here if needed
            break
        case "MARK_DONE":
            center.removeDeliveredNotifications(withIdentifiers: [id])
        case "SNOOZE_10":
            let content = response.notification.request.content
            let newContent = UNMutableNotificationContent()
            newContent.title = content.title
            newContent.body = content.body
            newContent.sound = content.sound
            newContent.badge = content.badge
            newContent.categoryIdentifier = content.categoryIdentifier
            newContent.userInfo = content.userInfo
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10*60, repeats: false)
            let newId = "\(id)_snooze_\(Int(Date().timeIntervalSince1970))"
            let req = UNNotificationRequest(identifier: newId, content: newContent, trigger: trigger)
            center.add(req, withCompletionHandler: nil)
        case "OPEN_APP", UNNotificationDefaultActionIdentifier:
            break
        default:
            break
        }
        completionHandler()
    }

    // Minimal mode: no custom audio playback
}
