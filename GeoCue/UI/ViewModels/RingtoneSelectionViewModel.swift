import Foundation
import SwiftUI
import Combine

@MainActor
final class RingtoneSelectionViewModel: ObservableObject, RingtoneServiceObserver {
    
    // MARK: - Published Properties
    
    @Published var selectedRingtone: RingtoneType = .defaultSound
    @Published var isRingtoneEnabled: Bool = true
    @Published var isLoading: Bool = false
    @Published var lastError: RingtoneError?
    
    // MARK: - Computed Properties
    
    var errorMessage: String {
        guard let error = lastError else { return "" }
        
        let message = error.localizedDescription
        if let suggestion = error.recoverySuggestion {
            return "\(message)\n\n\(suggestion)"
        }
        return message
    }
    
    var ringtoneCategories: [(key: RingtoneCategory, value: [RingtoneType])] {
        return Array(ringtoneService.ringtonesByCategory.sorted { first, second in
            categoryOrder(first.key) < categoryOrder(second.key)
        })
    }
    
    // MARK: - Private Properties
    
    private let ringtoneService: RingtoneServiceProtocol
    private let logger: LoggerProtocol
    private var cancellables = Set<AnyCancellable>()
    private var lastFailedOperation: (() -> Void)?
    
    // MARK: - Initialization
    
    init(ringtoneService: RingtoneServiceProtocol, logger: LoggerProtocol = Logger.shared) {
        self.ringtoneService = ringtoneService
        self.logger = logger
        
        setupServiceObservation()
        syncWithService()
    }
    
    deinit {
        ringtoneService.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    func onAppear() {
        logger.debug("RingtoneSelectionView appeared", category: .ui)
        ringtoneService.addObserver(self)
        syncWithService()
    }
    
    func onDisappear() {
        logger.debug("RingtoneSelectionView disappeared", category: .ui)
        ringtoneService.removeObserver(self)
        ringtoneService.stopPreview()
    }
    
    func selectRingtone(_ ringtone: RingtoneType) {
        guard ringtone != selectedRingtone else { return }
        
        logger.info("User selected ringtone: \(ringtone.displayName)", category: .ui)
        
        lastFailedOperation = { [weak self] in
            self?.selectRingtone(ringtone)
        }
        
        ringtoneService.updateRingtone(ringtone) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.lastFailedOperation = nil
                    self?.logger.debug("Ringtone selection successful", category: .ui)
                    
                case .failure(let error):
                    self?.logger.error("Ringtone selection failed: \(error.localizedDescription)", category: .ui)
                    self?.lastError = error
                }
            }
        }
    }
    
    func toggleRingtoneEnabled() {
        logger.info("User toggled ringtone enabled state", category: .ui)
        
        lastFailedOperation = { [weak self] in
            self?.toggleRingtoneEnabled()
        }
        
        ringtoneService.toggleRingtoneEnabled { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.lastFailedOperation = nil
                    self?.logger.debug("Ringtone toggle successful", category: .ui)
                    
                case .failure(let error):
                    self?.logger.error("Ringtone toggle failed: \(error.localizedDescription)", category: .ui)
                    self?.lastError = error
                }
            }
        }
    }
    
    func previewRingtone(_ ringtone: RingtoneType, completion: @escaping (Bool) -> Void) {
        logger.debug("User previewing ringtone: \(ringtone.displayName)", category: .ui)
        
        ringtoneService.previewRingtone(ringtone) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.logger.debug("Ringtone preview successful", category: .ui)
                    completion(true)
                    
                case .failure(let error):
                    self?.logger.error("Ringtone preview failed: \(error.localizedDescription)", category: .ui)
                    self?.lastError = error
                    completion(false)
                }
            }
        }
    }
    
    func stopPreview() {
        logger.debug("User stopped ringtone preview", category: .ui)
        ringtoneService.stopPreview()
    }
    
    func retryLastOperation() {
        guard let operation = lastFailedOperation else {
            logger.warning("No operation to retry", category: .ui)
            return
        }
        
        logger.info("Retrying last failed operation", category: .ui)
        clearError()
        operation()
    }
    
    func clearError() {
        lastError = nil
        lastFailedOperation = nil
    }
    
    // MARK: - RingtoneServiceObserver
    
    nonisolated func ringtoneService(_ service: RingtoneServiceProtocol, didUpdateRingtone ringtone: RingtoneType) {
        Task { @MainActor in
            self.selectedRingtone = ringtone
            self.logger.debug("Service updated ringtone to: \(ringtone.displayName)", category: .ui)
        }
    }
    
    nonisolated func ringtoneService(_ service: RingtoneServiceProtocol, didToggleEnabled isEnabled: Bool) {
        Task { @MainActor in
            self.isRingtoneEnabled = isEnabled
            self.logger.debug("Service toggled enabled to: \(isEnabled)", category: .ui)
        }
    }
    
    nonisolated func ringtoneService(_ service: RingtoneServiceProtocol, didEncounterError error: RingtoneError) {
        Task { @MainActor in
            self.lastError = error
            self.logger.error("Service encountered error: \(error.localizedDescription)", category: .ui)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupServiceObservation() {
        // Observe service loading state if it's an ObservableObject
        if let observableService = ringtoneService as? RingtoneService {
            observableService.$isLoading
                .receive(on: DispatchQueue.main)
                .assign(to: \.isLoading, on: self)
                .store(in: &cancellables)
            
            observableService.$lastError
                .receive(on: DispatchQueue.main)
                .assign(to: \.lastError, on: self)
                .store(in: &cancellables)
        }
    }
    
    private func syncWithService() {
        selectedRingtone = ringtoneService.selectedRingtone
        isRingtoneEnabled = ringtoneService.isRingtoneEnabled
        
        // Validate configuration
        let validationResult = ringtoneService.validateConfiguration()
        if case .failure(let error) = validationResult {
            lastError = error
            logger.warning("Service configuration validation failed: \(error.localizedDescription)", category: .ui)
        }
    }
    
    private func categoryOrder(_ category: RingtoneCategory) -> Int {
        switch category {
        case .system: return 0
        case .traditional: return 1
        case .musical: return 2
        case .modern: return 3
        case .ambient: return 4
        case .dramatic: return 5
        case .classical: return 6
        }
    }
}

// MARK: - Analytics Extension

extension RingtoneSelectionViewModel {
    
    private func trackRingtoneSelection(_ ringtone: RingtoneType) {
        // In production, you might want to track user interactions
        logger.info("Analytics: Ringtone selected - \(ringtone.displayName)", category: .ui)
        
        // Example analytics call:
        // AnalyticsService.shared.track("ringtone_selected", parameters: [
        //     "ringtone_type": ringtone.rawValue,
        //     "category": ringtone.category.rawValue
        // ])
    }
    
    private func trackPreviewAction(_ ringtone: RingtoneType) {
        logger.debug("Analytics: Ringtone previewed - \(ringtone.displayName)", category: .ui)
        
        // Example analytics call:
        // AnalyticsService.shared.track("ringtone_previewed", parameters: [
        //     "ringtone_type": ringtone.rawValue
        // ])
    }
}