import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private var ringtoneService: RingtoneServiceProtocol?
    private let logger = Logger.shared
    
    func setRingtoneService(_ service: RingtoneServiceProtocol) {
        self.ringtoneService = service
        logger.info("NotificationManager configured with new ringtone service", category: .notification)
    }
    
    override init() {
        super.init()
        setupNotificationCenter()
        checkAuthorizationStatus()
    }
    
    private func setupNotificationCenter() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // Set up notification categories to ensure proper sound handling
        setupNotificationCategories()
    }
    
    private func setupNotificationCategories() {
        // Create categories for different types of notifications
        let geofenceCategory = UNNotificationCategory(
            identifier: "GEOFENCE_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let soundTestCategory = UNNotificationCategory(
            identifier: "SOUND_TEST", 
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            geofenceCategory,
            soundTestCategory
        ])
        
        logger.info("Notification categories configured", category: .notification)
    }
    
    func requestNotificationPermission() {
        logger.info("Requesting notification permissions", category: .notification)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("Notification permission error: \(error.localizedDescription)", category: .notification)
                    ErrorHandler.shared.handle(error, context: "Notification Permission")
                } else if granted {
                    self.logger.info("Notification permissions granted", category: .notification)
                } else {
                    self.logger.warning("Notification permissions denied", category: .notification)
                    ErrorHandler.shared.handle(.notificationPermissionDenied, context: "Notification Permission")
                }
                self.checkAuthorizationStatus()
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.logger.debug("Notification authorization status: \(settings.authorizationStatus.rawValue)", category: .notification)
            }
        }
    }
    
    func scheduleGeofenceNotification(
        title: String,
        body: String,
        identifier: String,
        badge: NSNumber? = 1
    ) {
        guard authorizationStatus == .authorized else {
            logger.warning("Cannot schedule notification - not authorized", category: .notification)
            return
        }
        
        logger.info("Scheduling geofence notification: \(identifier)", category: .notification)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default  // Use iOS default notification sound
        content.badge = badge
        content.categoryIdentifier = "GEOFENCE_REMINDER"
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Error scheduling notification: \(error.localizedDescription)", category: .notification)
            } else {
                self.logger.info("Notification scheduled successfully: \(identifier)", category: .notification)
            }
        }
    }
    
    func removeNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    func testNotificationWithSound() {
        guard authorizationStatus == .authorized else {
            logger.warning("Cannot test notification - not authorized", category: .notification)
            return
        }
        
        logger.info("Testing notification sound", category: .notification)
        
        let content = UNMutableNotificationContent()
        content.title = "Sound Test"
        content.body = "This notification should ring with sound!"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "sound-test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Error testing notification sound: \(error.localizedDescription)", category: .notification)
            } else {
                self.logger.info("Test notification scheduled successfully", category: .notification)
            }
        }
    }
    
    func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.logger.debug("Notification settings - Auth: \(settings.authorizationStatus.rawValue), Sound: \(settings.soundSetting.rawValue)", category: .notification)
            }
        }
    }
    
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        
        switch response.actionIdentifier {
        case "DISMISS_ACTION":
            removeNotification(withIdentifier: identifier)
            
        case "VIEW_ACTION":
            break
            
        case UNNotificationDefaultActionIdentifier:
            break
            
        default:
            break
        }
        
        completionHandler()
    }
}