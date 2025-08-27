import SwiftUI
import MapKit
import Combine
import CoreLocation
import UIKit

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @EnvironmentObject private var notificationEscalator: NotificationEscalator
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.ringtoneService) private var ringtoneService
    @State private var showingSubscription = false
    @State private var showingSettings = false
    @State private var selectedLocation: GeofenceLocation?
    @State private var selectedTab = 0
    @State private var showingAddLocation = false
    @State private var mapRegion: MKCoordinateRegion

    init() {
        _mapRegion = State(initialValue: Self.initialMapRegion(locationManager: LocationManager()))
    }

    private static func initialMapRegion(locationManager: LocationManager) -> MKCoordinateRegion {
        if let location = locationManager.currentLocation {
            return MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab - Reminders List
            NavigationView {
                remindersListView
                    .navigationTitle("My Reminders")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showingAddLocation = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
            }
            .tag(0)
            .tabItem {
                Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                Text("Home")
            }
            
            // Map Tab - Map View
            mapView
            .tag(1)
            .tabItem {
                Image(systemName: selectedTab == 1 ? "map.fill" : "map")
                Text("Map")
            }
            
            // Settings Tab - Settings View
            NavigationView {
                settingsView
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tag(2)
            .tabItem {
                Image(systemName: selectedTab == 2 ? "gearshape.fill" : "gearshape")
                Text("Settings")
            }
        }
        .accentColor(.blue)
        .onChange(of: selectedTab) { _, newTab in
            // When switching to map tab (tab 1), center on user location
            if newTab == 1 {
                centerMapOnUserLocationOnly()
                
                if locationManager.currentLocation == nil {
                    locationManager.requestLocationUpdate()
                }
            }
        }
        .sheet(item: $selectedLocation) { location in
            LocationDetailView(location: location)
        }
        .sheet(isPresented: $showingAddLocation) {
            AddLocationView()
        }
        .alert("Location Permission Required", isPresented: $locationManager.showingLocationPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Try Again") {
                locationManager.retryPermissionRequest()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if !locationManager.isLocationServicesEnabled() {
                Text("Location Services are disabled. Please enable them in Settings > Privacy & Security > Location Services.")
            } else {
                Text("GeoCue needs 'Always' location permission to monitor geofences in the background. Please enable it in Settings > Privacy & Security > Location Services > GeoCue.")
            }
        }
        .onAppear {
            Logger.shared.info("ContentView appeared", category: .general)
            setupApp()
            if let location = locationManager.currentLocation {
                mapRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
    }
    
    // MARK: - Reminders List View (Home Tab)
    private var remindersListView: some View {
        Group {
            if locationManager.geofenceLocations.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    // Permission banner if needed
                    if !locationManager.canAddGeofences() {
                        permissionBannerView
                    }
                    
                    // Reminders content
                    remindersListContent
                }
            }
        }
    }
    
    private var remindersListContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 20) {
                // Organized sections
                let activeReminders = locationManager.geofenceLocations.filter { $0.isEnabled }
                let inactiveReminders = locationManager.geofenceLocations.filter { !$0.isEnabled }
                
                if !activeReminders.isEmpty {
                    reminderSection(title: "Active Reminders", 
                                   count: activeReminders.count, 
                                   color: .blue, 
                                   locations: activeReminders)
                }
                
                if !inactiveReminders.isEmpty {
                    reminderSection(title: "Inactive Reminders", 
                                   count: inactiveReminders.count, 
                                   color: .gray, 
                                   locations: inactiveReminders)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
    

    
    private func reminderSection(title: String, count: Int, color: Color, locations: [GeofenceLocation]) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(color)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            LazyVStack(spacing: 12) {
                ForEach(locations) { location in
                    SimpleLocationRowView(location: location) {
                        selectedLocation = location
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 40) {
            // Permission banner if needed
            if !locationManager.canAddGeofences() {
                permissionBannerView
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Illustration: map pin
            VStack(spacing: 20) {
                ZStack {
                    // Background glow
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .blur(radius: 15)
                    
                    // Map pin icon
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 80, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            // Text content
            VStack(spacing: 16) {
                Text("No reminders yet — create one to get started!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                if !locationManager.canAddGeofences() {
                    Text("Enable location permissions to create location-based reminders")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            // Create Reminder button
            Button("Create Reminder") {
                if !locationManager.canAddGeofences() {
                    // Request permission first
                    locationManager.requestLocationPermission()
                } else {
                    showingAddLocation = true
                }
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Permission Banner View
    private var permissionBannerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "location.slash")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Access Required")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Enable location permissions to create and monitor reminders")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Enable") {
                    locationManager.requestLocationPermission()
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Map View
    private var mapView: some View {
        ZStack {
            // Interactive map (light Apple Maps style)
            mapWithAnnotations
                .mapStyle(.standard)
                .ignoresSafeArea(.container, edges: .top)
            
            // Permission banner overlay if needed
            if !locationManager.canAddGeofences() {
                VStack {
                    permissionBannerView
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                    Spacer()
                }
            }
            
            // Floating Action Button (FAB) for adding new reminder
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    Button(action: {
                        if !locationManager.canAddGeofences() {
                            locationManager.requestLocationPermission()
                        } else {
                            showingAddLocation = true
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 120)
                }
            }
            
            // My Location button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        centerMapOnUserLocationOnly()
                    }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 20)
                    .disabled(!locationManager.canStartLocationUpdates())
                    .opacity(locationManager.canStartLocationUpdates() ? 1.0 : 0.5)
                }
                
                Spacer()
            }
            .padding(.top, 60)
        }
    }
    
    // MARK: - Interactive Map with Safety Measures
    private var mapWithAnnotations: some View {
        ZStack {
            // Modern Map implementation with safety measures
            Map {
                // User location
                if let currentLocation = locationManager.currentLocation {
                    Annotation("You", coordinate: currentLocation.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 20, height: 20)
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                
                // Geofence locations
                ForEach(locationManager.geofenceLocations) { location in
                    Annotation(location.name, coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                        Button(action: {
                            selectedLocation = location
                        }) {
                            ZStack {
                                Circle()
                                    .fill(pinColor(for: location))
                                    .frame(width: 30, height: 30)
                                
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onAppear {
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    centerMapOnCurrentLocation()
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                // Update map region conservatively with NaN validation
                DispatchQueue.main.async {
                    let safeRegion = validateMapRegion(context.region)
                    mapRegion = safeRegion
                }
            }
        }
        .clipped()
    }
    

    
    // Helper function for pin colors
    private func pinColor(for location: GeofenceLocation) -> Color {
        if location.notifyOnEntry {
            return Color.blue  // Blue for "Arrive"
        } else {
            return Color.orange  // Orange for "Leave"
        }
    }
    
    // MARK: - Settings View
    private var settingsView: some View {
        ScrollView {
                            VStack(spacing: 24) {
                    subscriptionSection
                    notificationStylesSection
                    themeSettingsSection
                    appInfoSection
                    privacySection
                    onboardingSection
                }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Settings Sections
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("App Information")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                NavigationLink(destination: ReleaseNotesView()) {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Version & Release Notes")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
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
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
                
                Text("Privacy")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                NavigationLink(destination: PrivacyNoticeView()) {
                    HStack {
                        Image(systemName: "doc.plaintext")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy Notice")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("How we handle your data")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
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
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yellow)
                
                Text("Premium Subscription")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                if subscriptionManager.isSubscribed {
                    // Active subscription
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active Subscription")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.green)
                            
                            if let planType = subscriptionManager.currentPlanType {
                                Text("\(planType.displayName) Plan")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            if let expirationInfo = subscriptionManager.subscriptionExpirationInfo {
                                Text(expirationInfo)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // No subscription
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unlock Premium Features")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Get unlimited locations, advanced notifications, and more")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Button("Upgrade") {
                            showingSubscription = true
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
    }
    
    private var notificationStylesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Notification Styles")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                // Notification Styles
                NavigationLink(destination: NotificationPreferencesView()) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Customize Notification Styles")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Set default styles and customize by priority")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
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
                
                // Ringtone Selection
                NavigationLink(destination: RingtoneSelectionView()) {
                    HStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Choose Notification Sounds")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Select from system sounds or BBC audio files")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
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
                
                // Notification Diagnostics
                NavigationLink(destination: NotificationDiagnosticsView()) {
                    HStack {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notification Diagnostics")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Test notifications and check permissions")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
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
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var onboardingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.purple)
                
                Text("Onboarding")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    onboardingManager.resetOnboarding()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset Onboarding")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Show onboarding guide again")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
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
            }
        }
        .padding(.horizontal, 20)
    }
    
    
    private var themeSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "paintbrush")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Appearance")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(themeManager.currentTheme.displayName)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("Theme", selection: $themeManager.currentTheme) {
                        ForEach(themeManager.allThemes, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Methods
    private func toggleAllGeofences() {
        let allEnabled = locationManager.geofenceLocations.allSatisfy(\.isEnabled)
        
        for location in locationManager.geofenceLocations {
            var updatedLocation = location
            updatedLocation.isEnabled = !allEnabled
            locationManager.updateGeofence(updatedLocation)
        }
    }
    
    private func centerMapOnCurrentLocation() {
        guard let currentLocation = locationManager.currentLocation else { return }
        
        let allLocations = locationManager.geofenceLocations
        
        if allLocations.isEmpty {
            // If no reminders, just center on user location
            let safeRegion = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            let validatedRegion = validateMapRegion(safeRegion)
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                mapRegion = validatedRegion
            }
        } else {
            // Calculate region that includes user location and all reminders
            var minLat = currentLocation.coordinate.latitude
            var maxLat = currentLocation.coordinate.latitude
            var minLon = currentLocation.coordinate.longitude
            var maxLon = currentLocation.coordinate.longitude
            
            for location in allLocations {
                // Validate each location's coordinates
                if !location.latitude.isNaN && !location.latitude.isInfinite {
                    minLat = min(minLat, location.latitude)
                    maxLat = max(maxLat, location.latitude)
                }
                if !location.longitude.isNaN && !location.longitude.isInfinite {
                    minLon = min(minLon, location.longitude)
                    maxLon = max(maxLon, location.longitude)
                }
            }
            
            // Add some padding around the bounds with NaN protection
            let rawLatDelta = (maxLat - minLat) * 1.4
            let rawLonDelta = (maxLon - minLon) * 1.4
            let latDelta = max(rawLatDelta.isNaN || rawLatDelta.isInfinite ? 0.01 : rawLatDelta, 0.01)
            let lonDelta = max(rawLonDelta.isNaN || rawLonDelta.isInfinite ? 0.01 : rawLonDelta, 0.01)
            
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            
            let calculatedRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
            let validatedRegion = validateMapRegion(calculatedRegion)
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                mapRegion = validatedRegion
            }
        }
    }
    
    private func updateMapToUserLocation() {
        centerMapOnCurrentLocation()
    }
    
    private func centerMapOnUserLocationOnly() {
        guard let currentLocation = locationManager.currentLocation else { 
            if locationManager.canStartLocationUpdates() {
                locationManager.startLocationUpdates()
            }
            return 
        }
        
        // Always center on user location with appropriate zoom
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            mapRegion.center = currentLocation.coordinate
            mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }
    }
    
    // Convert radius in meters to approximate map points
    private func radiusToMapPoints(_ radiusInMeters: Double) -> CGFloat {
        // Rough approximation: 1 degree ≈ 111,000 meters
        // This will vary by zoom level but gives a reasonable visual representation
        let degrees = radiusInMeters / 111000.0
        let spanRatio = degrees / mapRegion.span.latitudeDelta
        return CGFloat(spanRatio * 300) // 300 is approximate map view size factor
    }
    
    // Helper function to validate map region and prevent NaN values
    private func validateMapRegion(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        let safeLatitude = region.center.latitude.isNaN || region.center.latitude.isInfinite ? 37.7749 : region.center.latitude
        let safeLongitude = region.center.longitude.isNaN || region.center.longitude.isInfinite ? -122.4194 : region.center.longitude
        let safeLatitudeDelta = region.span.latitudeDelta.isNaN || region.span.latitudeDelta.isInfinite || region.span.latitudeDelta <= 0 ? 0.01 : region.span.latitudeDelta
        let safeLongitudeDelta = region.span.longitudeDelta.isNaN || region.span.longitudeDelta.isInfinite || region.span.longitudeDelta <= 0 ? 0.01 : region.span.longitudeDelta
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: safeLatitude, longitude: safeLongitude),
            span: MKCoordinateSpan(latitudeDelta: safeLatitudeDelta, longitudeDelta: safeLongitudeDelta)
        )
    }
    
    // MARK: - Lifecycle
    private func setupApp() {
        updateMapToUserLocation()
    }
    
}


// MARK: - Simple Location Row View
struct SimpleLocationRowView: View {
    let location: GeofenceLocation
    let onTap: () -> Void
    
    @EnvironmentObject private var locationManager: LocationManager
    @State private var locationName: String = ""
    
    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            let location = CLLocation(latitude: location.latitude, longitude: location.longitude)
            LocationNameCache.shared.locationName(for: location) { name in
                locationName = name
            }
        }
    }
    
    private var cardContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statusIndicator
                mainContent
                Spacer()
                rightSideControls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .opacity(location.isEnabled ? 1.0 : 0.6)
        .background(cardBackground)
        .overlay(cardBorder)
    }
    
    private var statusIndicator: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(location.isEnabled ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(location.isEnabled ? .blue : .gray)
            }
            
            triggerBadge
        }
    }
    
    private var triggerBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: triggerIcon(for: location))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
            
            Text(triggerText(for: location))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(triggerColor(for: location))
        .clipShape(Capsule())
    }
    
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(location.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(location.isEnabled ? .primary : .secondary)
                .lineLimit(1)
            
            Text(locationName.isEmpty ? "Loading location..." : locationName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            messagePreview
        }
    }
    
    private var messagePreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            if location.notifyOnEntry && !location.entryMessage.isEmpty {
                messageRow(icon: "arrow.down.circle.fill", color: .blue, message: location.entryMessage)
            }
            
            if location.notifyOnExit && !location.exitMessage.isEmpty {
                messageRow(icon: "arrow.up.circle.fill", color: .orange, message: location.exitMessage)
            }
        }
    }
    
    private func messageRow(icon: String, color: Color, message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    private var rightSideControls: some View {
        VStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { location.isEnabled },
                set: { newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        var updatedLocation = location
                        updatedLocation.isEnabled = newValue
                        locationManager.updateGeofence(updatedLocation)
                    }
                }
            ))
            .labelsHidden()
            .scaleEffect(0.8)
            
            statsSection
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 2) {
            Text(frequencyText(for: location))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            
            let stats = locationManager.getNotificationStats(for: location)
            if stats.totalCount > 0 {
                Text("\(stats.totalCount) sent")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(location.isEnabled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1), lineWidth: 1)
    }
    
    
    
    private func frequencyText(for location: GeofenceLocation) -> String {
        switch location.notificationMode {
        case .normal:
            return "Normal"
        case .frequent:
            return "Frequent"
        case .quiet:
            return "Quiet"
        case .onceDaily:
            return "Daily"
        }
    }
    
    private func triggerIcon(for location: GeofenceLocation) -> String {
        if location.notifyOnEntry {
            return "arrow.down"
        } else {
            return "arrow.up"
        }
    }
    
    private func triggerText(for location: GeofenceLocation) -> String {
        if location.notifyOnEntry {
            return "Arrive"
        } else {
            return "Leave"
        }
    }
    
    private func triggerColor(for location: GeofenceLocation) -> Color {
        if location.notifyOnEntry {
            return Color.blue
        } else {
            return Color.orange
        }
    }
}

