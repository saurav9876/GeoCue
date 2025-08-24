import SwiftUI
import Foundation

enum AppTheme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var displayName: String {
        return self.rawValue
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
    
    var icon: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "gear"
        }
    }
    
    var description: String {
        switch self {
        case .light:
            return "Light theme with white backgrounds"
        case .dark:
            return "Dark theme with black backgrounds"
        case .system:
            return "Follows system appearance setting"
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme {
        didSet {
            saveTheme()
        }
    }
    
    private let themeKey = "app_theme"
    
    init() {
        // Default to light theme as priority
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .light
        }
        
        print("🎨 ThemeManager initialized with theme: \(self.currentTheme.displayName)")
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
        print("🎨 Theme changed to: \(currentTheme.displayName)")
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
    
    var allThemes: [AppTheme] {
        return AppTheme.allCases
    }
}

