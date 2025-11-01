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
    @EnvironmentObject private var locationManager: AnyLocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var reminderTitle = ""
    @State private var locationQuery = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedLocationName = ""
    @State private var reminderType: ReminderType = .arrive
    @State private var radius: Double = 200
    @State private var isActive: Bool = true
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var isSearching = false
    @State private var searchResults: [MKMapItem] = []
    @State private var showingLocationPicker = false
    @State private var isWaitingForLocation = false
    @State private var isFetchingLocation = false
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
    
    var body: some View {
        NavigationView {
            ZStack {
                // Clean background
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Dismiss keyboard when tapping background
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
            .navigationTitle("New Reminder")
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
                        saveReminder()
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
        .onAppear {
            // Request location update if we don't have it yet
            if locationManager.currentLocation == nil {
                isFetchingLocation = true
                // Request location permission if needed
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestLocationPermission()
                } else if locationManager.authorizationStatus == .authorizedWhenInUse || 
                          locationManager.authorizationStatus == .authorizedAlways {
                    // We have permission, request location update
                    locationManager.requestLocationUpdate()
                } else {
                    isFetchingLocation = false
                }
            } else {
                // Initialize map with current location if available
                if let currentLocation = locationManager.currentLocation {
                    let newRegion = MKCoordinateRegion(
                        center: currentLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    mapRegion = newRegion
                    cameraPosition = .region(newRegion)
                    // Auto-select current location if no coordinate is selected
                    if selectedCoordinate == nil {
                        selectedCoordinate = currentLocation.coordinate
                        setCurrentLocationWithGeocoding(currentLocation)
                    }
                }
            }
        }
        .onReceive(locationManager.$currentLocation) { location in
            // When we get a location update, update the map if we don't have a selected coordinate
            if let location = location {
                isFetchingLocation = false // Stop loading indicator
                
                if isWaitingForLocation {
                    // User explicitly requested current location
                    setCurrentLocationWithGeocoding(location)
                    isWaitingForLocation = false
                } else if selectedCoordinate == nil {
                    // No location selected yet, use current location to center map
                    let newRegion = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    mapRegion = newRegion
                    cameraPosition = .region(newRegion)
                    // Auto-select current location
                    selectedCoordinate = location.coordinate
                    setCurrentLocationWithGeocoding(location)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("LocationAuthorizationChanged"))) { _ in
            // Stop loading if permission is denied
            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                isFetchingLocation = false
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            // Stop loading if permission is denied
            if newStatus == .denied || newStatus == .restricted {
                isFetchingLocation = false
            }
        }
        .onChange(of: selectedLocationName) { _, newName in
            // Update the location query when selectedLocationName changes (from map picker)
            if !newName.isEmpty && selectedCoordinate != nil {
                locationQuery = newName
                searchResults = [] // Clear search results when location is selected via map
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
                                        
                                        // Show address if available and different from name
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
                
                // Loading indicator when fetching location
                if isFetchingLocation && locationManager.currentLocation == nil {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Finding your location...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Map View - Always show map, center on current location or selected coordinate
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
            
            // Show current location marker if available and no coordinate selected
            if selectedCoordinate == nil, let currentLocation = locationManager.currentLocation {
                Annotation("Current Location", coordinate: currentLocation.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 16, height: 16)
                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 16, height: 16)
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
        // Rough approximation: 1 degree ≈ 111,000 meters
        // This will vary by zoom level but gives a reasonable visual representation
        let degrees = radiusInMeters / 111000.0
        let spanRatio = degrees / mapRegion.span.latitudeDelta
        return CGFloat(spanRatio * 300) // 300 is approximate map view size factor
    }
    
    private func saveReminder() {
        guard let coordinate = selectedCoordinate else { return }
        
        let finalMessage = reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let location = GeofenceLocation(
            name: finalMessage,
            address: selectedLocationName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: radius,
            entryMessage: reminderType == .arrive ? finalMessage : "",
            exitMessage: reminderType == .leave ? finalMessage : "",
            notifyOnEntry: reminderType == .arrive,
            notifyOnExit: reminderType == .leave,
            isEnabled: isActive,
            notificationMode: .normal
        )
        
        locationManager.addGeofence(location)
        dismiss()
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
    
    // Helper function to format address from placemark
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
    
    private func useCurrentLocation() {
        // If we don't have current location, try to request it
        if locationManager.currentLocation == nil {
            isWaitingForLocation = true
            locationQuery = "Getting current location..."
            
            // First check if we have permission
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestLocationPermission()
            } else if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                // We have permission, request location update
                locationManager.requestLocationUpdate()
            } else {
                // No permission, show alert or request permission
                locationManager.requestLocationPermission()
                return
            }
        } else {
            // We have current location, use it immediately
            if let currentLocation = locationManager.currentLocation {
                setCurrentLocationWithGeocoding(currentLocation)
            }
        }
    }
    
    private func setCurrentLocationWithGeocoding(_ location: CLLocation) {
        selectedCoordinate = location.coordinate
        let newRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapRegion = newRegion
        cameraPosition = .region(newRegion)
        searchResults = []
        isWaitingForLocation = false
        
        // Initially show "Current Location" while geocoding
        locationQuery = "Current Location"
        selectedLocationName = "Current Location"
        
        // Perform reverse geocoding to get actual address
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    // Try to construct a meaningful name from the placemark
                    var addressName = ""
                    
                    if let name = placemark.name, !name.isEmpty {
                        addressName = name
                    } else if let thoroughfare = placemark.thoroughfare {
                        if let subThoroughfare = placemark.subThoroughfare {
                            addressName = "\(subThoroughfare) \(thoroughfare)"
                        } else {
                            addressName = thoroughfare
                        }
                    } else if let locality = placemark.locality {
                        addressName = locality
                    } else if let administrativeArea = placemark.administrativeArea {
                        addressName = administrativeArea
                    }
                    
                    if !addressName.isEmpty {
                        self.selectedLocationName = addressName
                        self.locationQuery = addressName
                    }
                    // If geocoding fails, keep "Current Location" as fallback
                }
                // If geocoding fails completely, keep "Current Location" as fallback
            }
        }
    }
}

// MARK: - Supporting Components

struct LocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedLocationName: String
    @Binding var mapRegion: MKCoordinateRegion
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: AnyLocationManager
    
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
                } else if !isMapReady {
                    // Loading state - show progress indicator
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
                        Text("Loading Interactive Map...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                    
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
                            
                            // Perform reverse geocoding to get a proper address name
                            let geocoder = CLGeocoder()
                            let location = CLLocation(latitude: currentRegion.center.latitude, longitude: currentRegion.center.longitude)
                            
                            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                                DispatchQueue.main.async {
                                    if let placemark = placemarks?.first {
                                        // Try to construct a meaningful name from the placemark
                                        var name = ""
                                        
                                        if let name_ = placemark.name, !name_.isEmpty {
                                            name = name_
                                        } else if let thoroughfare = placemark.thoroughfare {
                                            name = thoroughfare
                                            if let subThoroughfare = placemark.subThoroughfare {
                                                name = "\(subThoroughfare) \(thoroughfare)"
                                            }
                                        } else if let locality = placemark.locality {
                                            name = locality
                                        } else if let administrativeArea = placemark.administrativeArea {
                                            name = administrativeArea
                                        } else {
                                            name = "Selected Location"
                                        }
                                        
                                        selectedLocationName = name
                                    } else {
                                        selectedLocationName = "Selected Location"
                                    }
                                }
                            }
                            
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .onAppear {
                Logger.shared.debug("LocationPickerView appeared, starting map initialization", category: .ui)
                // Shorter delay for better UX while still preventing Metal crashes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Logger.shared.debug("Showing map after optimized delay", category: .ui)
                    if !mapFailedToLoad {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMapReady = true
                        }
                    }
                }
                
                // Automatic timeout after 5 seconds (reduced from 8)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
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
        .environmentObject(ServiceLocator.locationManager)
}
