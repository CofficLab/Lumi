import Foundation
import Security

/// API Key 管理工具（纯 Security 框架实现，无项目依赖）。
///
/// 宿主应用可在启动时设置 `keychainService` 以适配自己的 Keychain 标识。
public enum VendorAPIKeyTools {

    /// Keychain service 标识，宿主应用可在启动时覆盖。
    nonisolated(unsafe) public static var keychainService = "com.kit.llm.apikey"

    /// 从 Keychain 解析 API Key；未配置时抛错。
    public static func resolve(storageKey: String?, displayName: String) throws -> String {
        guard let storageKey, !storageKey.isEmpty else {
            throw VendorAPIError.missingAPIKey(displayName)
        }
        guard let key = read(storageKey: storageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty else {
            throw VendorAPIError.missingAPIKey(displayName)
        }
        return key
    }

    /// 是否已配置 API Key。
    public static func has(storageKey: String?) -> Bool {
        guard let storageKey, !storageKey.isEmpty else { return false }
        return read(storageKey: storageKey) != nil
    }

    /// 读取 API Key（未配置返回空串）。
    public static func get(storageKey: String?) -> String {
        guard let storageKey, !storageKey.isEmpty else { return "" }
        return read(storageKey: storageKey) ?? ""
    }

    /// 写入 API Key。
    public static func set(_ apiKey: String, storageKey: String) {
        delete(storageKey: storageKey)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: storageKey,
            kSecValueData as String: Data(apiKey.utf8),
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    /// 删除 API Key。
    public static func remove(storageKey: String) {
        delete(storageKey: storageKey)
    }

    // MARK: - Private

    private static func read(storageKey: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: storageKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(storageKey: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: storageKey,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
