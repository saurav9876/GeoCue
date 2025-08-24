import Foundation
import SwiftUI

class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var hasCompletedOnboarding: Bool
    @Published var currentOnboardingStep: OnboardingStep = .welcome
    
    private let userDefaults = UserDefaults.standard
    private let onboardingCompletedKey = "onboarding_completed"
    
    private init() {
        self.hasCompletedOnboarding = userDefaults.bool(forKey: onboardingCompletedKey)
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: onboardingCompletedKey)
        userDefaults.synchronize()
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        userDefaults.set(false, forKey: onboardingCompletedKey)
        userDefaults.synchronize()
    }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case locationPermission = 1
    case notifications = 2
    case geofencing = 3
    case privacy = 4
    case ready = 5
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to GeoCue"
        case .locationPermission:
            return "Location Access"
        case .notifications:
            return "Smart Notifications"
        case .geofencing:
            return "Geofencing Magic"
        case .privacy:
            return "Your Privacy"
        case .ready:
            return "You're All Set!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .welcome:
            return "Your intelligent location-based reminder companion"
        case .locationPermission:
            return "GeoCue needs location access to send you timely reminders when you arrive or leave places"
        case .notifications:
            return "Get notified exactly when you need to remember something important"
        case .geofencing:
            return "Create virtual boundaries around locations to trigger your reminders automatically"
        case .privacy:
            return "Your location data stays on your device and is never shared with third parties"
        case .ready:
            return "Start creating your first location-based reminder"
        }
    }
    
    var icon: String {
        switch self {
        case .welcome:
            return "mappin.and.ellipse"
        case .locationPermission:
            return "location.fill"
        case .notifications:
            return "bell.badge.fill"
        case .geofencing:
            return "circle.dashed"
        case .privacy:
            return "hand.raised.fill"
        case .ready:
            return "checkmark.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .welcome:
            return .blue
        case .locationPermission:
            return .green
        case .notifications:
            return .orange
        case .geofencing:
            return .purple
        case .privacy:
            return .red
        case .ready:
            return .green
        }
    }
    
    var isLastStep: Bool {
        return self == .ready
    }
}
