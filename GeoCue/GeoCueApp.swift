import SwiftUI

@main
struct GeoCueApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var notificationEscalator = NotificationEscalator.shared
    
    private let serviceContainer = ServiceContainer.shared
    
    init() {
        setupAppConfiguration()
        setupCrashReporting()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingManager.hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(locationManager)
                        .environmentObject(notificationManager)
                        .environmentObject(themeManager)
                        .environmentObject(onboardingManager)
                        .environmentObject(notificationEscalator)
                        .withServices(serviceContainer)
                        .preferredColorScheme(themeManager.currentTheme.colorScheme)
                        .onAppear {
                            setupAppDependencies()
                        }
                } else {
                    OnboardingView()
                        .environmentObject(locationManager)
                        .environmentObject(notificationManager)
                        .environmentObject(themeManager)
                        .environmentObject(onboardingManager)
                        .environmentObject(notificationEscalator)
                        .withServices(serviceContainer)
                        .preferredColorScheme(themeManager.currentTheme.colorScheme)
                        .onAppear {
                            setupAppDependencies()
                        }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAppConfiguration() {
        Logger.shared.info("App starting up", category: .general)
        
        #if DEBUG
        Logger.shared.debug("Running in debug mode", category: .general)
        #endif
    }
    
    private func setupCrashReporting() {
        let crashReporter = CrashReporter.shared
        crashReporter.recordAppLaunched()
        
        // Set user properties for analytics
        crashReporter.setUserProperty(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            forName: "app_version"
        )
        crashReporter.setUserProperty(
            UIDevice.current.systemVersion,
            forName: "os_version"
        )
    }
    
    private func setupAppDependencies() {
        // Using iOS default notification sounds for production stability
        
        // Initialize app services
        notificationManager.requestNotificationPermission()
        
        Logger.shared.info("App dependencies configured successfully", category: .general)
    }
}
