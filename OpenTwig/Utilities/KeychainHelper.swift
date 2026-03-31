import Foundation
import Security

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case encodingFailed
    case unexpectedStatus(OSStatus)
    case itemNotFound
    case duplicateItem

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode the value for Keychain storage."
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
            return "Keychain operation failed: \(message) (OSStatus \(status))."
        case .itemNotFound:
            return "No Keychain item found for the given key."
        case .duplicateItem:
            return "A Keychain item with this key already exists."
        }
    }
}

// MARK: - KeychainHelper

/// Generic Keychain CRUD scoped to the OpenTwig service identifier.
/// Uses `kSecClassGenericPassword` items.
enum KeychainHelper {

    private static let serviceIdentifier = "com.tachyonlabs.OpenTwig"

    // MARK: - Data Operations

    /// Saves or updates raw data in the Keychain for the given key.
    static func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        // Delete any existing item first to avoid errSecDuplicateItem.
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Loads raw data from the Keychain. Returns `nil` if no item exists.
    static func load(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Deletes the Keychain item for the given key.
    static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - String Convenience

    /// Saves a UTF-8 string to the Keychain.
    static func saveString(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(key: key, data: data)
    }

    /// Loads a UTF-8 string from the Keychain. Returns `nil` if absent.
    static func loadString(key: String) throws -> String? {
        guard let data = try load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
