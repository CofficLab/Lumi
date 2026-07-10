import Foundation
import Security

/// Secure API key storage backed by the system Keychain.
public final class LumiAPIKeyStore: @unchecked Sendable {
    public static let shared = LumiAPIKeyStore()

    private let service = "com.coffic.lumi.apikey"

    private init() {}

    public func string(forKey key: String) -> String? {
        guard !key.isEmpty else { return nil }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }

    public func set(_ value: String, forKey key: String) {
        guard !key.isEmpty else { return }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            remove(forKey: key)
            return
        }

        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    public func remove(forKey key: String) {
        guard !key.isEmpty else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        _ = SecItemDelete(query as CFDictionary)
    }

    /// Reads from Keychain, migrating a legacy UserDefaults value when present.
    ///
    /// 兼容两层旧数据：
    /// 1. 当前 Keychain 键
    /// 2. 旧版 UserDefaults 键（与当前键同名，老版本曾用 UserDefaults 存 key）→ 自动迁到 Keychain
    public func loadMigratingLegacyUserDefaults(forKey key: String) -> String? {
        guard !key.isEmpty else { return nil }

        // 1. 当前 Keychain 键
        if let keychainValue = string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !keychainValue.isEmpty {
            return keychainValue
        }

        // 2. 旧版 UserDefaults 键（与当前键同名）→ 迁到 Keychain
        if let legacyUserDefaultsValue = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !legacyUserDefaultsValue.isEmpty {
            set(legacyUserDefaultsValue, forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
            return legacyUserDefaultsValue
        }

        return nil
    }
}
