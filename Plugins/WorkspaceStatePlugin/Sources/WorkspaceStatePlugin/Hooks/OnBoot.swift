import Foundation
import LumiKernel

/// WorkspaceState 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 WorkspaceState 服务注册,确保在 onReady 之前内核已持有 WorkspaceStateProviding。
@MainActor
public struct WorkspaceStateOnBootHook {
    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let service = DefaultWorkspaceStateProviding()
        kernel.registerWorkspaceStateService(service)
    }
}
