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
    case pluginDependencyMissing(pluginID: String, dependencyID: String)
    case pluginDependencyCycle(ids: [String])
    case invalidLifecycleOperation(operation: String, state: KernelLifecycleState)
    case asyncLifecycleRequired(pluginID: String)
    case pluginRequired(id: String)
    case pluginDependencyDisabled(pluginID: String, dependencyID: String)
    case contributionOwnerUnavailable
    /// 生命周期回调超过设定时限。
    case lifecycleTimeout(pluginID: String, phase: String)

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
        case .pluginDependencyMissing(let pluginID, let dependencyID):
            return "Plugin '\(pluginID)' requires missing plugin '\(dependencyID)'"
        case .pluginDependencyCycle(let ids):
            return "Plugin dependency cycle detected: \(ids.joined(separator: " -> "))"
        case .invalidLifecycleOperation(let operation, let state):
            return "Cannot \(operation) while kernel is \(state.rawValue)"
        case .asyncLifecycleRequired(let pluginID):
            return "Plugin '\(pluginID)' requires the asynchronous kernel lifecycle"
        case .pluginRequired(let id):
            return "Plugin '\(id)' is required and cannot be disabled"
        case .pluginDependencyDisabled(let pluginID, let dependencyID):
            return "Plugin '\(pluginID)' requires enabled plugin '\(dependencyID)'"
        case .contributionOwnerUnavailable:
            return "A plugin contribution must be registered during a plugin lifecycle callback or with an explicit owner"
        case .lifecycleTimeout(let pluginID, let phase):
            return "Plugin '\(pluginID)' exceeded the \(phase) lifecycle timeout"
        }
    }
}
