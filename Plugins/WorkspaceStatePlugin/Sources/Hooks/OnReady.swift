import Foundation
import LumiKernel

/// WorkspaceState 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct WorkspaceStateOnReadyHook {
    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        let service = DefaultWorkspaceStateProviding()
        kernel.registerWorkspaceStateService(service)
    }
}
