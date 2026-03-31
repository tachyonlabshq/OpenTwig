import Foundation
import Security

// MARK: - AIConfiguration

struct AIConfiguration: Sendable {

    var model: String
    var maxTokens: Int
    var temperature: Double
    var baseURL: String

    // MARK: - Defaults

    static let defaultModel = "claude-sonnet-4-6"
    static let defaultMaxTokens = 4096
    static let defaultTemperature = 0.3
    static let defaultBaseURL = "https://api.anthropic.com"

    private static let keychainService = "com.opentwig.ai"
    private static let keychainAccount = "anthropic-api-key"

    // UserDefaults keys
    private static let modelKey = "ai.model"
    private static let maxTokensKey = "ai.maxTokens"
    private static let temperatureKey = "ai.temperature"
    private static let baseURLKey = "ai.baseURL"

    init(
        model: String = AIConfiguration.defaultModel,
        maxTokens: Int = AIConfiguration.defaultMaxTokens,
        temperature: Double = AIConfiguration.defaultTemperature,
        baseURL: String = AIConfiguration.defaultBaseURL
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.baseURL = baseURL
    }

    // MARK: - API Key (Keychain)

    var apiKey: String? {
        get { try? Self.loadAPIKey() }
    }

    static func saveAPIKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw AIConfigurationError.dataConversionFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
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
            throw AIConfigurationError.keychainSaveFailed(status)
        }
    }

    static func loadAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw AIConfigurationError.apiKeyNotFound
        }

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else {
            throw AIConfigurationError.keychainLoadFailed(status)
        }

        return key
    }

    static func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AIConfigurationError.keychainDeleteFailed(status)
        }
    }

    // MARK: - UserDefaults Persistence

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(model, forKey: Self.modelKey)
        defaults.set(maxTokens, forKey: Self.maxTokensKey)
        defaults.set(temperature, forKey: Self.temperatureKey)
        defaults.set(baseURL, forKey: Self.baseURLKey)
    }

    static func load() -> AIConfiguration {
        let defaults = UserDefaults.standard
        return AIConfiguration(
            model: defaults.string(forKey: modelKey) ?? defaultModel,
            maxTokens: defaults.integer(forKey: maxTokensKey).nonZero ?? defaultMaxTokens,
            temperature: defaults.object(forKey: temperatureKey) as? Double ?? defaultTemperature,
            baseURL: defaults.string(forKey: baseURLKey) ?? defaultBaseURL
        )
    }
}

// MARK: - Errors

enum AIConfigurationError: LocalizedError, Sendable {
    case apiKeyNotFound
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case dataConversionFailed

    var errorDescription: String? {
        switch self {
        case .apiKeyNotFound:
            return "AI API key not found. Configure it in Settings."
        case .keychainSaveFailed(let status):
            return "Failed to save API key to Keychain (OSStatus \(status))"
        case .keychainLoadFailed(let status):
            return "Failed to load API key from Keychain (OSStatus \(status))"
        case .keychainDeleteFailed(let status):
            return "Failed to delete API key from Keychain (OSStatus \(status))"
        case .dataConversionFailed:
            return "Failed to convert API key data"
        }
    }
}

// MARK: - Int Helper

private extension Int {
    /// Returns self if non-zero, otherwise nil. Useful for UserDefaults where 0 means "not set".
    var nonZero: Int? { self == 0 ? nil : self }
}
