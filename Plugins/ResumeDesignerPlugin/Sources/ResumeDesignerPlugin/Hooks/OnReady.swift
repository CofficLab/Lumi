import Foundation
import KernelLumi

/// ResumeDesigner 插件 OnReady 阶段钩子（预留，暂无逻辑）。
@MainActor
public struct ResumeDesignerOnReadyHook {
    public init() {}

    public func execute(_ kernel: KernelLumi) async throws {}
}
