import Foundation
import UIKit

// MARK: - Performance Monitor

final class PerformanceMonitor {
    
    static let shared = PerformanceMonitor()
    
    private let logger = Logger.shared
    private let queue = DispatchQueue(label: "com.pixelsbysaurav.geocue.performance", qos: .utility)
    
    private var measurements: [String: TimeInterval] = [:]
    private var startTimes: [String: CFAbsoluteTime] = [:]
    
    private init() {
        if AppConfiguration.FeatureFlags.performanceMonitoringEnabled {
            startMemoryMonitoring()
        }
    }
    
    // MARK: - Time Measurement
    
    func startMeasuring(_ identifier: String) {
        queue.async {
            self.startTimes[identifier] = CFAbsoluteTimeGetCurrent()
        }
    }
    
    func endMeasuring(_ identifier: String) {
        queue.async {
            guard let startTime = self.startTimes[identifier] else {
                self.logger.warning("No start time found for measurement: \(identifier)", category: .general)
                return
            }
            
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            self.measurements[identifier] = elapsed
            self.startTimes.removeValue(forKey: identifier)
            
            if AppConfiguration.Environment.current.isDevelopment {
                self.logger.debug("Performance: \(identifier) took \(elapsed)s", category: .general)
            }
            
            // Log slow operations
            if elapsed > 1.0 {
                self.logger.warning("Slow operation detected: \(identifier) took \(elapsed)s", category: .general)
            }
        }
    }
    
    func getMeasurement(_ identifier: String) -> TimeInterval? {
        return queue.sync {
            return measurements[identifier]
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
    }
    
    private func checkMemoryUsage() {
        let memoryInfo = getMemoryUsage()
        
        if memoryInfo.used > 100 * 1024 * 1024 { // 100MB threshold
            logger.warning("High memory usage detected: \(memoryInfo.used / 1024 / 1024)MB", category: .general)
        }
        
        if AppConfiguration.Environment.current.isDevelopment {
            logger.debug("Memory usage: \(memoryInfo.used / 1024 / 1024)MB", category: .general)
        }
    }
    
    private func getMemoryUsage() -> (used: UInt64, total: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return (used: info.resident_size, total: info.virtual_size)
        } else {
            return (used: 0, total: 0)
        }
    }
    
    // MARK: - App State Monitoring
    
    func setupAppStateMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.warning("App received memory warning", category: .general)
            self?.handleMemoryWarning()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.info("App will terminate", category: .general)
            self?.cleanup()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.info("App entered background", category: .general)
            self?.handleBackgroundTransition()
        }
    }
    
    private func handleMemoryWarning() {
        // Clear caches and free up memory
        queue.async {
            self.measurements.removeAll()
            self.startTimes.removeAll()
        }
        
        // Notify service container to clean up
        if let container = ServiceLocator.shared as? ServiceContainer {
            // In a production app, you might want to implement cache clearing here
        }
    }
    
    private func handleBackgroundTransition() {
        // Save important state and pause non-essential operations
        queue.async {
            // Could implement state saving here
        }
    }
    
    private func cleanup() {
        queue.async {
            self.measurements.removeAll()
            self.startTimes.removeAll()
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Performance Measurement Wrapper

func measurePerformance<T>(_ identifier: String, operation: () throws -> T) rethrows -> T {
    PerformanceMonitor.shared.startMeasuring(identifier)
    defer {
        PerformanceMonitor.shared.endMeasuring(identifier)
    }
    return try operation()
}

func measurePerformanceAsync<T>(_ identifier: String, operation: () async throws -> T) async rethrows -> T {
    PerformanceMonitor.shared.startMeasuring(identifier)
    defer {
        PerformanceMonitor.shared.endMeasuring(identifier)
    }
    return try await operation()
}

// MARK: - Memory Management Extensions

extension RingtoneService {
    
    func optimizeMemoryUsage() {
        // Clear any cached data that can be regenerated
        Logger.shared.debug("Optimizing ringtone service memory usage", category: .service)
        
        // Stop any ongoing audio operations
        stopPreview()
        
        // Trigger garbage collection if needed
        if AppConfiguration.Environment.current.isDevelopment {
            Logger.shared.debug("Memory optimization completed", category: .service)
        }
    }
}

extension RingtoneAudioService {
    
    func handleMemoryWarning() {
        stopAudioPlayback()
        
        // Release any cached audio resources
        Logger.shared.debug("Audio service handled memory warning", category: .audio)
    }
}

// MARK: - Cache Management

final class CacheManager {
    
    static let shared = CacheManager()
    
    private let cache = NSCache<NSString, AnyObject>()
    private let logger = Logger.shared
    
    private init() {
        cache.countLimit = AppConfiguration.Performance.cacheSize
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        
        setupMemoryWarningHandling()
    }
    
    private func setupMemoryWarningHandling() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }
    
    func store<T: AnyObject>(_ object: T, forKey key: String, cost: Int = 0) {
        cache.setObject(object, forKey: key as NSString, cost: cost)
        logger.debug("Cached object for key: \(key)", category: .general)
    }
    
    func retrieve<T: AnyObject>(_ type: T.Type, forKey key: String) -> T? {
        return cache.object(forKey: key as NSString) as? T
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
        logger.debug("Removed cached object for key: \(key)", category: .general)
    }
    
    func clearCache() {
        cache.removeAllObjects()
        logger.info("Cache cleared", category: .general)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Resource Management

final class ResourceManager {
    
    static let shared = ResourceManager()
    
    private let operationQueue: OperationQueue
    private let logger = Logger.shared
    
    private init() {
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = AppConfiguration.Performance.maxConcurrentOperations
        operationQueue.qualityOfService = AppConfiguration.Performance.backgroundQueueQoS.qosClass
    }
    
    func executeBackgroundTask<T>(_ task: @escaping () -> T, completion: @escaping (T) -> Void) {
        operationQueue.addOperation {
            let result = task()
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func executeCriticalTask<T>(_ task: @escaping () throws -> T, completion: @escaping (Result<T, Error>) -> Void) {
        let operation = BlockOperation {
            do {
                let result = try task()
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        operation.queuePriority = .high
        operationQueue.addOperation(operation)
    }
    
    func cancelAllOperations() {
        operationQueue.cancelAllOperations()
        logger.info("All background operations cancelled", category: .general)
    }
}

// MARK: - Extensions for QoS Conversion

private extension DispatchQoS {
    var qosClass: QualityOfService {
        switch self {
        case .userInteractive:
            return .userInteractive
        case .userInitiated:
            return .userInitiated
        case .utility:
            return .utility
        case .background:
            return .background
        default:
            return .default
        }
    }
}