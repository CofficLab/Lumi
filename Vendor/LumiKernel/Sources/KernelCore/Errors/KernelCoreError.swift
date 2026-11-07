import Foundation

/// KernelCore 错误
public enum KernelCoreError: Error, LocalizedError {
    /// 同类型 Provider 重复注册
    case providerAlreadyRegistered(type: Any.Type)
    /// 尝试注销不存在的 Provider（预留；当前 `unregisterProvider` 为幂等 no-op）
    case providerNotRegistered(type: Any.Type)
    /// 通过 `requireProvider` 请求必需的 Provider 但未注册
    case providerNotFound(type: Any.Type)
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
    /// 插件生命周期回调（Boot / Ready）抛出，包装原始错误并携带归属信息。
    ///
    /// - Important: 生命周期引擎在回滚前已经知道失败的插件，但原始错误
    ///   （如 `CocoaError`、`FileManager` 错误）自身不含任何归属线索，直接
    ///   上抛会让宿主只能看到「文件 xxx 不存在」而无法定位是哪块出的问题。
    ///   本 case 在此把 `pluginID` 与阶段固定到错误值里，供宿主直接展示或记录。
    case pluginLifecycleFailed(pluginID: String, phase: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .providerAlreadyRegistered(let type):
            let typeName = String(reflecting: type)
            return "Provider '\(typeName)' is already registered"
        case .providerNotRegistered(let type):
            let typeName = String(reflecting: type)
            return "Provider '\(typeName)' is not registered"
        case .providerNotFound(let type):
            let typeName = String(reflecting: type)
            return "Provider '\(typeName)' is not found"
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
        case .pluginLifecycleFailed(let pluginID, let phase, let underlying):
            // 归属信息放在最前面：宿主的启动失败页会整段展示这段文本，
            // 用户复制去排查时第一眼就能看到是哪个插件的哪个阶段。
            return "Plugin '\(pluginID)' failed during \(phase): \(underlying.localizedDescription)"
        }
    }

    /// 生命周期的归属信息（插件 ID、失败阶段、底层错误）。
    ///
    /// 宿主（例如 App 的启动失败页）通常需要把这些字段拆开展示，
    /// 而不只是拼接 `errorDescription`。
    public var lifecycleAttribution: (pluginID: String, phase: String, underlying: Error)? {
        if case .pluginLifecycleFailed(let pluginID, let phase, let underlying) = self {
            return (pluginID, phase, underlying)
        }
        return nil
    }
}

public extension Error {
    /// 当自身是 `pluginLifecycleFailed` 时返回归属信息，否则返回 nil。
    ///
    /// 让宿主可以直接对任意 `Error` 取归属，而不必先做类型转换。
    var lifecycleAttribution: (pluginID: String, phase: String, underlying: Error)? {
        (self as? KernelCoreError)?.lifecycleAttribution
    }
}
