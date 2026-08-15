import Foundation

/// KernelCore 错误
public enum KernelCoreError: Error, LocalizedError {
    /// 同类型 Provider 重复注册
    case providerAlreadyRegistered(type: Any.Type)
    /// 尝试注销不存在的 Provider（预留；当前 `unregisterProvider` 为幂等 no-op）
    case providerNotRegistered(type: Any.Type)
    /// 同 id 插件重复注入
    case pluginAlreadyRegistered(id: String)
    /// 尝试注销不存在的插件（预留；当前 `unregisterPlugin` 为幂等 no-op）
    case pluginNotFound(id: String)

    public var errorDescription: String? {
        switch self {
        case .providerAlreadyRegistered(let type):
            let typeName = String(reflecting: type)
            return "Provider '\(typeName)' is already registered"
        case .providerNotRegistered(let type):
            let typeName = String(reflecting: type)
            return "Provider '\(typeName)' is not registered"
        case .pluginAlreadyRegistered(let id):
            return "Plugin '\(id)' is already registered"
        case .pluginNotFound(let id):
            return "Plugin '\(id)' not found"
        }
    }
}
