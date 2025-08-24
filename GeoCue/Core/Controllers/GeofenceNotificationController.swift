import Foundation

// MARK: - Geofence Notification Controller

final class GeofenceNotificationController {
    
    // MARK: - Constants
    
    private let minimumAwayTime: TimeInterval = 10 * 60 // 10 minutes
    private let safetyNetInterval: TimeInterval = 4 * 60 * 60 // 4 hours
    private let maxDailyNotifications = 10 // Prevent excessive notifications
    
    // MARK: - Storage
    
    private let userDefaults = UserDefaults.standard
    private let statesKey = "location_notification_states"
    private var notificationStates: [UUID: LocationNotificationState] = [:]
    
    // MARK: - Initialization
    
    init() {
        loadNotificationStates()
    }
    
    // MARK: - Public Interface
    
    /// Determines if a notification should be sent for a geofence event
    func shouldNotify(for location: GeofenceLocation, event: GeofenceEvent) -> Bool {
        guard location.isEnabled else {
            print("🔕 Location \(location.name) is disabled, skipping notification")
            return false
        }
        
        // Check if this event type is enabled for this location
        guard isEventTypeEnabled(event: event, for: location) else {
            print("🔕 \(event.displayName) notifications disabled for \(location.name)")
            return false
        }
        
        // Get or create notification state for this location
        var state = getNotificationState(for: location.id)
        
        // Update counters and check daily limits
        state.updateCounters()
        
        // Safety check: prevent excessive daily notifications
        if state.dailyNotificationCount >= maxDailyNotifications {
            print("🚫 Daily notification limit reached for \(location.name) (\(state.dailyNotificationCount)/\(maxDailyNotifications))")
            saveNotificationState(state, for: location.id)
            return false
        }
        
        // Apply notification logic based on the event and location settings
        let shouldSendNotification = evaluateNotificationRules(
            state: state, 
            location: location, 
            event: event
        )
        
        if shouldSendNotification {
            // Update state with the event
            switch event {
            case .entry:
                state.recordEntry()
            case .exit:
                state.recordExit()
            }
            
            print("✅ Notification approved for \(location.name) - \(event.displayName)")
        } else {
            // Still record the event even if we don't notify
            switch event {
            case .entry:
                state.recordEntry()
            case .exit:
                state.recordExit()
            }
            
            print("🔕 Notification suppressed for \(location.name) - \(event.displayName)")
        }
        
        // Save the updated state
        saveNotificationState(state, for: location.id)
        
        return shouldSendNotification
    }
    
    /// Records that a notification was actually sent
    func recordNotificationSent(for locationId: UUID) {
        var state = getNotificationState(for: locationId)
        state.recordNotification()
        saveNotificationState(state, for: locationId)
        
        print("📝 Recorded notification sent for location \(locationId)")
    }
    
    /// Gets notification statistics for a location
    func getNotificationStats(for locationId: UUID) -> (dailyCount: Int, totalCount: Int, lastNotification: Date?) {
        let state = getNotificationState(for: locationId)
        return (state.dailyNotificationCount, state.notificationCount, state.lastNotificationTime)
    }
    
    /// Resets notification state for a location (for testing or user request)
    func resetNotificationState(for locationId: UUID) {
        notificationStates[locationId] = LocationNotificationState()
        saveNotificationStates()
        print("🔄 Reset notification state for location \(locationId)")
    }
    
    // MARK: - Private Methods
    
    private func isEventTypeEnabled(event: GeofenceEvent, for location: GeofenceLocation) -> Bool {
        switch event {
        case .entry:
            return location.notifyOnEntry
        case .exit:
            return location.notifyOnExit
        }
    }
    
