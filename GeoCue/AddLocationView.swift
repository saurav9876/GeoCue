import SwiftUI
import MapKit
import UIKit

extension UIApplication {
    func endEditing(_ force: Bool) {
        if let windowScene = connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.endEditing(force)
        }
    }
}

// Simple wrapper to make CLLocationCoordinate2D identifiable
struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct AddLocationView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var reminderTitle = ""
    @State private var locationQuery = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedLocationName = ""
    @State private var reminderType: ReminderType = .arrive
    @State private var radius: Double = 100
    @State private var customMessage = ""
    @State private var notificationMode: NotificationMode = .normal
    @State private var showingAllFrequencyOptions = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isSearching = false
    @State private var searchResults: [MKMapItem] = []
    @State private var showingLocationPicker = false
    @State private var currentStep = 0
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField: Hashable {
        case title, locationQuery, customMessage
    }
    
    enum ReminderType: String, CaseIterable {
        case arrive = "Arrive"
        case leave = "Leave"
        
        var icon: String {
            switch self {
            case .arrive: return "arrow.down.circle.fill"
            case .leave: return "arrow.up.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .arrive: return .green
            case .leave: return .orange
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Clean background
            Color(.systemBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    // Safely dismiss keyboard when tapping background
                    Task { @MainActor in
                        UIApplication.shared.endEditing(true)
                    }
                }
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Title Field
                        titleSection
                        
                        // Location Search
                        locationSearchSection
                        
                        // Map View
                        if selectedCoordinate != nil {
                            mapSection
                        }
                        
                        // Reminder Type
                        reminderTypeSection
                        
                        // Notification Frequency
                        notificationFrequencySection
                        
                        // Custom Message (Optional)
                        customMessageSection
                        
                        // Save/Skip Buttons
                        actionButtonsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(
                selectedCoordinate: $selectedCoordinate,
                selectedLocationName: $selectedLocationName,
                mapRegion: $mapRegion
            )
        }
        .onAppear {
            if let currentLocation = locationManager.currentLocation {
                mapRegion.center = currentLocation.coordinate
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.primary)
            
            Spacer()
            
            Text("Add Reminder")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Done") {
                saveReminder()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isFormValid ? .blue : .gray)
            .disabled(!isFormValid)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder Title")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            TextField("What do you want to be reminded of?", text: $reminderTitle)
                .textFieldStyle(ModernTextFieldStyle())
        }
    }
    
    // MARK: - Location Search Section
    private var locationSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search for a place or address", text: $locationQuery)
                        .onChange(of: locationQuery) { _, newValue in
                            performLocationSearch()
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
                
                // Current location button
                Button(action: useCurrentLocation) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text("Use Current Location")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Search results
                if !searchResults.isEmpty {
                    ForEach(searchResults.prefix(3), id: \.self) { result in
                        Button(action: {
                            selectLocation(result)
                        }) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(result.name ?? "Unknown")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    if let address = result.placemark.title {
                                        Text(address)
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Location")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Change") {
                    showingLocationPicker = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
            
            ZStack {
                // Interactive map preview with safety measures
                if let coordinate = selectedCoordinate {
                    Map {
                        Annotation(selectedLocationName, coordinate: coordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title)
                                .background(
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 20, height: 20)
                                )
                        }
                    }
                    .mapStyle(.standard)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .disabled(true)
                    .allowsHitTesting(false)
                } else {
                    // Fallback when no coordinate is selected
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "mappin.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                
                                Text("No Location Selected")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                Text("Tap 'Change' to choose a location")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        )
                }
                
                // Location info overlay
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tap 'Change' to adjust")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(16)
                }
            }
        }
    }
    
    // MARK: - Reminder Type Section
    private var reminderTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remind me when I")
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                reminderType = type
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : type.color)
                
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundFor(type: type, isSelected: isSelected))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? type.color : type.color.opacity(0.3), lineWidth: 1.5)
            )
        }
    }
    
    @ViewBuilder
    private func backgroundFor(type: ReminderType, isSelected: Bool) -> some View {
        if isSelected {
            type.color
        } else {
            Rectangle()
                .fill(Material.ultraThinMaterial)
        }
    }
    
    // MARK: - Notification Frequency Section
    private var notificationFrequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Notification Frequency")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                // Default selected frequency
                Button(action: {
                    if showingAllFrequencyOptions {
                        showingAllFrequencyOptions = false
                    } else {
                        showingAllFrequencyOptions = true
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notificationMode.displayName.components(separatedBy: " (").first ?? notificationMode.displayName)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text(getFrequencyDescription(for: notificationMode))
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: showingAllFrequencyOptions ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // All frequency options (shown when expanded)
                if showingAllFrequencyOptions {
                    VStack(spacing: 8) {
                        ForEach(NotificationMode.allCases, id: \.self) { mode in
                            Button(action: {
                                notificationMode = mode
                                showingAllFrequencyOptions = false
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mode.displayName.components(separatedBy: " (").first ?? mode.displayName)
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.primary)
                                        
                                        Text(getFrequencyDescription(for: mode))
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if notificationMode == mode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(notificationMode == mode ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(notificationMode == mode ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.2), value: showingAllFrequencyOptions)
                }
            }
        }
    }
    
    // MARK: - Custom Message Section
    private var customMessageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Message (Optional)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            TextField("Add a custom reminder message...", text: $customMessage, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(ModernTextFieldStyle())
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Save reminder button
            Button("Save Reminder") {
                saveReminder()
            }
            .buttonStyle(PrimaryActionButtonStyle(isEnabled: isFormValid))
            .disabled(!isFormValid)
            
            // Skip for now button
            Button("Skip for Now") {
                dismiss()
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(.top, 20)
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedCoordinate != nil
    }
    
    // MARK: - Methods
    private func getFrequencyDescription(for mode: NotificationMode) -> String {
        switch mode {
        case .normal:
            return "Notify again after 30 minutes away"
        case .quiet:
            return "Notify again after 2 hours away"
        case .frequent:
            return "Notify again after 15 minutes away"
        case .onceDaily:
            return "Only notify once per day"
        }
    }
    
    private func saveReminder() {
        guard let coordinate = selectedCoordinate else { return }
        
        let finalMessage = customMessage.isEmpty ? "\(reminderType.rawValue) at \(selectedLocationName)" : customMessage
        
        let location = GeofenceLocation(
            name: reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: radius,
            entryMessage: reminderType == .arrive ? finalMessage : "",
            exitMessage: reminderType == .leave ? finalMessage : "",
            notifyOnEntry: reminderType == .arrive,
            notifyOnExit: reminderType == .leave,
            notificationMode: notificationMode
        )
        
        locationManager.addGeofence(location)
        dismiss()
    }
    
    private func performLocationSearch() {
        guard !locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationQuery
        request.region = mapRegion
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let response = response {
                    searchResults = Array(response.mapItems.prefix(5))
                } else {
                    searchResults = []
                }
            }
        }
    }
    
    private func selectLocation(_ mapItem: MKMapItem) {
        selectedCoordinate = mapItem.placemark.coordinate
        selectedLocationName = mapItem.name ?? "Selected Location"
        mapRegion.center = mapItem.placemark.coordinate
        mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        
        locationQuery = mapItem.name ?? ""
        searchResults = []
    }
    
    private func useCurrentLocation() {
        guard let currentLocation = locationManager.currentLocation else { return }
        
        selectedCoordinate = currentLocation.coordinate
        selectedLocationName = "Current Location"
        mapRegion.center = currentLocation.coordinate
        mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        
        locationQuery = "Current Location"
        searchResults = []
    }
}

