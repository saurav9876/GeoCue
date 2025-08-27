import Foundation
import UserNotifications
import Combine

final class RingtoneService: ObservableObject, RingtoneServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var selectedRingtone: RingtoneType = .defaultSound
    @Published private(set) var isRingtoneEnabled: Bool = true
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: RingtoneError?
    
    // MARK: - Private Properties
    
    private let persistenceService: RingtonePersistenceProtocol
    private let audioService: RingtoneAudioProtocol
    private let logger: LoggerProtocol
    
    private var cancellables = Set<AnyCancellable>()
    private let observerQueue = DispatchQueue(label: "com.pixelsbysaurav.geocue.ringtone.observers", qos: .utility)
    
    // Observer pattern for loose coupling
    private var observers = NSHashTable<AnyObject>.weakObjects()
    
    // MARK: - Initialization
    
    init(
        persistenceService: RingtonePersistenceProtocol = RingtonePersistenceService(),
        audioService: RingtoneAudioProtocol = RingtoneAudioService(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.persistenceService = persistenceService
        self.audioService = audioService
        self.logger = logger
        
        setupAudioService()
        loadInitialSettings()
    }
    
    // MARK: - Public Methods
    
    func updateRingtone(_ ringtone: RingtoneType, completion: @escaping RingtoneCompletion<Void>) {
        guard ringtone != selectedRingtone else {
            logger.debug("Ringtone \(ringtone.displayName) already selected", category: .service)
            completion(.success(()))
            return
        }
        
        isLoading = true
        lastError = nil
        
        let currentSettings = createCurrentSettings()
        let newSettings = RingtoneSettings(
            selectedRingtone: ringtone,
            isEnabled: currentSettings.isEnabled
        )
        
        saveSettings(newSettings) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.selectedRingtone = ringtone
                    self?.notifyObservers { observer in
                        observer.ringtoneService(self!, didUpdateRingtone: ringtone)
                    }
                    self?.logger.info("Successfully updated ringtone to \(ringtone.displayName)", category: .service)
                    completion(.success(()))
                    
                case .failure(let error):
                    self?.lastError = error
                    self?.notifyObservers { observer in
                        observer.ringtoneService(self!, didEncounterError: error)
                    }
                    completion(.failure(error))
                }
            }
        }
    }
    
    func toggleRingtoneEnabled(completion: @escaping RingtoneCompletion<Bool>) {
        isLoading = true
        lastError = nil
        
        let newEnabledState = !isRingtoneEnabled
        let currentSettings = createCurrentSettings()
        let newSettings = RingtoneSettings(
            selectedRingtone: currentSettings.selectedRingtone,
            isEnabled: newEnabledState
        )
        
        saveSettings(newSettings) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.isRingtoneEnabled = newEnabledState
                    self?.notifyObservers { observer in
                        observer.ringtoneService(self!, didToggleEnabled: newEnabledState)
                    }
                    self?.logger.info("Successfully toggled ringtone enabled to \(newEnabledState)", category: .service)
                    completion(.success(newEnabledState))
                    
                case .failure(let error):
                    self?.lastError = error
                    self?.notifyObservers { observer in
                        observer.ringtoneService(self!, didEncounterError: error)
                    }
                    completion(.failure(error))
                }
            }
        }
    }
    
    func previewRingtone(_ ringtone: RingtoneType, completion: @escaping RingtoneCompletion<Void>) {
        logger.debug("Previewing ringtone: \(ringtone.displayName)", category: .service)
        
        if ringtone == .defaultSound {
            audioService.playSystemSound(1007) { [weak self] result in
                switch result {
                case .success:
                    self?.logger.debug("Successfully previewed default sound", category: .service)
                    completion(.success(()))
                case .failure(let error):
                    self?.logger.error("Failed to preview default sound: \(error.localizedDescription)", category: .service)
                    completion(.failure(error))
                }
            }
        } else if let systemSoundID = ringtone.systemSoundID {
            audioService.playSystemSound(systemSoundID) { [weak self] result in
                switch result {
                case .success:
                    self?.logger.debug("Successfully previewed \(ringtone.displayName)", category: .service)
                    completion(.success(()))
                case .failure(let error):
                    self?.logger.error("Failed to preview \(ringtone.displayName): \(error.localizedDescription)", category: .service)
                    completion(.failure(error))
                }
            }
        } else {
            // Handle custom audio files (BBC and custom sounds)
            let fileName = ringtone.audioFileName
            if fileName.hasSuffix(".mp3") || fileName.hasSuffix(".m4a") {
                // Play custom audio file
                audioService.playCustomAudio(fileName) { [weak self] result in
                    switch result {
                    case .success:
                        self?.logger.debug("Successfully previewed custom audio: \(ringtone.displayName)", category: .service)
                        completion(.success(()))
                    case .failure(let error):
                        self?.logger.error("Failed to preview custom audio \(ringtone.displayName): \(error.localizedDescription)", category: .service)
                        completion(.failure(error))
                    }
                }
            } else {
                let error = RingtoneError.invalidConfiguration
                logger.error("Invalid ringtone configuration for \(ringtone.displayName)", category: .service)
                completion(.failure(error))
            }
        }
    }
    
    func stopPreview() {
        audioService.stopAudioPlayback()
        logger.debug("Stopped ringtone preview", category: .service)
    }
    
    func getNotificationSound() -> UNNotificationSound? {
        guard isRingtoneEnabled else {
            logger.debug("Ringtone disabled, returning nil for notification sound", category: .service)
            return nil
        }
        
        logger.debug("Returning notification sound for \(selectedRingtone.displayName)", category: .service)
        return selectedRingtone.notificationSound
    }
    
    func validateConfiguration() -> RingtoneResult<Void> {
        // Validate that the selected ringtone is still available
        if selectedRingtone != .defaultSound {
            if let _ = selectedRingtone.systemSoundID {
                // System sound is available
            } else {
                // Check if it's a custom audio file
                let fileName = selectedRingtone.audioFileName
                if fileName.hasSuffix(".mp3") || fileName.hasSuffix(".m4a") {
                    // Custom audio file - check if it exists in the bundle
                    let resourceName = String(fileName.dropLast(4)) // Remove file extension
                    let fileExtension = String(fileName.dropFirst(resourceName.count + 1)) // Get extension
                    if let _ = Bundle.main.path(forResource: resourceName, ofType: fileExtension) {
                        // Custom audio file exists
                    } else {
                        logger.warning("Selected custom ringtone \(selectedRingtone.displayName) file not found: \(fileName)", category: .service)
                        return .failure(.invalidConfiguration)
                    }
                } else {
                    logger.warning("Selected ringtone \(selectedRingtone.displayName) is no longer available", category: .service)
                    return .failure(.invalidConfiguration)
                }
            }
        }
        
        // Validate settings structure
        let currentSettings = createCurrentSettings()
        if currentSettings.version.isEmpty {
            logger.warning("Invalid settings version", category: .service)
            return .failure(.invalidConfiguration)
        }
        
        logger.debug("Configuration validation passed", category: .service)
        return .success(())
    }
    
    // MARK: - Observer Management
    
    func addObserver(_ observer: RingtoneServiceObserver) {
        observerQueue.async { [weak self] in
            self?.observers.add(observer)
        }
    }
    
    func removeObserver(_ observer: RingtoneServiceObserver) {
        observerQueue.async { [weak self] in
            self?.observers.remove(observer)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioService() {
        if let audioService = audioService as? RingtoneAudioService {
            audioService.startObservingAudioSession()
        }
    }
    
    private func loadInitialSettings() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let settings = try self.persistenceService.loadRingtoneSettings()
                
                DispatchQueue.main.async {
                    self.selectedRingtone = settings.selectedRingtone
                    self.isRingtoneEnabled = settings.isEnabled
                    self.isLoading = false
                    
                    self.logger.info("Successfully loaded initial ringtone settings", category: .service)
                    
                    // Validate configuration after loading
                    let validationResult = self.validateConfiguration()
                    if case .failure(let error) = validationResult {
                        self.handleConfigurationError(error)
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    let ringtoneError = error as? RingtoneError ?? RingtoneError.persistenceError(error.localizedDescription)
                    self.lastError = ringtoneError
                    
                    self.logger.error("Failed to load initial settings: \(error.localizedDescription)", category: .service)
                    
                    self.notifyObservers { observer in
                        observer.ringtoneService(self, didEncounterError: ringtoneError)
                    }
                }
            }
        }
    }
    
    private func saveSettings(_ settings: RingtoneSettings, completion: @escaping RingtoneCompletion<Void>) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.persistenceService.saveRingtoneSettings(settings)
                completion(.success(()))
            } catch {
                let ringtoneError = error as? RingtoneError ?? RingtoneError.persistenceError(error.localizedDescription)
                completion(.failure(ringtoneError))
            }
        }
    }
    
    private func createCurrentSettings() -> RingtoneSettings {
        return RingtoneSettings(
            selectedRingtone: selectedRingtone,
            isEnabled: isRingtoneEnabled
        )
    }
    
    private func notifyObservers(_ block: @escaping (RingtoneServiceObserver) -> Void) {
        observerQueue.async { [weak self] in
            guard let self = self else { return }
            
            let currentObservers = self.observers.allObjects.compactMap { $0 as? RingtoneServiceObserver }
            
            DispatchQueue.main.async {
                currentObservers.forEach(block)
            }
        }
    }
    
    private func handleConfigurationError(_ error: RingtoneError) {
        logger.warning("Configuration error detected, attempting to recover", category: .service)

        // Reset to default configuration
        let defaultSettings = RingtoneSettings()
        saveSettings(defaultSettings) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.selectedRingtone = defaultSettings.selectedRingtone
                    self?.isRingtoneEnabled = defaultSettings.isEnabled
                    self?.logger.info("Successfully recovered with default settings", category: .service)
                }
            case .failure(let saveError):
                self?.logger.error("Failed to recover with default settings: \(saveError.localizedDescription)", category: .service)
            }
        }
    }

    private var _availableRingtones: [RingtoneType]?

    var availableRingtones: [RingtoneType] {
        if _availableRingtones == nil {
            _availableRingtones = RingtoneType.allCases.filter { ringtone in
                if ringtone == .defaultSound {
                    return true
                }

                // Include system sounds
                if let _ = ringtone.systemSoundID {
                    return true
                }

                // Include custom audio files (BBC and custom sounds)
                let fileName = ringtone.audioFileName
                if fileName.hasSuffix(".m4a") || fileName.hasSuffix(".mp3") {
                    // Check if the audio file exists in the bundle
                    let resourceName = String(fileName.dropLast(4)) // Remove file extension
                    let fileExtension = String(fileName.dropFirst(resourceName.count + 1)) // Get extension
                    if let _ = Bundle.main.path(forResource: resourceName, ofType: fileExtension) {
                        return true
                    }
                }

                return false
            }
        }
        return _availableRingtones!
    }

    var ringtonesByCategory: [RingtoneCategory: [RingtoneType]] {
        return Dictionary(grouping: availableRingtones) { $0.category }
    }

    func isRingtoneAvailable(_ ringtone: RingtoneType) -> Bool {
        if ringtone == .defaultSound {
            return true
        }
        
        if let _ = ringtone.systemSoundID {
            return true
        }
        
        // Check if custom audio file exists
        let fileName = ringtone.audioFileName
        if fileName.hasSuffix(".m4a") || fileName.hasSuffix(".mp3") {
            let resourceName = String(fileName.dropLast(4)) // Remove file extension
            let fileExtension = String(fileName.dropFirst(resourceName.count + 1)) // Get extension
            if let _ = Bundle.main.path(forResource: resourceName, ofType: fileExtension) {
                return true
            }
        } else if fileName.hasSuffix(".caf") {
            // Check if custom CAF file exists for WhatsApp-style sounds
            if let _ = Bundle.main.path(forResource: String(fileName.dropLast(4)), ofType: "caf") {
                return true
            }
        }
        
        return false
    }
}