    private func evaluateNotificationRules(
        state: LocationNotificationState, 
        location: GeofenceLocation, 
        event: GeofenceEvent
    ) -> Bool {
        
        // Rule 1: First time notification - always allow
        guard let lastNotification = state.lastNotificationTime else {
            print("📍 First notification for \(location.name) - allowing")
            return true
        }
        
        let timeSinceLastNotification = Date().timeIntervalSince(lastNotification)
        
        // Rule 2: Safety Net - if it's been >4 hours, always notify
        if timeSinceLastNotification > safetyNetInterval {
            print("🛡️ Safety net triggered for \(location.name) (>4 hours)")
            return true
        }
        
        // Rule 3: Check cooldown period based on notification mode
        let cooldownPeriod = location.notificationMode.cooldownPeriod
        if timeSinceLastNotification < cooldownPeriod {
            let remainingTime = cooldownPeriod - timeSinceLastNotification
            print("⏰ Cooldown active for \(location.name) (\(Int(remainingTime/60)) minutes remaining)")
            return false
        }
        
        // Rule 4: For entries, check if user was actually away
        if event == .entry {
            if let lastExit = state.lastExitTime {
                let timeSinceExit = Date().timeIntervalSince(lastExit)
                if timeSinceExit < minimumAwayTime {
                    print("🚪 User barely left \(location.name) (\(Int(timeSinceExit/60)) min), suppressing entry notification")
                    return false
                }
            }
        }
        
        // Rule 5: Special handling for once-daily mode
        if location.notificationMode == .onceDaily && state.dailyNotificationCount > 0 {
            print("📅 Once-daily mode: already notified today for \(location.name)")
            return false
        }
        
        // All rules passed
        return true
    }
    
    // MARK: - Persistence
    
    private func getNotificationState(for locationId: UUID) -> LocationNotificationState {
        return notificationStates[locationId] ?? LocationNotificationState()
    }
    
    private func saveNotificationState(_ state: LocationNotificationState, for locationId: UUID) {
        notificationStates[locationId] = state
        saveNotificationStates()
    }
    
    private func loadNotificationStates() {
        guard let data = userDefaults.data(forKey: statesKey),
              let states = try? JSONDecoder().decode([String: LocationNotificationState].self, from: data) else {
            print("📂 No saved notification states found, starting fresh")
            return
        }
        
        // Convert string keys back to UUIDs
        notificationStates = states.compactMapValues { value in value }
            .reduce(into: [UUID: LocationNotificationState]()) { result, pair in
                if let uuid = UUID(uuidString: pair.key) {
                    result[uuid] = pair.value
                }
            }
        
        print("📂 Loaded notification states for \(notificationStates.count) locations")
    }
    
    private func saveNotificationStates() {
        // Convert UUID keys to strings for JSON encoding
        let stringKeyedStates = notificationStates.reduce(into: [String: LocationNotificationState]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        
        do {
            let data = try JSONEncoder().encode(stringKeyedStates)
            userDefaults.set(data, forKey: statesKey)
            print("💾 Saved notification states for \(stringKeyedStates.count) locations")
        } catch {
            print("❌ Failed to save notification states: \(error)")
        }
    }
}

// MARK: - Extensions for Debugging

extension GeofenceNotificationController {
    
    /// Gets a debug summary of all notification states
    func getDebugSummary() -> String {
        var summary = "🔍 Notification Controller Debug Summary\n"
        summary += "=====================================\n"
        summary += "Total tracked locations: \(notificationStates.count)\n\n"
        
        for (locationId, state) in notificationStates {
            summary += "Location: \(locationId)\n"
            summary += "  Daily notifications: \(state.dailyNotificationCount)\n"
            summary += "  Total notifications: \(state.notificationCount)\n"
            
            if let lastNotification = state.lastNotificationTime {
                let timeSince = Date().timeIntervalSince(lastNotification)
                summary += "  Last notification: \(Int(timeSince/60)) minutes ago\n"
            } else {
                summary += "  Last notification: Never\n"
            }
            
            if let lastEntry = state.lastEntryTime {
                let timeSince = Date().timeIntervalSince(lastEntry)
                summary += "  Last entry: \(Int(timeSince/60)) minutes ago\n"
            }
            
            if let lastExit = state.lastExitTime {
                let timeSince = Date().timeIntervalSince(lastExit)
                summary += "  Last exit: \(Int(timeSince/60)) minutes ago\n"
            }
            
            summary += "\n"
        }
        
        return summary
    }
}