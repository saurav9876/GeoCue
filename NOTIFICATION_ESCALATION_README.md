# GeoCue Notification Escalation System

## 🎯 Overview

GeoCue now features a sophisticated **Smart Notification Escalation System** that automatically determines the best way to deliver notifications based on priority, user preferences, and context. This system ensures users never miss important reminders while respecting their preferences and quiet hours.

## 🚀 Key Features

### 1. **Priority-Based Notification Styles**
- **Low Priority**: Standard notification without sound or vibration
- **Medium Priority**: Notification with sound but no vibration  
- **High Priority**: Notification with sound and haptic feedback
- **Critical Priority**: All channels with escalation and repetition

### 2. **Smart Priority Detection**
The system automatically determines notification priority based on:
- **Location Type**: Home, work, medical facilities get higher priority
- **Message Content**: Keywords like "medication", "urgent", "meeting" trigger critical priority
- **Time Context**: Rush hours (7-9 AM, 5-7 PM) get elevated priority
- **Night Time**: Non-critical notifications are reduced to low priority during quiet hours

### 3. **User Customization**
- **Default Style**: Set your preferred notification style for most reminders
- **Priority Overrides**: Customize specific priority levels differently
- **Sound & Haptic Control**: Enable/disable sound and vibration independently
- **Quiet Hours**: Set custom quiet hours with critical notification override

### 4. **Smart Escalation**
- **Automatic Escalation**: High-priority notifications escalate after 1 minute if not acknowledged
- **Critical Escalation**: Critical notifications escalate every 30 seconds until acknowledged
- **Quiet Hours Handling**: Non-critical notifications are delayed until quiet hours end

## 🏗️ Architecture

### Core Components

#### 1. **NotificationPriority.swift**
```swift
enum NotificationPriority: String, CaseIterable, Codable {
    case low = "low"        // Standard notification
    case medium = "medium"  // With sound
    case high = "high"      // With sound + haptic
    case critical = "critical" // All channels + escalation
}
```

#### 2. **NotificationStylePreferences.swift**
```swift
struct NotificationStylePreferences: Codable {
    var defaultStyle: NotificationPriority = .low
    var customStyles: [NotificationPriority: NotificationPriority] = [:]
    var soundEnabled: Bool = true
    var hapticEnabled: Bool = true
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = // 10:00 PM
    var quietHoursEnd: Date = // 8:00 AM
}
```

#### 3. **NotificationEscalator.swift**
- **Smart Delivery**: Determines optimal notification method based on priority and preferences
- **Escalation Management**: Handles automatic escalation for high-priority notifications
- **Quiet Hours**: Delays non-critical notifications during quiet hours
- **Haptic Feedback**: Provides appropriate tactile feedback based on priority

#### 4. **NotificationPreferencesView.swift**
- **User Interface**: Beautiful, intuitive settings for customizing notification styles
- **Live Preview**: Test notifications with current settings
- **Priority Overrides**: Customize specific priority levels
- **Quiet Hours Configuration**: Set custom quiet hours

## 🔧 Implementation Details

### Priority Detection Algorithm

```swift
private func determineNotificationPriority(for location: GeofenceLocation, event: GeofenceEvent) -> NotificationPriority {
    var basePriority: NotificationPriority = .medium
    
    // Location-based priority
    if location.name.lowercased().contains("home") || 
       location.name.lowercased().contains("work") ||
       location.name.lowercased().contains("medical") {
        basePriority = .high
    }
    
    // Content-based priority
    if location.entryMessage.lowercased().contains("medication") ||
       location.entryMessage.lowercased().contains("urgent") {
        basePriority = .critical
    }
    
    // Time-based adjustments
    let hour = Calendar.current.component(.hour, from: Date())
    if (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19) {
        if basePriority == .medium { basePriority = .high }
    }
    
    if hour >= 22 || hour <= 6 {
        if basePriority == .medium { basePriority = .low }
    }
    
    return basePriority
}
```

### Escalation Logic

```swift
// High priority: Escalate after 1 minute
if priority == .high {
    escalationDelay = 60
}

// Critical priority: Escalate every 30 seconds until acknowledged
if priority == .critical {
    escalationDelay = 30
    repeatUntilAcknowledged = true
}
```

### Quiet Hours Handling

```swift
// Check if we should respect quiet hours
if preferences.shouldRespectQuietHours(for: priority) {
    // Schedule for when quiet hours end
    scheduleForQuietHoursEnd(title: title, body: body, identifier: identifier, priority: priority, badge: badge)
    return
}

// Critical notifications always override quiet hours
if priority == .critical { return false }
```

## 📱 User Experience

### Settings Access
1. Open GeoCue
2. Go to **Settings** tab
3. Tap **"Customize Notification Styles"**
4. Configure your preferences

### Configuration Options

#### Default Style Selection
- Choose from 4 notification styles (Low, Medium, High, Critical)
- Each style shows clear description of what it includes
- Visual icons and colors make selection intuitive

#### Priority-Specific Overrides
- Override default style for specific priority levels
- Example: Use "High" for most notifications but "Critical" for work-related ones
- Unchecked priorities automatically use the default style

#### Sound & Haptic Control
- Independent toggles for sound and haptic feedback
- System automatically adjusts available options based on settings
- Clear feedback about limitations when features are disabled

#### Quiet Hours
- Set custom start and end times for quiet hours
- Non-critical notifications are automatically delayed
- Critical notifications always override quiet hours
- Support for overnight quiet hours (e.g., 10 PM to 8 AM)

