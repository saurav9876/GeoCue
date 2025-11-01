import Foundation

// MARK: - Geofence Notification Controller

final class GeofenceNotificationController {
    
    // MARK: - Constants
    
    // Simplified policy: no cooldowns, no daily limits, no away-time
    
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
        
        // Simplified rule: if enabled and event type allowed, allow notification
        print("✅ Notification approved (simplified policy) for \(location.name) - \(event.displayName)")
        return true
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
        // With simplified policy, always allow when called
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