import Foundation
import KernelCore
import ProviderPluginControl

/// 插件管理错误。
public enum PluginManagingError: Error, LocalizedError, Equatable {
    /// 内核尚未附加（宿主未调用 `attach(kernel:)` 或 init 未传 kernel）。
    case kernelNotAttached
    /// 指定 id 的插件不存在。
    case pluginNotFound(id: String)
    /// 生命周期操作失败（如卸载/重载时内核拒绝）。
    case lifecycle(String)

    public var errorDescription: String? {
        switch self {
        case .kernelNotAttached:
            return "Kernel is not attached"
        case let .pluginNotFound(id):
            return "Plugin '\(id)' not found"
        case let .lifecycle(message):
            return message
        }
    }
}