### Testing & Preview
- **Test Buttons**: Send test notifications for each priority level
- **Live Preview**: See exactly how notifications will look and feel
- **Immediate Feedback**: Test changes before saving

## 🔄 Integration Points

### LocationManager Integration
```swift
// Old way
notificationManager.scheduleGeofenceNotification(
    title: "GeoCue Reminder",
    body: message,
    identifier: "entry-\(geofenceLocation.id.uuidString)"
)

// New way with smart escalation
let priority = determineNotificationPriority(for: geofenceLocation, event: .entry)
NotificationEscalator.shared.sendNotification(
    title: "GeoCue Reminder",
    body: message,
    identifier: "entry-\(geofenceLocation.id.uuidString)",
    priority: priority
)
```

### App-Wide Integration
- **GeoCueApp.swift**: Provides NotificationEscalator as environment object
- **ContentView.swift**: Integrates notification preferences in settings
- **LocationManager.swift**: Uses escalation system for all geofence notifications

## 🎨 UI/UX Features

### Visual Design
- **Color-Coded Priorities**: Each priority has distinct colors and icons
- **Interactive Cards**: Tap to select notification styles
- **Progress Indicators**: Visual feedback for current selections
- **Smooth Animations**: Polished transitions and micro-interactions

### Accessibility
- **VoiceOver Support**: Clear descriptions for all notification styles
- **High Contrast**: Distinct visual differences between priority levels
- **Large Text Support**: Responsive typography scaling
- **Haptic Feedback**: Tactile confirmation of selections

## 🚦 Usage Examples

### Scenario 1: Standard User
- **Default Style**: Medium (sound, no haptic)
- **Custom Overrides**: None
- **Quiet Hours**: 10 PM - 8 AM
- **Result**: Most notifications have sound, work/home locations get high priority, night notifications are delayed

### Scenario 2: Power User
- **Default Style**: Low (silent)
- **Custom Overrides**: 
  - Medium priority → High (with haptic)
  - Critical priority → Critical (escalation)
- **Quiet Hours**: 11 PM - 7 AM
- **Result**: Silent default, enhanced important notifications, strict quiet hours

### Scenario 3: Medical Reminders
- **Default Style**: High (sound + haptic)
- **Custom Overrides**: None
- **Quiet Hours**: Disabled
- **Result**: All notifications are prominent, no delays, maximum visibility

## 🔧 Technical Implementation

### Data Persistence
- **UserDefaults**: Stores notification preferences
- **JSON Encoding**: Serializes complex preference structures
- **Automatic Sync**: Preferences update immediately across the app

### Performance Considerations
- **Lazy Loading**: Preferences loaded only when needed
- **Efficient Escalation**: Timer-based escalation with cleanup
- **Memory Management**: Proper cleanup of escalation timers

### Error Handling
- **Graceful Degradation**: Falls back to default settings if preferences corrupt
- **Validation**: Ensures preference values are within valid ranges
- **Logging**: Comprehensive logging for debugging and monitoring

## 🧪 Testing

### Test Notifications
- Each priority level has a dedicated test button
- Test notifications use current settings
- Immediate feedback on sound and haptic

### Edge Cases
- **Quiet Hours**: Test notifications during quiet hours
- **Escalation**: Verify escalation timing and behavior
- **Priority Overrides**: Test custom priority configurations
- **Sound/Haptic Disabled**: Verify graceful degradation

## 🔮 Future Enhancements

### Planned Features
- **Smart Learning**: Adapt to user behavior over time
- **Location Intelligence**: Better priority detection based on location patterns
- **Time-Based Rules**: More sophisticated time-based priority adjustments
- **User Analytics**: Insights into notification effectiveness

### Potential Integrations
- **Calendar Integration**: Adjust priority based on scheduled events
- **Health Data**: Medical reminders get automatic critical priority
- **Weather Conditions**: Adjust priority based on weather alerts
- **Traffic Data**: Commute-related notifications get elevated priority

## 📚 API Reference

### NotificationEscalator
```swift
class NotificationEscalator: ObservableObject {
    static let shared = NotificationEscalator()
    
    func sendNotification(
        title: String,
        body: String,
        identifier: String,
        priority: NotificationPriority,
        badge: NSNumber? = 1
    )
    
    func updatePreferences(_ preferences: NotificationStylePreferences)
    func resetToDefaults()
}
```

### NotificationStylePreferences
```swift
struct NotificationStylePreferences: Codable {
    var defaultStyle: NotificationPriority
    var customStyles: [NotificationPriority: NotificationPriority]
    var soundEnabled: Bool
    var hapticEnabled: Bool
    var quietHoursEnabled: Bool
    var quietHoursStart: Date
    var quietHoursEnd: Date
    
    func effectiveStyle(for priority: NotificationPriority) -> NotificationPriority
    func shouldRespectQuietHours(for priority: NotificationPriority) -> Bool
}
```

## 🎉 Conclusion

The GeoCue Notification Escalation System represents a significant advancement in location-based reminder applications. By combining intelligent priority detection, user customization, and smart escalation, it ensures that users receive the right level of notification attention at the right time, while maintaining full control over their experience.

The system is designed to be:
- **Intelligent**: Automatically determines appropriate notification levels
- **Customizable**: Gives users full control over their preferences
- **Respectful**: Honors quiet hours and user preferences
- **Reliable**: Ensures important notifications are never missed
- **Scalable**: Easy to extend with new features and integrations

This implementation provides a solid foundation for future enhancements while delivering immediate value to users through better notification management and user experience.