// MARK: - Location Permission View  
struct LocationPermissionView: View {
    @EnvironmentObject private var locationManager: LocationManager
    
    var body: some View {
        VStack(spacing: 40) {
            // Header: small logo at the top
            VStack(spacing: 20) {
                if let logoImage = UIImage(named: "Logo") {
                    Image(uiImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                } else {
                    // Fallback logo
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "location.fill")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Illustration: phone with map pin
            VStack(spacing: 30) {
                ZStack {
                    // Phone outline
                    RoundedRectangle(cornerRadius: 35)
                        .fill(Color.white)
                        .frame(width: 200, height: 360)
                        .overlay(
                            RoundedRectangle(cornerRadius: 35)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    
                    // Screen content
                    VStack(spacing: 0) {
                        // Status bar area
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 30)
                        
                        // Map content
                        ZStack {
                            // Map background
                            Rectangle()
                                .fill(Color.blue.opacity(0.1))
                            
                            // Map grid
                            VStack(spacing: 4) {
                                ForEach(0..<8, id: \.self) { _ in
                                    HStack(spacing: 4) {
                                        ForEach(0..<6, id: \.self) { _ in
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 16)
                                        }
                                    }
                                }
                            }
                            .padding(15)
                            
                            // Location pin
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.blue)
                                .background(Circle().fill(.white).frame(width: 12, height: 12))
                        }
                        .frame(height: 280)
                        
                        // Bottom safe area
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 50)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .padding(10)
                }
            }
            
            // Title and subtext
            VStack(spacing: 16) {
                Text("Enable Location Access")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("GeoCue needs your location to send reminders when you arrive or leave saved places.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 32)
            }
            
            // Action buttons
            VStack(spacing: 16) {
                Button("Allow Location") {
                    locationManager.requestLocationPermission()
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 40)
                
                Button("Not Now") {
                    // Handle skip
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(NotificationManager())
        .environmentObject(ThemeManager())
}
