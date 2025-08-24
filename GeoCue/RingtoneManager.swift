import Foundation
import UserNotifications

// MARK: - Legacy RingtoneManager for Backward Compatibility

@available(*, deprecated, message: "Use RingtoneService with dependency injection instead")
class RingtoneManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedRingtone: RingtoneType {
        didSet {
            syncWithService()
        }
    }
    
    @Published var isRingtoneEnabled: Bool {
        didSet {
            syncWithService()
        }
    }
    
    // MARK: - Private Properties
    
    private let ringtoneService: RingtoneServiceProtocol
    
    // MARK: - Initialization
    
    init(ringtoneService: RingtoneServiceProtocol? = nil) {
        self.ringtoneService = ringtoneService ?? ServiceLocator.ringtoneService
        
        // Initialize with service values
        self.selectedRingtone = self.ringtoneService.selectedRingtone
        self.isRingtoneEnabled = self.ringtoneService.isRingtoneEnabled
        
        // Load settings (for legacy compatibility)
        loadSettings()
    }
    
    // MARK: - Legacy Methods (Deprecated)
    
    @available(*, deprecated, message: "Settings are now automatically managed")
    func loadSettings() {
        selectedRingtone = ringtoneService.selectedRingtone
        isRingtoneEnabled = ringtoneService.isRingtoneEnabled
    }
    
    @available(*, deprecated, message: "Settings are now automatically saved")
    func saveSettings() {
        // No-op - settings are automatically saved by the service
    }
    
    @available(*, deprecated, message: "Use ringtoneService.updateRingtone(_:completion:) instead")
    func updateRingtone(_ ringtone: RingtoneType) {
        ringtoneService.updateRingtone(ringtone) { _ in }
    }
    
    @available(*, deprecated, message: "Use ringtoneService.toggleRingtoneEnabled(completion:) instead")
    func toggleRingtone() {
        ringtoneService.toggleRingtoneEnabled { _ in }
    }
    
    func getNotificationSound() -> UNNotificationSound? {
        return ringtoneService.getNotificationSound()
    }
    
    @available(*, deprecated, message: "Use ringtoneService.previewRingtone(_:completion:) instead")
    func previewRingtone(_ ringtone: RingtoneType) {
        ringtoneService.previewRingtone(ringtone) { _ in }
    }
    
    func stopPreview() {
        ringtoneService.stopPreview()
    }
    
    // MARK: - Private Methods
    
    private func syncWithService() {
        // This ensures backward compatibility by forwarding changes to the service
        if selectedRingtone != ringtoneService.selectedRingtone {
            updateRingtone(selectedRingtone)
        }
        
        if isRingtoneEnabled != ringtoneService.isRingtoneEnabled {
            toggleRingtone()
        }
    }
}