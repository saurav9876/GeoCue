import Foundation
import Security

// MARK: - Secure Storage Manager

final class SecureStorage {
    static let shared = SecureStorage()
    
    private let logger = Logger.shared
    private let serviceName = "com.pixelsbysaurav.geocue"
    
    private init() {}
    
    // MARK: - Keychain Operations
    
    func store(_ data: Data, for key: String) throws {
        // Delete any existing item first
        try? delete(key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            logger.error("Failed to store item in keychain: \(status)", category: .security)
            throw SecureStorageError.failedToStore(status)
        }
        
        logger.debug("Successfully stored item in keychain for key: \(key)", category: .security)
    }
    
    func retrieve(_ key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw SecureStorageError.itemNotFound
            }
            logger.error("Failed to retrieve item from keychain: \(status)", category: .security)
            throw SecureStorageError.failedToRetrieve(status)
        }
        
        guard let data = result as? Data else {
            throw SecureStorageError.invalidData
        }
        
        logger.debug("Successfully retrieved item from keychain for key: \(key)", category: .security)
        return data
    }
    
    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete item from keychain: \(status)", category: .security)
            throw SecureStorageError.failedToDelete(status)
        }
        
        logger.debug("Successfully deleted item from keychain for key: \(key)", category: .security)
    }
    
    func exists(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Convenience Methods
    
    func store<T: Codable>(_ object: T, for key: String) throws {
        let data = try JSONEncoder().encode(object)
        try store(data, for: key)
    }
    
    func retrieve<T: Codable>(_ type: T.Type, for key: String) throws -> T {
        let data = try retrieve(key)
        return try JSONDecoder().decode(type, from: data)
    }
    
    func storeString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw SecureStorageError.invalidData
        }
        try store(data, for: key)
    }
    
    func retrieveString(for key: String) throws -> String {
        let data = try retrieve(key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw SecureStorageError.invalidData
        }
        return string
    }
    
    // MARK: - Cleanup
    
    func clearAll() throws {
        logger.info("Clearing all keychain items", category: .security)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to clear keychain: \(status)", category: .security)
            throw SecureStorageError.failedToDelete(status)
        }
        
        logger.info("Successfully cleared all keychain items", category: .security)
    }
}

// MARK: - Secure Storage Error

enum SecureStorageError: LocalizedError {
    case failedToStore(OSStatus)
    case failedToRetrieve(OSStatus)
    case failedToDelete(OSStatus)
    case itemNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .failedToStore(let status):
            return "Failed to store item in secure storage: \(status)"
        case .failedToRetrieve(let status):
            return "Failed to retrieve item from secure storage: \(status)"
        case .failedToDelete(let status):
            return "Failed to delete item from secure storage: \(status)"
        case .itemNotFound:
            return "Item not found in secure storage"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

