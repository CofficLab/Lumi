import Foundation
import LumiCoreKit

/// API Key 管理工具集
/// 
/// 提供统一的 API Key 存储和读取接口，基于 Keychain 实现。
/// 各供应商可以按需使用这些工具函数来管理 API Key。
public enum APIKeyTools {
    
    /// 从 Keychain 解析 API Key，未配置时抛出错误
    /// 
    /// - Parameters:
    ///   - storageKey: Keychain 存储键
    ///   - displayName: 供应商显示名称（用于错误提示）
    /// - Returns: API Key 字符串
    /// - Throws: LumiLLMProviderSupportError.missingAPIKey 如果未配置
    public static func resolve(storageKey: String?, displayName: String) throws -> String {
        guard let storageKey = storageKey else {
            throw LumiLLMProviderSupportError.missingAPIKey(displayName)
        }
        
        let key = APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(displayName)
        }
        return key
    }
    
    /// 检查是否已配置 API Key
    /// 
    /// - Parameter storageKey: Keychain 存储键
    /// - Returns: 如果已配置返回 true，否则返回 false
    public static func has(storageKey: String?) -> Bool {
        guard let storageKey = storageKey else { return false }
        let key = APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
        return !key.isEmpty
    }

    /// 获取当前配置的 API Key
    ///
    /// - Parameter storageKey: Keychain 存储键
    /// - Returns: API Key 字符串，未配置时返回空字符串
    public static func get(storageKey: String?) -> String {
        guard let storageKey = storageKey else { return "" }
        return APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
    }
    
    /// 保存 API Key 到 Keychain
    /// 
    /// - Parameters:
    ///   - apiKey: 要保存的 API Key
    ///   - storageKey: Keychain 存储键
    public static func set(_ apiKey: String, storageKey: String?) {
        guard let storageKey = storageKey else { return }
        APIKeyStore.shared.set(apiKey, forKey: storageKey)
    }
    
    /// 从 Keychain 删除 API Key
    /// 
    /// - Parameter storageKey: Keychain 存储键
    public static func remove(storageKey: String?) {
        guard let storageKey = storageKey else { return }
        APIKeyStore.shared.remove(forKey: storageKey)
    }
}
