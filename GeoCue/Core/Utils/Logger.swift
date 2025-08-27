import Foundation

public enum LogCategory: String {
    case general = "General"
    case location = "Location"
    case notification = "Notification"
    case service = "Service"
    case persistence = "Persistence"
    case security = "Security"
    case audio = "Audio"
    case ui = "UI"
    case privacy = "Privacy"
    case analytics = "Analytics"
}

public protocol LoggerProtocol {
    func info(_ message: String, category: LogCategory)
    func debug(_ message: String, category: LogCategory)
    func warning(_ message: String, category: LogCategory)
    func error(_ message: String, category: LogCategory)
}

public class Logger: LoggerProtocol {
    public static let shared = Logger()

    private init() {}

    public func info(_ message: String, category: LogCategory) {
        print("[INFO] [\(category.rawValue)] \(message)")
    }

    public func debug(_ message: String, category: LogCategory) {
        print("[DEBUG] [\(category.rawValue)] \(message)")
    }

    public func warning(_ message: String, category: LogCategory) {
        print("[WARNING] [\(category.rawValue)] \(message)")
    }

    public func error(_ message: String, category: LogCategory) {
        print("[ERROR] [\(category.rawValue)] \(message)")
    }
}
