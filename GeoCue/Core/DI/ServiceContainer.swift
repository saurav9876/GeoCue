import Foundation
import SwiftUI
import AudioToolbox

// MARK: - Service Container Protocol

protocol ServiceContainerProtocol {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func register<T>(_ type: T.Type, instance: T)
    func resolve<T>(_ type: T.Type) -> T
    func resolveOptional<T>(_ type: T.Type) -> T?
}

// MARK: - Service Container Implementation

final class ServiceContainer: ServiceContainerProtocol {
    
    // MARK: - Singleton
    
    static let shared = ServiceContainer()
    
    // MARK: - Properties
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    private let queue = DispatchQueue(label: "com.pixelsbysaurav.geocue.service_container", attributes: .concurrent)
    
    // MARK: - Initialization
    
    private init() {
        registerDefaultServices()
    }
    
    // MARK: - Registration Methods
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.factories[key] = factory
        }
    }
    
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.services[key] = instance
        }
    }
    
    // MARK: - Resolution Methods
    
    func resolve<T>(_ type: T.Type) -> T {
        guard let instance = resolveOptional(type) else {
            fatalError("Service of type \(type) is not registered")
        }
        return instance
    }
    
    func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        return queue.sync {
            // First check if we have a cached instance
            if let instance = services[key] as? T {
                return instance
            }
            
            // Try to create from factory
            if let factory = factories[key] {
                let instance = factory() as! T
                
                // Cache singleton services (those that conform to specific protocols)
                if shouldCacheInstance(type) {
                    services[key] = instance
                }
                
                return instance
            }
            
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func registerDefaultServices() {
        // Register core services
        register(LoggerProtocol.self) {
            Logger.shared
        }
        
        register(RingtonePersistenceProtocol.self) {
            RingtonePersistenceService(
                userDefaults: .standard,
                logger: self.resolve(LoggerProtocol.self)
            )
        }
        
        register(RingtoneAudioProtocol.self) {
            let audioService = RingtoneAudioService(
                logger: self.resolve(LoggerProtocol.self)
            )
            audioService.startObservingAudioSession()
            return audioService
        }
        
        register(RingtoneServiceProtocol.self) {
            RingtoneService(
                persistenceService: self.resolve(RingtonePersistenceProtocol.self),
                audioService: self.resolve(RingtoneAudioProtocol.self),
                logger: self.resolve(LoggerProtocol.self)
            )
        }
    }
    
    private func shouldCacheInstance<T>(_ type: T.Type) -> Bool {
        // Cache services that should be singletons
        switch String(describing: type) {
        case String(describing: LoggerProtocol.self),
             String(describing: RingtoneServiceProtocol.self),
             String(describing: RingtonePersistenceProtocol.self),
             String(describing: RingtoneAudioProtocol.self):
            return true
        default:
            return false
        }
    }
}

// MARK: - Service Locator (Alternative Pattern)

final class ServiceLocator {
    
    static var shared: ServiceContainerProtocol = ServiceContainer.shared
    
    // Convenience methods for common services
    static var ringtoneService: RingtoneServiceProtocol {
        shared.resolve(RingtoneServiceProtocol.self)
    }
    
    static var logger: LoggerProtocol {
        shared.resolve(LoggerProtocol.self)
    }
    
    static var persistenceService: RingtonePersistenceProtocol {
        shared.resolve(RingtonePersistenceProtocol.self)
    }
    
    static var audioService: RingtoneAudioProtocol {
        shared.resolve(RingtoneAudioProtocol.self)
    }
}

// MARK: - Environment Key for SwiftUI

private struct RingtoneServiceKey: EnvironmentKey {
    static let defaultValue: RingtoneServiceProtocol = ServiceLocator.ringtoneService
}

extension EnvironmentValues {
    var ringtoneService: RingtoneServiceProtocol {
        get { self[RingtoneServiceKey.self] }
        set { self[RingtoneServiceKey.self] = newValue }
    }
}

// MARK: - View Modifiers for Dependency Injection

struct ServiceEnvironmentModifier: ViewModifier {
    let container: ServiceContainerProtocol
    
    func body(content: Content) -> some View {
        content
            .environment(\.ringtoneService, container.resolve(RingtoneServiceProtocol.self))
    }
}

extension View {
    func withServices(_ container: ServiceContainerProtocol = ServiceContainer.shared) -> some View {
        modifier(ServiceEnvironmentModifier(container: container))
    }
}

// MARK: - Testing Support

#if DEBUG
extension ServiceContainer {
    
    func registerMock<T>(_ type: T.Type, mock: T) {
        register(type, instance: mock)
    }
    
    func reset() {
        queue.async(flags: .barrier) {
            self.services.removeAll()
            self.factories.removeAll()
            self.registerDefaultServices()
        }
    }
    
    static func createTestContainer() -> ServiceContainer {
        return ServiceContainer.shared // For now, return the shared container
    }
}

// Mock services for testing (when not using separate test files)
final class MockRingtonePersistenceService: RingtonePersistenceProtocol {
    var savedSettings: RingtoneSettings?
    var shouldThrowError = false
    var errorToThrow: RingtoneError = .persistenceError("Mock error")
    
    func saveRingtoneSettings(_ settings: RingtoneSettings) throws {
        if shouldThrowError {
            throw errorToThrow
        }
        savedSettings = settings
    }
    
    func loadRingtoneSettings() throws -> RingtoneSettings {
        if shouldThrowError {
            throw errorToThrow
        }
        return savedSettings ?? RingtoneSettings()
    }
    
    func clearRingtoneSettings() throws {
        if shouldThrowError {
            throw errorToThrow
        }
        savedSettings = nil
    }
}

final class MockRingtoneAudioService: RingtoneAudioProtocol {
    var shouldFailPlayback = false
    var playbackError: RingtoneError = .soundPlaybackFailed("Mock playback error")
    var lastPlayedSoundID: SystemSoundID?
    
    func playSystemSound(_ soundID: SystemSoundID, completion: @escaping RingtoneCompletion<Void>) {
        lastPlayedSoundID = soundID
        
        if shouldFailPlayback {
            completion(.failure(playbackError))
        } else {
            completion(.success(()))
        }
    }
    
    func stopAudioPlayback() {
        lastPlayedSoundID = nil
    }
    
    func configureAudioSession() throws {
        // Mock implementation
    }
}
#endif