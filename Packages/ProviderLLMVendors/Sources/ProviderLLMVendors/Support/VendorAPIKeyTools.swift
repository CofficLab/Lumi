import Foundation
import KitKeychain

/// API Key 管理工具（新版供应商承载层）。
///
/// 与旧版 `LumiAPIKeyTools` / `APIKeyStore` 使用**相同的 Keychain service**
/// （`com.coffic.lumi.apikey`）与 account（storageKey）寻址，因此迁移后
/// 旧版写入的 key 无需重新配置即可被读取。读取时同样兼容历史 UserDefaults
/// 键迁移（KitKeychain 的 `loadMigratingLegacyUserDefaults`）。
public enum VendorAPIKeyTools {

    /// 历史正式版 service；必须与旧 `APIKeyStore.service` 保持一致。
    static let keychainService = "com.coffic.lumi.apikey"

    private static let store = KeychainStore(service: keychainService)

    /// 从 Keychain 解析 API Key；未配置时抛错。
    public static func resolve(storageKey: String?, displayName: String) throws -> String {
        guard let storageKey, !storageKey.isEmpty else {
            throw VendorAPIError.missingAPIKey(displayName)
        }
        guard let key = store.loadMigratingLegacyUserDefaults(forKey: storageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty else {
            throw VendorAPIError.missingAPIKey(displayName)
        }
        return key
    }

    /// 是否已配置 API Key。
    public static func has(storageKey: String?) -> Bool {
        guard let storageKey, !storageKey.isEmpty else { return false }
        return store.string(forKey: storageKey)?.isEmpty == false
    }

    /// 读取 API Key（未配置返回空串）。
    public static func get(storageKey: String?) -> String {
        guard let storageKey, !storageKey.isEmpty else { return "" }
        return store.string(forKey: storageKey) ?? ""
    }

    /// 写入 API Key。
    public static func set(_ apiKey: String, storageKey: String) {
        store.set(apiKey, forKey: storageKey)
    }

    /// 删除 API Key。
    public static func remove(storageKey: String) {
        store.remove(forKey: storageKey)
    }
}
