import SwiftUI

@main
struct GeoCueApp: App {
    @StateObject private var locationManager = ServiceLocator.locationManager
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
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
                        .environmentObject(themeManager)
                        .environmentObject(onboardingManager)
                        .environmentObject(subscriptionManager)
                        .preferredColorScheme(themeManager.currentTheme.colorScheme)
                        .onAppear {
                            setupAppDependencies()
                        }
                } else {
                    OnboardingView()
                        .environmentObject(locationManager)
                        .environmentObject(themeManager)
                        .environmentObject(onboardingManager)
                        .environmentObject(subscriptionManager)
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
        Logger.shared.info("App dependencies configured successfully", category: .general)
    }
}
