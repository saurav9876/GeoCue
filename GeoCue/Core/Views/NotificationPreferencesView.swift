import SwiftUI

struct NotificationPreferencesView: View {
    @EnvironmentObject private var notificationEscalator: NotificationEscalator
    @Environment(\.dismiss) private var dismiss
    
    @State private var preferences: NotificationStylePreferences
    @State private var showingResetAlert = false
    
    init() {
        // Initialize with current preferences
        _preferences = State(initialValue: NotificationEscalator.shared.preferences)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Default Style Section
                defaultStyleSection
                
                // Custom Styles Section
                customStylesSection
                
                // Sound & Haptic Section
                soundAndHapticSection
                
                // Quiet Hours Section
                quietHoursSection
                
                // Preview Section
                previewSection
                
                // Reset Section
                resetSection
            }
            .navigationTitle("Notification Styles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            preferences = notificationEscalator.preferences
        }
    }
    
    // MARK: - Default Style Section
    private var defaultStyleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Default Style")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("This style will be used for all notifications unless you customize specific priorities below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(NotificationPriority.allCases, id: \.self) { priority in
                        StyleOptionCard(
                            priority: priority,
                            isSelected: preferences.defaultStyle == priority,
                            action: {
                                preferences.defaultStyle = priority
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Default Notification Style")
        } footer: {
            Text("Choose how most notifications should be delivered by default.")
        }
    }
    
    // MARK: - Custom Styles Section
    private var customStylesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Customize by Priority")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Override the default style for specific priority levels. Leave unchecked to use the default style.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(NotificationPriority.allCases, id: \.self) { priority in
                    CustomStyleRow(
                        priority: priority,
                        currentStyle: preferences.customStyles[priority],
                        defaultStyle: preferences.defaultStyle,
                        onStyleChanged: { newStyle in
                            if newStyle == preferences.defaultStyle {
                                preferences.customStyles.removeValue(forKey: priority)
                            } else {
                                preferences.customStyles[priority] = newStyle
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Priority-Specific Styles")
        } footer: {
            Text("Customize how different priority levels are delivered. Unchecked priorities use the default style.")
        }
    }
    
    // MARK: - Sound & Haptic Section
    private var soundAndHapticSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable Sound", isOn: $preferences.soundEnabled)
                    .tint(.blue)
                
                Toggle("Enable Haptic Feedback", isOn: $preferences.hapticEnabled)
                    .tint(.orange)
                
                if !preferences.soundEnabled || !preferences.hapticEnabled {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Some notification styles may be limited when sound or haptic feedback is disabled.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 24)
                }
            }
        } header: {
            Text("Sound & Haptic")
        } footer: {
            Text("Control whether notifications can use sound and haptic feedback.")
        }
    }
    
    // MARK: - Quiet Hours Section
    private var quietHoursSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable Quiet Hours", isOn: $preferences.quietHoursEnabled)
                    .tint(.purple)
                
                if preferences.quietHoursEnabled {
                    HStack {
                        Text("Start Time")
                        Spacer()
                        DatePicker("", selection: $preferences.quietHoursStart, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text("End Time")
                        Spacer()
                        DatePicker("", selection: $preferences.quietHoursEnd, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Critical notifications will always override quiet hours.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 24)
                }
            }
        } header: {
            Text("Quiet Hours")
        } footer: {
            Text("During quiet hours, non-critical notifications will be delayed until the end time.")
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Preview Your Settings")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Test how your notifications will look and feel with the current settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(NotificationPriority.allCases, id: \.self) { priority in
                        Button(action: {
                            testNotification(for: priority)
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: priority.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(priority.color)
                                
                                Text("Test \(priority.displayName)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Test Notifications")
        } footer: {
            Text("Send test notifications to see how your current settings work.")
        }
    }
    
    // MARK: - Reset Section
    private var resetSection: some View {
        Section {
            Button(action: {
                showingResetAlert = true
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.red)
                    Text("Reset to Defaults")
                        .foregroundColor(.red)
                }
            }
        } footer: {
            Text("This will reset all notification preferences to their default values.")
        }
        .alert("Reset Preferences", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("Are you sure you want to reset all notification preferences to defaults?")
        }
    }
    
    // MARK: - Helper Methods
    
    private func savePreferences() {
        notificationEscalator.updatePreferences(preferences)
    }
    
    private func resetToDefaults() {
        preferences = NotificationStylePreferences()
        notificationEscalator.resetToDefaults()
    }
    
    private func testNotification(for priority: NotificationPriority) {
        let title = "Test \(priority.displayName) Notification"
        let body = "This is a test notification with \(priority.displayName.lowercased()) priority"
        let identifier = "test_\(priority.rawValue)_\(Date().timeIntervalSince1970)"
        
        notificationEscalator.sendNotification(
            title: title,
            body: body,
            identifier: identifier,
            priority: priority
        )
    }
}

// MARK: - Style Option Card
struct StyleOptionCard: View {
    let priority: NotificationPriority
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: priority.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : priority.color)
                
                Text(priority.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(priority.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? priority.color : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? priority.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Custom Style Row
struct CustomStyleRow: View {
    let priority: NotificationPriority
    let currentStyle: NotificationPriority?
    let defaultStyle: NotificationPriority
    let onStyleChanged: (NotificationPriority) -> Void
    
    private var effectiveStyle: NotificationPriority {
        currentStyle ?? defaultStyle
    }
    
    var body: some View {
        HStack {
            // Priority icon and name
            HStack(spacing: 12) {
                Image(systemName: priority.icon)
                    .font(.system(size: 20))
                    .foregroundColor(priority.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(priority.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Current: \(effectiveStyle.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Style picker
            Menu {
                ForEach(NotificationPriority.allCases, id: \.self) { style in
                    Button(action: {
                        onStyleChanged(style)
                    }) {
                        HStack {
                            Text(style.displayName)
                            if style == effectiveStyle {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: effectiveStyle.icon)
                        .font(.system(size: 14))
                        .foregroundColor(effectiveStyle.color)
                    
                    Text(effectiveStyle.displayName)
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NotificationPreferencesView()
        .environmentObject(NotificationEscalator.shared)
}
