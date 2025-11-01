import SwiftUI
import MapKit

struct LocationDetailView: View {
    @EnvironmentObject private var locationManager: AnyLocationManager
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
                ToolbarItem(placement: .topBarTrailing) {
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
    @EnvironmentObject private var locationManager: AnyLocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var reminderTitle: String
    @State private var reminderType: ReminderType
    @State private var radius: Double
    @State private var isActive: Bool
    @State private var locationQuery: String = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedLocationName: String = ""
    @State private var mapRegion: MKCoordinateRegion
    @State private var cameraPosition: MapCameraPosition
    @State private var isSearching = false
    @State private var searchResults: [MKMapItem] = []
    @State private var showingLocationPicker = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField: Hashable {
        case title, locationQuery
    }
    
    enum ReminderType: String, CaseIterable {
        case arrive = "On Entry"
        case leave = "On Exit"
        
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
    
    init(location: Binding<GeofenceLocation>) {
        self._location = location
        self._reminderTitle = State(initialValue: location.wrappedValue.name)
        self._reminderType = State(initialValue: location.wrappedValue.notifyOnEntry ? .arrive : .leave)
        self._radius = State(initialValue: location.wrappedValue.radius)
        self._isActive = State(initialValue: location.wrappedValue.isEnabled)
        
        let coord = location.wrappedValue.coordinate
        let region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        self._mapRegion = State(initialValue: region)
        self._cameraPosition = State(initialValue: .region(region))
        self._selectedCoordinate = State(initialValue: coord)
        self._selectedLocationName = State(initialValue: location.wrappedValue.address.isEmpty ? location.wrappedValue.name : location.wrappedValue.address)
        self._locationQuery = State(initialValue: location.wrappedValue.address.isEmpty ? location.wrappedValue.name : location.wrappedValue.address)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Clean background
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        focusedField = nil
                        Task { @MainActor in
                            UIApplication.shared.endEditing(true)
                        }
                    }
                
                VStack(spacing: 0) {
                    // Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 32) {
                            // REMINDER Section
                            reminderSection
                            
                            // TRIGGER Section
                            triggerSection
                            
                            // LOCATION Section
                            locationSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = nil
                        }
                    }
                }
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
                    .disabled(!isFormValid)
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
        .onChange(of: selectedLocationName) { _, newName in
            if !newName.isEmpty && selectedCoordinate != nil {
                locationQuery = newName
                searchResults = []
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onDisappear {
            // Cancel any ongoing search when view disappears
            searchTask?.cancel()
        }
    }
    
    // MARK: - Reminder Section
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("REMINDER")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            // Form Fields
            VStack(spacing: 0) {
                // Title Field
                TextField("Title", text: $reminderTitle)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.primary)
                    .focused($focusedField, equals: .title)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Trigger Section
    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("TRIGGER")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            // Form Fields
            VStack(spacing: 0) {
                // Trigger Type
                Button(action: {
                    focusedField = nil
                    // Toggle between On Entry and On Exit
                    reminderType = reminderType == .arrive ? .leave : .arrive
                }) {
                    HStack {
                        Text("Trigger")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(reminderType.rawValue)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                // Divider
                Divider()
                    .padding(.horizontal, 16)
                
                // Active Toggle
                HStack {
                    Text("Active")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Toggle("", isOn: $isActive)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Location Section
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("LOCATION")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            VStack(spacing: 16) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search for a place", text: $locationQuery)
                        .focused($focusedField, equals: .locationQuery)
                        .onChange(of: locationQuery) { _, newValue in
                            performLocationSearchDebounced()
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    // Clear button
                    if !locationQuery.isEmpty {
                        Button(action: {
                            searchTask?.cancel()
                            locationQuery = ""
                            searchResults = []
                            isSearching = false
                            focusedField = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Search Results List
                if !searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(searchResults.enumerated()), id: \.offset) { index, mapItem in
                            Button(action: {
                                selectLocation(mapItem)
                                focusedField = nil
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 20))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mapItem.name ?? "Unknown Location")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        if let address = getAddressString(from: mapItem), address != mapItem.name {
                                            Text(address)
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                            }
                            
                            if index < searchResults.count - 1 {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Map View
                mapSection
                
                // Radius Controls
                if selectedCoordinate != nil {
                    HStack {
                        Text("Radius: \(Int(radius))m")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                if radius > 50 {
                                    radius -= 50
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 32, height: 32)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                            }
                            .disabled(radius <= 50)
                            
                            Button(action: {
                                if radius < 1000 {
                                    radius += 50
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 32, height: 32)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                            }
                            .disabled(radius >= 1000)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Map Section
    private var mapSection: some View {
        Map(position: $cameraPosition) {
            // Show selected coordinate if available
            if let coordinate = selectedCoordinate {
                Annotation("Reminder", coordinate: coordinate) {
                    ZStack {
                        // Geofence circle
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: radiusToMapPoints(radius * 2), height: radiusToMapPoints(radius * 2))
                        
                        // Center pin
                        Image(systemName: "mappin")
                            .foregroundColor(.red)
                            .font(.title)
                            .background(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 12, height: 12)
                            )
                    }
                }
            }
        }
        .mapStyle(.standard)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            showingLocationPicker = true
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            mapRegion = context.region
        }
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedCoordinate != nil
    }
    
    // MARK: - Methods
    
    // Convert radius in meters to approximate map points
    private func radiusToMapPoints(_ radiusInMeters: Double) -> CGFloat {
        let degrees = radiusInMeters / 111000.0
        let spanRatio = degrees / mapRegion.span.latitudeDelta
        return CGFloat(spanRatio * 300)
    }
    
    // Debounced search function to avoid too many API calls
    private func performLocationSearchDebounced() {
        // Cancel any previous search task
        searchTask?.cancel()
        
        let trimmedQuery = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty, trimmedQuery.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        
        // Create a new search task with debounce delay
        searchTask = Task {
            // Wait 400ms before performing search (debounce)
            try? await Task.sleep(nanoseconds: 400_000_000)
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                performLocationSearch(query: trimmedQuery)
            }
        }
    }
    
    private func performLocationSearch(query: String) {
        isSearching = true
        
        // Use a much wider search region - search globally if needed
        // Apple's MKLocalSearch works better with a region, but we'll make it very large
        var searchRegion: MKCoordinateRegion
        
        if let currentLocation = locationManager.currentLocation {
            // Use a very large region centered on current location to get global results
            // This allows finding locations anywhere while still prioritizing nearby results
            searchRegion = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360) // Effectively global
            )
        } else {
            // If no current location, use a global region
            searchRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            )
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = searchRegion
        // Include all result types for comprehensive search
        request.resultTypes = [.pointOfInterest, .address]
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    // Silently handle search errors - just clear results
                    self.searchResults = []
                    return
                }
                
                if let response = response {
                    // Filter out results with invalid coordinates
                    var validResults = response.mapItems.filter { item in
                        let coord = item.placemark.coordinate
                        return !coord.latitude.isNaN && !coord.longitude.isNaN &&
                               coord.latitude >= -90 && coord.latitude <= 90 &&
                               coord.longitude >= -180 && coord.longitude <= 180
                    }
                    
                    // Sort results by relevance:
                    // 1. Exact name matches first
                    // 2. Name starts with query
                    // 3. Name contains query
                    // 4. Then by distance from current location if available
                    validResults.sort { item1, item2 in
                        let queryLower = query.lowercased()
                        let name1 = (item1.name ?? "").lowercased()
                        let name2 = (item2.name ?? "").lowercased()
                        
                        // Exact match check
                        let exactMatch1 = name1 == queryLower
                        let exactMatch2 = name2 == queryLower
                        if exactMatch1 != exactMatch2 {
                            return exactMatch1
                        }
                        
                        // Starts with check
                        let startsWith1 = name1.hasPrefix(queryLower)
                        let startsWith2 = name2.hasPrefix(queryLower)
                        if startsWith1 != startsWith2 {
                            return startsWith1
                        }
                        
                        // Contains check
                        let contains1 = name1.contains(queryLower)
                        let contains2 = name2.contains(queryLower)
                        if contains1 != contains2 {
                            return contains1
                        }
                        
                        // If both match equally, sort by distance if we have current location
                        if let currentLocation = self.locationManager.currentLocation {
                            let distance1 = CLLocation(
                                latitude: item1.placemark.coordinate.latitude,
                                longitude: item1.placemark.coordinate.longitude
                            ).distance(from: currentLocation)
                            
                            let distance2 = CLLocation(
                                latitude: item2.placemark.coordinate.latitude,
                                longitude: item2.placemark.coordinate.longitude
                            ).distance(from: currentLocation)
                            
                            return distance1 < distance2
                        }
                        
                        return false
                    }
                    
                    // Show up to 15 results for better discoverability
                    self.searchResults = Array(validResults.prefix(15))
                } else {
                    self.searchResults = []
                }
            }
        }
    }
    
    private func selectLocation(_ mapItem: MKMapItem) {
        selectedCoordinate = mapItem.placemark.coordinate
        selectedLocationName = mapItem.name ?? "Selected Location"
        let newRegion = MKCoordinateRegion(
            center: mapItem.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapRegion = newRegion
        cameraPosition = .region(newRegion)
        
        locationQuery = mapItem.name ?? ""
        searchResults = []
    }
    
    private func getAddressString(from mapItem: MKMapItem) -> String? {
        let placemark = mapItem.placemark
        var addressComponents: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            var street = thoroughfare
            if let subThoroughfare = placemark.subThoroughfare {
                street = "\(subThoroughfare) \(thoroughfare)"
            }
            addressComponents.append(street)
        }
        
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        let address = addressComponents.joined(separator: ", ")
        return address.isEmpty ? nil : address
    }
    
    private func saveChanges() {
        guard let coordinate = selectedCoordinate else { return }
        
        var updatedLocation = location
        updatedLocation.name = reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedLocation.address = selectedLocationName
        updatedLocation.latitude = coordinate.latitude
        updatedLocation.longitude = coordinate.longitude
        updatedLocation.radius = radius
        updatedLocation.notificationMode = .normal
        updatedLocation.isEnabled = isActive
        
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
                ToolbarItem(placement: .topBarTrailing) {
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
    .environmentObject(ServiceLocator.locationManager)
}