// MARK: - Supporting Components

struct LocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedLocationName: String
    @Binding var mapRegion: MKCoordinateRegion
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    
    @State private var cameraPosition: MapCameraPosition
    @State private var isMapReady = false
    @State private var mapFailedToLoad = false
    
    init(selectedCoordinate: Binding<CLLocationCoordinate2D?>, selectedLocationName: Binding<String>, mapRegion: Binding<MKCoordinateRegion>) {
        self._selectedCoordinate = selectedCoordinate
        self._selectedLocationName = selectedLocationName
        self._mapRegion = mapRegion
        
        // Validate and sanitize the map region to prevent NaN errors
        let safeRegion = Self.validateMapRegion(mapRegion.wrappedValue)
        self._mapRegion = mapRegion
        
        // Initialize camera position with safe region
        self._cameraPosition = State(initialValue: .region(safeRegion))
    }
    
    // Helper function to validate map region and prevent NaN values
    static func validateMapRegion(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        let safeLatitude = region.center.latitude.isNaN || region.center.latitude.isInfinite ? 37.7749 : region.center.latitude
        let safeLongitude = region.center.longitude.isNaN || region.center.longitude.isInfinite ? -122.4194 : region.center.longitude
        let safeLatitudeDelta = region.span.latitudeDelta.isNaN || region.span.latitudeDelta.isInfinite || region.span.latitudeDelta <= 0 ? 0.01 : region.span.latitudeDelta
        let safeLongitudeDelta = region.span.longitudeDelta.isNaN || region.span.longitudeDelta.isInfinite || region.span.longitudeDelta <= 0 ? 0.01 : region.span.longitudeDelta
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: safeLatitude, longitude: safeLongitude),
            span: MKCoordinateSpan(latitudeDelta: safeLatitudeDelta, longitudeDelta: safeLongitudeDelta)
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Safe background
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                if mapFailedToLoad {
                    // Fallback: Manual coordinate entry
                    VStack(spacing: 30) {
                        VStack(spacing: 16) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("Map Not Available")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Use the buttons below to select a location")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 16) {
                            Button("Use Current Location") {
                                if let currentLocation = locationManager.currentLocation {
                                    selectedCoordinate = currentLocation.coordinate
                                    selectedLocationName = "Current Location"
                                    mapRegion = MKCoordinateRegion(
                                        center: currentLocation.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )
                                    dismiss()
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle(isEnabled: locationManager.currentLocation != nil))
                            .disabled(locationManager.currentLocation == nil)
                            
                            Text("Manual coordinate entry and other location selection methods coming soon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(40)
                } else if isMapReady {
                    // Conservative map implementation with minimal features
                    Map(position: $cameraPosition)
                        .mapStyle(.standard)
                        .disabled(false)
                        .onMapCameraChange(frequency: .continuous) { context in
                            // Very conservative region updates with NaN validation
                            Task { @MainActor in
                                let safeRegion = Self.validateMapRegion(context.region)
                                mapRegion = safeRegion
                                print("🗺️ Map camera changed to safe region: lat=\(safeRegion.center.latitude), lng=\(safeRegion.center.longitude)")
                            }
                        }
                        .onAppear {
                            print("🗺️ LocationPicker Map appeared")
                        }
                        .onDisappear {
                            print("🗺️ LocationPicker Map disappeared")
                        }
                } else {
                    // Extended loading state with timeout
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading Interactive Map...")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Please wait while we prepare the map interface")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button("Skip Map Loading") {
                            mapFailedToLoad = true
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.top, 10)
                    }
                    .padding(40)
                }
                
                // Center crosshair
                VStack {
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                        .background(
                            Circle()
                                .fill(.white)
                                .frame(width: 40, height: 40)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                    Spacer()
                }
                
                // Top instruction banner
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose Location")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Drag map to position crosshair")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    
                    Spacer()
                }
                
                // Bottom action buttons
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Button("Use This Location") {
                            // Extract region from camera position
                            let currentRegion = mapRegion
                            selectedCoordinate = currentRegion.center
                            selectedLocationName = "Selected Location"
                            dismiss()
                        }
                        .buttonStyle(PrimaryActionButtonStyle(isEnabled: true))
                        
                        HStack(spacing: 12) {
                            Button("Current Location") {
                                if let currentLocation = locationManager.currentLocation {
                                    let newRegion = MKCoordinateRegion(
                                        center: currentLocation.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )
                                    cameraPosition = .region(newRegion)
                                    selectedCoordinate = currentLocation.coordinate
                                    selectedLocationName = "Current Location"
                                    mapRegion = newRegion
                                    dismiss()
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                            .disabled(locationManager.currentLocation == nil)
                            
                            Button("Cancel") {
                                dismiss()
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .onAppear {
                Logger.shared.debug("LocationPickerView appeared, starting map initialization", category: .ui)
                // Much longer delay to prevent Metal crashes
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    Logger.shared.debug("Showing map after delay", category: .ui)
                    if !mapFailedToLoad {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            isMapReady = true
                        }
                    }
                }
                
                // Automatic timeout after 8 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                    if !isMapReady && !mapFailedToLoad {
                        print("🗺️ Map loading timeout, switching to fallback mode")
                        mapFailedToLoad = true
                    }
                }
            }
            .onDisappear {
                print("🗺️ LocationPickerView disappearing, performing cleanup...")
                // Immediate cleanup to prevent Metal issues
                isMapReady = false
                
                // Additional cleanup with delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🗺️ Metal cleanup completed")
                }
            }
        }
    }
    
}

// MARK: - Custom Styles

struct ModernTextFieldStyle: TextFieldStyle {
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
            .submitLabel(.done)
            .onSubmit {
                // Safely dismiss keyboard with better error handling
                Task { @MainActor in
                    UIApplication.shared.endEditing(true)
                }
            }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                isEnabled ? 
                LinearGradient(
                    gradient: Gradient(colors: [
                        .blue,
                        .blue
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                LinearGradient(
                    gradient: Gradient(colors: [Color.gray, Color.gray]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: isEnabled ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.blue.opacity(0.3), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#Preview {
    AddLocationView()
        .environmentObject(LocationManager())
}