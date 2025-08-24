import Foundation
import SwiftUI
import CoreLocation

// MARK: - App Error Types

enum AppError: LocalizedError, Equatable {
    case locationPermissionDenied
    case locationServicesDisabled
    case notificationPermissionDenied
    case geofenceLimit
    case invalidLocation
    case networkError(String)
    case storageError(String)
    case validationError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return "Location permission is required to create location-based reminders."
        case .locationServicesDisabled:
            return "Location services are disabled. Please enable them in Settings."
        case .notificationPermissionDenied:
            return "Notification permission is required to send reminders."
        case .geofenceLimit:
            return "You've reached the maximum number of location reminders (20)."
        case .invalidLocation:
            return "The selected location is not valid."
        case .networkError(let message):
            return "Network error: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .locationPermissionDenied:
            return "Go to Settings > Privacy & Security > Location Services > GeoCue and select 'Always'."
        case .locationServicesDisabled:
            return "Go to Settings > Privacy & Security > Location Services and turn it on."
        case .notificationPermissionDenied:
            return "Go to Settings > Notifications > GeoCue and enable notifications."
        case .geofenceLimit:
            return "Delete some existing reminders to create new ones."
        case .invalidLocation:
            return "Please select a different location and try again."
        case .networkError, .storageError, .validationError, .unknown:
            return "Please try again. If the problem persists, contact support."
        }
    }
}

// MARK: - Error Handler

final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: AppError?
    @Published var isShowingError = false
    
    private let logger = Logger.shared
    
    private init() {}
    
    func handle(_ error: Error, context: String = "") {
        let appError = mapToAppError(error)
        
        logger.error("Error in \(context): \(error.localizedDescription)", category: .general)
        
        DispatchQueue.main.async {
            self.currentError = appError
            self.isShowingError = true
        }
    }
    
    func handle(_ appError: AppError, context: String = "") {
        logger.error("AppError in \(context): \(appError.localizedDescription)", category: .general)
        
        DispatchQueue.main.async {
            self.currentError = appError
            self.isShowingError = true
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.isShowingError = false
        }
    }
    
    private func mapToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Map system errors to app errors
        if let locationError = error as? CLError {
            switch locationError.code {
            case .denied:
                return .locationPermissionDenied
            case .locationUnknown:
                return .invalidLocation
            case .network:
                return .networkError(locationError.localizedDescription)
            default:
                return .unknown(locationError.localizedDescription)
            }
        }
        
        return .unknown(error.localizedDescription)
    }
}

// MARK: - SwiftUI Error Alert Modifier

struct ErrorAlert: ViewModifier {
    @ObservedObject var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorHandler.isShowingError) {
                Button("OK") {
                    errorHandler.clearError()
                }
                
                if errorHandler.currentError?.recoverySuggestion != nil {
                    Button("Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                        errorHandler.clearError()
                    }
                }
            } message: {
                VStack(alignment: .leading, spacing: 8) {
                    if let errorDescription = errorHandler.currentError?.errorDescription {
                        Text(errorDescription)
                    }
                    
                    if let recoverySuggestion = errorHandler.currentError?.recoverySuggestion {
                        Text(recoverySuggestion)
                            .font(.caption)
                    }
                }
            }
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorAlert())
    }
}