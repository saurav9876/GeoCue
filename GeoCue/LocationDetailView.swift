import SwiftUI
import MapKit

struct LocationDetailView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var location: GeofenceLocation
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    @State private var mapRegion: MKCoordinateRegion
    @State private var showingFullScreenMap = false
    
    init(location: GeofenceLocation) {
        self._location = State(initialValue: location)
        self._mapRegion = State(initialValue: MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Clean header with map
                headerMapView
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Reminder info card
                        reminderInfoCard
                        
                        // Location details card
                        locationDetailsCard
                        
                        // Status card
                        statusCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
                
                // Bottom action buttons
                bottomActionButtons
            }
            .navigationTitle("Reminder Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditLocationView(location: $location)
                .environmentObject(locationManager)
        }
        .fullScreenCover(isPresented: $showingFullScreenMap) {
            FullScreenMapView(location: location)
        }
        .alert("Delete Reminder", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                locationManager.removeGeofence(location)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(location.name)'? This action cannot be undone.")
        }
        .onAppear {
            if let updatedLocation = locationManager.geofenceLocations.first(where: { $0.id == location.id }) {
                location = updatedLocation
            }
        }
    }
    
    // MARK: - Header Map View
    private var headerMapView: some View {
        ZStack {
            // Clean map
            Map(coordinateRegion: .constant(mapRegion), annotationItems: [MapAnnotationItem(coordinate: location.coordinate)]) { item in
                MapPin(coordinate: item.coordinate, tint: .blue)
            }
            .frame(height: 200)
            .clipped()
            
            // View Map button overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button("View Map") {
                        showingFullScreenMap = true
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }
    
    // MARK: - Reminder Info Card
    private var reminderInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Pin icon with color coding
                ZStack {
                    Circle()
                        .fill(triggerColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(triggerColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: triggerIcon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(triggerText)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(triggerColor)
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // Status toggle
                VStack(spacing: 4) {
                    Toggle("", isOn: Binding(
                        get: { location.isEnabled },
                        set: { newValue in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                location.isEnabled = newValue
                                locationManager.updateGeofence(location)
                            }
                        }
                    ))
                    .labelsHidden()
                    
                    Text(location.isEnabled ? "Active" : "Inactive")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Location Details Card
    private var locationDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Location Details")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                detailRow(title: "Coordinates", value: coordinateString)
                detailRow(title: "Radius", value: "\(Int(location.radius))m")
                
                if !location.entryMessage.isEmpty {
                    detailRow(title: "Entry Message", value: location.entryMessage)
                }
                
                if !location.exitMessage.isEmpty {
                    detailRow(title: "Exit Message", value: location.exitMessage)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Status Card
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reminder Status")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Monitoring")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Circle()
                        .fill(location.isEnabled ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    
                    Text(location.isEnabled ? "Active" : "Paused")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(location.isEnabled ? .green : .orange)
                }
                
                HStack {
                    Text("Trigger")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(triggerText)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Notifications")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("Enabled")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Bottom Action Buttons
    private var bottomActionButtons: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Edit button
                Button(action: {
                    showingEditSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // View Map button
                Button(action: {
                    showingFullScreenMap = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.system(size: 16, weight: .semibold))
                        Text("View Map")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Delete button
            Button(action: {
                showingDeleteAlert = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Delete Reminder")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Views
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
    
    // MARK: - Computed Properties
    private var triggerColor: Color {
        location.notifyOnEntry ? .blue : .orange
    }
    
    private var triggerIcon: String {
        location.notifyOnEntry ? "arrow.down" : "arrow.up"
    }
    
    private var triggerText: String {
        location.notifyOnEntry ? "When I Arrive" : "When I Leave"
    }
    
    private var coordinateString: String {
        String(format: "%.6f, %.6f", location.latitude, location.longitude)
    }
}

// MARK: - Supporting Views

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct EditLocationView: View {
    @Binding var location: GeofenceLocation
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var reminderTitle: String
    @State private var reminderType: ReminderType
    @State private var radius: Double
    @State private var notificationMode: NotificationMode
    @FocusState private var isTextFieldFocused: Bool
    
    enum ReminderType: String, CaseIterable {
        case arrive = "When I Arrive"
        case leave = "When I Leave"
        
        var icon: String {
            switch self {
            case .arrive: return "arrow.down.circle.fill"
            case .leave: return "arrow.up.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .arrive: return .blue
            case .leave: return .orange
            }
        }
    }
    
    init(location: Binding<GeofenceLocation>) {
        self._location = location
        self._reminderTitle = State(initialValue: location.wrappedValue.name)
        self._reminderType = State(initialValue: location.wrappedValue.notifyOnEntry ? .arrive : .leave)
        self._radius = State(initialValue: location.wrappedValue.radius)
        self._notificationMode = State(initialValue: location.wrappedValue.notificationMode)
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Title Field
                    titleSection
                    
                    // Reminder Type
                    reminderTypeSection
                        .onTapGesture {
                            isTextFieldFocused = false
                        }
                    
                    // Notification Frequency
                    notificationModeSection
                        .onTapGesture {
                            isTextFieldFocused = false
                        }
                    
                    
                    // Radius Setting
                    radiusSection
                        .onTapGesture {
                            isTextFieldFocused = false
                        }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextFieldFocused = false
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextFieldFocused = false
            }
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { 
                        dismiss() 
                    }
                    .foregroundColor(.blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { 
                        saveChanges()
                    }
                    .foregroundColor(isFormValid ? .blue : .gray)
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder Title")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            TextField("What do you want to be reminded of?", text: $reminderTitle)
                .textFieldStyle(EditTextFieldStyle())
                .focused($isTextFieldFocused)
        }
    }
    
    // MARK: - Reminder Type Section
    private var reminderTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remind me")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                reminderTypeButton(for: .arrive)
                reminderTypeButton(for: .leave)
            }
        }
    }
    
    private func reminderTypeButton(for type: ReminderType) -> some View {
        let isSelected = reminderType == type
        
        return Button(action: {
            isTextFieldFocused = false // Dismiss keyboard
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                reminderType = type
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : type.color)
                
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? type.color : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(type.color.opacity(isSelected ? 1.0 : 0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    
    // MARK: - Notification Mode Section
    private var notificationModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notification Frequency")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ForEach(NotificationMode.allCases, id: \.self) { mode in
                    notificationModeButton(for: mode)
                }
            }
        }
    }
    
    private func notificationModeButton(for mode: NotificationMode) -> some View {
        let isSelected = notificationMode == mode
        
        return Button(action: {
            isTextFieldFocused = false // Dismiss keyboard
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                notificationMode = mode
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName.components(separatedBy: " (").first ?? mode.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if mode != .onceDaily {
                        Text("\(Int(mode.cooldownPeriod/60)) minute cooldown")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Maximum one notification per day")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(isSelected ? 1.0 : 0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Radius Section
    private var radiusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Detection Radius")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(radius))m")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.blue)
            }
            
            Slider(value: $radius, in: 50...500, step: 25)
                .accentColor(.blue)
                .onTapGesture {
                    isTextFieldFocused = false
                }
            
            HStack {
                Text("50m")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("500m")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Methods
    private func saveChanges() {
        var updatedLocation = location
        updatedLocation.name = reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedLocation.radius = radius
        updatedLocation.notificationMode = notificationMode
        
        // Update notification settings based on reminder type
        if reminderType == .arrive {
            updatedLocation.notifyOnEntry = true
            updatedLocation.notifyOnExit = false
            updatedLocation.entryMessage = "Reminder: \(updatedLocation.name)"
            updatedLocation.exitMessage = ""
        } else {
            updatedLocation.notifyOnEntry = false
            updatedLocation.notifyOnExit = true
            updatedLocation.exitMessage = "Reminder: \(updatedLocation.name)"
            updatedLocation.entryMessage = ""
        }
        
        // Update in location manager
        locationManager.updateGeofence(updatedLocation)
        
        // Update the binding
        location = updatedLocation
        
        dismiss()
    }
}

// MARK: - Custom Text Field Style
struct EditTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
    }
}

struct FullScreenMapView: View {
    let location: GeofenceLocation
    @Environment(\.dismiss) private var dismiss
    
    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: .constant(mapRegion), annotationItems: [MapAnnotationItem(coordinate: location.coordinate)]) { item in
                MapPin(coordinate: item.coordinate, tint: .blue)
            }
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LocationDetailView(
        location: GeofenceLocation(
            name: "Grocery Store",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 100,
            entryMessage: "Don't forget to buy milk!",
            exitMessage: ""
        )
    )
    .environmentObject(LocationManager())
}