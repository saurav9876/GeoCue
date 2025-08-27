import SwiftUI

struct NotificationPreferencesView: View {
    @EnvironmentObject private var notificationEscalator: NotificationEscalator
    @EnvironmentObject private var doNotDisturbManager: DoNotDisturbManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var preferences: NotificationStylePreferences
    @State private var showingDatePicker = false
    @State private var customDoNotDisturbDate = Date()
    
    init() {
        // Initialize with current preferences
        _preferences = State(initialValue: NotificationEscalator.shared.preferences)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Global Style Section
                globalStyleSection
                
                // Sound & Haptic Section
                soundAndHapticSection
                
                // Do Not Disturb Section
                doNotDisturbSection
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
    
    // MARK: - Global Style Section
    private var globalStyleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Notification Style")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("This style will be used for all your GeoCue reminders.")
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
            Text("Choose Your Style")
        } footer: {
            Text("Select how you want to receive notifications for all your location reminders.")
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
    
    // MARK: - Do Not Disturb Section
    private var doNotDisturbSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Current Status
                HStack {
                    Image(systemName: doNotDisturbManager.isCurrentlyActive ? "moon.zzz.fill" : "bell.fill")
                        .foregroundColor(doNotDisturbManager.isCurrentlyActive ? .purple : .blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Status")
                            .font(.headline)
                        Text(doNotDisturbManager.statusDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if doNotDisturbManager.isCurrentlyActive {
                        Button("Turn Off") {
                            doNotDisturbManager.setDoNotDisturb(.off)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                // Duration Options
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(DoNotDisturbDuration.allCases.filter { $0 != .off }, id: \.self) { duration in
                        Button(action: {
                            if duration == .until {
                                showingDatePicker = true
                            } else {
                                doNotDisturbManager.setDoNotDisturb(duration)
                            }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: duration.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(.purple)
                                
                                Text(duration.displayName)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        } header: {
            Text("Do Not Disturb")
        } footer: {
            Text("Silence all notifications for a specific period. You can turn it off anytime.")
        }
        .sheet(isPresented: $showingDatePicker) {
            doNotDisturbUntilDatePicker
        }
    }
    
    // MARK: - Do Not Disturb Until Date Picker
    private var doNotDisturbUntilDatePicker: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Do Not Disturb Until")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                DatePicker(
                    "Select Date & Time",
                    selection: $customDoNotDisturbDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingDatePicker = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Set") {
                        doNotDisturbManager.setDoNotDisturb(.until, customEndDate: customDoNotDisturbDate)
                        showingDatePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func savePreferences() {
        notificationEscalator.updatePreferences(preferences)
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

#Preview {
    NotificationPreferencesView()
        .environmentObject(NotificationEscalator.shared)
        .environmentObject(DoNotDisturbManager.shared)
}
