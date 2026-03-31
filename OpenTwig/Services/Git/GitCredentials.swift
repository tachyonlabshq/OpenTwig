import Foundation
import Security

// MARK: - Errors

enum GitCredentialError: LocalizedError, Sendable {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case dataConversionFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save credential to Keychain (OSStatus \(status))"
        case .loadFailed(let status):
            return "Failed to load credential from Keychain (OSStatus \(status))"
        case .deleteFailed(let status):
            return "Failed to delete credential from Keychain (OSStatus \(status))"
        case .dataConversionFailed:
            return "Failed to convert credential data"
        case .notFound:
            return "Credential not found in Keychain"
        }
    }
}

// MARK: - GitCredentials

struct GitCredentials: Sendable {

    // Keychain identifiers
    private static let service = "com.opentwig.git"
    private static let tokenAccount = "github-token"
    private static let usernameAccount = "github-username"

    var token: String
    var username: String

    init(token: String, username: String) {
        self.token = token
        self.username = username
    }

    // MARK: - Persistence

    func save() throws {
        try Self.setKeychainItem(account: Self.tokenAccount, value: token)
        try Self.setKeychainItem(account: Self.usernameAccount, value: username)
    }

    static func load() throws -> GitCredentials {
        let token = try getKeychainItem(account: tokenAccount)
        let username = try getKeychainItem(account: usernameAccount)
        return GitCredentials(token: token, username: username)
    }

    func delete() throws {
        try Self.deleteKeychainItem(account: Self.tokenAccount)
        try Self.deleteKeychainItem(account: Self.usernameAccount)
    }

    // MARK: - Keychain Helpers (private)

    private static func setKeychainItem(account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw GitCredentialError.dataConversionFailed
        }

        // Try to update first; if the item doesn't exist, add it.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            // Restrict access: only available when device is unlocked, never migrated to other devices.
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw GitCredentialError.saveFailed(status)
        }
    }

    private static func getKeychainItem(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw GitCredentialError.notFound
        }

        guard status == errSecSuccess else {
            throw GitCredentialError.loadFailed(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            throw GitCredentialError.dataConversionFailed
        }

        return string
    }

    private static func deleteKeychainItem(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GitCredentialError.deleteFailed(status)
        }
    }
}
