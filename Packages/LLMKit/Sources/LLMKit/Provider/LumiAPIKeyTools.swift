import Foundation
import KernelLumi

/// API Key 管理工具集
///
/// 提供统一的 API Key 存储和读取接口，基于 Keychain 实现。
/// 各供应商可以按需使用这些工具函数来管理 API Key。
public enum LumiAPIKeyTools {

    /// 从 Keychain 解析 API Key，未配置时抛出错误
    public static func resolve(storageKey: String?, displayName: String) throws -> String {
        guard let storageKey = storageKey else {
            throw LumiLLMProviderSupportError.missingAPIKey(displayName)
        }

        let key: String
        do {
            key = try APIKeyStore.shared
                .loadMigratingLegacyUserDefaultsReportingErrors(forKey: storageKey) ?? ""
        } catch let error as APIKeyStoreError {
            // Keychain 抖动（expected-configured 但持续报 missing）时，
            // APIKeyStore 已在错误里附带内存缓存值，直接放行而不是
            // 向用户呈现"未配置/不可用"。
            if let cached = error.cachedValue, !cached.isEmpty {
                return cached
            }
            throw LumiLLMProviderSupportError.apiKeyAccessFailed(
                provider: displayName,
                details: error.localizedDescription
            )
        } catch {
            throw LumiLLMProviderSupportError.apiKeyAccessFailed(
                provider: displayName,
                details: error.localizedDescription
            )
        }
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(displayName)
        }
        return key
    }

    /// 检查是否已配置 API Key
    public static func has(storageKey: String?) -> Bool {
        guard let storageKey = storageKey else { return false }
        let key = APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
        return !key.isEmpty
    }

    /// 获取当前配置的 API Key
    public static func get(storageKey: String?) -> String {
        guard let storageKey = storageKey else { return "" }
        return APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
    }

    /// 保存 API Key 到 Keychain
    public static func set(_ apiKey: String, storageKey: String?) {
        guard let storageKey = storageKey else { return }
        APIKeyStore.shared.set(apiKey, forKey: storageKey)
    }

    /// 从 Keychain 删除 API Key
    public static func remove(storageKey: String?) {
        guard let storageKey = storageKey else { return }
        APIKeyStore.shared.remove(forKey: storageKey)
    }
}
