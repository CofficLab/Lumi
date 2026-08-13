import Foundation
import KernelLumi
import os

/// PromoDesigner 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的所有初始化逻辑：
/// - 配置 Runtime（注入 kernel 引用）
/// - 重新加载工作区任务列表
@MainActor
public struct PromoDesignerOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.promo-designer")

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: KernelLumi) async throws {
        Runtime.configure(kernel: kernel)
        WorkspaceStore.shared.reload()
    }
}
