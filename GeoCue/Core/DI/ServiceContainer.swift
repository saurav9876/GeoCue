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
        
        // Ringtone services removed in minimal mode
        
        // Note: AnyLocationManager creation is handled separately due to MainActor requirements
    }
    
    private func shouldCacheInstance<T>(_ type: T.Type) -> Bool {
        // Cache services that should be singletons
        switch String(describing: type) {
        case String(describing: LoggerProtocol.self),
             String(describing: AnyLocationManager.self):
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
    
    @MainActor 
    static var locationManager: AnyLocationManager {
        // Create or return cached instance
        if let cached = shared.resolveOptional(AnyLocationManager.self) {
            return cached
        } else {
            let instance = AnyLocationManager()
            shared.register(AnyLocationManager.self, instance: instance)
            return instance
        }
    }
    
    static var logger: LoggerProtocol {
        shared.resolve(LoggerProtocol.self)
    }
    
}

// Ringtone environment and modifiers removed in minimal mode

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
// Ringtone mock services removed in minimal mode - ringtone functionality removed
#endif