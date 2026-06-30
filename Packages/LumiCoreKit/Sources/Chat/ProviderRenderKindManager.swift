import Foundation

/// 提供商渲染种类管理器协议
///
/// 负责管理各 LLM 提供商的渲染前缀，支持动态注册和查询，
/// 避免在核心渲染器中硬编码提供商前缀。
public protocol ProviderRenderKindManaging: Sendable {
    /// 注册提供商的渲染前缀
    /// - Parameters:
    ///   - prefix: 渲染前缀（如 "zhipu-"）
    ///   - providerId: 提供商唯一标识符
    func registerProviderPrefix(_ prefix: String, for providerId: String)
    
    /// 取消注册提供商的渲染前缀
    /// - Parameter providerId: 提供商唯一标识符
    func unregisterProviderPrefix(for providerId: String)
    
    /// 检查给定的 renderKind 是否属于某个提供商的特定类型
    /// - Parameter renderKind: 渲染种类字符串
    /// - Returns: 如果是提供商特定类型返回 true，否则返回 false
    func isProviderSpecificRenderKind(_ renderKind: String?) -> Bool
    
    /// 检查给定的 renderKind 是否属于指定提供商
    /// - Parameters:
    ///   - renderKind: 渲染种类字符串
    ///   - providerId: 提供商唯一标识符
    /// - Returns: 如果属于该提供商返回 true，否则返回 false
    func isRenderKind(_ renderKind: String?, ownedBy providerId: String) -> Bool
    
    /// 获取指定提供商的渲染前缀
    /// - Parameter providerId: 提供商唯一标识符
    /// - Returns: 提供商的渲染前缀，如果未注册返回 nil
    func providerPrefix(for providerId: String) -> String?
    
    /// 获取所有已注册的提供商前缀
    /// - Returns: 所有前缀的集合
    func allProviderPrefixes() -> Set<String>
    
    /// 获取所有已注册的提供商 ID
    /// - Returns: 所有提供商 ID 的集合
    func allProviderIds() -> Set<String>
    
    /// 重置所有注册的提供商前缀（主要用于测试）
    func reset()
}

/// 提供商渲染种类管理器实现
///
/// 使用线程安全的方式管理提供商前缀注册表，支持并发访问。
public final class ProviderRenderKindManager: ProviderRenderKindManaging, @unchecked Sendable {
    /// 全局共享实例
    public static let shared = ProviderRenderKindManager()
    
    /// 提供商 ID 到前缀的映射
    private var prefixByProvider: [String: String] = [:]
    
    /// 前缀到提供商 ID 的映射（用于反向查找）
    private var providerByPrefix: [String: String] = [:]
    
    /// 读写锁，确保线程安全
    private let lock = NSLock()
    
    private init() {}
    
    public func registerProviderPrefix(_ prefix: String, for providerId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        prefixByProvider[providerId] = prefix
        providerByPrefix[prefix] = providerId
    }
    
    public func unregisterProviderPrefix(for providerId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if let prefix = prefixByProvider[providerId] {
            providerByPrefix.removeValue(forKey: prefix)
            prefixByProvider.removeValue(forKey: providerId)
        }
    }
    
    public func isProviderSpecificRenderKind(_ renderKind: String?) -> Bool {
        guard let renderKind = renderKind else { return false }
        
        lock.lock()
        defer { lock.unlock() }
        
        return providerByPrefix.keys.contains { prefix in
            renderKind.hasPrefix(prefix)
        }
    }
    
    public func isRenderKind(_ renderKind: String?, ownedBy providerId: String) -> Bool {
        guard let renderKind = renderKind else { return false }
        
        lock.lock()
        defer { lock.unlock() }
        
        guard let prefix = prefixByProvider[providerId] else { return false }
        return renderKind.hasPrefix(prefix)
    }
    
    public func providerPrefix(for providerId: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        return prefixByProvider[providerId]
    }
    
    public func allProviderPrefixes() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        
        return Set(providerByPrefix.keys)
    }
    
    public func allProviderIds() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        
        return Set(prefixByProvider.keys)
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        prefixByProvider.removeAll()
        providerByPrefix.removeAll()
    }
}
